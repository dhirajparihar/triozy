import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

  const ListingDetailScreen({super.key, required this.listingId, this.seed});

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
    final listing = await context.read<DatabaseService>().getListing(
      widget.listingId,
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This is your listing')));
      return;
    }

    try {
      final conversationId = await context.read<ChatProvider>().createOrGetChat(
        otherUserId: listing.ownerId,
        chatType: ChatType.listing.value,
        referenceId: listing.id,
        listingTitle: listing.title,
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open chat: $error')));
    }
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

    if (listing.needsRoommate && listing.propertyType == PropertyType.room) {
      return _RoomPostDetailScaffold(listing: listing, onStartChat: _startChat);
    }

    if (listing.propertyType == PropertyType.pg && listing.isOwnerPost) {
      return _PgDetailScaffold(listing: listing, onStartChat: _startChat);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _GenericImagePager(imageUrls: listing.imageUrls),
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
                    Text(listing.title, style: AppTheme.headline(fontSize: 24)),
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
                    Text(
                      'Location preview',
                      style: AppTheme.headline(fontSize: 20),
                    ),
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
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.onSurface,
                ),
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

class _RoomPostDetailScaffold extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onStartChat;

  const _RoomPostDetailScaffold({
    required this.listing,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    final name = listing.ownerName.trim().isEmpty
        ? 'Triozy user'
        : listing.ownerName.trim();
    final occupancy = _occupancyFromHighlights;
    final lookingFor = (listing.genderPreference ?? '').trim().isEmpty
        ? 'Any'
        : listing.genderPreference!.trim();
    final amenities = _amenities;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 30),
        ),
        title: Text('Detail', style: AppTheme.headline(fontSize: 24)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded, size: 30),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
        children: [
          _RoomImageHero(imageUrls: listing.imageUrls),
          const SizedBox(height: 34),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headline(
                    fontSize: 22,
                    color: const Color(0xFF3F4145),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '₹${listing.price.toStringAsFixed(0)}',
                      style: AppTheme.headline(
                        fontSize: 24,
                        color: const Color(0xFF3F4145),
                      ),
                    ),
                    TextSpan(
                      text: ' pm',
                      style: AppTheme.body(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8E8E8E),
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
              const Icon(Icons.location_on, color: Color(0xFF8E8E8E), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  listing.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E8E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 66),
          Text(
            'Basic Info',
            style: AppTheme.headline(
              fontSize: 20,
              color: const Color(0xFF3F4145),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BasicInfoCard(
                  icon: Icons.transgender_rounded,
                  label: 'Gender',
                  value: lookingFor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BasicInfoCard(
                  icon: Icons.bed_rounded,
                  label: 'Occupancy',
                  value: occupancy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BasicInfoCard(
                  icon: Icons.manage_search_rounded,
                  label: 'Looking For',
                  value: lookingFor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 66),
          Text(
            'Amenities',
            style: AppTheme.headline(
              fontSize: 20,
              color: const Color(0xFF3F4145),
            ),
          ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: amenities
                  .map((amenity) => _RequirementHighlightChip(label: amenity))
                  .toList(),
            ),
          ],
          if (listing.description.trim().isNotEmpty) ...[
            const SizedBox(height: 44),
            Text(
              'Description',
              style: AppTheme.headline(
                fontSize: 20,
                color: const Color(0xFF3F4145),
              ),
            ),
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
        gender: lookingFor,
        onStartChat: onStartChat,
      ),
    );
  }

  String get _occupancyFromHighlights {
    const occupancyValues = {'Single', 'Double', 'Triple'};
    for (final highlight in listing.highlights) {
      final cleaned = highlight.trim();
      if (occupancyValues.contains(cleaned)) {
        return cleaned;
      }
    }
    return 'Any';
  }

  List<String> get _amenities {
    const hidden = {'Single', 'Double', 'Triple', 'Mobile public', 'Chat only'};
    return listing.highlights
        .map((item) => item.trim())
        .where(
          (item) =>
              item.isNotEmpty &&
              !hidden.contains(item) &&
              !item.startsWith('Looking for '),
        )
        .toList();
  }
}

class _PgDetailScaffold extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback onStartChat;

  const _PgDetailScaffold({required this.listing, required this.onStartChat});

  @override
  State<_PgDetailScaffold> createState() => _PgDetailScaffoldState();
}

class _PgDetailScaffoldState extends State<_PgDetailScaffold> {
  final PageController _imageController = PageController();
  int _imageIndex = 0;
  bool _saved = false;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final details = _PgParsedDetails.fromListing(listing);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PgImageCarousel(
              imageUrls: listing.imageUrls,
              controller: _imageController,
              index: _imageIndex,
              onPageChanged: (index) => setState(() => _imageIndex = index),
              saved: _saved,
              onBack: () => Navigator.pop(context),
              onSave: () => setState(() => _saved = !_saved),
              onShare: () => Share.share(
                '${listing.title}\nStarting from ₹${listing.price.toStringAsFixed(0)}/month\n${listing.location}',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _PgOverviewCard(listing: listing, details: details),
                const SizedBox(height: 14),
                _PgPricingCard(listing: listing, details: details),
                const SizedBox(height: 18),
                _SectionHeading('Room Configurations'),
                const SizedBox(height: 10),
                ...details.rooms.map((room) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PgRoomCard(room: room),
                  );
                }),
                const SizedBox(height: 8),
                _SectionHeading('Amenities'),
                const SizedBox(height: 10),
                _PgAmenitiesGrid(amenities: details.amenities),
                const SizedBox(height: 18),
                _SectionHeading('Rules & Preferences'),
                const SizedBox(height: 10),
                _PgRulesCard(details: details, listing: listing),
                const SizedBox(height: 18),
                _SectionHeading('Description'),
                const SizedBox(height: 10),
                _ReadMoreText(text: details.cleanDescription),
                const SizedBox(height: 18),
                _SectionHeading('Location'),
                const SizedBox(height: 10),
                _PgLocationCard(listing: listing, nearby: details.nearby),
                const SizedBox(height: 18),
                _SectionHeading('Owner / Contact'),
                const SizedBox(height: 10),
                _PgOwnerCard(
                  listing: listing,
                  phone: details.contact,
                  whatsApp: details.whatsApp,
                  onStartChat: widget.onStartChat,
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PgStickyCta(
        onBookVisit: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Visit request started')),
          );
          widget.onStartChat();
        },
        onContactOwner: widget.onStartChat,
      ),
    );
  }
}

