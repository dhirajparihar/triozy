import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/listing_model.dart';
import '../models/requirement_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createListing(ListingModel listing) async {
    await _firestore
        .collection('listings')
        .doc(listing.id)
        .set(listing.toMap(includeCreatedAt: true));
  }

  Future<List<ListingModel>> getAllListings() async {
    final snapshot = await _firestore.collection('listings').limit(300).get();
    final listings = snapshot.docs
        .map((doc) => ListingModel.fromMap(doc.data(), doc.id))
        .toList();
    listings.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return listings;
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
    PropertyType? propertyType,
    ListingPurpose? purpose,
    double? maxPrice,
    bool featuredOnly = false,
  }) async {
    final listings = await getAllListings();
    final q = query.trim().toLowerCase();

    return listings.where((listing) {
      if (type != null && listing.type != type) return false;
      if (propertyType != null && listing.propertyType != propertyType) {
        return false;
      }
      if (purpose != null && listing.purpose != purpose) return false;
      if (maxPrice != null && listing.price > maxPrice) return false;
      if (featuredOnly && !listing.isFeatured) return false;
      if (q.isEmpty) return true;
      final requirement = listing.requirementDetails;
      return listing.title.toLowerCase().contains(q) ||
          listing.description.toLowerCase().contains(q) ||
          listing.location.toLowerCase().contains(q) ||
          listing.propertyTypeLabel.toLowerCase().contains(q) ||
          listing.purposeLabel.toLowerCase().contains(q) ||
          (requirement != null &&
              (requirement.needType.label.toLowerCase().contains(q) ||
                  requirement.amenities.any(
                    (item) => item.toLowerCase().contains(q),
                  ) ||
                  requirement.lifestyle.any(
                    (item) => item.toLowerCase().contains(q),
                  )));
    }).toList();
  }

  Future<ListingModel?> getListing(String listingId) async {
    final byId = await _firestore.collection('listings').doc(listingId).get();
    if (byId.exists) {
      return ListingModel.fromMap(byId.data()!, byId.id);
    }
    return null;
  }

  Future<void> deleteListing({
    required String listingId,
    required String userId,
  }) async {
    final listingRef = _firestore.collection('listings').doc(listingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(listingRef);
      if (!snapshot.exists) {
        return;
      }

      final ownerId = (snapshot.data()?['ownerId'] ?? '').toString();
      if (ownerId != userId) {
        throw StateError('Only the listing owner can delete this listing');
      }

      transaction.delete(listingRef);
    });
  }

  Future<bool> hasUserPostedListing(String userId) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
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
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
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
}
