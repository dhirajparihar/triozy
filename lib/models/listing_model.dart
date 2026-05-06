import 'package:cloud_firestore/cloud_firestore.dart';

enum ListingType { housing, marketplace }

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

enum ListingCategory { room, pg, flat, flatmate, item }

enum ListingFlow { owner, requirement }

extension ListingFlowX on ListingFlow {
  String get value {
    switch (this) {
      case ListingFlow.owner:
        return 'owner';
      case ListingFlow.requirement:
        return 'requirement';
    }
  }

  static ListingFlow fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'requirement':
        return ListingFlow.requirement;
      case 'owner':
      default:
        return ListingFlow.owner;
    }
  }
}

extension ListingCategoryX on ListingCategory {
  String get value {
    switch (this) {
      case ListingCategory.room:
        return 'room';
      case ListingCategory.pg:
        return 'pg';
      case ListingCategory.flat:
        return 'flat';
      case ListingCategory.flatmate:
        return 'flatmate';
      case ListingCategory.item:
        return 'item';
    }
  }

  String get label {
    switch (this) {
      case ListingCategory.room:
        return 'Room';
      case ListingCategory.pg:
        return 'PG';
      case ListingCategory.flat:
        return 'Flat';
      case ListingCategory.flatmate:
        return 'Flatmate';
      case ListingCategory.item:
        return 'Buy Items';
    }
  }

  ListingType get listingType {
    switch (this) {
      case ListingCategory.item:
        return ListingType.marketplace;
      case ListingCategory.room:
      case ListingCategory.pg:
      case ListingCategory.flat:
      case ListingCategory.flatmate:
        return ListingType.housing;
    }
  }

  static ListingCategory fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pg':
        return ListingCategory.pg;
      case 'flat':
        return ListingCategory.flat;
      case 'flatmate':
        return ListingCategory.flatmate;
      case 'item':
        return ListingCategory.item;
      case 'room':
      default:
        return ListingCategory.room;
    }
  }
}

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
  final ListingCategory category;
  final List<String> imageUrls;
  final List<String> highlights;
  final String? genderPreference;
  final String? condition;
  final String? furnishing;
  final String? availableFrom;
  final ListingFlow flow;
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
    required this.category,
    this.imageUrls = const [],
    this.highlights = const [],
    this.genderPreference,
    this.condition,
    this.furnishing,
    this.availableFrom,
    this.flow = ListingFlow.owner,
    this.isFeatured = false,
    this.createdAt,
  });

  factory ListingModel.fromMap(Map<String, dynamic> map, String docId) {
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
      type: ListingTypeX.fromString((map['type'] ?? '').toString()),
      category: ListingCategoryX.fromString((map['category'] ?? '').toString()),
      imageUrls: List<String>.from(map['imageUrls'] ?? const <String>[]),
      highlights: List<String>.from(map['highlights'] ?? const <String>[]),
      genderPreference: map['genderPreference'] as String?,
      condition: map['condition'] as String?,
      furnishing: map['furnishing'] as String?,
      availableFrom: map['availableFrom'] as String?,
      flow: ListingFlowX.fromString((map['flow'] ?? '').toString()),
      isFeatured: map['isFeatured'] as bool? ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

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
      'category': category.value,
      'imageUrls': imageUrls,
      'highlights': highlights,
      'genderPreference': genderPreference,
      'condition': condition,
      'furnishing': furnishing,
      'availableFrom': availableFrom,
      'flow': flow.value,
      'isFeatured': isFeatured,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get priceLabel {
    final rounded = price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(0);
    if (category == ListingCategory.item) {
      return 'Rs $rounded';
    }
    return 'Rs $rounded/mo';
  }

  String get categoryLabel => category.label;

  String get typeLabel => type.label;
}
