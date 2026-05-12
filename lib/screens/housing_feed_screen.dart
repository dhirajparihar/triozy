import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

class HousingFeedScreen extends StatelessWidget {
  final int initialTabIndex;

  const HousingFeedScreen({super.key, this.initialTabIndex = 0})
    : assert(initialTabIndex >= 0 && initialTabIndex < 3);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final headerSize = isCompact ? 20.0 : 24.0;
    final tabFontSize = isCompact ? 13.0 : 14.0;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                      padding: isCompact ? 8 : 10,
                      size: isCompact ? 18 : 20,
                    ),
                    Text(
                      'Housing',
                      style: AppTheme.headline(fontSize: headerSize, fontWeight: FontWeight.w800, color: AppColors.inverseSurface),
                    ),
                    _IconBtn(
                      icon: Icons.tune_rounded,
                      color: AppColors.primary,
                      onTap: () {},
                      padding: isCompact ? 8 : 10,
                      size: isCompact ? 18 : 20,
                    ),
                  ],
                ),
              ),
              
              // TabBar inside a pill
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isCompact ? 6 : 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: const Color(0xFFF6F5FF), // AppColors.surfaceContainerLow
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: AppTheme.body(fontSize: tabFontSize, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Rooms'),
                    Tab(text: 'Flatmates'),
                    Tab(text: 'PGs'),
                  ],
                ),
              ),
              
              
              // TabBarView
              Expanded(
                child: const TabBarView(
                  children: [
                    _HousingTab(propertyType: PropertyType.room),
                    _HousingTab(
                      purpose: ListingPurpose.needRoommate,
                      includeRoomRequirements: true,
                    ),
                    _HousingTab(propertyType: PropertyType.pg),
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double padding;
  final double size;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.padding = 10,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _HousingTab extends StatefulWidget {
  final PropertyType? propertyType;
  final ListingPurpose? purpose;
  final bool includeRoomRequirements;

  const _HousingTab({
    this.propertyType,
    this.purpose,
    this.includeRoomRequirements = false,
  });

  @override
  State<_HousingTab> createState() => _HousingTabState();
}

class _HousingTabState extends State<_HousingTab> {
  List<ListingModel> _listings = [];
  Set<String> _savedIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<DatabaseService>();
    final listings = await db.searchListings(type: ListingType.housing);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final saved = userId == null
        ? <ListingModel>[]
        : await db.getSavedListings(userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _listings = listings.where(_matchesTab).toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      _savedIds = saved.map((listing) => listing.id).toSet();
      _loading = false;
    });
  }

  bool _matchesTab(ListingModel listing) {
    if (widget.includeRoomRequirements) {
      return listing.isRequirementPost ||
          (listing.purpose == ListingPurpose.needRoommate &&
              listing.propertyType == PropertyType.flat);
    }
    if (!widget.includeRoomRequirements && listing.isRequirementPost) {
      return false;
    }
    if (widget.propertyType != null &&
        listing.propertyType != widget.propertyType) {
      return false;
    }
    if (widget.purpose != null && listing.purpose != widget.purpose) {
      return false;
    }
    return true;
  }

  Future<void> _toggleSave(String listingId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to save listings')));
      return;
    }

    await context.read<DatabaseService>().toggleSavedListing(
      userId: userId,
      listingId: listingId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (_savedIds.contains(listingId)) {
        _savedIds.remove(listingId);
      } else {
        _savedIds.add(listingId);
      }
    });
  }

  void _openListing(ListingModel listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListingDetailScreen(listingId: listing.id, seed: listing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 12.0 : 16.0;

    final list = RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(horizontalPadding, horizontalPadding, horizontalPadding, 24),
        children: [
          if (_loading)
            const _HousingLoadingState()
          else if (_listings.isEmpty)
            _HousingEmptyState(
              propertyType: widget.propertyType,
              purpose: widget.purpose,
              includeRoomRequirements: widget.includeRoomRequirements,
            )
          else
            ..._listings.map((listing) {
              return Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 12 : 16),
                child: ListingCard(
                  listing: listing,
                  compact: true,
                  onTap: () => _openListing(listing),
                  onSaveTap: () => _toggleSave(listing.id),
                  isSaved: _savedIds.contains(listing.id),
                ),
              );
            }),
        ],
      ),
    );

    return list;
  }
}

class _HousingLoadingState extends StatelessWidget {
  const _HousingLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 24,
        shadowAlpha: 0.05,
        blur: 18,
        offsetY: 8,
      ),
    );
  }
}

class _HousingEmptyState extends StatelessWidget {
  final PropertyType? propertyType;
  final ListingPurpose? purpose;
  final bool includeRoomRequirements;

  const _HousingEmptyState({
    this.propertyType,
    this.purpose,
    this.includeRoomRequirements = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch ((propertyType, purpose)) {
      (PropertyType.room, _) => (
        Icons.meeting_room_rounded,
        'No rooms yet',
        'Fresh room listings will appear here as soon as they are posted.',
      ),
      (_, ListingPurpose.needRoommate) when includeRoomRequirements => (
        Icons.groups_rounded,
        'No flatmate or room needs yet',
        'People looking for rooms or flatmates will appear here.',
      ),
      (_, ListingPurpose.needRoommate) => (
        Icons.groups_rounded,
        'No flatmate posts yet',
        'This tab will fill up once people start looking for flatmates.',
      ),
      (PropertyType.pg, _) => (
        Icons.apartment_rounded,
        'No PGs yet',
        'PG and hostel listings from owners will show up here.',
      ),
      _ => (
        Icons.home_work_rounded,
        'No housing listings yet',
        'Listings will show up here once they are posted.',
      ),
    };

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 24,
        shadowAlpha: 0.05,
        blur: 18,
        offsetY: 8,
      ),
      child: Column(
        children: [
          Container(
            width: isCompact ? 48 : 56,
            height: isCompact ? 48 : 56,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppTheme.radius(16),
            ),
            child: Icon(icon, color: AppColors.onPrimaryContainer, size: isCompact ? 24 : 28),
          ),
          SizedBox(height: isCompact ? 12 : 14),
          Text(title, style: AppTheme.headline(fontSize: isCompact ? 18 : 20)),
          SizedBox(height: isCompact ? 4 : 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.body(
              fontSize: isCompact ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
