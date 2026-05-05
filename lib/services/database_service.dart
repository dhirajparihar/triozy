import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/listing_model.dart';
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

  /// Finds worker document by canonical doc id (uid) first, then legacy uid-field query.
  Future<DocumentReference<Map<String, dynamic>>?> _workerDocRef(String uid) async {
    final byId = _firestore.collection('workers').doc(uid);
    final byIdSnap = await byId.get();
    if (byIdSnap.exists) return byId;

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
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['uid'] = (data['uid'] == null || '${data['uid']}'.trim().isEmpty)
              ? doc.id
              : data['uid'];
          return WorkerModel.fromMap(data);
        })
        .toList();
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
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['uid'] = (data['uid'] == null || '${data['uid']}'.trim().isEmpty)
              ? doc.id
              : data['uid'];
          return WorkerModel.fromMap(data);
        })
        .toList();
  }

  /// Get top rated workers (limit)
  Future<List<WorkerModel>> getTopWorkers({int limit = 5}) async {
    final snapshot = await _firestore
        .collection('workers')
        .where('isAvailable', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['uid'] = (data['uid'] == null || '${data['uid']}'.trim().isEmpty)
              ? doc.id
              : data['uid'];
          return WorkerModel.fromMap(data);
        })
        .toList();
  }

  /// Get single worker by uid
  Future<WorkerModel?> getWorker(String uid) async {
    final byId = await _firestore.collection('workers').doc(uid).get();
    if (byId.exists) {
      final data = Map<String, dynamic>.from(byId.data()!);
      data['uid'] = (data['uid'] == null || '${data['uid']}'.trim().isEmpty)
          ? byId.id
          : data['uid'];
      return WorkerModel.fromMap(data);
    }

    final snap = await _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final data = Map<String, dynamic>.from(doc.data());
      data['uid'] = (data['uid'] == null || '${data['uid']}'.trim().isEmpty)
          ? doc.id
          : data['uid'];
      return WorkerModel.fromMap(data);
    }
    return null;
  }

  /// Stream a single worker document (real-time updates)
  Stream<WorkerModel?> streamWorker(String uid) {
    return _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) {
            return null;
          }
          final doc = snap.docs.first;
          final data = Map<String, dynamic>.from(doc.data());
          data['uid'] = (data['uid'] == null || '${data['uid']}'.trim().isEmpty)
              ? doc.id
              : data['uid'];
          return WorkerModel.fromMap(data);
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
    final safeStars = stars.clamp(1.0, 5.0).toDouble();
    final workerRef = await _workerDocRef(workerId);
    if (workerRef == null) return;
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
          ? safeStars
          : ((currentRating * totalRatings) - oldStars + safeStars) / totalRatings;
    } else {
      newTotal = totalRatings + 1;
      newAverage = ((currentRating * totalRatings) + safeStars) / newTotal;
    }
    final clampedAverage = newAverage.clamp(0.0, 5.0).toDouble();

    await Future.wait([
      workerRef.update({
        'rating': double.parse(clampedAverage.toStringAsFixed(1)),
        'totalRatings': newTotal,
      }),
      ratingRef.set({
        'stars': safeStars,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
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

  /// Update an existing mate listing (only by the owner)
  Future<void> updateMate(MateModel mate) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Unauthorized: not logged in.');
    if (mate.userId != uid) throw Exception('Unauthorized: you can only edit your own listings.');
    await _firestore.collection('mates').doc(mate.id).update(mate.toMap(includeCreatedAt: false));
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
  /// Fallback strategy for mates:
  /// 1) Within [radiusKm]
  /// 2) Same city (string match in mate.location)
  /// 3) Same state (string match in mate.location)
  /// 4) Most recent
  Future<List<MateModel>> getNearbyMatesWithFallback({
    required double latitude,
    required double longitude,
    String? city,
    String? state,
    int limit = 8,
    double radiusKm = 25,
  }) async {
    final snap = await _firestore.collection('mates').limit(300).get();
    final mates = snap.docs
        .map((doc) => MateModel.fromMap(doc.data(), doc.id))
        .toList();
    mates.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );

    final near = <MapEntry<MateModel, double>>[];
    for (final mate in mates) {
      final lat = mate.latitude;
      final lng = mate.longitude;
      if (lat == null || lng == null) continue;

      final distanceKm = Geolocator.distanceBetween(
            latitude,
            longitude,
            lat,
            lng,
          ) /
          1000;
      if (distanceKm <= radiusKm) {
        near.add(MapEntry(mate, distanceKm));
      }
    }

    if (near.isNotEmpty) {
      near.sort((a, b) => a.value.compareTo(b.value));
      return near.map((e) => e.key).take(limit).toList();
    }

    String norm(String s) => s.toLowerCase().trim();

    if (city != null && city.trim().isNotEmpty) {
      final cityNorm = norm(city);
      final cityMatches = mates
          .where((m) => norm(m.location).contains(cityNorm))
          .take(limit)
          .toList();
      if (cityMatches.isNotEmpty) return cityMatches;
    }

    if (state != null && state.trim().isNotEmpty) {
      final stateNorm = norm(state);
      final stateMatches = mates
          .where((m) => norm(m.location).contains(stateNorm))
          .take(limit)
          .toList();
      if (stateMatches.isNotEmpty) return stateMatches;
    }

    return mates.take(limit).toList();
  }
  // ─── Users ───

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final byId = await _firestore.collection('users').doc(uid).get();
      if (byId.exists) return byId.data();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      return null;
    }
    try {
      final fallback = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (fallback.docs.isNotEmpty) return fallback.docs.first.data();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      return null;
    }
    return null;
  }

  Future<void> createListing(ListingModel listing) async {
    await _firestore
        .collection('listings')
        .doc(listing.id)
        .set(listing.toMap(includeCreatedAt: true));
  }

  Future<List<ListingModel>> getAllListings() async {
    final snapshot = await _firestore.collection('listings').limit(80).get();
    final listings = snapshot.docs
        .map((doc) => ListingModel.fromMap(doc.data(), doc.id))
        .toList();
    listings.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    if (listings.isNotEmpty) {
      return listings;
    }
    return _sampleListings();
  }

  Future<List<ListingModel>> getFeaturedListings({
    ListingType? type,
    int limit = 6,
  }) async {
    final listings = await getAllListings();
    final filtered = listings.where((listing) {
      if (!listing.isFeatured) {
        return false;
      }
      return type == null || listing.type == type;
    }).toList();
    if (filtered.isNotEmpty) {
      return filtered.take(limit).toList();
    }
    return listings
        .where((listing) => type == null || listing.type == type)
        .take(limit)
        .toList();
  }

  Future<List<ListingModel>> getRecentListings({
    ListingType? type,
    int limit = 8,
  }) async {
    final listings = await getAllListings();
    return listings
        .where((listing) => type == null || listing.type == type)
        .take(limit)
        .toList();
  }

  Future<List<ListingModel>> searchListings({
    String query = '',
    ListingType? type,
    ListingCategory? category,
    double? maxPrice,
    bool featuredOnly = false,
  }) async {
    final listings = await getAllListings();
    final q = query.trim().toLowerCase();

    return listings.where((listing) {
      if (type != null && listing.type != type) {
        return false;
      }
      if (category != null && listing.category != category) {
        return false;
      }
      if (maxPrice != null && listing.price > maxPrice) {
        return false;
      }
      if (featuredOnly && !listing.isFeatured) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      return listing.title.toLowerCase().contains(q) ||
          listing.description.toLowerCase().contains(q) ||
          listing.location.toLowerCase().contains(q) ||
          listing.categoryLabel.toLowerCase().contains(q);
    }).toList();
  }

  Future<ListingModel?> getListing(String listingId) async {
    final byId = await _firestore.collection('listings').doc(listingId).get();
    if (byId.exists) {
      return ListingModel.fromMap(byId.data()!, byId.id);
    }

    for (final sample in _sampleListings()) {
      if (sample.id == listingId) {
        return sample;
      }
    }
    return null;
  }

  Stream<List<ListingModel>> streamUserListings(String userId) {
    return _firestore
        .collection('listings')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final listings = snapshot.docs
              .map((doc) => ListingModel.fromMap(doc.data(), doc.id))
              .toList();
          listings.sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
          );
          return listings;
        });
  }

  Stream<Set<String>> streamSavedListingIds(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) {
        return <String>{};
      }
      return Set<String>.from(data['savedListingIds'] ?? const <String>[]);
    });
  }

  Future<void> toggleSavedListing({
    required String userId,
    required String listingId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final snapshot = await userRef.get();
    final savedIds = Set<String>.from(
      snapshot.data()?['savedListingIds'] ?? const <String>[],
    );

    if (savedIds.contains(listingId)) {
      await userRef.set({
        'savedListingIds': FieldValue.arrayRemove([listingId]),
      }, SetOptions(merge: true));
      return;
    }

    await userRef.set({
      'savedListingIds': FieldValue.arrayUnion([listingId]),
    }, SetOptions(merge: true));
  }

  Future<List<ListingModel>> getSavedListings(String userId) async {
    final userSnap = await _firestore.collection('users').doc(userId).get();
    final savedIds = List<String>.from(
      userSnap.data()?['savedListingIds'] ?? const <String>[],
    );
    if (savedIds.isEmpty) {
      return [];
    }

    final listings = await getAllListings();
    return listings.where((listing) => savedIds.contains(listing.id)).toList();
  }

  List<ListingModel> _sampleListings() {
    final now = DateTime.now();
    return [
      ListingModel(
        id: 'sample-room-1',
        ownerId: 'demo-owner-1',
        ownerName: 'Aarav S',
        title: 'Sunny room near Indiranagar metro',
        description:
            'Private furnished room in a 2BHK with Wi-Fi, washing machine, and a quiet study corner.',
        location: 'Indiranagar, Bengaluru',
        price: 14500,
        type: ListingType.housing,
        category: ListingCategory.room,
        imageUrls: const [
          'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=1200&q=80',
        ],
        highlights: const ['Furnished', 'Wi-Fi', 'Metro 8 min'],
        furnishing: 'Fully furnished',
        genderPreference: 'Any',
        availableFrom: 'Available now',
        isFeatured: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      ListingModel(
        id: 'sample-pg-1',
        ownerId: 'demo-owner-2',
        ownerName: 'Triozy Host',
        title: 'Modern PG for working professionals',
        description:
            'Clean PG with meals, housekeeping, power backup, and biometric entry.',
        location: 'Gachibowli, Hyderabad',
        price: 9800,
        type: ListingType.housing,
        category: ListingCategory.pg,
        imageUrls: const [
          'https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1200&q=80',
        ],
        highlights: const ['Meals included', 'Housekeeping', 'Girls only'],
        genderPreference: 'Female',
        furnishing: 'Semi furnished',
        availableFrom: 'Move in this week',
        isFeatured: true,
        createdAt: now.subtract(const Duration(hours: 7)),
      ),
      ListingModel(
        id: 'sample-flatmate-1',
        ownerId: 'demo-owner-3',
        ownerName: 'Neha R',
        title: 'Looking for a flatmate in a 3BHK near HSR',
        description:
            'One room opens next month. Ideal for someone working in Koramangala or HSR.',
        location: 'HSR Layout, Bengaluru',
        price: 12000,
        type: ListingType.housing,
        category: ListingCategory.flatmate,
        imageUrls: const [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80',
        ],
        highlights: const ['Students welcome', 'No brokerage', 'Balcony'],
        genderPreference: 'Female',
        furnishing: 'Fully furnished',
        availableFrom: 'Available from 15 May',
        isFeatured: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ListingModel(
        id: 'sample-flat-1',
        ownerId: 'demo-owner-4',
        ownerName: 'Rahul K',
        title: 'Compact studio flat close to business park',
        description:
            'Ideal starter flat with attached kitchen and dedicated work setup.',
        location: 'Hinjewadi, Pune',
        price: 18500,
        type: ListingType.housing,
        category: ListingCategory.flat,
        imageUrls: const [
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80',
        ],
        highlights: const ['Studio', 'Work desk', 'Parking'],
        furnishing: 'Fully furnished',
        availableFrom: 'Ready to move',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ListingModel(
        id: 'sample-item-1',
        ownerId: 'demo-owner-5',
        ownerName: 'Kabir M',
        title: 'Study table + ergonomic chair combo',
        description:
            'Selling a clean workstation setup, perfect for a new move or hostel room.',
        location: 'Kothrud, Pune',
        price: 4200,
        type: ListingType.marketplace,
        category: ListingCategory.item,
        imageUrls: const [
          'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?auto=format&fit=crop&w=1200&q=80',
        ],
        highlights: const ['Good condition', 'Pickup today', 'Negotiable'],
        condition: 'Used - Good',
        isFeatured: true,
        createdAt: now.subtract(const Duration(hours: 10)),
      ),
      ListingModel(
        id: 'sample-item-2',
        ownerId: 'demo-owner-6',
        ownerName: 'Maya D',
        title: 'Mini fridge for hostel or studio',
        description:
            'Compact cooling unit, serviced recently, easy to move in a hatchback.',
        location: 'Viman Nagar, Pune',
        price: 6500,
        type: ListingType.marketplace,
        category: ListingCategory.item,
        imageUrls: const [
          'https://images.unsplash.com/photo-1584568694244-14fbdf83bd30?auto=format&fit=crop&w=1200&q=80',
        ],
        highlights: const ['Low power', '1 year old', 'Fast pickup'],
        condition: 'Used - Like New',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

}

