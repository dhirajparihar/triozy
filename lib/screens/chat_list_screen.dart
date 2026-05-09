import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

enum _ChatInboxSegment { housing, marketplace }

class ChatListScreen extends StatefulWidget {
  final bool showScaffold;

  const ChatListScreen({super.key, this.showScaffold = true});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _currentUserId;
  _ChatInboxSegment _selectedSegment = _ChatInboxSegment.housing;

  @override
  void initState() {
    super.initState();
    _currentUserId = normalizeChatUid(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );
    _searchController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = _currentUserId;
      if (uid != null && uid.isNotEmpty) {
        context.read<ChatProvider>().initialize(uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      return widget.showScaffold
          ? const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: Text('Please sign in to view chats')),
            )
          : const Center(child: Text('Please sign in to view chats'));
    }

    final content = Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = chatProvider.conversations.where((conversation) {
          final peer = conversation.peerMetaFor(uid);
          final searchable = [
            peer?.name ?? '',
            conversation.listingTitle,
            conversation.lastMessage,
          ].join(' ').toLowerCase();
          return _matchesSegment(conversation) &&
              (query.isEmpty || searchable.contains(query));
        }).toList();

        return Container(
          color: AppColors.background,
          child: Column(
            children: [
              _ChatListHeader(
                controller: _searchController,
                focusNode: _searchFocusNode,
                selectedSegment: _selectedSegment,
                onSegmentChanged: (segment) {
                  setState(() => _selectedSegment = segment);
                },
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if ((chatProvider.errorMessage ?? '').isNotEmpty) {
                      return _ErrorState(message: chatProvider.errorMessage!);
                    }
                    if (chatProvider.isLoading && filtered.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        hasSearch: query.isNotEmpty,
                        query: query,
                        selectedSegment: _selectedSegment,
                      );
                    }

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        chatProvider.initialize(uid);
                        await Future<void>.delayed(
                          const Duration(milliseconds: 300),
                        );
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final conversation = filtered[index];
                          return _ConversationTile(
                            conversation: conversation,
                            currentUserId: uid,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    conversationId: conversation.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: content),
    );
  }

  bool _matchesSegment(ConversationModel conversation) {
    switch (_selectedSegment) {
      case _ChatInboxSegment.housing:
        return conversation.chatType == ChatType.listing;
      case _ChatInboxSegment.marketplace:
        return conversation.chatType != ChatType.listing;
    }
  }
}

class _ChatListHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final _ChatInboxSegment selectedSegment;
  final ValueChanged<_ChatInboxSegment> onSegmentChanged;

  const _ChatListHeader({
    required this.controller,
    required this.focusNode,
    required this.selectedSegment,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _HeaderIconButton(
                      icon: Icons.location_on_outlined,
                      onTap: () {},
                    ),
                  ),
                  Text(
                    'Triozy',
                    style: AppTheme.headline(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _HeaderIconButton(
                      icon: Icons.search_rounded,
                      onTap: focusNode.requestFocus,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppTheme.body(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: AppTheme.body(
                    fontSize: 16,
                    color: AppColors.slate500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 28,
                    color: AppColors.slate500,
                  ),
                  suffixIcon: controller.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: controller.clear,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.slate500,
                          ),
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 56,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Housing',
                      selected: selectedSegment == _ChatInboxSegment.housing,
                      onTap: () =>
                          onSegmentChanged(_ChatInboxSegment.housing),
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Marketplace',
                      selected: selectedSegment == _ChatInboxSegment.marketplace,
                      onTap: () =>
                          onSegmentChanged(_ChatInboxSegment.marketplace),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Icon(icon, color: AppColors.primary, size: 30),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.body(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final peer = conversation.peerMetaFor(currentUserId);
    final unreadCount = conversation.unreadCountFor(currentUserId);
    final isPeerTyping = conversation.isPeerTypingFor(currentUserId);
    final isUnread = unreadCount > 0;
    final peerName = (peer?.name ?? '').trim();
    final name = peerName.isEmpty ? 'User' : peerName;
    final subtitle = isPeerTyping
        ? 'Typing...'
        : (conversation.lastMessage.trim().isEmpty
              ? 'Say hello to start the conversation.'
              : conversation.lastMessage.trim());
    final photoUrl = (peer?.photoUrl ?? '').trim();
    final listingTitle = conversation.listingTitle.trim().isEmpty
        ? conversation.chatType.label
        : conversation.listingTitle.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _Avatar(
                name: name,
                photoUrl: photoUrl,
                showPresence: isUnread || isPeerTyping,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headline(
                              fontSize: 24,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isUnread
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatConversationTime(conversation.lastMessageTime),
                          style: AppTheme.body(
                            fontSize: 13,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isUnread
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isUnread
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isUnread
                                  ? AppColors.onSurface
                                  : AppColors.slate500,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 12),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatConversationTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }
    if (difference == 1) {
      return 'Yesterday';
    }
    if (difference < 7) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[dateTime.weekday - 1];
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool showPresence;

  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.showPresence,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
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
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
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
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (showPresence)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceContainerLowest, width: 3),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Couldn’t load chats',
              style: AppTheme.headline(fontSize: 24, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final String query;
  final _ChatInboxSegment selectedSegment;

  const _EmptyState({
    required this.hasSearch,
    required this.query,
    required this.selectedSegment,
  });

  @override
  Widget build(BuildContext context) {
    final title = hasSearch
        ? 'No matching chats'
        : selectedSegment == _ChatInboxSegment.marketplace
        ? 'No marketplace chats'
        : 'No chats yet';
    final subtitle = hasSearch
        ? 'Nothing matched "$query". Try a person, listing title, or message text.'
        : selectedSegment == _ChatInboxSegment.marketplace
        ? 'Marketplace conversations will appear here once buying or selling chats are enabled.'
        : 'Start a conversation from any listing and it will appear here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTheme.headline(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
