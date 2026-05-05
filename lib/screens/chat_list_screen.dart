import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/listing_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
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
  final Map<String, Future<_ChatPeerData>> _peerFutureCache = {};
  final Map<String, _ChatPeerData> _peerDataCache = {};
  bool _showAllPending = false;

  ImageProvider? _safeAvatarProvider(String? url) {
    final raw = (url ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return NetworkImage(raw);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final uid = _currentUserId;
      if (uid == null || uid.isEmpty) {
        return;
      }
      context.read<ChatProvider>().initialize(uid);
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
          ? Scaffold(
              appBar: AppBar(
                title: const Text('Messages'),
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              body: const Center(child: Text('Please sign in to view chats')),
            )
          : const Center(child: Text('Please sign in to view chats'));
    }

    final content = Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                  },
                  child: ListView(
                    children: [
                      _buildPendingSection(chatProvider),
                      _buildAllChatsSection(chatProvider),
                    ],
                  ),
                ),
              ),
            ],
          );
      },
    );

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: content,
    );
  }

  List<ConversationModel> _pendingChats(List<ConversationModel> conversations) {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      return [];
    }
    final pending = conversations.where((chat) {
      final lastReadAt = chat.lastReadAt[uid];
      final hasUnread = (lastReadAt == null ||
              chat.lastMessageTime.isAfter(lastReadAt)) &&
          chat.lastSenderId.isNotEmpty &&
          chat.lastSenderId != uid;
      return chat.chatType == ChatType.request && hasUnread;
    }).toList();

    pending.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return pending;
  }

  Widget _buildPendingSection(ChatProvider chatProvider) {
    final pending = _pendingChats(chatProvider.conversations);
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pending Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text('${pending.length} Pending'),
                backgroundColor: Colors.orange[100],
                labelStyle: TextStyle(color: Colors.orange[900]),
              ),
            ],
          ),
        ),
        ...(_showAllPending ? pending : pending.take(3)).map(
          (c) =>
              _buildConversationTile(c, _searchController.text.trim().toLowerCase()),
        ),
        if (pending.length > 3)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextButton(
              onPressed: () =>
                  setState(() => _showAllPending = !_showAllPending),
              child: Text(
                _showAllPending
                    ? 'Show less'
                    : 'View all ${pending.length} pending requests',
              ),
            ),
          ),
        const Divider(),
      ],
    );
  }

  Widget _buildAllChatsSection(ChatProvider chatProvider) {
    final pendingIds = _pendingChats(
      chatProvider.conversations,
    ).map((c) => c.id).toSet();
    final chats =
        chatProvider.conversations
            .where((c) => !pendingIds.contains(c.id))
            .toList()
          ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    if (chats.isEmpty && pendingIds.isEmpty) {
      return _buildEmptyState(context);
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = chats.where((chat) {
      if (query.isEmpty) {
        return true;
      }
      if (chat.lastMessage.toLowerCase().contains(query)) {
        return true;
      }
      final peer = _peerDataCache[chat.id];
      if (peer == null) {
        return true;
      }
      return peer.name.toLowerCase().contains(query) ||
          peer.typeLabel.toLowerCase().contains(query) ||
          peer.location.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No chats found',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: const Text(
            'All Chats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...filtered.map((c) => _buildConversationTile(c, query)),
      ],
    );
  }

  Widget _buildConversationTile(ConversationModel conv, String query) {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      return const SizedBox.shrink();
    }
    final lastReadAt = conv.lastReadAt[uid];
    final hasUnread = (lastReadAt == null ||
            conv.lastMessageTime.isAfter(lastReadAt)) &&
        conv.lastSenderId.isNotEmpty &&
        conv.lastSenderId != uid;

    return FutureBuilder<_ChatPeerData>(
      future: _peerFutureCache.putIfAbsent(
        conv.id,
        () => _resolveChatPeer(conv),
      ),
      builder: (context, snapshot) {
        final peer = snapshot.data ?? const _ChatPeerData.unknown();
        if (snapshot.hasData) {
          _peerDataCache[conv.id] = snapshot.data!;
        }
        final matchesQuery = query.isEmpty ||
            conv.lastMessage.toLowerCase().contains(query) ||
            peer.name.toLowerCase().contains(query) ||
            peer.typeLabel.toLowerCase().contains(query) ||
            peer.location.toLowerCase().contains(query);
        if (!matchesQuery) {
          return const SizedBox.shrink();
        }
        final fallbackInitial = peer.name.isNotEmpty
            ? peer.name[0].toUpperCase()
            : '?';
        final avatarImage = _safeAvatarProvider(peer.photoUrl);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          title: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(conversationId: conv.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: avatarImage,
                    onBackgroundImageError: avatarImage == null
                        ? null
                        : (exception, stackTrace) {},
                    child: peer.photoUrl.isEmpty ? Text(fallbackInitial) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                peer.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              conv.formattedTime,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildTypeBadge(
                              conv.chatType,
                              peer.typeLabel.isNotEmpty
                                  ? peer.typeLabel
                                  : conv.chatType.label,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                conv.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasUnread
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontWeight: hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (hasUnread)
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
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
      },
    );
  }

  Widget _buildTypeBadge(ChatType type, String label) {
    Color bgcolor;
    Color textcolor;

    switch (type) {
      case ChatType.mate:
        bgcolor = Colors.blue[100]!;
        textcolor = Colors.blue[900]!;
        break;
      case ChatType.service:
        bgcolor = Colors.green[100]!;
        textcolor = Colors.green[900]!;
        break;
      case ChatType.request:
        bgcolor = Colors.orange[100]!;
        textcolor = Colors.orange[900]!;
        break;
      case ChatType.listing:
        bgcolor = Colors.blue[100]!;
        textcolor = Colors.blue[900]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgcolor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: textcolor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<_ChatPeerData> _resolveChatPeer(ConversationModel conv) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      return const _ChatPeerData.unknown();
    }
    final db = context.read<DatabaseService>();
    final firestore = FirebaseFirestore.instance;
    final otherUserId = conv.participants.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) {
      return const _ChatPeerData.unknown();
    }

    String name = 'User';
    String photoUrl = '';
    String location = '';
    String typeLabel = conv.chatType.label;

    if (conv.chatType == ChatType.listing) {
      final listingDoc = await firestore
          .collection('listings')
          .doc(conv.referenceId)
          .get();
      if (listingDoc.exists) {
        final data = listingDoc.data()!;
        final ownerId = (data['ownerId'] ?? '').toString().trim();
        if (ownerId == otherUserId) {
          name = (data['ownerName'] ?? name).toString();
          photoUrl = (data['ownerPhotoUrl'] ?? '').toString();
          location = (data['location'] ?? '').toString();
        }
        final category = ListingCategoryX.fromString(
          (data['category'] ?? '').toString(),
        );
        typeLabel = category.label;
      }
    } else if (conv.chatType == ChatType.service) {
      var workerDoc = await firestore
          .collection('workers')
          .doc(conv.referenceId)
          .get();
      if (!workerDoc.exists) {
        final fallback = await firestore
            .collection('workers')
            .where('uid', isEqualTo: conv.referenceId)
            .limit(1)
            .get();
        if (fallback.docs.isNotEmpty) {
          workerDoc = fallback.docs.first;
        }
      }
      if (workerDoc.exists) {
        final data = workerDoc.data()!;
        final workerUid = (data['uid'] ?? conv.referenceId).toString().trim();
        if (workerUid == otherUserId) {
          name = (data['name'] ?? name).toString();
          photoUrl = (data['photoUrl'] ?? '').toString();
          location = (data['location'] ?? '').toString();
        }
        final serviceType = (data['serviceType'] ?? '').toString().trim();
        if (serviceType.isNotEmpty) {
          typeLabel = serviceType;
        }
      }
    } else if (conv.chatType == ChatType.mate) {
      final mateDoc = await firestore
          .collection('mates')
          .doc(conv.referenceId)
          .get();
      if (mateDoc.exists) {
        final mateData = mateDoc.data()!;
        final mateOwnerId = (mateData['userId'] ?? '').toString().trim();
        if (mateOwnerId == otherUserId) {
          name = (mateData['userName'] ?? name).toString();
          photoUrl = (mateData['userPhoto'] ?? '').toString();
          location = (mateData['location'] ?? '').toString();
        }
        final mateType = (mateData['type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (mateType.isNotEmpty) {
          typeLabel = _mateTypeLabel(mateType);
        }
      }
    } else if (conv.chatType == ChatType.request) {
      final requestDoc = await firestore
          .collection('jobs')
          .doc(conv.referenceId)
          .get();
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final posterId = (requestData['userId'] ?? '').toString().trim();
        if (posterId == otherUserId) {
          name = (requestData['posterName'] ?? name).toString();
          photoUrl = (requestData['photoUrl'] ?? '').toString();
          location = (requestData['location'] ?? '').toString();
        }
        final category = (requestData['category'] ?? '').toString().trim();
        if (category.isNotEmpty) {
          typeLabel = category;
        }
      }
    }

    if (name == 'User' || photoUrl.isEmpty || location.isEmpty) {
      final userData = await db.getUserData(otherUserId);
      if (userData != null) {
        if (name == 'User') {
          name = (userData['name'] ?? name).toString();
        }
        if (photoUrl.isEmpty) {
          photoUrl = (userData['photoUrl'] ?? '').toString();
        }
        if (location.isEmpty) {
          location = (userData['location'] ?? '').toString();
        }
      }
    }

    return _ChatPeerData(
      name: name,
      photoUrl: photoUrl,
      location: location,
      typeLabel: typeLabel,
    );
  }

  String _mateTypeLabel(String value) {
    switch (value) {
      case 'helpmate':
        return 'Helpmate';
      case 'ridemate':
        return 'Ridemate';
      case 'roommate':
      default:
        return 'Roommate';
    }
  }


  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Start by messaging on a room, flatmate, or marketplace listing',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPeerData {
  final String name;
  final String photoUrl;
  final String location;
  final String typeLabel;

  const _ChatPeerData({
    required this.name,
    required this.photoUrl,
    required this.location,
    required this.typeLabel,
  });

  const _ChatPeerData.unknown()
    : name = 'User',
      photoUrl = '',
      location = '',
      typeLabel = '';
}
