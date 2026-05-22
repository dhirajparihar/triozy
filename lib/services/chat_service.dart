import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';


// === Chat data access ========================================================

/// Firestore-backed chat access for conversations and messages.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the current user id or throws if not authenticated.
  String _currentUserIdOrThrow() {
    final currentUserId = normalizeChatUid(_auth.currentUser?.uid ?? '');
    if (currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }
    return currentUserId;
  }

  /// Creates a deterministic chat id based on participants and reference.
  String _generateChatId(
    String uid1,
    String uid2,
    ChatType chatType,
    String referenceId,
  ) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}_${chatType.value}_$referenceId';
  }

  /// Full payload for first-time conversation creation.
  Map<String, dynamic> _conversationPayload({
    required String currentUserId,
    required String otherUserId,
    required ChatType chatType,
    required String referenceId,
    required String listingTitle,
    required String otherUserName,
    required String otherUserPhotoUrl,
    required String currentUserName,
    required String currentUserPhotoUrl,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      'participants': [currentUserId, otherUserId],
      'participantMeta': {
        currentUserId: {
          'name': currentUserName.trim(),
          'photoUrl': currentUserPhotoUrl.trim(),
        },
        otherUserId: {
          'name': otherUserName.trim(),
          'photoUrl': otherUserPhotoUrl.trim(),
        },
      },
      'chatType': chatType.value,
      'referenceId': referenceId,
      'listingTitle': listingTitle.trim(),
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageTime': now,
      'lastSenderId': '',
      'lastReadAt': {currentUserId: now, otherUserId: now},
      'unreadCountByUser': {currentUserId: 0, otherUserId: 0},
      'typingByUser': {currentUserId: false, otherUserId: false},
      'hiddenBy': [],
      'createdAt': now,
    };
  }

  /// Minimal payload used when full creation is not permitted.
  Map<String, dynamic> _conversationMergePayload({
    required String currentUserId,
    required String otherUserId,
    required ChatType chatType,
    required String referenceId,
    required String listingTitle,
    required String otherUserName,
    required String otherUserPhotoUrl,
    required String currentUserName,
    required String currentUserPhotoUrl,
  }) {
    return {
      'participants': [currentUserId, otherUserId],
      'participantMeta': {
        currentUserId: {
          'name': currentUserName.trim(),
          'photoUrl': currentUserPhotoUrl.trim(),
        },
        otherUserId: {
          'name': otherUserName.trim(),
          'photoUrl': otherUserPhotoUrl.trim(),
        },
      },
      'chatType': chatType.value,
      'referenceId': referenceId,
      'listingTitle': listingTitle.trim(),
      'unreadCountByUser': {currentUserId: 0, otherUserId: 0},
      'typingByUser': {currentUserId: false, otherUserId: false},
      'hiddenBy': [],
    };
  }

  /// Creates or fetches a conversation and returns its id.
  ///
  /// Falls back to a merged write when full creation is blocked by rules.
  Future<String> getOrCreateConversation({
    required String otherUserId,
    required ChatType chatType,
    required String referenceId,
    required String listingTitle,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? otherUserLocation,
    String? currentUserName,
    String? currentUserPhotoUrl,
    String? currentUserLocation,
  }) async {
    final currentUserId = _currentUserIdOrThrow();
    final normalizedOtherUserId = normalizeChatUid(otherUserId);
    if (normalizedOtherUserId.isEmpty) {
      throw Exception('Invalid recipient');
    }

    final chatId = _generateChatId(
      currentUserId,
      normalizedOtherUserId,
      chatType,
      referenceId,
    );
    final ref = _firestore.collection('chats').doc(chatId);

    try {
      await ref.set(
        _conversationPayload(
          currentUserId: currentUserId,
          otherUserId: normalizedOtherUserId,
          chatType: chatType,
          referenceId: referenceId,
          listingTitle: listingTitle,
          otherUserName: otherUserName ?? 'User',
          otherUserPhotoUrl: otherUserPhotoUrl ?? '',
          currentUserName: currentUserName ?? 'You',
          currentUserPhotoUrl: currentUserPhotoUrl ?? '',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
      await ref.set(
        _conversationMergePayload(
          currentUserId: currentUserId,
          otherUserId: normalizedOtherUserId,
          chatType: chatType,
          referenceId: referenceId,
          listingTitle: listingTitle,
          otherUserName: otherUserName ?? 'User',
          otherUserPhotoUrl: otherUserPhotoUrl ?? '',
          currentUserName: currentUserName ?? 'You',
          currentUserPhotoUrl: currentUserPhotoUrl ?? '',
        ),
        SetOptions(merge: true),
      );
    }

    return chatId;
  }

  /// Sends a text message within a conversation.
  ///
  /// Uses a transaction to keep the conversation summary in sync.
  Future<void> sendMessage(
    String conversationId,
    String text, {
    required String clientId,
  }) async {
    final currentUserId = _currentUserIdOrThrow();
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final conversationRef = _firestore.collection('chats').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc(clientId);

    await _firestore.runTransaction((txn) async {
      final convDoc = await txn.get(conversationRef);
      if (!convDoc.exists) {
        throw Exception('Conversation not found');
      }

      final participants = List<String>.from(
        convDoc.data()?['participants'] ?? const <String>[],
      ).map(normalizeChatUid).toList();
      if (!participants.contains(currentUserId)) {
        throw Exception('Not a participant of this conversation');
      }

      final receiverId = participants.firstWhere(
        (uid) => uid != currentUserId,
        orElse: () => throw Exception('Receiver not found in conversation'),
      );
      final now = FieldValue.serverTimestamp();

      txn.set(messageRef, {
        'clientId': clientId,
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': normalizedText,
        'timestamp': now,
        'status': 'sent',
      });
      txn.update(conversationRef, {
        'lastMessage': normalizedText,
        'lastMessageType': 'text',
        'lastMessageTime': now,
        'lastSenderId': currentUserId,
        'lastReadAt.$currentUserId': now,
        'unreadCountByUser.$currentUserId': 0,
        'unreadCountByUser.$receiverId': FieldValue.increment(1),
        'typingByUser.$currentUserId': false,
      });
    });
  }

  /// Streams the user's conversations ordered by latest activity.
  Stream<List<ConversationModel>> streamConversations(String userId) {
    final normalizedUserId = normalizeChatUid(userId);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: normalizedUserId)
        .orderBy('lastMessageTime', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final conversations = snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              .where((conversation) {
                if (conversation.hiddenBy.contains(normalizedUserId)) {
                  return false;
                }
                final deletedAt = conversation.referenceDeletedAt;
                if (deletedAt != null && now.difference(deletedAt).inDays >= 30) {
                  // TODO: Move this archival cleanup to a scheduled Cloud Function
                  // once backend functions are available.
                  return false;
                }
                return true;
              })
              .toList();
          conversations.sort(
            (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
          );
          return conversations;
        });
  }

  /// Hides the given conversation for the current user only.
  Future<void> hideConversationForCurrentUser(String conversationId) async {
    final currentUserId = _currentUserIdOrThrow();
    await _firestore.collection('chats').doc(conversationId).update({
      'hiddenBy': FieldValue.arrayUnion([currentUserId]),
    });
  }

  /// Marks all chat documents related to a deleted listing as deleted.
  Future<void> markChatsAsListingDeleted(String listingId) async {
    final chatQuery = await _firestore
        .collection('chats')
        .where('referenceId', isEqualTo: listingId)
        .get();
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final doc in chatQuery.docs) {
      batch.update(doc.reference, {
        'referenceDeleted': true,
        'referenceDeletedAt': now,
      });
    }

    await batch.commit();
  }

  /// Streams messages within a conversation in ascending time order.
  Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(120)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

        /// Marks the current conversation as read for the current user.
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserId = _currentUserIdOrThrow();
    final now = FieldValue.serverTimestamp();

    await _firestore.collection('chats').doc(conversationId).update({
      'lastReadAt.$currentUserId': now,
      'unreadCountByUser.$currentUserId': 0,
      'typingByUser.$currentUserId': false,
    });
  }

  /// Updates typing state for the current user.
  Future<void> setTypingStatus(
    String conversationId, {
    required bool isTyping,
  }) async {
    final currentUserId = _currentUserIdOrThrow();
    await _firestore.collection('chats').doc(conversationId).update({
      'typingByUser.$currentUserId': isTyping,
    });
  }
}
