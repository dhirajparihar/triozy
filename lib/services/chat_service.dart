import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Normalize legacy ids like "Name_uid" to canonical Firebase uid.
  String _normalizeUid(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return value;
    }
    if (!value.contains('_')) {
      return value;
    }
    final parts = value.split('_');
    final tail = parts.isNotEmpty ? parts.last.trim() : value;
    final looksLikeUid = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(tail);
    return looksLikeUid ? tail : value;
  }

  /// Generate deterministic chat ID to prevent duplicates/collisions.
  /// Format: uid1_uid2_chatType_referenceId (UIDs sorted alphabetically)
  String _generateChatId(
    String uid1,
    String uid2,
    ChatType chatType,
    String referenceId,
  ) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}_${chatType.value}_$referenceId';
  }

  Map<String, dynamic> _conversationPayload({
    required String currentUserId,
    required String otherUserId,
    required ChatType chatType,
    required String referenceId,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      'participants': [currentUserId, otherUserId],
      'chatType': chatType.value,
      'referenceId': referenceId,
      'lastMessage': '',
      'lastMessageTime': now,
      'lastSenderId': '',
      // Only creator has read state at creation time.
      // Recipient should remain unread once first incoming message is sent.
      'lastReadAt': {currentUserId: now},
      'createdAt': now,
    };
  }

  Future<bool> _conversationExistsAndReadable(String chatId) async {
    final snap = await _firestore.collection('chats').doc(chatId).get();
    return snap.exists;
  }

  Future<void> _createConversation(
    String chatId,
    Map<String, dynamic> payload,
  ) async {
    await _firestore.collection('chats').doc(chatId).set(payload);
  }

  /// Get or create a conversation
  /// Returns the conversation ID
  Future<String> getOrCreateConversation({
    required String otherUserId,
    required ChatType chatType,
    required String referenceId,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? otherUserLocation,
    String? currentUserName,
    String? currentUserPhotoUrl,
    String? currentUserLocation,
  }) async {
    final currentUserId = _normalizeUid(_auth.currentUser?.uid ?? '');
    if (currentUserId.isEmpty) throw Exception('User not authenticated');
    final normalizedOtherUserId = _normalizeUid(otherUserId);
    if (normalizedOtherUserId.isEmpty) {
      throw Exception('Invalid recipient');
    }

    final primaryChatId = _generateChatId(
      currentUserId,
      normalizedOtherUserId,
      chatType,
      referenceId,
    );
    final candidateChatIds = <String>[primaryChatId, 'v2_$primaryChatId'];
    final payload = _conversationPayload(
      currentUserId: currentUserId,
      otherUserId: normalizedOtherUserId,
      chatType: chatType,
      referenceId: referenceId,
    );

    FirebaseException? lastPermissionError;
    for (final chatId in candidateChatIds) {
      bool existsAndReadable = false;
      try {
        existsAndReadable = await _conversationExistsAndReadable(chatId);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // The document might not exist (Firestore rules deny read if exists=false
          // and rule requires resource.data contents). We'll try to create it.
          existsAndReadable = false;
        } else {
          rethrow;
        }
      }

      if (existsAndReadable) {
        return chatId;
      }

      try {
        await _createConversation(chatId, payload);
        return chatId;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          lastPermissionError = e;
          continue;
        }
        rethrow;
      }
    }

    if (lastPermissionError != null) {
      throw lastPermissionError;
    }
    throw Exception('Unable to create or access conversation');
  }

  /// Send a message
  Future<void> sendMessage(String conversationId, String text) async {
    final currentUserIdRaw = _auth.currentUser?.uid;
    if (currentUserIdRaw == null) throw Exception('User not authenticated');
    final currentUserId = _normalizeUid(currentUserIdRaw);
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final conversationRef = _firestore.collection('chats').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();
    await _firestore.runTransaction((txn) async {
      final convDoc = await txn.get(conversationRef);
      if (!convDoc.exists) {
        throw Exception('Conversation not found');
      }

      final participantsRaw = List<String>.from(
        convDoc.data()?['participants'] ?? [],
      );
      final participants = participantsRaw
          .map(_normalizeUid)
          .where((id) => id.isNotEmpty)
          .toList();
      if (!participants.contains(currentUserId)) {
        throw Exception('Not a participant of this conversation');
      }
      final receiverId = participants.firstWhere(
        (uid) => uid != currentUserId,
        orElse: () => throw Exception('Receiver not found in conversation'),
      );
      final now = FieldValue.serverTimestamp();
      txn.set(messageRef, {
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': normalizedText,
        'timestamp': now,
        'status': 'sent',
      });
      txn.update(conversationRef, {
        'lastMessage': normalizedText,
        'lastMessageTime': now,
        'lastSenderId': currentUserId,
        'lastReadAt.$currentUserId': now,
      });
    });
  }

  /// Stream conversations for current user, ordered by lastMessageTime
  Stream<List<ConversationModel>> streamConversations(String userId) {
    final normalizedUserId = _normalizeUid(userId);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: normalizedUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          final allConvs = snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              // Conversation docs are created when user opens chat.
              // Keep message list clean: only show after first actual message.
              .where((conv) => conv.lastMessage.trim().isNotEmpty)
              .toList();

          // Force explicit local sort just in case Firestore's local cache
          // orders pending writes (null timestamps) randomly at the bottom.
          allConvs.sort(
            (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
          );

          // Deduplicate chats based on referenceId and chatType
          final seenKeys = <String>{};
          final uniqueConvs = <ConversationModel>[];

          for (final conv in allConvs) {
            final otherUser = conv.participants.firstWhere(
              (p) => p != normalizedUserId,
              orElse: () => '',
            );
            final uniqueKey = '${conv.chatType}_${conv.referenceId}_$otherUser';

            if (!seenKeys.contains(uniqueKey)) {
              seenKeys.add(uniqueKey);
              uniqueConvs.add(conv);
            }
          }

          return uniqueConvs;
        });
  }

  /// Stream pending requests (where this user received an unread request message)
  Stream<List<ConversationModel>> streamPendingRequests(String userId) {
    final normalizedUserId = _normalizeUid(userId);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: normalizedUserId)
        .where('chatType', isEqualTo: 'request')
        .snapshots()
        .map((snapshot) {
          var allChats = snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              .toList();

          // Sort by lastMessageTime descending first so deduplication keeps the latest
          allChats.sort(
            (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
          );

          // Deduplicate
          final seenKeys = <String>{};
          final uniqueConvs = <ConversationModel>[];

          for (final conv in allChats) {
            final otherUser = conv.participants.firstWhere(
              (p) => p != normalizedUserId,
              orElse: () => '',
            );
            final uniqueKey = '${conv.chatType}_${conv.referenceId}_$otherUser';

            if (!seenKeys.contains(uniqueKey)) {
              seenKeys.add(uniqueKey);
              uniqueConvs.add(conv);
            }
          }

          return uniqueConvs.where((chat) {
            final lastReadAt = chat.lastReadAt[normalizedUserId];
            final hasUnread =
                lastReadAt == null || chat.lastMessageTime.isAfter(lastReadAt);
            final isIncoming =
                chat.lastSenderId.isNotEmpty &&
                chat.lastSenderId != normalizedUserId;
            return hasUnread && isIncoming;
          }).toList();
        });
  }

  /// Stream messages in a conversation (last 200 for pagination)
  Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
          // Reverse back to chronological order (oldest to newest)
          return messages.reversed.toList();
        });
  }

  /// Mark a message as read
  Future<void> markMessageAsRead(
    String conversationId,
    String messageId,
  ) async {
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'status': 'read'});
  }

  /// Mark all messages in conversation as read and update lastReadAt
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserIdRaw = _auth.currentUser?.uid;
    if (currentUserIdRaw == null) throw Exception('User not authenticated');
    final currentUserId = _normalizeUid(currentUserIdRaw);

    final now = FieldValue.serverTimestamp();

    // Update all unread messages from other user.
    // We filter client-side by normalized receiver id for legacy compatibility.
    // Limit to 500 unread messages to prevent massive queries
    final snapshot = await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .where('status', isEqualTo: 'sent')
        .limit(500)
        .get();

    if (snapshot.docs.isEmpty) {
      // Just update conversation lastReadAt for current user
      await _firestore.collection('chats').doc(conversationId).update({
        'lastReadAt.$currentUserId': now,
      });
      return;
    }

    // Chunking the batch to avoid Firestore 500 write limits
    final batches = <WriteBatch>[];
    WriteBatch currentBatch = _firestore.batch();
    int operationCount = 0;

    for (final doc in snapshot.docs) {
      final receiverRaw = (doc.data()['receiverId'] ?? '').toString().trim();
      if (receiverRaw == currentUserId) {
        currentBatch.update(doc.reference, {'status': 'read'});
        operationCount++;

        if (operationCount >= 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }
    }

    if (operationCount > 0) {
      batches.add(currentBatch);
    }

    for (final batch in batches) {
      await batch.commit();
    }

    // Update conversation lastReadAt for current user
    await _firestore.collection('chats').doc(conversationId).update({
      'lastReadAt.$currentUserId': now,
    });
  }

  /// Get a single conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(conversationId)
        .get();

    if (!snapshot.exists) return null;
    return ConversationModel.fromMap(snapshot.data()!, conversationId);
  }
}