class _PgImageCarousel extends StatelessWidget {
  final List<String> imageUrls;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const _PgImageCarousel({
    required this.imageUrls,
    required this.controller,
    required this.index,
    required this.onPageChanged,
    required this.saved,
    required this.onBack,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final images = imageUrls.isEmpty ? [''] : imageUrls;
    return SizedBox(
      height: 330,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, itemIndex) {
              final imageUrl = images[itemIndex];
              return GestureDetector(
                onTap: imageUrl.isEmpty
                    ? null
                    : () => _openImageViewer(
                        context,
                        imageUrls: imageUrls,
                        initialIndex: itemIndex,
                      ),
                child: imageUrl.isEmpty
                    ? Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(
                            Icons.apartment_rounded,
                            size: 58,
                            color: AppColors.outline,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            Container(color: AppColors.surfaceContainerHigh),
                      ),
              );
            },
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: _CircleAction(icon: Icons.arrow_back_rounded, onTap: onBack),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 12,
            child: Row(
              children: [
                _CircleAction(icon: Icons.ios_share_rounded, onTap: onShare),
                const SizedBox(width: 10),
                _CircleAction(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onTap: onSave,
                ),
              ],
            ),
          ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (dot) {
                  final active = dot == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: active ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 21, color: AppColors.onSurface),
      ),
    );
  }
}

class _PgOverviewCard extends StatelessWidget {
  final ListingModel listing;
  final _PgParsedDetails details;

