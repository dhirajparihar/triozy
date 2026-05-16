import 'package:cloud_firestore/cloud_firestore.dart';

import 'requirement_model.dart';


// === Listing enums ===========================================================

/// High-level listing category.
enum ListingType { housing, marketplace }

/// Convenience helpers for serializing and labeling [ListingType].
extension ListingTypeX on ListingType {
  String get value {
    switch (this) {
      case ListingType.housing:
        return 'housing';
      case ListingType.marketplace:
        return 'marketplace';
    }
  }

  String get label {
    switch (this) {
      case ListingType.housing:
        return 'Housing';
      case ListingType.marketplace:
        return 'Marketplace';
    }
  }

  static ListingType fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'marketplace':
        return ListingType.marketplace;
      case 'housing':
      default:
        return ListingType.housing;
    }
  }
}

/// Property subtype for a listing.
enum PropertyType { room, flat, pg, item }

/// Convenience helpers for serializing and labeling [PropertyType].
extension PropertyTypeX on PropertyType {
  String get value {
    switch (this) {
      case PropertyType.room:
        return 'room';
      case PropertyType.flat:
        return 'flat';
      case PropertyType.pg:
        return 'pg';
      case PropertyType.item:
        return 'item';
    }
  }

  String get label {
    switch (this) {
      case PropertyType.room:
        return 'Room';
      case PropertyType.flat:
        return 'Flat';
      case PropertyType.pg:
        return 'PG';
      case PropertyType.item:
        return 'Item';
    }
  }

  ListingType get listingType {
    switch (this) {
      case PropertyType.item:
        return ListingType.marketplace;
      case PropertyType.room:
      case PropertyType.flat:
      case PropertyType.pg:
        return ListingType.housing;
    }
  }

  static PropertyType fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pg':
      case 'hostel':
        return PropertyType.pg;
      case 'flat':
      case 'apartment':
        return PropertyType.flat;
      case 'item':
      case 'marketplace':
        return PropertyType.item;
      case 'flatmate':
        return PropertyType.flat;
      case 'room':
      default:
        return PropertyType.room;
    }
  }
}

/// Intent of the listing (looking vs offering vs selling).
enum ListingPurpose {
  needPlace,
  needRoommate,
  offerProperty,
  marketplaceSell,
}

/// Convenience helpers for serializing and labeling [ListingPurpose].
extension ListingPurposeX on ListingPurpose {
  String get value {
    switch (this) {
      case ListingPurpose.needPlace:
        return 'needPlace';
      case ListingPurpose.needRoommate:
        return 'needRoommate';
      case ListingPurpose.offerProperty:
        return 'offerProperty';
      case ListingPurpose.marketplaceSell:
        return 'marketplaceSell';
    }
  }

  String get label {
    switch (this) {
      case ListingPurpose.needPlace:
        return 'Looking for place';
      case ListingPurpose.needRoommate:
        return 'Looking for roommate';
      case ListingPurpose.offerProperty:
        return 'Property available';
      case ListingPurpose.marketplaceSell:
        return 'For sale';
    }
  }

  static ListingPurpose fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'needplace':
      case 'need_place':
      case 'requirement':
        return ListingPurpose.needPlace;
      case 'needroommate':
      case 'need_roommate':
      case 'flatmate':
        return ListingPurpose.needRoommate;
      case 'marketplacesell':
      case 'marketplace_sell':
      case 'sell':
        return ListingPurpose.marketplaceSell;
      case 'offerproperty':
      case 'offer_property':
      case 'owner':
      default:
        return ListingPurpose.offerProperty;
    }
  }
}


// === Listing model ===========================================================

