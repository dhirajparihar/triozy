import 'package:cloud_firestore/cloud_firestore.dart';

/// Mate types supported by the platform.
enum MateType { roommate, helpmate, ridemate }

extension MateTypeX on MateType {
  String get value {
    switch (this) {
      case MateType.roommate: return 'roommate';
      case MateType.helpmate: return 'helpmate';
      case MateType.ridemate: return 'ridemate';
    }
  }

  String get label {
    switch (this) {
      case MateType.roommate: return 'Roommate';
      case MateType.helpmate: return 'Helpmate';
      case MateType.ridemate: return 'Ridemate';
    }
  }

  static MateType fromString(String v) {
    switch (v) {
      case 'helpmate': return MateType.helpmate;
      case 'ridemate': return MateType.ridemate;
      default: return MateType.roommate;
    }
  }
}

class MateModel {
  final String id;
  final MateType type;
  final String userId;
  final String userName;
  final String userPhoto;
  final String phone;
  final String location;
  final double? latitude;
  final double? longitude;
  final String description;
  final DateTime? createdAt;

  // ── Roommate ──────────────────────────────
  final String? budget;           // e.g. '₹5,000 – ₹8,000'
  final String? preferredGender;  // 'Any' | 'Male' | 'Female'
  final List<String> lifestyle;   // ['Non-smoker', 'Vegetarian', ...]

  // ── Helpmate ──────────────────────────────
  final List<String> helpTypes;   // ['Errands', 'Emergency', 'Medical', ...]
  final bool available;

  // ── Ridemate ──────────────────────────────
  final String? fromLocation;
  final String? toLocation;
  final String? departureTime;    // e.g. '09:00 AM'
  final String? frequency;        // 'Daily' | 'Weekdays' | 'Weekends' | 'Once'
  final String? vehicleType;      // 'Bike' | 'Scooty' | 'Car'

  const MateModel({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    this.userPhoto = '',
    this.phone = '',
    this.location = '',
    this.latitude,
    this.longitude,
    this.description = '',
    this.createdAt,
    // Roommate
    this.budget,
    this.preferredGender,
    this.lifestyle = const [],
    // Helpmate
    this.helpTypes = const [],
    this.available = true,
    // Ridemate
    this.fromLocation,
    this.toLocation,
    this.departureTime,
    this.frequency,
    this.vehicleType,
  });

  static String _normalizeUid(String raw) {
    final value = raw.trim();
    if (value.isEmpty || !value.contains('_')) {
      return value;
    }
    final tail = value.split('_').last.trim();
    final looksLikeUid = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(tail);
    return looksLikeUid ? tail : value;
  }

  factory MateModel.fromMap(Map<String, dynamic> map, String docId) {
    return MateModel(
      id: docId,
      type: MateTypeX.fromString(map['type'] ?? 'roommate'),
      userId: _normalizeUid((map['userId'] ?? '').toString()),
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'] ?? '',
      phone: map['phone'] ?? '',
      location: map['location'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      description: map['description'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      budget: map['budget'],
      preferredGender: map['preferredGender'],
      lifestyle: List<String>.from(map['lifestyle'] ?? []),
      helpTypes: List<String>.from(map['helpTypes'] ?? []),
      available: map['available'] ?? true,
      fromLocation: map['fromLocation'],
      toLocation: map['toLocation'],
      departureTime: map['departureTime'],
      frequency: map['frequency'],
      vehicleType: map['vehicleType'],
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = true}) {
    final map = <String, dynamic>{
      'type': type.value,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'phone': phone,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      // Roommate
      'budget': budget,
      'preferredGender': preferredGender,
      'lifestyle': lifestyle,
      // Helpmate
      'helpTypes': helpTypes,
      'available': available,
      // Ridemate
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'departureTime': departureTime,
      'frequency': frequency,
      'vehicleType': vehicleType,
    };
    if (includeCreatedAt) map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }
}
