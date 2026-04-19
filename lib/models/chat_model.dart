import 'package:cloud_firestore/cloud_firestore.dart';

String _normalizeUid(String raw) {
  final value = raw.trim();
  if (value.isEmpty || !value.contains('_')) {
    return value;
  }
  final tail = value.split('_').last.trim();
  final looksLikeUid = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(tail);
  return looksLikeUid ? tail : value;
}

/// Chat types
enum ChatType { mate, service, request }

extension ChatTypeX on ChatType {
  String get value {
    switch (this) {
      case ChatType.mate:
        return 'mate';
      case ChatType.service:
        return 'service';
      case ChatType.request:
        return 'request';
    }
  }

  String get label {
    switch (this) {
      case ChatType.mate:
        return 'Mate';
      case ChatType.service:
        return 'Service';
      case ChatType.request:
        return 'Request';
    }
  }

  static ChatType fromString(String v) {
    switch (v) {
      case 'service':
        return ChatType.service;
      case 'request':
        return ChatType.request;
      default:
        return ChatType.mate;
    }
  }
}

/// Individual message in a conversation
class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final String status; // 'sent' | 'read'

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = 'sent',
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: _normalizeUid((map['senderId'] ?? '').toString()),
      receiverId: _normalizeUid((map['receiverId'] ?? '').toString()),
      text: map['text'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      status: map['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    String? status,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }
}

/// Conversation (chat) model
class ConversationModel {
  final String id;
  final List<String> participants; // [uid1, uid2]
  final ChatType chatType; // 'mate' | 'service' | 'request'
  final String referenceId; // mateId | jobId | workerId

  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;

  final Map<String, DateTime> lastReadAt; // {uid1: Timestamp, uid2: Timestamp}
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.chatType,
    required this.referenceId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.lastReadAt,
    required this.createdAt,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    // Parse lastReadAt map
    final Map<String, DateTime> lastReadAt = {};
    if (map['lastReadAt'] is Map) {
      (map['lastReadAt'] as Map).forEach((key, value) {
        if (value is Timestamp) {
          lastReadAt[_normalizeUid('$key')] = value.toDate();
        }
      });
    }

    final participants = List<String>.from(
      map['participants'] ?? const <String>[],
    ).map((id) => _normalizeUid(id)).toSet().toList();

    return ConversationModel(
      id: id,
      participants: participants,
      chatType: ChatTypeX.fromString(map['chatType'] ?? 'mate'),
      referenceId: map['referenceId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] is Timestamp
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      lastSenderId: _normalizeUid((map['lastSenderId'] ?? '').toString()),
      lastReadAt: lastReadAt,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    // Convert lastReadAt to Firestore format
    Map<String, dynamic> readAtFirestore = {};
    lastReadAt.forEach((key, value) {
      readAtFirestore[key] = Timestamp.fromDate(value);
    });
    return {
      'participants': participants,
      'chatType': chatType.value,
      'referenceId': referenceId,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastSenderId': lastSenderId,
      'lastReadAt': readAtFirestore,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get the type badge color
  String get typeBadgeColor {
    switch (chatType) {
      case ChatType.mate:
        return '#3B82F6'; // Blue
      case ChatType.service:
        return '#10B981'; // Green
      case ChatType.request:
        return '#F97316'; // Orange
    }
  }

  /// Get formatted relative time (e.g., "Just now", "Yesterday")
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final dayOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return dayOfWeek[lastMessageTime.weekday - 1];
    } else {
      return '${lastMessageTime.month}/${lastMessageTime.day}';
    }
  }

  ConversationModel copyWith({
    String? id,
    List<String>? participants,
    ChatType? chatType,
    String? referenceId,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastSenderId,
    Map<String, DateTime>? lastReadAt,
    DateTime? createdAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      chatType: chatType ?? this.chatType,
      referenceId: referenceId ?? this.referenceId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
