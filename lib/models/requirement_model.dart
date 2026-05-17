import 'package:cloud_firestore/cloud_firestore.dart';


// === Requirement metadata ====================================================

/// Types of housing needs used in requirement listings.
enum NeedType { room, flat, pg, hostel }

/// Convenience helpers for serializing and labeling [NeedType].
extension NeedTypeX on NeedType {
  String get value {
    switch (this) {
      case NeedType.flat:
        return 'flat';
      case NeedType.pg:
        return 'pg';
      case NeedType.hostel:
        return 'hostel';
      case NeedType.room:
        return 'room';
    }
  }

  String get label {
    switch (this) {
      case NeedType.flat:
        return 'Flat';
      case NeedType.pg:
        return 'PG';
      case NeedType.hostel:
        return 'Hostel';
      case NeedType.room:
        return 'Room';
    }
  }

  static NeedType fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'flat':
        return NeedType.flat;
      case 'pg':
        return NeedType.pg;
      case 'hostel':
        return NeedType.hostel;
      case 'room':
      default:
        return NeedType.room;
    }
  }
}


// === Requirement model =======================================================

/// Requirement data for users looking for a place.
class RequirementModel {
  final String id;
  final String userId;
  final NeedType needType;
  final String location;
  final int minBudget;
  final int maxBudget;
  final String moveInWhen;
  final String occupancy;
  final String genderPreference;
  final String description;
  final List<String> amenities;
  final List<String> lifestyle;
  final List<String> contactMethods;
  final DateTime? createdAt;

  RequirementModel({
    required this.id,
    required this.userId,
    required this.needType,
    required this.location,
    required this.minBudget,
    required this.maxBudget,
    required this.moveInWhen,
    required this.occupancy,
    required this.genderPreference,
    required this.description,
    this.amenities = const [],
    this.lifestyle = const [],
    this.contactMethods = const [],
    this.createdAt,
  });

  /// Serializes this requirement to a Firestore-friendly map.
  Map<String, dynamic> toMap({bool includeCreatedAt = true}) => {
        'userId': userId,
        'needType': needType.value,
        'location': location,
        'minBudget': minBudget,
        'maxBudget': maxBudget,
        'moveInWhen': moveInWhen,
        'occupancy': occupancy,
        'genderPreference': genderPreference,
        'description': description,
        'amenities': amenities,
        'lifestyle': lifestyle,
        'contactMethods': contactMethods,
        if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
      };

  /// Builds a [RequirementModel] from Firestore data.
  factory RequirementModel.fromMap(Map<String, dynamic> map, String id) {
    return RequirementModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      needType: NeedTypeX.fromString((map['needType'] ?? 'room').toString()),
      location: (map['location'] ?? '').toString(),
      minBudget: (map['minBudget'] as num?)?.toInt() ?? 0,
      maxBudget: (map['maxBudget'] as num?)?.toInt() ?? 0,
      moveInWhen: (map['moveInWhen'] ?? '').toString(),
      occupancy: (map['occupancy'] ?? '').toString(),
      genderPreference: (map['genderPreference'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      amenities: List<String>.from(map['amenities'] ?? const <String>[]),
      lifestyle: List<String>.from(map['lifestyle'] ?? const <String>[]),
      contactMethods: List<String>.from(map['contactMethods'] ?? const <String>[]),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