/// Primary listing model used across housing and marketplace flows.
class ListingModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhotoUrl;
  final String title;
  final String description;
  final String location;
  final double? latitude;
  final double? longitude;
  final double price;
  final ListingType type;
  final PropertyType propertyType;
  final List<String> imageUrls;
  final List<String> highlights;
  final String? genderPreference;
  final String? condition;
  final String? furnishing;
  final String? availableFrom;
  final ListingPurpose purpose;
  final RequirementModel? requirementDetails;
  final bool isFeatured;
  final DateTime? createdAt;

  const ListingModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    this.ownerPhotoUrl = '',
    required this.title,
    required this.description,
    required this.location,
    this.latitude,
    this.longitude,
    required this.price,
    required this.type,
    required this.propertyType,
    this.imageUrls = const [],
    this.highlights = const [],
    this.genderPreference,
    this.condition,
    this.furnishing,
    this.availableFrom,
    this.purpose = ListingPurpose.offerProperty,
    this.requirementDetails,
    this.isFeatured = false,
    this.createdAt,
  }) : assert(
          (type == ListingType.marketplace &&
                  propertyType == PropertyType.item &&
                  purpose == ListingPurpose.marketplaceSell) ||
              (type == ListingType.housing &&
                  propertyType != PropertyType.item &&
                  purpose != ListingPurpose.marketplaceSell &&
                  (purpose != ListingPurpose.needRoommate ||
                      propertyType != PropertyType.pg)),
          'Invalid listing type, property type, and purpose combination',
        );

  /// Builds a [ListingModel] from Firestore data.
  factory ListingModel.fromMap(Map<String, dynamic> map, String docId) {
    final normalized = _normalizeListingFields(map);

    return ListingModel(
      id: docId,
      ownerId: (map['ownerId'] ?? '').toString(),
      ownerName: (map['ownerName'] ?? '').toString(),
      ownerPhotoUrl: (map['ownerPhotoUrl'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      type: normalized.$1,
      propertyType: normalized.$2,
      imageUrls: List<String>.from(map['imageUrls'] ?? const <String>[]),
      highlights: List<String>.from(map['highlights'] ?? const <String>[]),
      genderPreference: map['genderPreference'] as String?,
      condition: map['condition'] as String?,
      furnishing: map['furnishing'] as String?,
      availableFrom: map['availableFrom'] as String?,
      purpose: normalized.$3,
      requirementDetails: _requirementDetailsFromMap(
        map,
        docId,
        normalized.$3,
      ),
      isFeatured: map['isFeatured'] as bool? ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Serializes this listing to a Firestore-friendly map.
  Map<String, dynamic> toMap({bool includeCreatedAt = true}) {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhotoUrl': ownerPhotoUrl,
      'title': title,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'price': price,
      'type': type.value,
      'propertyType': propertyType.value,
      'imageUrls': imageUrls,
      'highlights': highlights,
      'genderPreference': genderPreference,
      'condition': condition,
      'furnishing': furnishing,
      'availableFrom': availableFrom,
      'purpose': purpose.value,
      if (requirementDetails != null)
        'requirementDetails':
            requirementDetails!.toMap(includeCreatedAt: false),
      'isFeatured': isFeatured,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Validates whether a listing type/purpose combination makes sense.
  static bool isValidCombination({
    required ListingType type,
    required PropertyType propertyType,
    required ListingPurpose purpose,
  }) {
    if (type == ListingType.marketplace) {
      return propertyType == PropertyType.item &&
          purpose == ListingPurpose.marketplaceSell;
    }

    if (propertyType == PropertyType.item ||
        purpose == ListingPurpose.marketplaceSell) {
      return false;
    }

    if (purpose == ListingPurpose.needRoommate) {
      return propertyType == PropertyType.room ||
          propertyType == PropertyType.flat;
    }

    return propertyType == PropertyType.room ||
        propertyType == PropertyType.flat ||
        propertyType == PropertyType.pg;
  }

  /// Normalizes legacy/variant fields into a consistent listing triple.
  static (ListingType, PropertyType, ListingPurpose) _normalizeListingFields(
    Map<String, dynamic> map,
  ) {
    final rawPropertyType =
        (map['propertyType'] ?? map['category'] ?? '').toString();
    final rawPurpose = (map['purpose'] ?? map['flow'] ?? '').toString();
    final legacyCategory = (map['category'] ?? '').toString().trim().toLowerCase();

    var propertyType = PropertyTypeX.fromString(rawPropertyType);
    var type = map['type'] == null
        ? propertyType.listingType
        : ListingTypeX.fromString(map['type'].toString());
    var purpose = map['purpose'] == null && legacyCategory == 'flatmate'
        ? ListingPurpose.needRoommate
        : ListingPurposeX.fromString(rawPurpose);

    if (type == ListingType.marketplace || propertyType == PropertyType.item) {
      type = ListingType.marketplace;
      propertyType = PropertyType.item;
      purpose = ListingPurpose.marketplaceSell;
    } else {
      type = ListingType.housing;
      if (purpose == ListingPurpose.marketplaceSell) {
        purpose = ListingPurpose.offerProperty;
      }
      if (legacyCategory == 'flatmate') {
        propertyType = PropertyType.flat;
        purpose = ListingPurpose.needRoommate;
      }
      if (purpose == ListingPurpose.needRoommate &&
          propertyType == PropertyType.pg) {
        propertyType = PropertyType.flat;
      }
    }

    return (type, propertyType, purpose);
  }

  /// Builds requirement details from nested data or legacy fields.
  static RequirementModel? _requirementDetailsFromMap(
    Map<String, dynamic> map,
    String docId,
    ListingPurpose purpose,
  ) {
    final raw = map['requirementDetails'];
    if (raw is Map<String, dynamic>) {
      return RequirementModel.fromMap(raw, docId);
    }
    if (raw is Map) {
      return RequirementModel.fromMap(Map<String, dynamic>.from(raw), docId);
    }
    if (purpose != ListingPurpose.needPlace) {
      return null;
    }

    return RequirementModel(
      id: docId,
      userId: (map['ownerId'] ?? '').toString(),
      needType: NeedTypeX.fromString(
        (map['needType'] ?? map['propertyType'] ?? map['category'] ?? 'room')
            .toString(),
      ),
      location: (map['location'] ?? '').toString(),
      minBudget: (map['minBudget'] as num?)?.toInt() ?? 0,
      maxBudget: (map['maxBudget'] as num?)?.toInt() ??
          (map['price'] as num?)?.toInt() ??
          0,
      moveInWhen:
          (map['moveInWhen'] ?? map['availableFrom'] ?? '').toString(),
      occupancy: (map['occupancy'] ?? '').toString(),
      genderPreference: (map['genderPreference'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      amenities: List<String>.from(map['amenities'] ?? const <String>[]),
      lifestyle: List<String>.from(map['lifestyle'] ?? const <String>[]),
      contactMethods:
          List<String>.from(map['contactMethods'] ?? const <String>[]),
    );
  }

  /// Human-friendly price label based on listing type/purpose.
  String get priceLabel {
    final rounded =
        price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(0);
    if (isMarketplacePost) {
      return 'Rs $rounded';
    }
    if (isRequirementPost) {
      return 'Up to Rs $rounded';
    }
    return 'Rs $rounded/mo';
  }

  /// True when this listing represents a user looking for a place.
  bool get isRequirementPost => purpose == ListingPurpose.needPlace;

  /// True when this listing represents an owner/offer post.
  bool get isOwnerPost => purpose == ListingPurpose.offerProperty;

  /// True when this is a marketplace item.
  bool get isMarketplacePost => type == ListingType.marketplace;

  /// True when the listing is looking for a roommate.
  bool get needsRoommate => purpose == ListingPurpose.needRoommate;

  /// Label for UI display of the property type.
  String get propertyTypeLabel => propertyType.label;

  /// Label for UI display of the listing purpose.
  String get purposeLabel => purpose.label;

  /// Label for UI display of the listing type.
  String get typeLabel => type.label;
}
