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

    if (_loading && listing == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (listing == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Listing not found')),
      );
    }

    if (listing.isRequirementPost && listing.requirementDetails != null) {
      return _RequirementDetailScaffold(
        listing: listing,
        onStartChat: _startChat,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
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
                                  _Pill(label: listing.propertyTypeLabel),
                                  _Pill(label: listing.purposeLabel),
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

class _RequirementDetailScaffold extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onStartChat;

  const _RequirementDetailScaffold({
    required this.listing,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    final details = listing.requirementDetails!;
    final gender = (listing.genderPreference ?? details.genderPreference).trim();
    final occupancy = details.occupancy.trim();
    final lookingFor = details.genderPreference.trim();
    final rent = details.maxBudget > 0 ? details.maxBudget : listing.price.toInt();
    final highlights = <String>[
      ...listing.highlights,
      ...details.lifestyle,
      ...details.amenities,
      if (details.moveInWhen.isNotEmpty) details.moveInWhen,
    ].where((item) => item.trim().isNotEmpty).toSet().take(6).toList();
    final preferences = <(IconData, String)>[
      (Icons.nightlight_round, 'Quiet'),
      (Icons.local_florist_rounded, 'Lifestyle'),
      (Icons.menu_book_rounded, 'Study'),
      (Icons.fitness_center_rounded, 'Fitness'),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Text('Detail', style: AppTheme.headline(fontSize: 24)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headline(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Rs ${rent.toString()}',
                      style: AppTheme.headline(fontSize: 22),
                    ),
                    TextSpan(
                      text: ' pm',
                      style: AppTheme.body(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.slate500, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  listing.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 70),
          Text('Basic Info', style: AppTheme.headline(fontSize: 20)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BasicInfoCard(
                  icon: Icons.transgender_rounded,
                  label: 'Gender',
                  value: gender.isEmpty ? 'Any' : gender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BasicInfoCard(
                  icon: Icons.bed_rounded,
                  label: 'Occupancy',
                  value: occupancy.isEmpty ? 'Any' : occupancy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BasicInfoCard(
                  icon: Icons.manage_search_rounded,
                  label: 'Looking For',
                  value: lookingFor.isEmpty ? listing.propertyTypeLabel : lookingFor,
                ),
              ),
            ],
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 70),
            Text('Highlights', style: AppTheme.headline(fontSize: 20)),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: highlights.map((highlight) {
                return _RequirementHighlightChip(label: highlight);
              }).toList(),
            ),
          ],
          const SizedBox(height: 70),
          Text('Preferences', style: AppTheme.headline(fontSize: 20)),
          const SizedBox(height: 20),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preferences.length,
              separatorBuilder: (_, _) => const SizedBox(width: 22),
              itemBuilder: (context, index) {
                final item = preferences[index];
                return _PreferenceCircle(icon: item.$1, label: item.$2);
              },
            ),
          ),
          if (listing.description.trim().isNotEmpty) ...[
            const SizedBox(height: 44),
            Text('Description', style: AppTheme.headline(fontSize: 20)),
            const SizedBox(height: 12),
            Text(
              listing.description.trim(),
              style: AppTheme.body(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _RequirementContactBar(
        listing: listing,
        gender: gender.isEmpty ? 'Any' : gender,
        onStartChat: onStartChat,
      ),
    );
  }

  String get _ownerName {
    final name = listing.ownerName.trim();
    return name.isEmpty ? 'Triozy user' : name;
  }
}

class _BasicInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BasicInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 105;
        final labelSize = isTight ? 13.0 : 15.0;
        final valueSize = isTight ? 15.0 : 17.0;

        return Container(
          height: isTight ? 146 : 138,
          padding: EdgeInsets.all(isTight ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: isTight ? 28 : 34,
                color: AppColors.outlineVariant,
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: AppTheme.body(
                    fontSize: valueSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequirementHighlightChip extends StatelessWidget {
  final String label;

  const _RequirementHighlightChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 28, color: AppColors.slate500),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTheme.body(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PreferenceCircle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreferenceCircle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6ED),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, size: 38, color: AppColors.primary),
      ),
    );
  }
}

class _RequirementContactBar extends StatelessWidget {
  final ListingModel listing;
  final String gender;
  final VoidCallback onStartChat;

  const _RequirementContactBar({
    required this.listing,
    required this.gender,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    final name = listing.ownerName.trim().isEmpty
        ? 'Triozy user'
        : listing.ownerName.trim();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            _RequirementAvatar(
              photoUrl: listing.ownerPhotoUrl,
              name: name,
              size: 58,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headline(fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    gender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onStartChat,
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: AppColors.secondary,
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

class _RequirementAvatar extends StatelessWidget {
  final String photoUrl;
  final String name;
  final double size;

  const _RequirementAvatar({
    required this.photoUrl,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase();

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl.trim().isEmpty
            ? Container(
                color: AppColors.blue50,
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AppTheme.headline(fontSize: size * 0.46, color: AppColors.primary),
                ),
              )
            : CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: AppColors.blue50,
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: AppTheme.headline(
                      fontSize: size * 0.46,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
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
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.24)),
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
