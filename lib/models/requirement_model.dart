import 'package:cloud_firestore/cloud_firestore.dart';

enum NeedType { room, flat, pg, hostel }

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
}

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

  Map<String, dynamic> toMap() => {
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
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory RequirementModel.fromMap(Map<String, dynamic> map, String id) {
    return RequirementModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      needType: NeedType.values.firstWhere((e) => e.value == (map['needType'] ?? 'room')),
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
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
