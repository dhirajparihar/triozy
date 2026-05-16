import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';


// === Chat helpers ============================================================

/// Normalizes stored ids that may include a composite prefix.
String normalizeChatUid(String raw) {
  final value = raw.trim();
  if (value.isEmpty || !value.contains('_')) {
    return value;
  }
  final tail = value.split('_').last.trim();
  final looksLikeUid = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(tail);
  return looksLikeUid ? tail : value;
}

/// Generates a client-side message id for optimistic UI rendering.
String generateChatClientId() {
  final millis = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(1 << 20).toRadixString(16);
  return 'm_${millis}_$random';
}

/// Chat categories used for conversation routing and labels.
enum ChatType { listing, marketplace }

/// Convenience helpers for serializing and labeling [ChatType].
extension ChatTypeX on ChatType {
  String get value {
    switch (this) {
      case ChatType.listing:
        return 'listing';
      case ChatType.marketplace:
        return 'marketplace';
    }
  }

  String get label {
    switch (this) {
      case ChatType.listing:
        return 'Listing';
      case ChatType.marketplace:
        return 'Marketplace';
    }
  }

  static ChatType fromString(String value, {String? id}) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _inferFromId(id);
    }

    if (normalized == 'marketplace' ||
        normalized == 'marketplacesell' ||
        normalized == 'marketplace_sell' ||
        normalized == 'marketplace sell' ||
        normalized == 'item') {
      return ChatType.marketplace;
    }

    if (normalized == 'housing' || normalized == 'listing') {
      return ChatType.listing;
    }

    return _inferFromId(id);
  }

  static ChatType _inferFromId(String? id) {
    if (id == null || id.isEmpty) {
      return ChatType.listing;
    }

    final normalizedId = id.toLowerCase();
    if (normalizedId.contains('_marketplace_') ||
        normalizedId.contains('_item_') ||
        normalizedId.contains('_marketplace sell_') ||
        normalizedId.contains('_marketplacesell_') ||
        normalizedId.contains('_marketplace_sell_')) {
      return ChatType.marketplace;
    }

    return ChatType.listing;
  }
}


// === Participant metadata ====================================================

/// Display metadata for a chat participant.
class ChatParticipantMeta {
  final String userId;
  final String name;
  final String photoUrl;

  const ChatParticipantMeta({
    required this.userId,
    required this.name,
    required this.photoUrl,
  });

