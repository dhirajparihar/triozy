import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
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
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
          ? const Scaffold(body: Center(child: Text('Please sign in to view chats')))
          : const Center(child: Text('Please sign in to view chats'));
    }

    final content = Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final conversations = chatProvider.conversations;
        if (conversations.isEmpty) {
          return _EmptyState(showSearch: true, controller: _searchController);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchController.clear,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<ChatProvider>().initialize(uid);
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    return FutureBuilder<_ChatPeerData>(
                      future: _resolveChatPeer(conv),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(title: Text('Loading...'));
                        }
                        final peer = snapshot.data!;
                        final query = _searchController.text.trim().toLowerCase();
                        final matches = query.isEmpty ||
                            peer.name.toLowerCase().contains(query) ||
                            peer.listingTitle.toLowerCase().contains(query) ||
                            conv.lastMessage.toLowerCase().contains(query);
                        if (!matches) {
                          return const SizedBox.shrink();
                        }

                        final lastReadAt = conv.lastReadAt[uid];
                        final hasUnread = (lastReadAt == null ||
                                conv.lastMessageTime.isAfter(lastReadAt)) &&
                            conv.lastSenderId.isNotEmpty &&
                            conv.lastSenderId != uid;

                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(conversationId: conv.id),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.blue50,
                            backgroundImage: peer.photoUrl.isEmpty
                                ? null
                                : CachedNetworkImageProvider(peer.photoUrl),
                            child: peer.photoUrl.isEmpty
                                ? Text(peer.name.isEmpty ? '?' : peer.name[0].toUpperCase())
                                : null,
                          ),
                          title: Text(
                            peer.name,
                            style: AppTheme.body(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (peer.listingTitle.isNotEmpty)
                                Text(
                                  peer.listingTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              Text(
                                conv.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body(
                                  fontSize: 13,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                conv.formattedTime,
                                style: AppTheme.body(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate500,
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!widget.showScaffold) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
      ),
      body: content,
    );
  }

  Future<_ChatPeerData> _resolveChatPeer(ConversationModel conv) async {
    final uid = _currentUserId ?? '';
    final db = context.read<DatabaseService>();
    final otherUserId = conv.participants.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );

    String name = 'User';
    String photoUrl = '';
    String listingTitle = '';

    final listing = await db.getListing(conv.referenceId);
    if (listing != null) {
      listingTitle = listing.title;
      if (listing.ownerId == otherUserId) {
        name = listing.ownerName;
        photoUrl = listing.ownerPhotoUrl;
      }
    }

    if ((name == 'User' || photoUrl.isEmpty) && otherUserId.isNotEmpty) {
      final userData = await db.getUserData(otherUserId);
      if (userData != null) {
        name = (userData['name'] ?? name).toString();
        photoUrl = (userData['photoUrl'] ?? photoUrl).toString();
      }
    }

    return _ChatPeerData(
      name: name,
      photoUrl: photoUrl,
      listingTitle: listingTitle,
    );
  }
}

class _ChatPeerData {
  final String name;
  final String photoUrl;
  final String listingTitle;

  const _ChatPeerData({
    required this.name,
    required this.photoUrl,
    required this.listingTitle,
  });
}

class _EmptyState extends StatelessWidget {
  final bool showSearch;
  final TextEditingController controller;

  const _EmptyState({
    required this.showSearch,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mail_outline, size: 72, color: AppColors.slate400),
                  const SizedBox(height: 16),
                  Text('No chats yet', style: AppTheme.headline(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                    'Start by messaging on a room, PG, flatmate, or marketplace listing.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
