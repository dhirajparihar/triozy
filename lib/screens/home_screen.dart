

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../providers/location_provider.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'housing_entry_screen.dart';
import 'listing_detail_screen.dart';
import 'list_property_screen.dart';
import 'location_search_screen.dart';

/// Home feed with hero, quick actions, and featured listings.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onExploreTapped;
  final VoidCallback? onSearchTapped;
  final ValueChanged<PropertyType>? onPropertyTypeSelected;

  const HomeScreen({
    super.key,
    this.onExploreTapped,
    this.onSearchTapped,
    this.onPropertyTypeSelected,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

/// Drives featured listings, saved state, and quick actions.
class HomeScreenState extends State<HomeScreen> {
  static const int _maxSectionListings = 5;

  List<ListingModel> _listings = [];
  Set<String> _savedIds = <String>{};
  bool _loading = true;
  bool _hasPublishedRequirement = false;
  bool _hasPostedHousingListing = false;
  String? _selectedLocationAddress;

  @override
  void initState() {
    super.initState();
    // Load feed data after first frame to avoid build timing issues.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> refreshFromShell() => _loadData();

  Future<void> _handleRefresh() async {
    final locProvider = context.read<LocationProvider>();
    await locProvider.forceRefetchLocation();
    await _loadData();
  }

  Future<void> _loadData() async {
    // Fetch featured listings and per-user flags.
    final db = context.read<DatabaseService>();
    final locProvider = context.read<LocationProvider>();
    try {
      if (!locProvider.isAvailable && !locProvider.hasError) {
        await locProvider.fetchLocation();
      }

      final listings = await db.searchListings(
        lat: locProvider.latitude,
        lon: locProvider.longitude,
        locationName: locProvider.address,
      );
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final saved = userId == null
          ? <ListingModel>[]
          : await db.getSavedListings(userId);
      final hasPublishedRequirement = userId != null &&
          await db.hasUserPublishedRequirement(userId);
      final hasPostedHousingListing = userId != null &&
          await db.hasUserPostedHousingListing(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedLocationAddress = locProvider.address;
        _listings = listings;
        _savedIds = saved.map((listing) => listing.id).toSet();
        _hasPublishedRequirement = hasPublishedRequirement;
        _hasPostedHousingListing = hasPostedHousingListing;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  List<ListingModel> _sectionListings(bool Function(ListingModel) test) {
    return _listings.where(test).take(_maxSectionListings).toList();
  }

  bool _isRoomListing(ListingModel listing) {
    return listing.type == ListingType.housing &&
        listing.purpose == ListingPurpose.needRoommate && !listing.isRequirementPost;
  }

  bool _isFlatmateListing(ListingModel listing) {
    return listing.type == ListingType.housing &&
        listing.isRequirementPost;
  }

  bool _isPropertyListing(ListingModel listing) {
    return listing.type == ListingType.housing &&
        listing.purpose == ListingPurpose.offerProperty;
  }

  bool _isMarketplaceListing(ListingModel listing) {
    return listing.type == ListingType.marketplace ||
        listing.propertyType == PropertyType.item;
  }

  Future<void> _toggleSave(String listingId) async {
    // Persist saved state and update local set.
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
    setState(() {
      if (_savedIds.contains(listingId)) {
        _savedIds.remove(listingId);
      } else {
        _savedIds.add(listingId);
      }
    });
  }

  void _openListing(ListingModel listing) {
    // Seed data for faster detail rendering.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListingDetailScreen(listingId: listing.id, seed: listing),
      ),
    );
  }

  Future<void> _openFlatmates() async {
    // Route to housing entry if no listing exists yet.
    if (_hasPostedHousingListing) {
      widget.onPropertyTypeSelected?.call(PropertyType.flat);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HousingEntryScreen()),
    );
  }

  Future<void> _openRoom() async {
    // Route to housing entry if no listing exists yet.
    if (_hasPostedHousingListing) {
      widget.onPropertyTypeSelected?.call(PropertyType.room);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HousingEntryScreen()),
    );
  }

  void _openPostListing() {
    // Open PG/hostel listing flow.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListPropertyScreen()),
    );
  }

  Future<void> _openLocationSearch() async {
    // Launch location search flow.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layout values scale for compact screens.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 16.0 : 20.0;
    final cardHeight = isCompact ? 190.0 : 210.0;
    final cardWidth = isCompact ? 180.0 : 200.0;
    final rooms = _sectionListings(_isRoomListing);
    final flatmates = _sectionListings(_isFlatmateListing);
    final properties = _sectionListings(_isPropertyListing);
    final marketplace = _sectionListings(_isMarketplaceListing);
    final hasAnyListings = rooms.isNotEmpty ||
        flatmates.isNotEmpty ||
        properties.isNotEmpty ||
        marketplace.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(horizontalPadding, isCompact ? 12 : 16, horizontalPadding, 24),
        children: [
          _HeroSection(
            onSearchTap: _openLocationSearch,
            selectedLocation: _selectedLocationAddress,
          ),
          SizedBox(height: isCompact ? 16 : 20),
          _QuickActions(
            hasPublishedRequirement: _hasPublishedRequirement,
            onFindRoomTap: _openRoom,
            onFlatmatesTap: _openFlatmates,
            onPostListingTap: _openPostListing,
            onMarketplaceTap: () =>
                widget.onPropertyTypeSelected?.call(PropertyType.item),
            onAllServicesTap: widget.onSearchTapped ?? widget.onExploreTapped,
          ),
          SizedBox(height: isCompact ? 28 : 32),
          if (_loading)
            const _HomeLoadingState()
          else if (!hasAnyListings)
            const _EmptyFeaturedState()
          else ...[
            if (rooms.isNotEmpty)
              _ListingSection(
                title: 'Rooms',
                listings: rooms,
                cardHeight: cardHeight,
                cardWidth: cardWidth,
                isSaved: (listing) => _savedIds.contains(listing.id),
                onListingTap: _openListing,
                onSaveTap: (listing) => _toggleSave(listing.id),
                onSeeAllTap: () =>
                    widget.onPropertyTypeSelected?.call(PropertyType.room),
              ),
            if (flatmates.isNotEmpty)
              _ListingSection(
                title: 'Flatmates',
                listings: flatmates,
                cardHeight: cardHeight,
                cardWidth: cardWidth,
                showProfileCards: true,
                isSaved: (listing) => _savedIds.contains(listing.id),
                onListingTap: _openListing,
                onSaveTap: (listing) => _toggleSave(listing.id),
                onSeeAllTap: () =>
                    widget.onPropertyTypeSelected?.call(PropertyType.flat),
              ),
            if (properties.isNotEmpty)
              _ListingSection(
                title: 'Properties',
                listings: properties,
                cardHeight: cardHeight,
                cardWidth: cardWidth,
                isSaved: (listing) => _savedIds.contains(listing.id),
                onListingTap: _openListing,
                onSaveTap: (listing) => _toggleSave(listing.id),
                onSeeAllTap: () =>
                    widget.onPropertyTypeSelected?.call(PropertyType.pg),
              ),
            if (marketplace.isNotEmpty)
              _ListingSection(
                title: 'Marketplace',
                listings: marketplace,
                cardHeight: cardHeight,
                cardWidth: cardWidth,
                isSaved: (listing) => _savedIds.contains(listing.id),
                onListingTap: _openListing,
                onSaveTap: (listing) => _toggleSave(listing.id),
                onSeeAllTap: () =>
                    widget.onPropertyTypeSelected?.call(PropertyType.item),
              ),
          ],
        ],
      ),
    );
  }

}

