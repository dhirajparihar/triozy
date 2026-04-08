import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/worker_model.dart';
import '../models/request_model.dart';
import '../models/mate_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Requests ───

  /// Post a new request
  Future<void> postRequest(RequestModel request) async {
    await _firestore.collection('jobs').doc(request.id).set(request.toMap(includeCreatedAt: true));
  }

  /// Update an existing request (only by the owner)
  Future<void> updateRequest(RequestModel request) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid != request.userId) {
      throw Exception('Unauthorized: you can only edit your own requests.');
    }
    await _firestore.collection('jobs').doc(request.id).update(request.toMap());
  }

  /// Delete a request posting (only by the owner)
  Future<void> deleteRequest(String requestId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Unauthorized: not logged in.');
    final doc = await _firestore.collection('jobs').doc(requestId).get();
    if (doc.exists && doc.data()?['userId'] != uid) {
      throw Exception('Unauthorized: you can only delete your own requests.');
    }
    await _firestore.collection('jobs').doc(requestId).delete();
  }

  /// Stream of requests posted by a specific user
  Stream<List<RequestModel>> getUserRequests(String userId) {
    return _firestore
        .collection('jobs')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort client-side to avoid needing a Firestore composite index
          requests.sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
          return requests;
        });
  }

  /// Stream of all requests in the system
  Stream<List<RequestModel>> getAllRequests() {
    return _firestore.collection('jobs').snapshots().map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort client-side to avoid needing a Firestore composite index
      requests.sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return requests;
    });
  }

  // ─── Workers ───

  /// Finds a worker document reference by querying on the uid field.
  /// Works for both old (uid-only) and new (Name_uid) document IDs.
  Future<DocumentReference?> _workerDocRef(String uid) async {
    final snap = await _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference;
    return null;
  }

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
    final snap = await _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return WorkerModel.fromMap(snap.docs.first.data());
    return null;
  }

  /// Stream a single worker document (real-time updates)
  Stream<WorkerModel?> streamWorker(String uid) {
    return _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty
            ? WorkerModel.fromMap(snap.docs.first.data())
            : null);
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
    final ref = await _workerDocRef(uid);
    await ref?.update({'isAvailable': available});
  }

  /// Increment the totalJobs (calls received) counter for a worker
  Future<void> incrementWorkerCalls(String workerId) async {
    final ref = await _workerDocRef(workerId);
    await ref?.update({'totalJobs': FieldValue.increment(1)});
  }

  /// Returns the rating (1-5) the given user previously gave this worker, or null if never rated.
  Future<double?> getUserRatingForWorker(String workerId, String userId) async {
    final workerRef = await _workerDocRef(workerId);
    if (workerRef == null) return null;
    final ratingDoc = await workerRef.collection('ratings').doc(userId).get();
    if (!ratingDoc.exists) return null;
    return (ratingDoc.data()!['stars'] as num?)?.toDouble();
  }

  /// Submit or update a star rating for a worker.
  /// Each user can only rate once; re-rating replaces the previous value.
  Future<void> submitWorkerRating(String workerId, String userId, double stars) async {
    final workerRef = await _workerDocRef(workerId);
    if (workerRef == null) return;
    final ratingRef = workerRef.collection('ratings').doc(userId);

    final workerDoc = await workerRef.get();
    if (!workerDoc.exists) return;

    final data = workerDoc.data()! as Map<String, dynamic>;
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

  // ─── Mates ───

  /// Post a new mate listing (roommate / helpmate / ridemate)
  Future<void> postMate(MateModel mate) async {
    await _firestore.collection('mates').doc(mate.id).set(mate.toMap());
  }

  /// Real-time stream of all mates of a given type, newest first
  Stream<List<MateModel>> streamMates(MateType type) {
    return _firestore
        .collection('mates')
        .where('type', isEqualTo: type.value)
        .snapshots()
        .map((snap) {
          final mates = snap.docs
              .map((doc) => MateModel.fromMap(doc.data(), doc.id))
              .toList();
          mates.sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
          );
          return mates;
        });
  }

  /// Stream of mates posted by the current user
  Stream<List<MateModel>> streamMyMates(String userId) {
    return _firestore
        .collection('mates')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final mates = snap.docs
              .map((doc) => MateModel.fromMap(doc.data(), doc.id))
              .toList();
          mates.sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
          );
          return mates;
        });
  }

  /// Delete a mate listing (only by the owner)
  Future<void> deleteMate(String mateId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Unauthorized: not logged in.');
    final doc = await _firestore.collection('mates').doc(mateId).get();
    if (doc.exists && doc.data()?['userId'] != uid) {
      throw Exception('Unauthorized: you can only delete your own listings.');
    }
    await _firestore.collection('mates').doc(mateId).delete();
  }

  /// Fetch the most recently posted mates across all types
  Future<List<MateModel>> getRecentMates({int limit = 8}) async {
    final snap = await _firestore.collection('mates').limit(30).get();
    final mates = snap.docs
        .map((doc) => MateModel.fromMap(doc.data(), doc.id))
        .toList();
    mates.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return mates.take(limit).toList();
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
