import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  ChatProvider(this._chatService);

  List<ConversationModel> _conversations = [];
  List<MessageModel> _streamMessages = [];
  List<MessageModel> _pendingMessages = [];
  String? _currentConversationId;
  String? _currentUserId;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTyping = false;

  StreamSubscription<List<ConversationModel>>? _conversationsSubscription;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;

  List<ConversationModel> get conversations => _conversations;
  List<MessageModel> get currentMessages => _mergedCurrentMessages();
  String? get currentConversationId => _currentConversationId;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTyping => _isTyping;

  ConversationModel? get currentConversation {
    final id = _currentConversationId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  int get totalUnreadCount {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return 0;
    }
    return _conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.unreadCountFor(userId),
    );
  }

  void initialize(String userId) {
    _currentUserId = normalizeChatUid(userId);
    _errorMessage = null;
    _conversationsSubscription?.cancel();

    _conversationsSubscription = _chatService
        .streamConversations(_currentUserId!)
        .listen(
          (conversations) {
            _conversations = conversations;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = 'Failed to load conversations: $error';
            notifyListeners();
          },
        );
  }

  Future<void> openConversation(String conversationId, String userId) async {
    _currentUserId = normalizeChatUid(userId);
    _currentConversationId = conversationId;
    _streamMessages = [];
    _pendingMessages = [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _messagesSubscription?.cancel();
      _messagesSubscription = _chatService
          .streamMessages(conversationId)
          .listen(
            (messages) {
              _streamMessages = messages;
              _reconcilePendingMessages();
              notifyListeners();
            },
            onError: (error) {
              _errorMessage = error.toString();
              notifyListeners();
            },
          );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markConversationAsReadIfNeeded(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final conversation = _conversationById(conversationId);
    if (conversation == null || conversation.unreadCountFor(userId) == 0) {
      return;
    }

    await _chatService.markConversationAsRead(conversationId);
  }

  Future<void> setTypingForCurrentConversation(bool value) async {
    if (_currentConversationId == null) {
      return;
    }
    if (_isTyping == value) {
      return;
    }

    _isTyping = value;
    notifyListeners();

    try {
      await _chatService.setTypingStatus(
        _currentConversationId!,
        isTyping: value,
      );
    } catch (_) {
      _isTyping = false;
      notifyListeners();
    }
  }

  void closeConversation() {
    final conversationId = _currentConversationId;
    if (conversationId != null && _isTyping) {
      unawaited(_chatService.setTypingStatus(conversationId, isTyping: false));
    }
    _currentConversationId = null;
    _streamMessages = [];
    _pendingMessages = [];
    _isTyping = false;
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final conversationId = _currentConversationId;
    final currentUserId = _currentUserId;
    if (conversationId == null || currentUserId == null) {
      throw Exception('No conversation open');
    }

    final conversation = _conversationById(conversationId);
    final receiverId = conversation?.peerIdFor(currentUserId) ?? '';
    final clientId = generateChatClientId();
    final pendingMessage = MessageModel.optimistic(
      clientId: clientId,
      senderId: currentUserId,
      receiverId: receiverId,
      text: text.trim(),
    );

    _pendingMessages = [..._pendingMessages, pendingMessage];
    _isTyping = false;
    _errorMessage = null;
    notifyListeners();

    try {
      await _chatService.sendMessage(conversationId, text, clientId: clientId);
      _updatePendingStatus(clientId, 'sent');
    } catch (error) {
      _updatePendingStatus(clientId, 'failed');
      _errorMessage = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> retryMessage(String clientId) async {
    MessageModel? failedMessage;
    for (final message in _pendingMessages) {
      if (message.clientId == clientId) {
        failedMessage = message;
        break;
      }
    }
    if (failedMessage == null) {
      return;
    }

    _pendingMessages = _pendingMessages
        .where((message) => message.clientId != clientId)
        .toList();
    notifyListeners();
    await sendMessage(failedMessage.text);
  }

  Future<String> createOrGetChat({
    required String otherUserId,
    required String chatType,
    required String referenceId,
    required String listingTitle,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? otherUserLocation,
    String? currentUserName,
    String? currentUserPhotoUrl,
    String? currentUserLocation,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _chatService.getOrCreateConversation(
        otherUserId: otherUserId,
        chatType: ChatTypeX.fromString(chatType),
        referenceId: referenceId,
        listingTitle: listingTitle,
        otherUserName: otherUserName,
        otherUserPhotoUrl: otherUserPhotoUrl,
        otherUserLocation: otherUserLocation,
        currentUserName: currentUserName,
        currentUserPhotoUrl: currentUserPhotoUrl,
        currentUserLocation: currentUserLocation,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ConversationModel? _conversationById(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }
    return null;
  }

  void _updatePendingStatus(String clientId, String status) {
    _pendingMessages = _pendingMessages
        .map(
          (message) => message.clientId == clientId
              ? message.copyWith(status: status)
              : message,
        )
        .toList();
    notifyListeners();
  }

  void _reconcilePendingMessages() {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }
    final serverClientIds = _streamMessages
        .map((message) => message.clientId)
        .toSet();
    _pendingMessages = _pendingMessages.where((pending) {
      if (serverClientIds.contains(pending.clientId)) {
        return false;
      }
      for (final message in _streamMessages) {
        final sameSender = message.senderId == currentUserId;
        final sameText = message.text.trim() == pending.text.trim();
        final closeInTime =
            message.timestamp.difference(pending.timestamp).inSeconds.abs() <=
            20;
        if (sameSender && sameText && closeInTime) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<MessageModel> _mergedCurrentMessages() {
    final merged = [..._streamMessages, ..._pendingMessages];
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
