import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;

  const ChatDetailScreen({super.key, required this.conversationId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  late String _currentUserId;
  late Future<_ChatHeaderData> _headerFuture;
  bool _isSending = false;
  bool _isUserNearBottom = true;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _headerFuture = _resolveHeaderData();

    // Open conversation in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openConversation();
    });
  }

  Future<void> _openConversation() async {
    final provider = context.read<ChatProvider>();
    await provider.openConversation(widget.conversationId, _currentUserId);
    if (!mounted) return;
    await provider.markConversationAsReadIfNeeded(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    if (_isSending || _messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      setState(() => _isSending = true);
      await context.read<ChatProvider>().sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwn = message.senderId == _currentUserId;

                    return _buildMessageBubble(message, isOwn);
                  },
                );
              },
            ),
          ),

          // Message input
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    shape: const CircleBorder(),
                    color: (_messageController.text.trim().isEmpty || _isSending)
                        ? Colors.blue.withValues(alpha: 0.55)
                        : Colors.blue,
                    child: InkWell(
                      onTap:
                          (_messageController.text.trim().isEmpty || _isSending)
                          ? null
                          : _sendMessage,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.send,
                          color:
                              (_messageController.text.trim().isEmpty ||
                                  _isSending)
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white,
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
    final fallback = const _ChatHeaderData(
      name: 'Messages',
      photoUrl: '',
      typeLabel: '',
    );
    return AppBar(
      title: FutureBuilder<_ChatHeaderData>(
        future: _headerFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? fallback;
          final avatar = _safeAvatarProvider(data.photoUrl);
          final initial = data.name.isNotEmpty
              ? data.name[0].toUpperCase()
              : '?';
          return Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: avatar,
                child: avatar == null ? Text(initial) : null,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (data.typeLabel.isNotEmpty)
                      Text(
                        data.typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      elevation: 1,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isOwn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isOwn ? const Color(0xFF2F80ED) : Colors.grey[200],
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
                  style: TextStyle(
                    fontSize: 15,
                    color: isOwn ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOwn
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.grey,
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
                            ? Colors.cyan
                            : Colors.white.withValues(alpha: 0.7),
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

  String _mateTypeLabel(String value) {
    switch (value.toLowerCase()) {
      case 'helpmate':
        return 'Helpmate';
      case 'ridemate':
        return 'Ridemate';
      case 'roommate':
      default:
        return 'Roommate';
    }
  }

  Future<_ChatHeaderData> _resolveHeaderData() async {
    final uid = _currentUserId;
    final db = context.read<DatabaseService>();
    if (uid.isEmpty) {
      return const _ChatHeaderData(
        name: 'Messages',
        photoUrl: '',
        typeLabel: '',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final convSnap = await firestore
        .collection('chats')
        .doc(widget.conversationId)
        .get();
    if (!convSnap.exists) {
      return const _ChatHeaderData(
        name: 'Messages',
        photoUrl: '',
        typeLabel: '',
      );
    }

    final data = convSnap.data() ?? <String, dynamic>{};
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );
    final referenceId = (data['referenceId'] ?? '').toString();
    final chatType = ChatTypeX.fromString((data['chatType'] ?? '').toString());

    String name = 'User';
    String photoUrl = '';
    String typeLabel = chatType.label;

    if (chatType == ChatType.service) {
      var workerDoc = await firestore
          .collection('workers')
          .doc(referenceId)
          .get();
      if (!workerDoc.exists) {
        final fallback = await firestore
            .collection('workers')
            .where('uid', isEqualTo: referenceId)
            .limit(1)
            .get();
        if (fallback.docs.isNotEmpty) {
          workerDoc = fallback.docs.first;
        }
      }
      if (workerDoc.exists) {
        final worker = workerDoc.data()!;
        final workerUid = (worker['uid'] ?? referenceId).toString().trim();
        if (workerUid == otherUserId) {
          name = (worker['name'] ?? name).toString();
          photoUrl = (worker['photoUrl'] ?? '').toString();
        }
        final serviceType = (worker['serviceType'] ?? '').toString().trim();
        if (serviceType.isNotEmpty) {
          typeLabel = serviceType;
        }
      }
    } else if (chatType == ChatType.mate) {
      final mateDoc = await firestore
          .collection('mates')
          .doc(referenceId)
          .get();
      if (mateDoc.exists) {
        final mate = mateDoc.data()!;
        final mateOwnerId = (mate['userId'] ?? '').toString().trim();
        if (mateOwnerId == otherUserId) {
          name = (mate['userName'] ?? name).toString();
          photoUrl = (mate['userPhoto'] ?? '').toString();
        }
        final mateType = (mate['type'] ?? '').toString().trim();
        if (mateType.isNotEmpty) {
          typeLabel = _mateTypeLabel(mateType);
        }
      }
    } else if (chatType == ChatType.request) {
      final requestDoc = await firestore
          .collection('jobs')
          .doc(referenceId)
          .get();
      if (requestDoc.exists) {
        final request = requestDoc.data()!;
        final posterId = (request['userId'] ?? '').toString().trim();
        if (posterId == otherUserId) {
          name = (request['posterName'] ?? name).toString();
          photoUrl = (request['photoUrl'] ?? '').toString();
        }
        final category = (request['category'] ?? '').toString().trim();
        if (category.isNotEmpty) {
          typeLabel = category;
        }
      }
    }

    if ((name == 'User' || photoUrl.isEmpty) && otherUserId.isNotEmpty) {
      final userData = await db.getUserData(otherUserId);
      if (userData != null) {
        if (name == 'User') {
          name = (userData['name'] ?? name).toString();
        }
        if (photoUrl.isEmpty) {
          photoUrl = (userData['photoUrl'] ?? '').toString();
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
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
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
