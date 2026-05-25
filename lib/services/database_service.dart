import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing_model.dart';
import '../models/requirement_model.dart';


// === Firestore data access ===================================================

/// Centralized Firestore access for listings and user data.
///
/// Keeps reads/writes in one place and applies lightweight client-side
/// filtering to keep UI widgets simple.
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a new listing document using the model's id.
  Future<void> createListing(ListingModel listing) async {
    await _firestore
        .collection('listings')
        .doc(listing.id)
        .set(listing.toMap(includeCreatedAt: true));
  }

  /// Fetches up to 300 listings and sorts them by newest first.
  /// If [fetchAll] is false, only approved listings are returned.
  Future<List<ListingModel>> getAllListings({bool fetchAll = false}) async {
    Query query = _firestore.collection('listings');
    if (!fetchAll) {
      query = query.where('isApproved', isEqualTo: true);
    }
    final snapshot = await query.limit(300).get();
    final listings = snapshot.docs
        .map((doc) => ListingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    listings.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return listings;
  }

  /// Marks a listing as approved (Admin only).
  Future<void> adminApproveListing(String listingId) async {
    await _firestore.collection('listings').doc(listingId).update({
      'isApproved': true,
    });
  }

  /// Deletes a listing regardless of ownership (Admin only).
  Future<void> adminDeleteListing(String listingId) async {
    await _firestore.collection('listings').doc(listingId).delete();
    await markChatsAsListingDeleted(listingId);
  }

  /// Fetches all users (Admin only)
  Future<List<Map<String, dynamic>>> adminGetAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Returns featured listings, falling back to recent ones if none match.
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

  /// Returns recent listings (optionally filtered by type).
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

  /// Searches listings by text and optional filters.
  ///
  /// This is client-side filtering over the cached list, which keeps the
  /// query simple and supports composite search fields.
  Future<List<ListingModel>> searchListings({
    String query = '',
    ListingType? type,
    PropertyType? propertyType,
    ListingPurpose? purpose,
    double? maxPrice,
    bool featuredOnly = false,
    double? lat,
    double? lon,
    String locationName = '',
    double radiusKm = 50.0,
  }) async {
    final listings = await getAllListings();
    final q = query.trim().toLowerCase();
    final locationTerms = locationName
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.length > 2)
        .toSet();

    return listings.where((listing) {
      if (type != null && listing.type != type) return false;
      if (propertyType != null && listing.propertyType != propertyType) {
        return false;
      }
      if (purpose != null && listing.purpose != purpose) return false;
      if (maxPrice != null && listing.price > maxPrice) return false;
      if (featuredOnly && !listing.isFeatured) return false;

      // Proximity Filtering
      if (lat != null && lon != null) {
        bool isNearby = false;
        if (listing.latitude != null && listing.longitude != null) {
          final distance = _haversineKm(
            lat, lon, listing.latitude!, listing.longitude!,
          );
          if (distance <= radiusKm) {
            isNearby = true;
          }
        } else if (locationTerms.isNotEmpty) {
          final loc = listing.location.toLowerCase();
          if (locationTerms.any((term) => loc.contains(term))) {
            isNearby = true;
          }
        }
        if (!isNearby) return false;
      }

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

  /// Fetches a single listing by id.
  Future<ListingModel?> getListing(String listingId) async {
    final byId = await _firestore.collection('listings').doc(listingId).get();
    if (byId.exists) {
      return ListingModel.fromMap(byId.data()!, byId.id);
    }
    return null;
  }

  /// Deletes a listing only if the requester is the owner.
  ///
  /// Uses a transaction to prevent stale ownership reads.
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

  /// Marks chat threads as deleted when a listing is removed.
  Future<void> markChatsAsListingDeleted(String listingId) async {
    final chatQuery = await _firestore
        .collection('chats')
        .where('referenceId', isEqualTo: listingId)
        .get();
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final doc in chatQuery.docs) {
      batch.update(doc.reference, {
        'referenceDeleted': true,
        'referenceDeletedAt': now,
      });
    }

    await batch.commit();
  }

  /// Checks whether a user has posted any listing.
  Future<bool> hasUserPostedListing(String userId) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Checks whether a user has posted a housing listing.
  Future<bool> hasUserPostedHousingListing(String userId) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('ownerId', isEqualTo: userId)
        .where('type', isEqualTo: ListingType.housing.value)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Checks whether a user has published a housing requirement listing.
  Future<bool> hasUserPublishedRequirement(String userId) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('ownerId', isEqualTo: userId)
        .where('type', isEqualTo: ListingType.housing.value)
        .where('purpose', isEqualTo: ListingPurpose.needPlace.value)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Streams the current user's listings ordered by newest first.
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

  /// Streams the current user's saved listing ids.
  Stream<Set<String>> streamSavedListingIds(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return <String>{};
      return Set<String>.from(data['savedListingIds'] ?? const <String>[]);
    });
  }

  /// Adds or removes a listing from the user's saved list.
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

  /// Returns saved listings by id for the given user.
  Future<List<ListingModel>> getSavedListings(String userId) async {
    final userSnap = await _firestore.collection('users').doc(userId).get();
    final savedIds = List<String>.from(
      userSnap.data()?['savedListingIds'] ?? const <String>[],
    );
    if (savedIds.isEmpty) return [];

    final listings = await getAllListings();
    return listings.where((listing) => savedIds.contains(listing.id)).toList();
  }

  /// Fetches user data only when the requested uid matches the current user.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId != uid) {
      return null;
    }

    final byId = await _firestore.collection('users').doc(uid).get();
    return byId.data();
  }

  /// Returns listings within [radiusKm] of [lat]/[lon].
  /// Falls back to text-matching on [locationName] for listings without coords.
  Future<List<ListingModel>> getNearbyListings({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
    String locationName = '',
  }) async {
    final listings = await getAllListings();
    final locationTerms = locationName
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.length > 2)
        .toSet();

    final results = <ListingModel>[];
    for (final listing in listings) {
      if (listing.latitude != null && listing.longitude != null) {
        // Haversine distance check
        final distance = _haversineKm(
          lat, lon, listing.latitude!, listing.longitude!,
        );
        if (distance <= radiusKm) {
          results.add(listing);
        }
      } else if (locationTerms.isNotEmpty) {
        // Fallback: text-based matching — any term matches the location string
        final loc = listing.location.toLowerCase();
        if (locationTerms.any((term) => loc.contains(term))) {
          results.add(listing);
        }
      }
    }
    return results;
  }

  /// Haversine formula — returns distance in kilometres between two points.
  static double _haversineKm(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}