  const _PgOverviewCard({required this.listing, required this.details});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  style: AppTheme.headline(fontSize: 24),
                ),
              ),
              const SizedBox(width: 10),
              _VerifiedBadge(label: 'Verified'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: details.propertyType),
              if ((listing.genderPreference ?? '').isNotEmpty)
                _Pill(label: listing.genderPreference!),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.slate500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  listing.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
          if (details.nearby.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Near ${details.nearby}',
              style: AppTheme.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PgPricingCard extends StatelessWidget {
  final ListingModel listing;
  final _PgParsedDetails details;

  const _PgPricingCard({required this.listing, required this.details});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Starting from ₹${listing.price.toStringAsFixed(0)}/month',
            style: AppTheme.headline(fontSize: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniInfoTile(
                  icon: Icons.security_rounded,
                  label: 'Deposit',
                  value: details.deposit.isEmpty
                      ? 'Ask owner'
                      : details.deposit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInfoTile(
                  icon: Icons.restaurant_rounded,
                  label: 'Food',
                  value: details.foodIncluded ? 'Included' : 'Not included',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInfoTile(
                  icon: Icons.electric_bolt_rounded,
                  label: 'Electricity',
                  value: details.electricityIncluded ? 'Included' : 'Extra',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PgRoomCard extends StatefulWidget {
  final _PgRoomConfig room;

  const _PgRoomCard({required this.room});

  @override
  State<_PgRoomCard> createState() => _PgRoomCardState();
}

class _PgRoomCardState extends State<_PgRoomCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    return _DetailCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.king_bed_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomType,
                        style: AppTheme.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${room.rent}/month • ${room.vacantBeds} beds available',
                        style: AppTheme.label(
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PgSpecChip(
                    icon: Icons.people_rounded,
                    label: 'Capacity ${room.capacity}',
                  ),
                  _PgSpecChip(
                    icon: Icons.bathtub_rounded,
                    label: room.attachedBathroom,
                  ),
                  _PgSpecChip(icon: Icons.ac_unit_rounded, label: room.ac),
                  _PgSpecChip(icon: Icons.chair_rounded, label: room.furnished),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PgAmenitiesGrid extends StatelessWidget {
  final List<String> amenities;

  const _PgAmenitiesGrid({required this.amenities});

  @override
  Widget build(BuildContext context) {
    final items = amenities.isEmpty ? ['WiFi', 'Food', 'CCTV'] : amenities;
    return _DetailCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((amenity) {
          return _PgSpecChip(icon: _amenityIcon(amenity), label: amenity);
        }).toList(),
      ),
    );
  }

  IconData _amenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi')) return Icons.wifi_rounded;
    if (lower.contains('food')) return Icons.restaurant_rounded;
    if (lower.contains('laundry')) return Icons.local_laundry_service_rounded;
    if (lower.contains('parking')) return Icons.local_parking_rounded;
    if (lower.contains('cctv')) return Icons.videocam_rounded;
    if (lower.contains('backup')) return Icons.battery_charging_full_rounded;
    if (lower.contains('lift')) return Icons.elevator_rounded;
    if (lower.contains('geyser')) return Icons.hot_tub_rounded;
    if (lower.contains('ac')) return Icons.ac_unit_rounded;
    return Icons.check_circle_rounded;
  }
}

class _PgRulesCard extends StatelessWidget {
  final _PgParsedDetails details;
  final ListingModel listing;

  const _PgRulesCard({required this.details, required this.listing});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        children: [
          _RuleRow('Preferred Gender', listing.genderPreference ?? 'Any'),
          _RuleRow('Occupants', details.occupantType),
          _RuleRow('Smoking', details.smoking),
          _RuleRow('Visitors', details.visitors),
          _RuleRow(
            'Curfew',
            details.curfew.isEmpty ? 'Ask owner' : details.curfew,
          ),
        ],
      ),
    );
  }
}

class _PgLocationCard extends StatelessWidget {
  final ListingModel listing;
  final String nearby;

  const _PgLocationCard({required this.listing, required this.nearby});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        children: [
          Container(
            height: 132,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: AppColors.primary,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.location,
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (nearby.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RuleRow('Nearby', nearby),
          ],
        ],
      ),
    );
  }
}

class _PgOwnerCard extends StatelessWidget {
  final ListingModel listing;
  final String phone;
  final String whatsApp;
  final VoidCallback onStartChat;

  const _PgOwnerCard({
    required this.listing,
    required this.phone,
    required this.whatsApp,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    final displayPhone = phone.isEmpty ? 'Contact through chat' : phone;
    return _DetailCard(
      child: Row(
        children: [
          _RequirementAvatar(
            photoUrl: listing.ownerPhotoUrl,
            name: listing.ownerName,
            size: 54,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayPhone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label(color: AppColors.slate500),
                ),
              ],
            ),
          ),
          _ContactIconButton(
            icon: Icons.call_rounded,
            onTap: phone.isEmpty ? null : () => _launchUri('tel:$phone'),
          ),
          _ContactIconButton(icon: Icons.chat_rounded, onTap: onStartChat),
          _ContactIconButton(
            icon: Icons.message_rounded,
            onTap: whatsApp.isEmpty
                ? null
                : () => _launchUri('https://wa.me/${_digitsOnly(whatsApp)}'),
          ),
        ],
      ),
    );
  }
}

class _PgStickyCta extends StatelessWidget {
  final VoidCallback onBookVisit;
  final VoidCallback onContactOwner;

  const _PgStickyCta({required this.onBookVisit, required this.onContactOwner});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBookVisit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Book Visit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onContactOwner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Contact Owner'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;

  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTheme.headline(fontSize: 20));
  }
}

