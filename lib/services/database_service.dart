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

  /// Submit a star rating for a worker.
  /// Recalculates the average rating using a running average.
  Future<void> submitWorkerRating(String workerId, double stars) async {
    final doc = await _firestore.collection('workers').doc(workerId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final currentRating = (data['rating'] ?? 0).toDouble();
    final totalRatings = (data['totalRatings'] ?? 0).toInt();

    final newTotal = totalRatings + 1;
    final newAverage = ((currentRating * totalRatings) + stars) / newTotal;

    await _firestore.collection('workers').doc(workerId).update({
      'rating': double.parse(newAverage.toStringAsFixed(1)),
      'totalRatings': newTotal,
    });
  }

  // ─── Users ───

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) return doc.data();
    return null;
  }

  // ─── Seeding ───

  /// Helper to create a GeoFirePoint data map
  Map<String, dynamic> _geoData(double lat, double lng) {
    return GeoFirePoint(GeoPoint(lat, lng)).data;
  }

  /// Seed sample workers into Firestore (call once for development).
  /// Only seeds if sample data doesn't already exist.
  Future<void> seedWorkers() async {
    final existing = await _firestore
        .collection('workers')
        .doc('worker_alex_thompson')
        .get();
    if (existing.exists) return; // Already seeded

    // Sample worker data with coordinates (around New York area)
    final sampleWorkers = [
      {
        'uid': 'worker_alex_thompson',
        'name': 'Alex Thompson',
        'email': 'alex@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 123-4567',
        'skills': ['Electrician'],
        'serviceType': 'Electrician',

        'experience': 8,
        'location': 'Brooklyn, NY',
        'latitude': 40.6782,
        'longitude': -73.9442,
        'position': _geoData(40.6782, -73.9442),
        'rating': 4.9,
        'totalJobs': 342,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'Specializing in smart home integration and complex circuit repair. Precision-focused solutions with a lifetime guarantee on labor.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_elena_rodriguez',
        'name': 'Elena Rodriguez',
        'email': 'elena@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 234-5678',
        'skills': ['Plumber'],
        'serviceType': 'Plumber',

        'experience': 12,
        'location': 'Manhattan, NY',
        'latitude': 40.7831,
        'longitude': -73.9712,
        'position': _geoData(40.7831, -73.9712),
        'rating': 4.7,
        'totalJobs': 218,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'Expert in modern bathroom fixtures and water filtration systems. Certified eco-plumber with quick response times.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_marcus_chen',
        'name': 'Marcus Chen',
        'email': 'marcus@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 345-6789',
        'skills': ['AC Repair'],
        'serviceType': 'AC Repair',

        'experience': 15,
        'location': 'Queens, NY',
        'latitude': 40.7282,
        'longitude': -73.7949,
        'position': _geoData(40.7282, -73.7949),
        'rating': 4.8,
        'totalJobs': 456,
        'isAvailable': false,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'HVAC expert specializing in central air systems, duct repair, and energy-efficient installations.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_sarah_jenkins',
        'name': 'Sarah Jenkins',
        'email': 'sarah@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 456-7890',
        'skills': ['Plumber'],
        'serviceType': 'Plumber',

        'experience': 8,
        'location': 'Downtown, NY',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'position': _geoData(40.7128, -74.0060),
        'rating': 5.0,
        'totalJobs': 167,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'Installation specialist for modern bathroom fixtures and water filtration systems. Certified eco-plumber.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_david_park',
        'name': 'David Park',
        'email': 'david@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 567-8901',
        'skills': ['Electrician'],
        'serviceType': 'Electrician',

        'experience': 10,
        'location': 'North Heights, NY',
        'latitude': 40.6960,
        'longitude': -73.9936,
        'position': _geoData(40.6960, -73.9936),
        'rating': 4.6,
        'totalJobs': 289,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'Panel upgrades, rewiring, and EV charging station installation. Licensed and insured for commercial work.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_priya_sharma',
        'name': 'Priya Sharma',
        'email': 'priya@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 678-9012',
        'skills': ['AC Repair', 'Electrician'],
        'serviceType': 'AC Repair',

        'experience': 6,
        'location': 'East Riverside, NY',
        'latitude': 40.7180,
        'longitude': -73.9840,
        'position': _geoData(40.7180, -73.9840),
        'rating': 4.5,
        'totalJobs': 132,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'AC maintenance, repair, and installation. Also handles basic electrical work. Fast and reliable service.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_james_wilson',
        'name': 'James Wilson',
        'email': 'james@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 789-0123',
        'skills': ['Painter', 'Carpenter'],
        'serviceType': 'Painter',

        'experience': 20,
        'location': 'Brooklyn, NY',
        'latitude': 40.6501,
        'longitude': -73.9496,
        'position': _geoData(40.6501, -73.9496),
        'rating': 4.9,
        'totalJobs': 521,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'Master painter and carpenter. Interior/exterior painting, custom cabinetry, and finish carpentry.',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker_maria_gonzalez',
        'name': 'Maria Gonzalez',
        'email': 'maria@example.com',
        'photoUrl': '',
        'phone': '+1 (555) 890-1234',
        'skills': ['Carpenter'],
        'serviceType': 'Carpenter',

        'experience': 14,
        'location': 'Manhattan, NY',
        'latitude': 40.7589,
        'longitude': -73.9851,
        'position': _geoData(40.7589, -73.9851),
        'rating': 4.8,
        'totalJobs': 378,
        'isAvailable': true,
        'isSubscribed': true,
        'status': 'active',
        'description':
            'Custom furniture, kitchen remodeling, and structural woodwork. Precision craftsmanship guaranteed.',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (final workerData in sampleWorkers) {
      final uid = workerData['uid'] as String;
      batch.set(_firestore.collection('workers').doc(uid), workerData);
    }
    await batch.commit();
  }
}