  factory ChatParticipantMeta.fromMap(String userId, Map<String, dynamic> map) {
    return ChatParticipantMeta(
      userId: normalizeChatUid(userId),
      name: (map['name'] ?? '').toString().trim(),
      photoUrl: (map['photoUrl'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'photoUrl': photoUrl};
  }
}


// === Message model ===========================================================

/// Message payload persisted in Firestore.
class MessageModel {
  final String id;
  final String clientId;
  final String rawSenderId;
  final String rawReceiverId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final String status;
  final bool isLocalOnly;

  const MessageModel({
    required this.id,
    required this.clientId,
    required this.rawSenderId,
    required this.rawReceiverId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = 'sent',
    this.isLocalOnly = false,
  });

  bool get isSending => status == 'sending';
  bool get isFailed => status == 'failed';
  bool get isRead => status == 'read';

  /// Builds a message from Firestore data.
  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    final timestamp = map['timestamp'] is Timestamp
        ? (map['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    return MessageModel(
      id: id,
      clientId: (map['clientId'] ?? id).toString(),
      rawSenderId: (map['senderId'] ?? '').toString().trim(),
      rawReceiverId: (map['receiverId'] ?? '').toString().trim(),
      senderId: normalizeChatUid((map['senderId'] ?? '').toString()),
      receiverId: normalizeChatUid((map['receiverId'] ?? '').toString()),
      text: (map['text'] ?? '').toString(),
      timestamp: timestamp,
      status: (map['status'] ?? 'sent').toString(),
    );
  }

  /// Builds an optimistic message for immediate UI display.
  factory MessageModel.optimistic({
    required String clientId,
    required String senderId,
    required String receiverId,
    required String text,
  }) {
    return MessageModel(
      id: clientId,
      clientId: clientId,
      rawSenderId: senderId.trim(),
      rawReceiverId: receiverId.trim(),
      senderId: normalizeChatUid(senderId),
      receiverId: normalizeChatUid(receiverId),
      text: text,
      timestamp: DateTime.now(),
      status: 'sending',
      isLocalOnly: true,
    );
  }

  /// Returns a copy with updated fields.
  MessageModel copyWith({
    String? id,
    String? clientId,
    String? rawSenderId,
    String? rawReceiverId,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    String? status,
    bool? isLocalOnly,
  }) {
    return MessageModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      rawSenderId: rawSenderId ?? this.rawSenderId,
      rawReceiverId: rawReceiverId ?? this.rawReceiverId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }
}


// === Conversation model ======================================================

/// Summary model for a conversation list tile.
class ConversationModel {
  final String id;
  final List<String> participants;
  final ChatType chatType;
  final String referenceId;
  final String listingTitle;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, DateTime> lastReadAt;
  final Map<String, int> unreadCountByUser;
  final Map<String, bool> typingByUser;
  final Map<String, ChatParticipantMeta> participantMeta;
  final DateTime createdAt;

  const ConversationModel({
    required this.id,
    required this.participants,
    required this.chatType,
    required this.referenceId,
    required this.listingTitle,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.lastReadAt,
    required this.unreadCountByUser,
    required this.typingByUser,
    required this.participantMeta,
    required this.createdAt,
  });

  /// Builds a conversation from Firestore data.
  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    final lastReadAt = <String, DateTime>{};
    if (map['lastReadAt'] is Map) {
      (map['lastReadAt'] as Map).forEach((key, value) {
        if (value is Timestamp) {
          lastReadAt[normalizeChatUid('$key')] = value.toDate();
        }
      });
    }

    final unreadCountByUser = <String, int>{};
    if (map['unreadCountByUser'] is Map) {
      (map['unreadCountByUser'] as Map).forEach((key, value) {
        if (value is num) {
          unreadCountByUser[normalizeChatUid('$key')] = value.toInt();
        }
      });
    }

    final typingByUser = <String, bool>{};
    if (map['typingByUser'] is Map) {
      (map['typingByUser'] as Map).forEach((key, value) {
        if (value is bool) {
          typingByUser[normalizeChatUid('$key')] = value;
        }
      });
    }

    final participantMeta = <String, ChatParticipantMeta>{};
    if (map['participantMeta'] is Map) {
      (map['participantMeta'] as Map).forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final normalizedKey = normalizeChatUid('$key');
          participantMeta[normalizedKey] = ChatParticipantMeta.fromMap(
            normalizedKey,
            value,
          );
        } else if (value is Map) {
          final normalizedKey = normalizeChatUid('$key');
          participantMeta[normalizedKey] = ChatParticipantMeta.fromMap(
            normalizedKey,
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return ConversationModel(
      id: id,
      participants: List<String>.from(
        map['participants'] ?? const <String>[],
      ).map(normalizeChatUid).toSet().toList(),
      chatType: ChatTypeX.fromString(
        (map['chatType'] ?? '').toString(),
        id: id,
      ),
      referenceId: (map['referenceId'] ?? '').toString(),
      listingTitle: (map['listingTitle'] ?? '').toString().trim(),
      lastMessage: (map['lastMessage'] ?? '').toString(),
      lastMessageType: (map['lastMessageType'] ?? 'text').toString(),
      lastMessageTime: map['lastMessageTime'] is Timestamp
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      lastSenderId: normalizeChatUid((map['lastSenderId'] ?? '').toString()),
      lastReadAt: lastReadAt,
      unreadCountByUser: unreadCountByUser,
      typingByUser: typingByUser,
      participantMeta: participantMeta,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Returns the other participant id for the current user.
  String peerIdFor(String currentUserId) {
    final normalized = normalizeChatUid(currentUserId);
    return participants.firstWhere((id) => id != normalized, orElse: () => '');
  }

  /// Returns display metadata for the peer participant.
  ChatParticipantMeta? peerMetaFor(String currentUserId) {
    final peerId = peerIdFor(currentUserId);
    if (peerId.isEmpty) {
      return null;
    }
    return participantMeta[peerId];
  }

  /// Computes unread count for the current user.
  int unreadCountFor(String currentUserId) {
    final normalized = normalizeChatUid(currentUserId);
    final direct = unreadCountByUser[normalized];
    if (direct != null) {
      return direct;
    }

    final lastRead = lastReadAt[normalized];
    final isIncoming =
        lastSenderId.isNotEmpty && normalizeChatUid(lastSenderId) != normalized;
    if (isIncoming &&
        (lastRead == null || lastMessageTime.isAfter(lastRead)) &&
        lastMessage.trim().isNotEmpty) {
      return 1;
    }
    return 0;
  }

  /// True when the peer is typing for this conversation.
  bool isPeerTypingFor(String currentUserId) {
    final peerId = peerIdFor(currentUserId);
    if (peerId.isEmpty) {
      return false;
    }
    return typingByUser[peerId] ?? false;
  }

  /// Human-friendly timestamp for conversation list tiles.
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);

    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) {
      final hour = lastMessageTime.hour % 12 == 0
          ? 12
          : lastMessageTime.hour % 12;
      final minute = lastMessageTime.minute.toString().padLeft(2, '0');
      final suffix = lastMessageTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) {
      const dayOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return dayOfWeek[lastMessageTime.weekday - 1];
    }
    return '${lastMessageTime.day}/${lastMessageTime.month}';
  }
}
