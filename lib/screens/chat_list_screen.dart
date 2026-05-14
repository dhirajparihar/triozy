import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../models/listing_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

enum _ChatInboxSegment { all, housing, marketplace }

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
  _ChatInboxSegment _selectedSegment = _ChatInboxSegment.all;
  final Map<String, ListingType> _referenceTypeCache = {};
  final Set<String> _referenceTypeLoading = {};

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = 16.0;
    final listGap = isCompact ? 10.0 : 14.0;
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
        var filtered = chatProvider.conversations.where((conversation) {
          final peer = conversation.peerMetaFor(uid);
          final searchable = [
            peer?.name ?? '',
            conversation.listingTitle,
            conversation.lastMessage,
          ].join(' ').toLowerCase();
          return _matchesSegment(conversation) &&
              (query.isEmpty || searchable.contains(query));
        }).toList();

        // Deduplicate only when the same peer has both housing and marketplace chats.
        if (_selectedSegment == _ChatInboxSegment.all) {
          final conversationsByPeer = <String, List<ConversationModel>>{};
          for (final conversation in filtered) {
            final peerId = conversation.peerIdFor(uid).trim();
            final key = peerId.isEmpty ? conversation.id : peerId;
            conversationsByPeer.putIfAbsent(key, () => []).add(conversation);
          }

          final deduped = <ConversationModel>[];
          for (final group in conversationsByPeer.values) {
            if (group.length == 1) {
              deduped.add(group.first);
              continue;
            }

            // Check if this peer has conversations of different types
            final types = group.map((c) => c.chatType).toSet();
            if (types.length > 1) {
              // Same peer has both housing and marketplace chats; keep the latest one
              final combined = [...group];
              combined.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
              deduped.add(combined.first);
            } else {
              deduped.addAll(group);
            }
          }

          filtered = deduped..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        }

        return _buildChatList(filtered, chatProvider, query, uid, horizontalPadding, isCompact, listGap);
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

  ChatType _effectiveChatType(ConversationModel conversation) {
    if (conversation.chatType == ChatType.marketplace) {
      return ChatType.marketplace;
    }

    final referenceId = conversation.referenceId.trim();
    if (referenceId.isEmpty) {
      return ChatType.listing;
    }

    final cachedType = _referenceTypeCache[referenceId];
    if (cachedType != null) {
      return cachedType == ListingType.marketplace
          ? ChatType.marketplace
          : ChatType.listing;
    }

    // If not cached, trigger async resolution but return listing for now
    // The UI will update when the cache is populated
    _resolveReferenceType(referenceId);
    return ChatType.listing;
  }

  Future<ChatType> _effectiveChatTypeAsync(ConversationModel conversation) async {
    if (conversation.chatType == ChatType.marketplace) {
      return ChatType.marketplace;
    }

    final referenceId = conversation.referenceId.trim();
    if (referenceId.isEmpty) {
      return ChatType.listing;
    }

    final cachedType = _referenceTypeCache[referenceId];
    if (cachedType != null) {
      return cachedType == ListingType.marketplace
          ? ChatType.marketplace
          : ChatType.listing;
    }

    // Wait for the type to be resolved
    await _resolveReferenceType(referenceId);
    final resolvedType = _referenceTypeCache[referenceId];
    return resolvedType == ListingType.marketplace
        ? ChatType.marketplace
        : ChatType.listing;
  }

  Future<void> _resolveReferenceType(String referenceId) async {
    if (referenceId.isEmpty || _referenceTypeCache.containsKey(referenceId)) {
      return;
    }
    if (_referenceTypeLoading.contains(referenceId)) {
      return;
    }

    _referenceTypeLoading.add(referenceId);
    try {
      final listing = await context.read<DatabaseService>().getListing(referenceId);
      if (!mounted) {
        return;
      }
      setState(() {
        _referenceTypeCache[referenceId] =
            listing?.type ?? ListingType.housing;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _referenceTypeCache[referenceId] = ListingType.housing;
      });
    } finally {
      _referenceTypeLoading.remove(referenceId);
    }
  }

  Future<List<ConversationModel>> _deduplicateConversations(List<ConversationModel> conversations, String uid) async {
    final conversationsByPeer = <String, List<ConversationModel>>{};
    for (final conversation in conversations) {
      final peerId = conversation.peerIdFor(uid).trim();
      final key = peerId.isEmpty ? conversation.id : peerId;
      conversationsByPeer.putIfAbsent(key, () => []).add(conversation);
    }

    final deduped = <ConversationModel>[];
    for (final group in conversationsByPeer.values) {
      if (group.length == 1) {
        deduped.add(group.first);
        continue;
      }

      // Wait for all chat types to be resolved
      final resolvedTypes = <ConversationModel, ChatType>{};
      for (final conversation in group) {
        resolvedTypes[conversation] = await _effectiveChatTypeAsync(conversation);
      }

      final housingChats = group.where(
        (conversation) => resolvedTypes[conversation] == ChatType.listing,
      );
      final marketplaceChats = group.where(
        (conversation) => resolvedTypes[conversation] == ChatType.marketplace,
      );

      if (housingChats.isNotEmpty && marketplaceChats.isNotEmpty) {
        // Same peer has chats in both categories; keep the latest chat.
        final combined = [...housingChats, ...marketplaceChats];
        combined.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        deduped.add(combined.first);
      } else {
        deduped.addAll(group);
      }
    }

    return deduped..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
  }

  Widget _buildChatList(List<ConversationModel> filtered, ChatProvider chatProvider, String query, String uid, double horizontalPadding, bool isCompact, double listGap) {
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
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isCompact ? 8 : 10,
                      horizontalPadding,
                      24,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => SizedBox(height: listGap),
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
  }

  bool _matchesSegment(ConversationModel conversation) {
    final effectiveType = _effectiveChatType(conversation);
    switch (_selectedSegment) {
      case _ChatInboxSegment.all:
        return true;
      case _ChatInboxSegment.housing:
        return effectiveType == ChatType.listing;
      case _ChatInboxSegment.marketplace:
        return effectiveType == ChatType.marketplace;
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
    final isCompact = MediaQuery.sizeOf(context).width < 380;

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: AppTheme.headline(
                fontSize: isCompact ? 28 : 32,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: isCompact ? 10 : 14),
            Container(
              height: isCompact ? 50 : 56,
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
                  fontSize: isCompact ? 14 : 16,
                  color: AppColors.onSurfaceVariant,
                ),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: AppTheme.body(
                    fontSize: isCompact ? 14 : 16,
                    color: AppColors.slate500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 24,
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
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isCompact ? 14 : 17,
                  ),
                ),
              ),
            ),
            SizedBox(height: isCompact ? 10 : 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: selectedSegment == _ChatInboxSegment.all,
                    onTap: () => onSegmentChanged(_ChatInboxSegment.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Housing',
                    selected: selectedSegment == _ChatInboxSegment.housing,
                    onTap: () => onSegmentChanged(_ChatInboxSegment.housing),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Marketplace',
                    selected: selectedSegment == _ChatInboxSegment.marketplace,
                    onTap: () => onSegmentChanged(_ChatInboxSegment.marketplace),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 20,
          vertical: isCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.textPrimary
              : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppTheme.body(
            fontSize: isCompact ? 13 : 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
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
    final isCompact = MediaQuery.sizeOf(context).width < 380;
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
        borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: isCompact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
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
              SizedBox(width: isCompact ? 10 : 14),
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
                              fontSize: isCompact ? 18 : 22,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isUnread
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : 8),
                        Text(
                          _formatConversationTime(conversation.lastMessageTime),
                          style: AppTheme.body(
                            fontSize: isCompact ? 11 : 12,
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
                    SizedBox(height: isCompact ? 3 : 4),
                    Text(
                      listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: isCompact ? 12 : 14,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isUnread
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: isCompact ? 13 : 15,
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
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final size = isCompact ? 48.0 : 56.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
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
                        fontSize: isCompact ? 18 : 20,
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
                          fontSize: isCompact ? 18 : 20,
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
                border: Border.all(
                  color: AppColors.surfaceContainerLowest,
                  width: 3,
                ),
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
              "Couldn't load chats",
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
        : selectedSegment == _ChatInboxSegment.all
        ? 'No chats yet'
        : 'No chats yet';
    final subtitle = hasSearch
        ? 'Nothing matched "$query". Try a person, listing title, or message text.'
        : selectedSegment == _ChatInboxSegment.marketplace
        ? 'Marketplace conversations will appear here once buying or selling chats are enabled.'
        : selectedSegment == _ChatInboxSegment.all
        ? 'Start a conversation from any listing and it will appear here.'
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
