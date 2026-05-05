import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  ChatProvider(this._chatService);

  List<ConversationModel> _conversations = [];
  List<MessageModel> _currentMessages = [];
  String? _currentConversationId;
  String? _currentUserId;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<ConversationModel>>? _conversationsSubscription;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;

  List<ConversationModel> get conversations => _conversations;
  List<MessageModel> get currentMessages => _currentMessages;
  String? get currentConversationId => _currentConversationId;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalUnreadCount {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return 0;
    }
    return _conversations.fold<int>(0, (unreadTotal, conv) {
      final lastReadAt = conv.lastReadAt[userId];
      final isIncoming =
          conv.lastSenderId != userId && conv.lastSenderId.isNotEmpty;
      final hasUnread =
          isIncoming &&
          (lastReadAt == null || conv.lastMessageTime.isAfter(lastReadAt));
      return unreadTotal + (hasUnread ? 1 : 0);
    });
  }

  void initialize(String userId) {
    _currentUserId = userId;
    _conversationsSubscription?.cancel();

    _conversationsSubscription = _chatService.streamConversations(userId).listen(
      (convs) {
        _conversations = convs;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Failed to load conversations: $e';
        notifyListeners();
      },
    );
  }

  Future<void> openConversation(String conversationId, String userId) async {
    _currentUserId = userId;
    _currentConversationId = conversationId;
    _currentMessages = [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _messagesSubscription?.cancel();
      _messagesSubscription = _chatService.streamMessages(conversationId).listen(
        (messages) {
          _currentMessages = messages;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = e.toString();
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
    if (userId == null || userId.isEmpty) return;

    ConversationModel? conv;
    for (final item in _conversations) {
      if (item.id == conversationId) {
        conv = item;
        break;
      }
    }
    if (conv == null) return;

    final lastReadAt = conv.lastReadAt[userId];
    final hasUnreadIncoming =
        conv.lastSenderId.isNotEmpty &&
        conv.lastSenderId != userId &&
        (lastReadAt == null || conv.lastMessageTime.isAfter(lastReadAt));
    if (!hasUnreadIncoming) return;

    await _chatService.markConversationAsRead(conversationId);
  }

  void closeConversation() {
    _currentConversationId = null;
    _currentMessages = [];
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_currentConversationId == null) {
      throw Exception('No conversation open');
    }
    await _chatService.sendMessage(_currentConversationId!, text);
  }

  Future<String> createOrGetChat({
    required String otherUserId,
    required String chatType,
    required String referenceId,
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

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