class _VerifiedBadge extends StatelessWidget {
  final String label;

  const _VerifiedBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 15,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.label(
              fontWeight: FontWeight.w900,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 9),
          Text(label, style: AppTheme.label(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PgSpecChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PgSpecChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(label, style: AppTheme.label(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String label;
  final String value;

  const _RuleRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.label(color: AppColors.slate500),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.body(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadMoreText extends StatefulWidget {
  final String text;

  const _ReadMoreText({required this.text});

  @override
  State<_ReadMoreText> createState() => _ReadMoreTextState();
}

class _ReadMoreTextState extends State<_ReadMoreText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (widget.text.length > 140)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Read Less' : 'Read More'),
            ),
        ],
      ),
    );
  }
}

class _ContactIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ContactIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.blue50,
        foregroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.surfaceContainerLow,
      ),
    );
  }
}

class _PgParsedDetails {
  final String propertyType;
  final String deposit;
  final String nearby;
  final String contact;
  final String whatsApp;
  final String occupantType;
  final String smoking;
  final String visitors;
  final String curfew;
  final bool foodIncluded;
  final bool electricityIncluded;
  final List<String> amenities;
  final List<_PgRoomConfig> rooms;
  final String cleanDescription;

  const _PgParsedDetails({
    required this.propertyType,
    required this.deposit,
    required this.nearby,
    required this.contact,
    required this.whatsApp,
    required this.occupantType,
    required this.smoking,
    required this.visitors,
    required this.curfew,
    required this.foodIncluded,
    required this.electricityIncluded,
    required this.amenities,
    required this.rooms,
    required this.cleanDescription,
  });

  factory _PgParsedDetails.fromListing(ListingModel listing) {
    final lines = listing.description
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final roomLines = lines
        .where((line) => line.startsWith('- '))
        .map((line) => line.substring(2))
        .toList();
    final rawDescription = lines.isEmpty ? listing.description : lines.first;
    final hiddenPrefixes = [
      'Address:',
      'Nearby:',
      'Room configurations:',
      '- ',
      'Total capacity:',
      'Vacant beds:',
      'Beds available:',
      'Security deposit:',
      'Maintenance:',
      'Contact:',
      'Brokerage:',
      'Smoking:',
      'Drinking:',
      'Pets:',
      'Visitor restrictions:',
      'Curfew:',
      'WhatsApp:',
      'Video tour selected:',
    ];
    final clean = lines
        .where((line) => !hiddenPrefixes.any(line.startsWith))
        .join('\n')
        .trim();
    final rooms = roomLines.map(_PgRoomConfig.parse).toList();

    return _PgParsedDetails(
      propertyType: listing.highlights.isEmpty
          ? 'PG/Hostel'
          : listing.highlights.first,
      deposit: _lineValue(lines, 'Security deposit:').replaceFirst('Rs ', '₹'),
      nearby: _lineValue(lines, 'Nearby:'),
      contact: _lineValue(lines, 'Contact:'),
      whatsApp: _lineValue(lines, 'WhatsApp:'),
      occupantType: _findHighlight(listing.highlights, const [
        'Student',
        'Working Professional',
        'Both',
      ], fallback: 'Both'),
      smoking: _lineValue(lines, 'Smoking:').isEmpty
          ? 'Ask owner'
          : _lineValue(lines, 'Smoking:'),
      visitors: _lineValue(lines, 'Visitor restrictions:').isEmpty
          ? 'Ask owner'
          : _lineValue(lines, 'Visitor restrictions:'),
      curfew: _lineValue(lines, 'Curfew:'),
      foodIncluded: listing.highlights.contains('Food Included'),
      electricityIncluded: listing.highlights.contains('Electricity Included'),
      amenities: _amenitiesFromHighlights(listing.highlights),
      rooms: rooms.isEmpty
          ? [
              _PgRoomConfig(
                roomType: listing.highlights.length > 1
                    ? listing.highlights[1]
                    : 'Room',
                rent: listing.price.toStringAsFixed(0),
                capacity: '-',
                vacantBeds: '-',
                attachedBathroom: 'Ask owner',
                ac: 'Ask owner',
                furnished: listing.furnishing ?? 'Ask owner',
              ),
            ]
          : rooms,
      cleanDescription: clean.isEmpty ? rawDescription : clean,
    );
  }

