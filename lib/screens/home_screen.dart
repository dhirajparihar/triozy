

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'housing_entry_screen.dart';
import 'listing_detail_screen.dart';
import 'list_property_screen.dart';
import 'location_search_screen.dart';
import 'pg_listing_form_screen.dart';

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

class HomeScreenState extends State<HomeScreen> {
  List<ListingModel> _featured = [];
  Set<String> _savedIds = <String>{};
  bool _loading = true;
  bool _hasPublishedRequirement = false;
  bool _hasPostedHousingListing = false;
  String? _selectedLocationAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> refreshFromShell() => _loadData();

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    try {
      final featured = await db.getFeaturedListings(
        type: ListingType.housing,
        limit: 6,
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
        _featured = featured;
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

  Future<void> _openFlatmates() async {
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListPropertyScreen()),
    );
  }

  Future<void> _openLocationSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 16.0 : 20.0;
    final cardHeight = isCompact ? 265.0 : 280.0;
    final cardWidth = isCompact ? 180.0 : 200.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
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
          _SectionHeader(
            title: 'Recommended for you',
            actionLabel: 'See all',
            onActionTap: widget.onExploreTapped,
          ),
          SizedBox(height: isCompact ? 14 : 16),
          if (_loading)
            const _HomeLoadingState()
          else if (_featured.isEmpty)
            const _EmptyFeaturedState()
          else
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _featured.length,
                separatorBuilder: (_, _) => SizedBox(width: isCompact ? 12 : 14),
                itemBuilder: (context, index) {
                  final listing = _featured[index];
                  return SizedBox(
                    width: cardWidth,
                    child: FeaturedListingCard(
                      listing: listing,
                      isSaved: _savedIds.contains(listing.id),
                      onTap: () => _openListing(listing),
                      onSaveTap: () => _toggleSave(listing.id),
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
              padding: EdgeInsets.only(left: isCompact ? 16 : 20, right: 6, top: 6, bottom: 6),
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
                    child: selectedLocation != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              selectedLocation!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              'Search city or locality',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                  Container(
                    width: isCompact ? 42 : 46,
                    height: isCompact ? 42 : 46,
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
                      size: isCompact ? 20 : 22,
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
      padding: const EdgeInsets.symmetric(vertical: 20),
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
              title: 'Daily Help',
              subtitle: 'Services',
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
    final itemWidth = isCompact ? 80.0 : 90.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompact ? 52 : 58,
              height: isCompact ? 52 : 58,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: isCompact ? 24 : 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                fontSize: isCompact ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                fontSize: isCompact ? 8 : 9,
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
  final ListingModel listing;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const FeaturedListingCard({
    super.key,
    required this.listing,
    required this.isSaved,
    required this.onTap,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = listing.propertyType == PropertyType.pg ? 'PG'
        : listing.propertyType == PropertyType.flat ? 'Flatmate'
        : listing.propertyType == PropertyType.room ? 'Room' : 'Item';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    listing.imageUrls.isEmpty
                        ? Container(
                            color: AppColors.accentLavender,
                            alignment: Alignment.center,
                            child: Icon(Icons.home_work_outlined,
                              color: AppColors.primary.withValues(alpha: 0.4), size: 36),
                          )
                        : CachedNetworkImage(
                            imageUrl: listing.imageUrls.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.accentLavender,
                              alignment: Alignment.center,
                              child: Icon(Icons.home_work_outlined,
                                color: AppColors.primary.withValues(alpha: 0.4), size: 36),
                            ),
                          ),
                    Positioned(
                      bottom: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(typeLabel,
                          style: AppTheme.body(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: onSaveTap,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isSaved ? AppColors.tertiary : AppColors.textSecondary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Expanded(child: Text(listing.location,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
                  ]),
                  const SizedBox(height: 6),
                  RichText(text: TextSpan(
                    style: AppTheme.headline(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    children: [
                      TextSpan(text: listing.priceLabel),
                      TextSpan(text: listing.price > 0 ? ' /month' : '',
                        style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    ],
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
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
