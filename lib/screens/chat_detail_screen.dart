import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
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
  late final String _currentUserRawId;
  late final String _currentUserId;
  Timer? _typingTimer;
  Timer? _typingStartTimer;
  bool _isSending = false;
  bool _isUserNearBottom = true;
  bool _isMarkingRead = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
    _currentUserRawId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _currentUserId = normalizeChatUid(_currentUserRawId);

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
    await _markConversationRead(provider);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingStartTimer?.cancel();
    if (_currentUserId.isNotEmpty) {
      unawaited(
        context.read<ChatProvider>().setTypingForCurrentConversation(false),
      );
    }
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
    _isUserNearBottom = distanceToBottom <= 140;
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    if (!animated) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
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
    final chatProvider = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final text = _messageController.text.trim();
    if (_isSending || text.isEmpty) {
      return;
    }

    _typingTimer?.cancel();
    _typingStartTimer?.cancel();
    _messageController.clear();
    await chatProvider.setTypingForCurrentConversation(false);
    if (!mounted) {
      return;
    }
    setState(() => _isSending = true);

    try {
      await chatProvider.sendMessage(text);
      if (!mounted) {
        return;
      }
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _handleComposerChanged(String value) {
    setState(() {});

    _typingTimer?.cancel();
    _typingStartTimer?.cancel();
    if (value.trim().isEmpty) {
      unawaited(
        context.read<ChatProvider>().setTypingForCurrentConversation(false),
      );
      return;
    }

    _typingStartTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      unawaited(
        context.read<ChatProvider>().setTypingForCurrentConversation(true),
      );
    });
    _typingTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) {
        return;
      }
      unawaited(
        context.read<ChatProvider>().setTypingForCurrentConversation(false),
      );
    });
  }

  bool get _canSend => !_isSending && _messageController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final conversation = chatProvider.currentConversation;
        final messages = chatProvider.currentMessages;
        final peerId = conversation?.peerIdFor(_currentUserId) ?? '';
        final peerLastReadAt = peerId.isEmpty
            ? null
            : conversation?.lastReadAt[peerId];
        _maybeAutoScroll(messages);

        if (conversation != null &&
            conversation.unreadCountFor(_currentUserId) > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _markConversationRead(chatProvider);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F8FF),
          appBar: _buildAppBar(conversation),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F8FF), Color(0xFFEAF2FF)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -20,
                  child: _BackdropOrb(
                    size: 180,
                    color: AppColors.primary.withValues(alpha: 0.10),
                  ),
                ),
                Positioned(
                  top: 180,
                  left: -30,
                  child: _BackdropOrb(
                    size: 150,
                    color: AppColors.blue600.withValues(alpha: 0.08),
                  ),
                ),
                Column(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (chatProvider.isLoading && messages.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if ((chatProvider.errorMessage ?? '').isNotEmpty &&
                              messages.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  chatProvider.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (messages.isEmpty) {
                            return Center(
                              child: Text(
                                'No messages yet. Say hello and start the conversation.',
                                textAlign: TextAlign.center,
                                style: AppTheme.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slate500,
                                  height: 1.6,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final previous = index > 0
                                  ? messages[index - 1]
                                  : null;
                              final isOwnMessage = _isOwnMessage(
                                message,
                                conversation,
                              );
                              final previousIsOwnMessage = previous == null
                                  ? null
                                  : _isOwnMessage(previous, conversation);
                              final showDateHeader =
                                  previous == null ||
                                  !_isSameDay(
                                    previous.timestamp,
                                    message.timestamp,
                                  );
                              final groupedWithPrevious =
                                  previous != null &&
                                  previousIsOwnMessage == isOwnMessage &&
                                  _isSameDay(
                                    previous.timestamp,
                                    message.timestamp,
                                  ) &&
                                  message.timestamp
                                          .difference(previous.timestamp)
                                          .inMinutes <
                                      4;

                              return Column(
                                children: [
                                  if (showDateHeader)
                                    _DateChip(
                                      label: _dayLabel(message.timestamp),
                                    ),
                                  _MessageBubble(
                                    message: message,
                                    isOwn: isOwnMessage,
                                    isReadByPeer:
                                        isOwnMessage &&
                                        peerLastReadAt != null &&
                                        !message.isFailed &&
                                        !message.isSending &&
                                        !peerLastReadAt.isBefore(
                                          message.timestamp,
                                        ),
                                    groupedWithPrevious: groupedWithPrevious,
                                    formattedTime: _formatTime(
                                      message.timestamp,
                                    ),
                                    onRetry: message.isFailed
                                        ? () => chatProvider.retryMessage(
                                            message.clientId,
                                          )
                                        : null,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _Composer(
                      controller: _messageController,
                      canSend: _canSend,
                      onChanged: _handleComposerChanged,
                      onSend: _sendMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(ConversationModel? conversation) {
    final peer = conversation?.peerMetaFor(_currentUserId);
    final isPeerTyping = conversation?.isPeerTypingFor(_currentUserId) ?? false;
    final peerName = (peer?.name ?? '').trim();
    final name = peerName.isEmpty ? 'Messages' : peerName;
    final subtitle = isPeerTyping
        ? 'typing...'
        : ((conversation?.listingTitle ?? '').trim().isEmpty
              ? 'Conversation'
              : conversation!.listingTitle.trim());
    final photoUrl = (peer?.photoUrl ?? '').trim();

    return AppBar(
      backgroundColor: const Color(0xFFF8FBFF),
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      titleSpacing: 4,
      title: Row(
        children: [
          _PeerAvatar(name: name, photoUrl: photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPeerTyping ? AppColors.primary : AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _dayLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) {
      return 'Today';
    }
    if (difference == 1) {
      return 'Yesterday';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isOwnMessage(MessageModel message, ConversationModel? conversation) {
    if (message.rawSenderId.isNotEmpty &&
        message.rawSenderId == _currentUserRawId) {
      return true;
    }
    if (message.rawReceiverId.isNotEmpty &&
        message.rawReceiverId == _currentUserRawId) {
      return false;
    }

    final senderId = normalizeChatUid(message.senderId);
    final receiverId = normalizeChatUid(message.receiverId);

    if (senderId == _currentUserId) {
      return true;
    }
    if (receiverId == _currentUserId) {
      return false;
    }

    final peerId = conversation?.peerIdFor(_currentUserId) ?? '';
    if (peerId.isNotEmpty) {
      return senderId != peerId;
    }

    return false;
  }

  Future<void> _markConversationRead(ChatProvider provider) async {
    if (_isMarkingRead) {
      return;
    }
    _isMarkingRead = true;
    try {
      await provider.markConversationAsReadIfNeeded(widget.conversationId);
    } finally {
      _isMarkingRead = false;
    }
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFDFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: AppTheme.body(
                      fontSize: 15,
                      color: AppColors.slate400,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: canSend
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.28),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: canSend ? onSend : null,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
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
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;

  const _PeerAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue50,
      ),
      child: ClipOval(
        child: photoUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: AppTheme.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    initial,
                    style: AppTheme.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.blue50.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: AppTheme.label(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isOwn;
  final bool isReadByPeer;
  final bool groupedWithPrevious;
  final String formattedTime;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.isReadByPeer,
    required this.groupedWithPrevious,
    required this.formattedTime,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isOwn ? const Color(0xFFDCEBFF) : const Color(0xFFFDFEFF);
    final timeColor = message.isFailed
        ? AppColors.error
        : (isOwn ? AppColors.slate500 : AppColors.slate500);
    final radius = Radius.circular(groupedWithPrevious ? 14 : 22);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: groupedWithPrevious ? 2 : 8, bottom: 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: GestureDetector(
            onTap: message.isFailed ? onRetry : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                border: Border.all(
                  color: isOwn
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : AppColors.outlineVariant.withValues(alpha: 0.22),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: Radius.circular(isOwn ? 22 : 6),
                  bottomRight: Radius.circular(isOwn ? 6 : 22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message.text,
                      style: AppTheme.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isFailed)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            'Tap to retry',
                            style: AppTheme.label(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      Text(
                        formattedTime,
                        style: AppTheme.label(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: timeColor,
                        ),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 4),
                        _StatusIcon(
                          message: message,
                          isReadByPeer: isReadByPeer,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageModel message;
  final bool isReadByPeer;

  const _StatusIcon({required this.message, required this.isReadByPeer});

  @override
  Widget build(BuildContext context) {
    if (message.isSending) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.slate500,
        ),
      );
    }
    if (message.isFailed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 14,
        color: AppColors.error,
      );
    }
    if (isReadByPeer || message.isRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: AppColors.primary,
      );
    }
    return const Icon(
      Icons.done_all_rounded,
      size: 15,
      color: AppColors.slate500,
    );
  }
}
