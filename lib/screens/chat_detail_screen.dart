import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../models/listing_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;

  const ChatDetailScreen({super.key, required this.conversationId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final String _currentUserId;
  late Future<_ChatHeaderData> _headerFuture;
  bool _isSending = false;
  bool _isUserNearBottom = true;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _headerFuture = _resolveHeaderData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openConversation();
    });
  }

  Future<void> _openConversation() async {
    final provider = context.read<ChatProvider>();
    await provider.openConversation(widget.conversationId, _currentUserId);
    if (!mounted) {
      return;
    }
    await provider.markConversationAsReadIfNeeded(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    context.read<ChatProvider>().closeConversation();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final distanceToBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    _isUserNearBottom = distanceToBottom <= 120;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _maybeAutoScroll(List<MessageModel> messages) {
    if (messages.isEmpty) {
      _lastMessageCount = 0;
      return;
    }

    final hasNewMessage = messages.length != _lastMessageCount;
    _lastMessageCount = messages.length;
    if (!hasNewMessage) {
      return;
    }

    final isLatestOwn = messages.last.senderId == _currentUserId;
    if (_isUserNearBottom || isLatestOwn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (_isSending || text.isEmpty) {
      return;
    }

    _messageController.clear();
    setState(() {
      _isSending = true;
    });

    try {
      await context.read<ChatProvider>().sendMessage(text);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  bool get _canSend => !_isSending && _messageController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.isLoading &&
                    chatProvider.currentMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = chatProvider.currentMessages;
                _maybeAutoScroll(messages);

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: AppTheme.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      isOwn: message.senderId == _currentUserId,
                      formattedTime: _formatTime(message.timestamp),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _canSend
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _canSend ? _sendMessage : null,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.onSurface,
      elevation: 0.5,
      title: FutureBuilder<_ChatHeaderData>(
        future: _headerFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ??
              const _ChatHeaderData(
                name: 'Messages',
                photoUrl: '',
                typeLabel: '',
              );
          final avatar = _safeAvatarProvider(data.photoUrl);
          final initial = data.name.isEmpty ? '?' : data.name[0].toUpperCase();

          return Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.blue50,
                backgroundImage: avatar,
                child: avatar == null
                    ? Text(
                        initial,
                        style: AppTheme.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (data.typeLabel.isNotEmpty)
                      Text(
                        data.typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ImageProvider? _safeAvatarProvider(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return NetworkImage(trimmed);
  }

  Future<_ChatHeaderData> _resolveHeaderData() async {
    if (_currentUserId.isEmpty) {
      return const _ChatHeaderData(
        name: 'Messages',
        photoUrl: '',
        typeLabel: '',
      );
    }

    final chatProvider = context.read<ChatProvider>();
    ConversationModel? conversation;
    for (final item in chatProvider.conversations) {
      if (item.id == widget.conversationId) {
        conversation = item;
        break;
      }
    }

    if (conversation == null) {
      return const _ChatHeaderData(
        name: 'Messages',
        photoUrl: '',
        typeLabel: '',
      );
    }

    final otherUserId = conversation.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    final db = context.read<DatabaseService>();
    final listing = await db.getListing(conversation.referenceId);

    String name = 'User';
    String photoUrl = '';
    String typeLabel = 'Listing';

    if (listing != null) {
      typeLabel = listing.propertyType.label;
      if (listing.ownerId == otherUserId) {
        name = listing.ownerName.isEmpty ? name : listing.ownerName;
        photoUrl = listing.ownerPhotoUrl;
      }
      if (listing.title.trim().isNotEmpty) {
        typeLabel = '${listing.propertyType.label} - ${listing.title.trim()}';
      }
    }

    if ((name == 'User' || photoUrl.isEmpty) && otherUserId.isNotEmpty) {
      final userData = await db.getUserData(otherUserId);
      if (userData != null) {
        final resolvedName = (userData['name'] ?? '').toString().trim();
        final resolvedPhoto = (userData['photoUrl'] ?? '').toString().trim();
        if (resolvedName.isNotEmpty) {
          name = resolvedName;
        }
        if (resolvedPhoto.isNotEmpty) {
          photoUrl = resolvedPhoto;
        }
      }
    }

    return _ChatHeaderData(
      name: name,
      photoUrl: photoUrl,
      typeLabel: typeLabel,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;
  final String formattedTime;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOwn ? AppColors.primary : AppColors.surfaceContainer,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOwn ? 16 : 4),
                bottomRight: Radius.circular(isOwn ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: AppTheme.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isOwn ? Colors.white : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedTime,
                      style: AppTheme.body(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOwn
                            ? Colors.white.withValues(alpha: 0.72)
                            : AppColors.slate500,
                      ),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == 'read'
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 14,
                        color: message.status == 'read'
                            ? Colors.cyanAccent
                            : Colors.white.withValues(alpha: 0.72),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHeaderData {
  final String name;
  final String photoUrl;
  final String typeLabel;

  const _ChatHeaderData({
    required this.name,
    required this.photoUrl,
    required this.typeLabel,
  });
}
