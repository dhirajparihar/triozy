import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String phone;
  final List<String> skills;
  final String serviceType;
  final int experience;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final double rating;
  final int totalJobs;
  final bool isAvailable;
  final String description;
  final DateTime? createdAt;
  final bool isSubscribed;
  final String status;

  /// Distance from user's current position (calculated client-side, not stored)
  double? distanceKm;

  WorkerModel({
    required this.uid,
    required this.name,
    this.email = '',
    this.photoUrl = '',
    this.phone = '',
    this.skills = const [],
    this.serviceType = '',
    this.experience = 0,
    this.location = '',
    this.latitude,
    this.longitude,
    this.geohash,
    this.rating = 0,
    this.totalJobs = 0,
    this.isAvailable = true,
    this.description = '',
    this.createdAt,
    this.isSubscribed = false,
    this.status = 'none',
    this.distanceKm,
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

  static double _clampRating(double raw) {
    return raw.clamp(0.0, 5.0).toDouble();
  }

  factory WorkerModel.fromMap(Map<String, dynamic> map) {
    double? lat;
    double? lng;
    String? hash;

    final position = map['position'];
    if (position is Map<String, dynamic>) {
      final geopoint = position['geopoint'];
      if (geopoint is GeoPoint) {
        lat = geopoint.latitude;
        lng = geopoint.longitude;
      }
      hash = position['geohash'] as String?;
    }

    lat ??= (map['latitude'] as num?)?.toDouble();
    lng ??= (map['longitude'] as num?)?.toDouble();

    return WorkerModel(
      uid: _normalizeUid((map['uid'] ?? '').toString()),
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      phone: map['phone'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      serviceType: map['serviceType'] ?? (map['skills'] != null && (map['skills'] as List).isNotEmpty ? map['skills'][0] : ''),
      experience: (map['experience'] ?? 0).toInt(),
      location: map['location'] ?? '',
      latitude: lat,
      longitude: lng,
      geohash: hash,
      rating: _clampRating((map['rating'] ?? 0).toDouble()),
      totalJobs: (map['totalJobs'] ?? 0).toInt(),
      isAvailable: map['isAvailable'] ?? true,
      description: map['description'] ?? '',
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
      isSubscribed: map['isSubscribed'] ?? false,
      status: map['status'] ?? 'none',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'phone': phone,
      'skills': skills,
      'serviceType': serviceType,
      'experience': experience,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'rating': _clampRating(rating),
      'totalJobs': totalJobs,
      'isAvailable': isAvailable,
      'description': description,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isSubscribed': isSubscribed,
      'status': status,
    };
  }

  String get experienceDisplay => '$experience Years';
  String get ratingDisplay => _clampRating(rating).toStringAsFixed(1);
  String get distanceDisplay {
    if (distanceKm == null) return location;
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).toInt()} m away';
    }
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  bool get hasGeoData => latitude != null && longitude != null;
  bool get available => isAvailable;
}
