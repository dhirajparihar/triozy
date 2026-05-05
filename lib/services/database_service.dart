import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/listing_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      if (!listing.isFeatured) return false;
      return type == null || listing.type == type;
    }).toList();
    if (filtered.isNotEmpty) return filtered.take(limit).toList();
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
      if (type != null && listing.type != type) return false;
      if (category != null && listing.category != category) return false;
      if (maxPrice != null && listing.price > maxPrice) return false;
      if (featuredOnly && !listing.isFeatured) return false;
      if (q.isEmpty) return true;
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
      if (sample.id == listingId) return sample;
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
      if (data == null) return <String>{};
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
    if (savedIds.isEmpty) return [];

    final listings = await getAllListings();
    return listings.where((listing) => savedIds.contains(listing.id)).toList();
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final byId = await _firestore.collection('users').doc(uid).get();
    if (byId.exists) return byId.data();

    final fallback = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (fallback.docs.isNotEmpty) return fallback.docs.first.data();
    return null;
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
