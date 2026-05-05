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

enum ChatType { listing }

extension ChatTypeX on ChatType {
  String get value => 'listing';

  String get label => 'Listing';

  static ChatType fromString(String _) => ChatType.listing;
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final String status;

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
}

class ConversationModel {
  final String id;
  final List<String> participants;
  final ChatType chatType;
  final String referenceId;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, DateTime> lastReadAt;
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
    final Map<String, DateTime> lastReadAt = {};
    if (map['lastReadAt'] is Map) {
      (map['lastReadAt'] as Map).forEach((key, value) {
        if (value is Timestamp) {
          lastReadAt[_normalizeUid('$key')] = value.toDate();
        }
      });
    }

    return ConversationModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? const <String>[])
          .map(_normalizeUid)
          .toSet()
          .toList(),
      chatType: ChatTypeX.fromString((map['chatType'] ?? '').toString()),
      referenceId: (map['referenceId'] ?? '').toString(),
      lastMessage: (map['lastMessage'] ?? '').toString(),
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

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) {
      const dayOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return dayOfWeek[lastMessageTime.weekday - 1];
    }
    return '${lastMessageTime.month}/${lastMessageTime.day}';
  }
}
