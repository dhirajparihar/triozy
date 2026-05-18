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


// === Chat inbox ==============================================================

enum _ChatInboxSegment { all, housing, marketplace }

/// Inbox screen showing conversations and filters.
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
  // Cache listing property type per reference id to avoid repeated Firestore lookups.
  final Map<String, PropertyType> _referenceTypeCache = {};
  final Set<String> _referenceTypeLoading = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = normalizeChatUid(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );
    _searchController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start the conversation stream after first frame to avoid build churn.
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

    // Signed-out guard: show a friendly message without wiring streams.
    if (uid == null || uid.isEmpty) {
      return widget.showScaffold
          ? const Scaffold(
              backgroundColor: Color(0xFFF2F0FF),
              body: Center(child: Text('Please sign in to view chats')),
            )
          : const Center(child: Text('Please sign in to view chats'));
    }

    final content = Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        // Search is client-side over cached conversation list.
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

        for (final conversation in chatProvider.conversations) {
          if (conversation.chatType == ChatType.listing &&
              conversation.referenceId.trim().isNotEmpty &&
              !_referenceTypeCache.containsKey(conversation.referenceId)) {
            _resolveReferenceType(conversation.referenceId);
          }
        }

        filtered.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

        final allUnreadCount = _unreadCountForSegment(chatProvider.conversations, _ChatInboxSegment.all, uid);
        final housingUnreadCount = _unreadCountForSegment(chatProvider.conversations, _ChatInboxSegment.housing, uid);
        final marketplaceUnreadCount = _unreadCountForSegment(chatProvider.conversations, _ChatInboxSegment.marketplace, uid);

        return _buildChatList(
          filtered,
          chatProvider,
          query,
          uid,
          horizontalPadding,
          isCompact,
          listGap,
          allUnreadCount,
          housingUnreadCount,
          marketplaceUnreadCount,
        );
      },
    );

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0FF),
      body: SafeArea(child: content),
    );
  }

  Future<void> _resolveReferenceType(String referenceId) async {
    // Resolve listing property type once and cache to avoid repeated lookups.
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
            listing?.propertyType ?? PropertyType.room;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _referenceTypeCache[referenceId] = PropertyType.room;
      });
    } finally {
      _referenceTypeLoading.remove(referenceId);
    }
  }

  Future<void> _markAllRead(
    List<ConversationModel> filtered,
    ChatProvider chatProvider,
    String userId,
  ) async {
    for (final conversation in filtered) {
      if (conversation.unreadCountFor(userId) > 0) {
        await chatProvider.markConversationAsReadIfNeeded(conversation.id);
      }
    }
  }

  Widget _buildChatList(
    List<ConversationModel> filtered,
    ChatProvider chatProvider,
    String query,
    String uid,
    double horizontalPadding,
    bool isCompact,
    double listGap,
    int allUnreadCount,
    int housingUnreadCount,
    int marketplaceUnreadCount,
  ) {
    return Container(
      color: const Color(0xFFF2F0FF),
      child: Column(
        children: [
          // Header: title, search, and segment filters.
          _ChatListHeader(
            controller: _searchController,
            focusNode: _searchFocusNode,
            selectedSegment: _selectedSegment,
            onSegmentChanged: (segment) {
              setState(() => _selectedSegment = segment);
            },
            allUnreadCount: allUnreadCount,
            housingUnreadCount: housingUnreadCount,
            marketplaceUnreadCount: marketplaceUnreadCount,
          ),
          if (_selectedSegment == _ChatInboxSegment.all) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EDFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chat with confidence',
                        style: AppTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'Learn more',
                        style: AppTheme.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Recent',
                  style: AppTheme.headline(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await _markAllRead(filtered, chatProvider, uid);
                  },
                  child: Row(
                    children: const [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Color(0xFF5B4FCF),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Mark all as read',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5B4FCF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Builder(
              builder: (context) {
                // Error state overrides all other content.
                if ((chatProvider.errorMessage ?? '').isNotEmpty) {
                  return _ErrorState(message: chatProvider.errorMessage!);
                }
                // Loading state only when no cached conversations yet.
                if (chatProvider.isLoading && filtered.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }
                // Empty state varies based on search and segment.
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
                    // Reinitialize to force a fresh stream snapshot.
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
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, _) => SizedBox(height: listGap),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return _ChatListFooter(isCompact: isCompact);
                      }
                      final conversation = filtered[index];
                      return _ConversationTile(
                        conversation: conversation,
                        currentUserId: uid,
                        referencePropertyType: _referenceTypeCache[conversation.referenceId],
                        onTap: () {
                          // Open the conversation detail view.
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
    switch (_selectedSegment) {
      case _ChatInboxSegment.all:
        return true;
      case _ChatInboxSegment.housing:
        return conversation.chatType == ChatType.listing;
      case _ChatInboxSegment.marketplace:
        return conversation.chatType == ChatType.marketplace;
    }
  }

  bool _matchesSegmentFilter(ConversationModel conversation, _ChatInboxSegment segment) {
    switch (segment) {
      case _ChatInboxSegment.all:
        return true;
      case _ChatInboxSegment.housing:
        return conversation.chatType == ChatType.listing;
      case _ChatInboxSegment.marketplace:
        return conversation.chatType == ChatType.marketplace;
    }
  }

  int _unreadCountForSegment(
    List<ConversationModel> conversations,
    _ChatInboxSegment segment,
    String userId,
  ) {
    return conversations.fold<int>(0, (sum, conversation) {
      if (!_matchesSegmentFilter(conversation, segment)) {
        return sum;
      }
      return sum + conversation.unreadCountFor(userId);
    });
  }
}

class _ChatListHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final _ChatInboxSegment selectedSegment;
  final ValueChanged<_ChatInboxSegment> onSegmentChanged;
  final int allUnreadCount;
  final int housingUnreadCount;
  final int marketplaceUnreadCount;

  const _ChatListHeader({
    required this.controller,
    required this.focusNode,
    required this.selectedSegment,
    required this.onSegmentChanged,
    required this.allUnreadCount,
    required this.housingUnreadCount,
    required this.marketplaceUnreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title.
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
                  // Segment toggles.
                  _FilterChip(
                    label: 'All',
                    selected: selectedSegment == _ChatInboxSegment.all,
                    badgeCount: allUnreadCount,
                    onTap: () => onSegmentChanged(_ChatInboxSegment.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Housing',
                    selected: selectedSegment == _ChatInboxSegment.housing,
                    badgeCount: housingUnreadCount,
                    onTap: () => onSegmentChanged(_ChatInboxSegment.housing),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Marketplace',
                    selected: selectedSegment == _ChatInboxSegment.marketplace,
                    badgeCount: marketplaceUnreadCount,
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
  final int badgeCount;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.badgeCount = 0,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5B4FCF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(
                  color: const Color(0xFF5B4FCF),
                  width: 1.5,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForLabel(label),
              size: isCompact ? 16 : 18,
              color: selected ? Colors.white : const Color(0xFF5B4FCF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.body(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF5B4FCF),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFF5B4FCF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: AppTheme.body(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? const Color(0xFF5B4FCF) : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('market')) {
      return Icons.storefront_rounded;
    }
    if (lower.contains('house') || lower.contains('housing')) {
      return Icons.home_work_rounded;
    }
    return Icons.chat_bubble_rounded;
  }
}

class _ConversationCategoryChip extends StatelessWidget {
  final ChatType chatType;
  final PropertyType? propertyType;

  const _ConversationCategoryChip({
    required this.chatType,
    this.propertyType,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final label = _chipLabel();
    final colors = _chipColors();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.body(
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }

  String _chipLabel() {
    if (chatType == ChatType.marketplace) {
      return 'Marketplace';
    }
    switch (propertyType) {
      case PropertyType.pg:
        return 'PG';
      case PropertyType.room:
        return 'Room';
      case PropertyType.flat:
        return 'Flat/Flatmate';
      case PropertyType.item:
        return 'Marketplace';
      default:
        return 'Housing';
    }
  }

  _ChipColors _chipColors() {
    if (chatType == ChatType.marketplace || propertyType == PropertyType.item) {
      return const _ChipColors(
        background: Color(0xFFEDE7F6),
        text: Color(0xFF5B4FCF),
      );
    }
    switch (propertyType) {
      case PropertyType.pg:
        return const _ChipColors(
          background: Color(0xFFFFE4F0),
          text: Color(0xFFD63384),
        );
      case PropertyType.room:
        return const _ChipColors(
          background: Color(0xFFE4F0FF),
          text: Color(0xFF0D6EFD),
        );
      case PropertyType.flat:
      default:
        return const _ChipColors(
          background: Color(0xFFFFF3E0),
          text: Color(0xFFE65100),
        );
    }
  }
}

class _ChipColors {
  final Color background;
  final Color text;

  const _ChipColors({required this.background, required this.text});
}


// === Conversation tile =======================================================

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final PropertyType? referencePropertyType;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    this.referencePropertyType,
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
    // Prefer typing indicator over last message preview.
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: isCompact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with optional presence dot.
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
                                  ? const Color(0xFF1A1A2E)
                                  : const Color(0xFF444444),
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : 8),
                        // Show last activity time in a compact format.
                        Text(
                          _formatConversationTime(conversation.lastMessageTime),
                          style: AppTheme.body(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 3 : 4),
                    _ConversationCategoryChip(
                      chatType: conversation.chatType,
                      propertyType: referencePropertyType,
                    ),
                    SizedBox(height: isCompact ? 6 : 8),
                    Text(
                      listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF444444),
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF888888),
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 12),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5B4FCF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: AppTheme.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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

  String _formatConversationTime(DateTime dateTime) {
    // Format time relative to today for quick scanning.
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


// === Avatar ================================================================

class _ChatListFooter extends StatelessWidget {
  final bool isCompact;

  const _ChatListFooter({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your perfect match faster',
                  style: AppTheme.headline(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get more responses by exploring listings tailored to your preferences.',
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF888888),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4FCF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 14 : 16,
                      horizontal: isCompact ? 20 : 24,
                    ),
                  ),
                  child: Text(
                    'Explore Now',
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.people_rounded,
            size: 48,
            color: Color(0xFFDDD5FF),
          ),
        ],
      ),
    );
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _avatarColor(name),
          ),
          child: ClipOval(
            child: photoUrl.isEmpty
                // Fallback to initials when no photo exists.
                ? Center(
                    child: Text(
                      initial,
                      style: AppTheme.headline(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Center(
                      // Fallback to initials if image fails.
                      child: Text(
                        initial,
                        style: AppTheme.headline(
                          fontSize: isCompact ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF0D6EFD),
      Color(0xFFD63384),
      Color(0xFF2E7D32),
      Color(0xFFE65100),
      Color(0xFF0097A7),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}


// === Error and empty states ==================================================

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
            // Visual cue for network/permission issues.
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
            // Surface the error message for debugging.
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
    // Copy varies based on filter + search state.
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
