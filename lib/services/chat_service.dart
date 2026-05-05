import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _normalizeUid(String raw) {
    final value = raw.trim();
    if (value.isEmpty || !value.contains('_')) {
      return value;
    }
    final tail = value.split('_').last.trim();
    final looksLikeUid = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(tail);
    return looksLikeUid ? tail : value;
  }

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
      'lastReadAt': {currentUserId: now},
      'createdAt': now,
    };
  }

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

    final chatId = _generateChatId(
      currentUserId,
      normalizedOtherUserId,
      chatType,
      referenceId,
    );
    final ref = _firestore.collection('chats').doc(chatId);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      return chatId;
    }

    await ref.set(
      _conversationPayload(
        currentUserId: currentUserId,
        otherUserId: normalizedOtherUserId,
        chatType: chatType,
        referenceId: referenceId,
      ),
    );
    return chatId;
  }

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

      final participants = List<String>.from(
        convDoc.data()?['participants'] ?? const <String>[],
      ).map(_normalizeUid).toList();
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

  Stream<List<ConversationModel>> streamConversations(String userId) {
    final normalizedUserId = _normalizeUid(userId);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: normalizedUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              .where((conv) => conv.lastMessage.trim().isNotEmpty)
              .toList();
          conversations.sort(
            (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
          );
          return conversations;
        });
  }

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
          return messages.reversed.toList();
        });
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserIdRaw = _auth.currentUser?.uid;
    if (currentUserIdRaw == null) throw Exception('User not authenticated');
    final currentUserId = _normalizeUid(currentUserIdRaw);
    final now = FieldValue.serverTimestamp();

    final snapshot = await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .where('status', isEqualTo: 'sent')
        .limit(500)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final receiverRaw = (doc.data()['receiverId'] ?? '').toString().trim();
        if (receiverRaw == currentUserId) {
          batch.update(doc.reference, {'status': 'read'});
        }
      }
      await batch.commit();
    }

    await _firestore.collection('chats').doc(conversationId).update({
      'lastReadAt.$currentUserId': now,
    });
  }
}