  static String _lineValue(List<String> lines, String prefix) {
    for (final line in lines) {
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return '';
  }

  static String _findHighlight(
    List<String> highlights,
    List<String> options, {
    required String fallback,
  }) {
    for (final option in options) {
      if (highlights.contains(option)) return option;
    }
    return fallback;
  }

  static List<String> _amenitiesFromHighlights(List<String> highlights) {
    const excluded = {
      'Boys PG',
      'Girls PG',
      'Co-ed PG',
      'Hostel',
      'Male',
      'Female',
      'Any',
      'Student',
      'Working Professional',
      'Both',
      'Food Included',
      'Electricity Included',
    };
    return highlights
        .where(
          (item) => !excluded.contains(item) && !item.contains('beds vacant'),
        )
        .toList();
  }
}

class _PgRoomConfig {
  final String roomType;
  final String rent;
  final String capacity;
  final String vacantBeds;
  final String attachedBathroom;
  final String ac;
  final String furnished;

  const _PgRoomConfig({
    required this.roomType,
    required this.rent,
    required this.capacity,
    required this.vacantBeds,
    required this.attachedBathroom,
    required this.ac,
    required this.furnished,
  });

  factory _PgRoomConfig.parse(String raw) {
    final parts = raw.split('->').map((part) => part.trim()).toList();
    final tail = parts.length > 4
        ? parts[4].split(',').map((part) => part.trim()).toList()
        : <String>[];
    return _PgRoomConfig(
      roomType: parts.isNotEmpty ? parts[0] : 'Room',
      rent: parts.length > 1 ? _digitsOnly(parts[1]) : '-',
      capacity: parts.length > 2
          ? _digitsOnly(parts[2]).isEmpty
                ? '-'
                : _digitsOnly(parts[2])
          : '-',
      vacantBeds: parts.length > 3
          ? _digitsOnly(parts[3]).isEmpty
                ? '-'
                : _digitsOnly(parts[3])
          : '-',
      ac: tail.isNotEmpty ? tail[0] : 'Ask owner',
      furnished: tail.length > 1 ? tail[1] : 'Ask owner',
      attachedBathroom: tail.length > 2 ? tail[2] : 'Ask owner',
    );
  }
}

Future<void> _launchUri(String rawUrl) async {
  final uri = Uri.parse(rawUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

class _RoomImageHero extends StatelessWidget {
  final List<String> imageUrls;

  const _RoomImageHero({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    final hasImages = imageUrls.isNotEmpty;

    return GestureDetector(
      onTap: hasImages
          ? () => _openImageViewer(context, imageUrls: imageUrls)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 1.55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImages)
                CachedNetworkImage(
                  imageUrl: imageUrls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _fallback(),
                )
              else
                _fallback(),
              if (hasImages)
                Container(color: Colors.black.withValues(alpha: 0.52)),
              if (hasImages)
                Center(
                  child: Text(
                    'Tap to view images',
                    style: AppTheme.body(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Center(
        child: Icon(
          Icons.home_work_rounded,
          size: 56,
          color: AppColors.outline,
        ),
      ),
    );
  }
}

class _GenericImagePager extends StatelessWidget {
  final List<String> imageUrls;

  const _GenericImagePager({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: PageView(
        children: (imageUrls.isEmpty ? [''] : imageUrls).map((imageUrl) {
          return GestureDetector(
            onTap: imageUrl.isEmpty
                ? null
                : () => _openImageViewer(
                    context,
                    imageUrls: imageUrls,
                    initialIndex: imageUrls.indexOf(imageUrl),
                  ),
            child: imageUrl.isEmpty
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
                    errorWidget: (_, _, _) =>
                        Container(color: AppColors.surfaceContainerHigh),
                  ),
          );
        }).toList(),
      ),
    );
  }
}

void _openImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  if (imageUrls.isEmpty) {
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _FullscreenImageViewer(
        imageUrls: imageUrls.take(3).toList(),
        initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
      ),
    ),
  );
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: Colors.white,
                iconSize: 32,
                tooltip: 'Close',
              ),
            ),
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.imageUrls.length}',
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    final gender = (listing.genderPreference ?? details.genderPreference)
        .trim();
    final occupancy = details.occupancy.trim();
    final lookingFor = details.genderPreference.trim();
    final rent = details.maxBudget > 0
        ? details.maxBudget
        : listing.price.toInt();
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
              const Icon(
                Icons.location_on,
                color: AppColors.slate500,
                size: 28,
              ),
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
                  value: lookingFor.isEmpty
                      ? listing.propertyTypeLabel
                      : lookingFor,
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
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.18),
          ),
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
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
            ),
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
                  style: AppTheme.headline(
                    fontSize: size * 0.46,
                    color: AppColors.primary,
                  ),
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
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.24),
        ),
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
