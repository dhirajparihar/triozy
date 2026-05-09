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
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _DetailHeader(
                  conversation: conversation,
                  currentUserId: _currentUserId,
                ),
                _ListingPreview(conversation: conversation),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (chatProvider.isLoading && messages.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
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
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: _SafetyTip(),
                            );
                          }

                          final actualIndex = index - 1;
                          final message = messages[actualIndex];
                          final previous = actualIndex > 0
                              ? messages[actualIndex - 1]
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
                              !_isSameDay(previous.timestamp, message.timestamp);
                          final groupedWithPrevious =
                              previous != null &&
                              previousIsOwnMessage == isOwnMessage &&
                              _isSameDay(previous.timestamp, message.timestamp) &&
                              message.timestamp
                                      .difference(previous.timestamp)
                                      .inMinutes <
                                  4;

                          return Column(
                            children: [
                              if (showDateHeader)
                                _DateChip(label: _dayLabel(message.timestamp)),
                              _MessageBubble(
                                message: message,
                                isOwn: isOwnMessage,
                                isReadByPeer:
                                    isOwnMessage &&
                                    peerLastReadAt != null &&
                                    !message.isFailed &&
                                    !message.isSending &&
                                    !peerLastReadAt.isBefore(message.timestamp),
                                groupedWithPrevious: groupedWithPrevious,
                                formattedTime: _formatTime(message.timestamp),
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
          ),
        );
      },
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
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (difference < 7) {
      return weekdays[dateTime.weekday - 1];
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

class _DetailHeader extends StatelessWidget {
  final ConversationModel? conversation;
  final String currentUserId;

  const _DetailHeader({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final peer = conversation?.peerMetaFor(currentUserId);
    final peerName = (peer?.name ?? '').trim();
    final name = peerName.isEmpty ? 'Messages' : peerName;
    final photoUrl = (peer?.photoUrl ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          Expanded(
            child: Row(
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
                        style: AppTheme.headline(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 16,
                              color: AppColors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Verified',
                              style: AppTheme.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingPreview extends StatelessWidget {
  final ConversationModel? conversation;

  const _ListingPreview({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final title = conversation?.listingTitle.trim().isNotEmpty == true
        ? conversation!.listingTitle.trim()
        : 'Sunny 1BR in Downtown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(
                'assets/onboarding/home.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listing Inquiry',
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headline(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View listing for pricing',
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              'View Details',
              style: AppTheme.body(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.onSurfaceVariant,
                size: 36,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onChanged: onChanged,
                    style: AppTheme.body(
                      fontSize: 16,
                      color: AppColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: AppTheme.body(
                        fontSize: 16,
                        color: AppColors.slate500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: canSend ? onSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: canSend
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppColors.onPrimary,
                  size: 28,
                ),
              ),
            ),
          ],
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
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainerHigh,
      ),
      child: ClipOval(
        child: photoUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: AppTheme.headline(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
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
                    style: AppTheme.headline(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
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
    final bubbleColor = isOwn
        ? AppColors.primary
        : AppColors.surfaceContainerLow;
    final textColor = isOwn ? AppColors.onPrimary : AppColors.onSurface;
    final timeColor = message.isFailed
        ? AppColors.error
        : (isOwn ? AppColors.slate500 : AppColors.onSurfaceVariant);
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          top: groupedWithPrevious ? 4 : 8,
          bottom: 8,
          left: isOwn ? 42 : 0,
          right: isOwn ? 0 : 42,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: isOwn
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: message.isFailed ? onRetry : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isOwn ? 26 : 10),
                      topRight: Radius.circular(isOwn ? 10 : 26),
                      bottomLeft: const Radius.circular(26),
                      bottomRight: const Radius.circular(26),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: AppTheme.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isFailed)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        'Tap to retry',
                        style: AppTheme.body(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  Text(
                    formattedTime,
                    style: AppTheme.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
        size: 16,
        color: AppColors.primary,
      );
    }
    return const Icon(
      Icons.done_all_rounded,
      size: 16,
      color: AppColors.slate500,
    );
  }
}

class _SafetyTip extends StatelessWidget {
  const _SafetyTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTheme.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                  height: 1.55,
                ),
                children: [
                  TextSpan(
                    text: 'Safety Tip: ',
                    style: AppTheme.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'For your protection, always keep your communications and payments within the Triozy platform. Avoid transferring money externally.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
