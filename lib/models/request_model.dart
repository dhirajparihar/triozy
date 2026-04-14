import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String userId;
  final String posterName;
  final String category;
  final String description;
  final String location;
  final String time;
  final String budgetRange; // 'Economy', 'Standard', 'Premium'
  final String status; // 'Open' | 'Closed'
  final String phone;
  final double? price;
  final String? photoUrl;
  final DateTime? createdAt;

  RequestModel({
    required this.id,
    required this.userId,
    this.posterName = '',
    required this.category,
    required this.description,
    required this.location,
    required this.time,
    required this.budgetRange,
    this.status = 'Open',
    this.phone = '',
    this.price,
    this.photoUrl,
    this.createdAt,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      id: id,
      userId: map['userId'] ?? '',
      posterName: map['posterName'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      time: map['time'] ?? '',
      budgetRange: map['budgetRange'] ?? 'Standard',
      status: map['status'] ?? 'Open',
      phone: map['phone'] ?? '',
      price: (map['price'] as num?)?.toDouble(),
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore map. Set [includeCreatedAt] to true only on first create.
  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'userId': userId,
      'posterName': posterName,
      'category': category,
      'description': description,
      'location': location,
      'time': time,
      'budgetRange': budgetRange,
      'status': status,
      'phone': phone,
      'price': price,
      'photoUrl': photoUrl,
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  RequestModel copyWith({
    String? posterName,
    String? category,
    String? description,
    String? location,
    String? time,
    String? budgetRange,
    String? status,
    String? phone,
    double? price,
    String? photoUrl,
  }) {
    return RequestModel(
      id: id,
      userId: userId,
      posterName: posterName ?? this.posterName,
      category: category ?? this.category,
      description: description ?? this.description,
      location: location ?? this.location,
      time: time ?? this.time,
      budgetRange: budgetRange ?? this.budgetRange,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      price: price ?? this.price,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }
}
