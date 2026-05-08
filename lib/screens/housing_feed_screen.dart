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
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          title: const Text('Housing'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            labelStyle: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            tabs: const [
              Tab(text: 'Rooms'),
              Tab(text: 'Flatmates'),
              Tab(text: 'PGs'),
            ],
          ),
        ),
        body: const TabBarView(
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
          listing.purpose == ListingPurpose.needRoommate;
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
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
                padding: const EdgeInsets.only(bottom: 16),
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
  }
}

class _HousingLoadingState extends StatelessWidget {
  const _HousingLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTheme.headline(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
