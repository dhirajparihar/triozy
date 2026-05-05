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

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  final ListingModel? seed;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.seed,
  });

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  ListingModel? _listing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listing = widget.seed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadListing());
  }

  Future<void> _loadListing() async {
    final listing = await context.read<DatabaseService>().getListing(widget.listingId);
    if (!mounted) {
      return;
    }
    setState(() {
      _listing = listing ?? widget.seed;
      _loading = false;
    });
  }

  Future<void> _startChat() async {
    final listing = _listing;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (listing == null || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to contact the listing owner')),
      );
      return;
    }
    if (currentUser.uid == listing.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your listing')),
      );
      return;
    }

    final conversationId = await context.read<ChatProvider>().createOrGetChat(
      otherUserId: listing.ownerId,
      chatType: ChatType.listing.value,
      referenceId: listing.id,
      otherUserName: listing.ownerName,
      otherUserPhotoUrl: listing.ownerPhotoUrl,
      currentUserName: currentUser.displayName,
      currentUserPhotoUrl: currentUser.photoURL,
    );

    if (!mounted) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversationId: conversationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading && listing == null
          ? const Center(child: CircularProgressIndicator())
          : listing == null
              ? const Center(child: Text('Listing not found'))
              : Stack(
                  children: [
                    ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(
                          height: 320,
                          child: PageView(
                            children: (listing.imageUrls.isEmpty
                                    ? ['']
                                    : listing.imageUrls)
                                .map((imageUrl) {
                              return imageUrl.isEmpty
                                  ? Container(
                                      color: AppColors.surfaceContainerHigh,
                                      child: const Icon(
                                        Icons.home_work_rounded,
                                        size: 54,
                                        color: AppColors.outline,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        color: AppColors.surfaceContainerHigh,
                                      ),
                                    );
                            }).toList(),
                          ),
                        ),
                        Container(
                          transform: Matrix4.translationValues(0, -28, 0),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listing.priceLabel,
                                style: AppTheme.headline(
                                  fontSize: 30,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                listing.title,
                                style: AppTheme.headline(fontSize: 24),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      listing.location,
                                      style: AppTheme.body(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Pill(label: listing.categoryLabel),
                                  _Pill(label: listing.typeLabel),
                                  if ((listing.genderPreference ?? '').isNotEmpty)
                                    _Pill(label: listing.genderPreference!),
                                  if ((listing.condition ?? '').isNotEmpty)
                                    _Pill(label: listing.condition!),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _InfoPanel(listing: listing),
                              const SizedBox(height: 24),
                              Text('Description', style: AppTheme.headline(fontSize: 20)),
                              const SizedBox(height: 10),
                              Text(
                                listing.description,
                                style: AppTheme.body(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text('Location preview', style: AppTheme.headline(fontSize: 20)),
                              const SizedBox(height: 12),
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.map_outlined,
                                        size: 32,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        listing.location,
                                        style: AppTheme.body(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: SafeArea(
                        top: false,
                        child: ElevatedButton(
                          onPressed: _startChat,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'Contact on chat',
                            style: AppTheme.body(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final ListingModel listing;

  const _InfoPanel({required this.listing});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String)>[
      (Icons.person_outline_rounded, listing.ownerName),
      if ((listing.availableFrom ?? '').isNotEmpty)
        (Icons.calendar_today_rounded, listing.availableFrom!),
      if ((listing.furnishing ?? '').isNotEmpty)
        (Icons.chair_outlined, listing.furnishing!),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(row.$1, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.$2,
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
