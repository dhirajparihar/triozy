import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/worker_model.dart';
import '../models/job_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Jobs ───

  /// Post a new job
  Future<void> postJob(JobModel job) async {
    await _firestore.collection('jobs').doc(job.id).set(job.toMap(includeCreatedAt: true));
  }

  /// Update an existing job (only by the owner)
  Future<void> updateJob(JobModel job) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid != job.userId) {
      throw Exception('Unauthorized: you can only edit your own jobs.');
    }
    await _firestore.collection('jobs').doc(job.id).update(job.toMap());
  }

  /// Delete a job posting (only by the owner)
  Future<void> deleteJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Unauthorized: not logged in.');
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (doc.exists && doc.data()?['userId'] != uid) {
      throw Exception('Unauthorized: you can only delete your own jobs.');
    }
    await _firestore.collection('jobs').doc(jobId).delete();
  }

  /// Stream of jobs posted by a specific user
  Stream<List<JobModel>> getUserJobs(String userId) {
    return _firestore
        .collection('jobs')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort client-side to avoid needing a Firestore composite index
          jobs.sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
          return jobs;
        });
  }

  /// Stream of all jobs in the system
  Stream<List<JobModel>> getAllJobs() {
    return _firestore.collection('jobs').snapshots().map((snapshot) {
      final jobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort client-side to avoid needing a Firestore composite index
      jobs.sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return jobs;
    });
  }

  // ─── Workers ───

  /// Get all workers
  Future<List<WorkerModel>> getAllWorkers() async {
    final snapshot = await _firestore
        .collection('workers')
        .orderBy('rating', descending: true)
        .get();
    return snapshot.docs.map((doc) => WorkerModel.fromMap(doc.data())).toList();
  }

  /// Get workers by service type / category
  Future<List<WorkerModel>> getWorkersByCategory(String category) async {
    if (category == 'All Services' || category.isEmpty) {
      return getAllWorkers();
    }
    // Normalize: "Electricians" → "Electrician", "Plumbers" → "Plumber"
    String normalized = category;
    if (normalized.endsWith('s') && !normalized.endsWith('ss')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final snapshot = await _firestore
        .collection('workers')
        .where('skills', arrayContains: normalized)
        .get();
    return snapshot.docs.map((doc) => WorkerModel.fromMap(doc.data())).toList();
  }

  /// Get top rated workers (limit)
  Future<List<WorkerModel>> getTopWorkers({int limit = 5}) async {
    final snapshot = await _firestore
        .collection('workers')
        .where('isAvailable', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => WorkerModel.fromMap(doc.data())).toList();
  }

  /// Get single worker by uid
  Future<WorkerModel?> getWorker(String uid) async {
    final doc = await _firestore.collection('workers').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return WorkerModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Stream a single worker document (real-time updates)
  Stream<WorkerModel?> streamWorker(String uid) {
    return _firestore.collection('workers').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return WorkerModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  /// Search workers by name or skill
  Future<List<WorkerModel>> searchWorkers(String query) async {
    if (query.trim().isEmpty) return getAllWorkers();

    // Firestore doesn't support full-text search natively.
    // We fetch all workers and filter client-side for simplicity.
    final all = await getAllWorkers();
    final q = query.toLowerCase();
    return all.where((w) {
      return w.name.toLowerCase().contains(q) ||
          w.serviceType.toLowerCase().contains(q) ||
          w.skills.any((s) => s.toLowerCase().contains(q)) ||
          w.location.toLowerCase().contains(q) ||
          w.description.toLowerCase().contains(q);
    }).toList();
  }

  /// Update worker availability (only by the worker themselves)
  Future<void> setWorkerAvailability(String uid, bool available) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      throw Exception('Unauthorized: you can only change your own availability.');
    }
    await _firestore.collection('workers').doc(uid).update({
      'isAvailable': available,
    });
  }

  /// Increment the totalJobs (calls received) counter for a worker
  Future<void> incrementWorkerCalls(String workerId) async {
    await _firestore.collection('workers').doc(workerId).update({
      'totalJobs': FieldValue.increment(1),
    });
  }

  /// Returns the rating (1-5) the given user previously gave this worker, or null if never rated.
  Future<double?> getUserRatingForWorker(String workerId, String userId) async {
    final ratingDoc = await _firestore
        .collection('workers')
        .doc(workerId)
        .collection('ratings')
        .doc(userId)
        .get();
    if (!ratingDoc.exists) return null;
    return (ratingDoc.data()!['stars'] as num?)?.toDouble();
  }

  /// Submit or update a star rating for a worker.
  /// Each user can only rate once; re-rating replaces the previous value.
  Future<void> submitWorkerRating(String workerId, String userId, double stars) async {
    final workerRef = _firestore.collection('workers').doc(workerId);
    final ratingRef = workerRef.collection('ratings').doc(userId);

    final workerDoc = await workerRef.get();
    if (!workerDoc.exists) return;

    final data = workerDoc.data()!;
    double currentRating = (data['rating'] ?? 0).toDouble();
    int totalRatings = (data['totalRatings'] ?? 0).toInt();

    final prevRatingDoc = await ratingRef.get();
    double newAverage;
    int newTotal;

    if (prevRatingDoc.exists) {
      // Replace existing rating: remove old, add new
      final oldStars = (prevRatingDoc.data()!['stars'] as num).toDouble();
      // totalRatings stays the same
      newTotal = totalRatings;
      newAverage = totalRatings == 0
          ? stars
          : ((currentRating * totalRatings) - oldStars + stars) / totalRatings;
    } else {
      newTotal = totalRatings + 1;
      newAverage = ((currentRating * totalRatings) + stars) / newTotal;
    }

    await Future.wait([
      workerRef.update({
        'rating': double.parse(newAverage.toStringAsFixed(1)),
        'totalRatings': newTotal,
      }),
      ratingRef.set({'stars': stars, 'updatedAt': FieldValue.serverTimestamp()}),
    ]);
  }

  // ─── Users ───

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snap = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.data();
    return null;
  }

}