class _ListingSection extends StatelessWidget {
  final String title;
  final List<ListingModel> listings;
  final double cardHeight;
  final double cardWidth;
  final bool showProfileCards;
  final bool Function(ListingModel listing) isSaved;
  final ValueChanged<ListingModel> onListingTap;
  final ValueChanged<ListingModel> onSaveTap;
  final VoidCallback? onSeeAllTap;

  const _ListingSection({
    required this.title,
    required this.listings,
    required this.cardHeight,
    required this.cardWidth,
    this.showProfileCards = false,
    required this.isSaved,
    required this.onListingTap,
    required this.onSaveTap,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 28 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            actionLabel: 'See all',
            onActionTap: onSeeAllTap,
          ),
          SizedBox(height: isCompact ? 14 : 16),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: listings.length,
              separatorBuilder: (_, _) => SizedBox(width: isCompact ? 12 : 14),
              itemBuilder: (context, index) {
                final listing = listings[index];
                return SizedBox(
                  width: cardWidth,
                  child: FeaturedListingCard(
                    listing: listing,
                    isSaved: isSaved(listing),
                    showProfile: showProfileCards,
                    onTap: () => onListingTap(listing),
                    onSaveTap: () => onSaveTap(listing),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  /// Gradient hero block with search CTA.
  final VoidCallback? onSearchTap;
  final String? selectedLocation;

  const _HeroSection({this.onSearchTap, this.selectedLocation});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Container(

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEEF2FF),
            Color(0xFFE8EAFF),
            Color(0xFFF0EDFF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: isCompact ? -30 : -20,
            top: 0,
            bottom: isCompact ? 16 : 20,
            child: Image.asset(
              'assets/images/suitcase2-removebg-preview.png',
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 20, isCompact ? 20 : 24,
              isCompact ? 16 : 20, isCompact ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTheme.headline(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2,
                letterSpacing: -0.3,
              ),
              children: [
                const TextSpan(text: 'Move to a new city\nwithout starting\nfrom '),
                TextSpan(
                  text: 'zero.',
                  style: AppTheme.headline(
                    fontSize: isCompact ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Text(
            'Find rooms, flatmates and everything\nyou need to settle in.',
            style: AppTheme.body(
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: isCompact ? 16 : 20),
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(left: isCompact ? 14 : 16, right: 5, top: 5, bottom: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Search city or locality',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: isCompact ? 38 : 42,
                    height: isCompact ? 38 : 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: isCompact ? 18 : 20,
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
    );
  }
}


class _QuickActions extends StatelessWidget {
  /// Horizontal scroll of primary actions.
  final bool hasPublishedRequirement;
  final VoidCallback onFindRoomTap;
  final VoidCallback onFlatmatesTap;
  final VoidCallback onPostListingTap;
  final VoidCallback onMarketplaceTap;
  final VoidCallback? onAllServicesTap;

  const _QuickActions({
    required this.hasPublishedRequirement,
    required this.onFindRoomTap,
    required this.onFlatmatesTap,
    required this.onPostListingTap,
    required this.onMarketplaceTap,
    this.onAllServicesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryCard(
              title: 'Find Room',
              subtitle: 'Explore rooms',
              icon: Icons.apartment_rounded,
              bgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF3B82F6),
              onTap: onFindRoomTap,
            ),
            _CategoryCard(
              title: 'Find Flatmate',
              subtitle: 'Get matched',
              icon: Icons.groups_rounded,
              bgColor: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF8B5CF6),
              onTap: onFlatmatesTap,
            ),
            _CategoryCard(
              title: 'Rent Property',
              subtitle: 'For Owners',
              icon: Icons.add_box_rounded,
              bgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF6366F1),
              onTap: onPostListingTap,
            ),
            _CategoryCard(
              title: 'Marketplace',
              subtitle: 'Buy & sell',
              icon: Icons.storefront_rounded,
              bgColor: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF97316),
              onTap: onMarketplaceTap,
            ),
            _CategoryCard(
              title: 'All Services',
              subtitle: 'Browse',
              icon: Icons.grid_view_rounded,
              bgColor: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF10B981),
              onTap: onAllServicesTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  /// Compact action card used in the quick actions row.
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    // Fixed width ensures text doesn't wrap awkwardly and fits nicely in a scrollable row
    final itemWidth = isCompact ? 72.0 : 82.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompact ? 46 : 50,
              height: isCompact ? 46 : 50,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: isCompact ? 20 : 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                fontSize: isCompact ? 9 : 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                fontSize: isCompact ? 7 : 8,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  /// Section header with optional action.
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.headline(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        GestureDetector(
          onTap: onActionTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionLabel,
                style: AppTheme.body(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: isCompact ? 16 : 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FeaturedListingCard extends StatelessWidget {
  /// Compact featured listing tile used in the carousel.
  final ListingModel listing;
  final bool isSaved;
  final bool showProfile;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const FeaturedListingCard({
    super.key,
    required this.listing,
    required this.isSaved,
    this.showProfile = false,
    required this.onTap,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = listing.propertyType == PropertyType.pg
        ? 'PG'
        : listing.propertyType == PropertyType.flat
            ? listing.needsRoommate
                ? 'Flatmate'
                : 'Flat'
            : listing.propertyType == PropertyType.room
                ? 'Room'
                : 'Item';
    final isRoommateNeeded = listing.purpose == ListingPurpose.needRoommate;
    String displayTitle = listing.title;
    if (isRoommateNeeded) {
      final gender = (listing.genderPreference ?? listing.requirementDetails?.genderPreference ?? '').trim();
      if (gender.isNotEmpty && gender.toLowerCase() != 'any') {
        final capGender = gender[0].toUpperCase() + gender.substring(1).toLowerCase();
        displayTitle = '$capGender roommate needed';
      } else {
        displayTitle = 'Roommate needed';
      }
    } else if (showProfile) {
      displayTitle = listing.ownerName.trim().isEmpty ? listing.title.trim() : listing.ownerName.trim();
    }

    final locationWords = listing.location.trim().split(RegExp(r'\s+'));
    final displayLocation = locationWords.length > 2
        ? '${locationWords.take(2).join(' ')}...'
        : listing.location;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    showProfile
                        ? _ProfileCardMedia(listing: listing)
                        : listing.imageUrls.isEmpty
                            ? Container(
                                color: AppColors.accentLavender,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.home_work_outlined,
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  size: 36,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: listing.imageUrls.first,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.accentLavender,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.home_work_outlined,
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    size: 36,
                                  ),
                                ),
                              ),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(typeLabel,
                          style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: GestureDetector(
                        onTap: onSaveTap,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isSaved ? AppColors.tertiary : Colors.white,
                            size: 24,
                            shadows: [
                              if (!isSaved)
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        style: AppTheme.headline(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(text: displayTitle),
                          if (showProfile && (listing.price > 0 || (listing.requirementDetails?.minBudget ?? 0) > 0 || (listing.requirementDetails?.maxBudget ?? 0) > 0)) ...[
                            const TextSpan(text: '  |  ', style: TextStyle(color: AppColors.textSecondary)),
                            TextSpan(
                              style: const TextStyle(color: AppColors.primary),
                              children: [
                                const TextSpan(text: '₹'),
                                if (listing.requirementDetails != null && listing.requirementDetails!.minBudget > 0 && listing.requirementDetails!.maxBudget > 0)
                                  TextSpan(text: '${listing.requirementDetails!.minBudget} - ₹${listing.requirementDetails!.maxBudget}')
                                else if (listing.requirementDetails != null && listing.requirementDetails!.maxBudget > 0)
                                  TextSpan(text: 'Upto ${listing.requirementDetails!.maxBudget}')
                                else if (listing.requirementDetails != null && listing.requirementDetails!.minBudget > 0)
                                  TextSpan(text: '${listing.requirementDetails!.minBudget} onwards')
                                else if (listing.price > 0)
                                  TextSpan(text: listing.priceLabel.replaceFirst(RegExp(r'(?:Rs\.?|₹)\s*', caseSensitive: false), '')),
                                if (listing.price > 0 && !listing.priceLabel.endsWith('/mo'))
                                  TextSpan(text: ' /mo', style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary.withValues(alpha: 0.8))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                displayLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!showProfile)
                        const SizedBox(width: 8),
                      if (!showProfile)
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: RichText(
                              text: TextSpan(
                                style: AppTheme.headline(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                                children: [
                                  if (listing.price > 0)
                                    const TextSpan(text: '₹'),
                                  TextSpan(text: listing.price > 0 ? listing.priceLabel.replaceFirst(RegExp(r'(?:Rs\.?|₹)\s*', caseSensitive: false), '') : listing.priceLabel),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _ProfileCardMedia extends StatelessWidget {
  final ListingModel listing;

  const _ProfileCardMedia({required this.listing});

  @override
  Widget build(BuildContext context) {
    final displayName = listing.ownerName.trim().isEmpty
        ? listing.title.trim()
        : listing.ownerName.trim();
    final initial = displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();
    final photoUrl = listing.ownerPhotoUrl.trim();

    if (photoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _ProfileFallback(initial: initial),
      );
    }

    return _ProfileFallback(initial: initial);
  }
}

class _ProfileFallback extends StatelessWidget {
  final String initial;

  const _ProfileFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentLavender,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTheme.headline(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  /// Skeleton placeholders while loading featured listings.
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          return Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFeaturedState extends StatelessWidget {
  /// Empty state shown when no featured listings exist.
  const _EmptyFeaturedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Text(
        'Featured verified homes will appear here once listings are available.',
        style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.6),
      ),
    );
  }
}
