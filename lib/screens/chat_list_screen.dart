import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final bool showScaffold;

  const ChatListScreen({super.key, this.showScaffold = true});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _currentUserId;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      return widget.showScaffold
          ? const Scaffold(
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
          return query.isEmpty || searchable.contains(query);
        }).toList();

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4F8FF), Colors.white],
            ),
          ),
          child: Column(
            children: [
              _Header(
                controller: _searchController,
                totalUnreadCount: chatProvider.totalUnreadCount,
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
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      backgroundColor: Colors.white,
      body: SafeArea(child: content),
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final int totalUnreadCount;

  const _Header({required this.controller, required this.totalUnreadCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Messages',
                  style: AppTheme.headline(fontSize: 30, letterSpacing: -0.9),
                ),
              ),
              if (totalUnreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalUnreadCount unread',
                    style: AppTheme.label(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Fast, threaded conversations with real-time delivery and read state.',
            style: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search people, listings, messages',
                hintStyle: AppTheme.body(
                  fontSize: 14,
                  color: AppColors.slate400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ],
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
    final peerName = (peer?.name ?? '').trim();
    final name = peerName.isEmpty ? 'User' : peerName;
    final subtitle = isPeerTyping
        ? 'typing...'
        : (conversation.lastMessage.trim().isEmpty
              ? 'Tap to start the conversation'
              : conversation.lastMessage.trim());
    final subtitleColor = isPeerTyping
        ? AppColors.secondary
        : (unreadCount > 0 ? AppColors.onSurface : AppColors.slate500);
    final photoUrl = (peer?.photoUrl ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: unreadCount > 0
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.outlineVariant.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _Avatar(name: name, photoUrl: photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: 16,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          conversation.formattedTime,
                          style: AppTheme.label(
                            fontSize: 11,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: unreadCount > 0
                                ? AppColors.primary
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.listingTitle.trim().isEmpty
                          ? conversation.chatType.label
                          : conversation.listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.label(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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
                              fontSize: 13,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              textAlign: TextAlign.center,
                              style: AppTheme.label(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
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
}

class _Avatar extends StatelessWidget {
  final String name;
  final String photoUrl;

  const _Avatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue50,
      ),
      child: ClipOval(
        child: photoUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: AppTheme.headline(
                    fontSize: 22,
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
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
      ),
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
                height: 1.5,
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

  const _EmptyState({required this.hasSearch, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch ? 'No matching chats' : 'No chats yet',
              style: AppTheme.headline(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Nothing matched "$query". Try a person, listing title, or message text.'
                  : 'Start a conversation from any listing and it will show up here with unread counts and live typing state.',
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
