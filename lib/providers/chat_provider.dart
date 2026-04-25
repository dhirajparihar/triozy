import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  ChatProvider(this._chatService);

  // State
  List<ConversationModel> _conversations = [];
  List<ConversationModel> _pendingRequests = [];
  List<MessageModel> _currentMessages = [];
  String? _currentConversationId;
  String? _currentUserId;

  bool _isLoading = false;
  String? _errorMessage;

  // Stream subscriptions (to manage lifecycle)
  StreamSubscription<List<ConversationModel>>? _conversationsSubscription;
  StreamSubscription<List<ConversationModel>>? _pendingRequestsSubscription;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;

  // Getters
  List<ConversationModel> get conversations => _conversations;
  List<ConversationModel> get pendingRequests => _pendingRequests;
  List<MessageModel> get currentMessages => _currentMessages;
  String? get currentConversationId => _currentConversationId;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Total unread count across all conversations
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

  /// Get unread count for a specific user
  int getUnreadCount(String userId) {
    if (userId.isEmpty) return 0;
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

  /// Initialize: start listening to conversations and pending requests
  void initialize(String userId) {
    _currentUserId = userId;
    _conversationsSubscription?.cancel();
    _pendingRequestsSubscription?.cancel();

    // Stream conversations
    _conversationsSubscription = _chatService
        .streamConversations(userId)
        .listen(
          (convs) {
            _conversations = convs;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = 'Failed to load conversations: $e';
            notifyListeners();
          },
        );

    // Stream pending requests
    _pendingRequestsSubscription = _chatService
        .streamPendingRequests(userId)
        .listen(
          (pending) {
            _pendingRequests = pending;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = 'Failed to load pending requests: $e';
            notifyListeners();
          },
        );
  }

  /// Open a conversation and start listening to messages
  Future<void> openConversation(String conversationId, String userId) async {
    _currentUserId = userId;
    _currentConversationId = conversationId;
    _currentMessages = []; // Clear previous messages to prevent state bleeding
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Cancel previous messages subscription
      _messagesSubscription?.cancel();

      // Listen to messages first
      _messagesSubscription = _chatService
          .streamMessages(conversationId)
          .listen(
            (messages) {
              _currentMessages = messages;
              notifyListeners();
            },
            onError: (e) {
              _errorMessage = e.toString();
              notifyListeners();
            },
          );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a conversation as read only when it actually has incoming unread items.
  Future<void> markConversationAsReadIfNeeded(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    ConversationModel? conv;
    for (final c in _conversations) {
      if (c.id == conversationId) {
        conv = c;
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

  /// Close current conversation
  void closeConversation() {
    _currentConversationId = null;
    _currentMessages = [];
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  /// Send a message
  Future<void> sendMessage(String text) async {
    if (_currentConversationId == null) {
      throw Exception('No conversation open');
    }

    try {
      await _chatService.sendMessage(_currentConversationId!, text);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create or get a context-based chat:
  /// chatId = sorted(uid1, uid2) + "_" + referenceId
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
      final chatTypeEnum = ChatTypeX.fromString(chatType);
      final conversationId = await _chatService.getOrCreateConversation(
        otherUserId: otherUserId,
        chatType: chatTypeEnum,
        referenceId: referenceId,
        otherUserName: otherUserName,
        otherUserPhotoUrl: otherUserPhotoUrl,
        otherUserLocation: otherUserLocation,
        currentUserName: currentUserName,
        currentUserPhotoUrl: currentUserPhotoUrl,
        currentUserLocation: currentUserLocation,
      );

      return conversationId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _pendingRequestsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
