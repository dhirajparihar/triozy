import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';

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

      if (!mounted) {
        return;
      }
      setState(() {
        _featured = featured;
        _savedIds = saved.map((listing) => listing.id).toSet();
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

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        children: [
          _WelcomeSection(firstName: firstName),
          const SizedBox(height: 24),
          _QuickActions(
            onFindRoomTap: () =>
                widget.onPropertyTypeSelected?.call(PropertyType.room),
            onFlatmatesTap: () =>
                widget.onPropertyTypeSelected?.call(PropertyType.flat),
            onMarketplaceTap: () =>
                widget.onPropertyTypeSelected?.call(PropertyType.item),
          ),
          const SizedBox(height: 30),
          _SectionHeader(
            title: 'Verified Homes for You',
            actionLabel: 'See all',
            onActionTap: widget.onExploreTapped,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const _HomeLoadingState()
          else if (_featured.isEmpty)
            const _EmptyFeaturedState()
          else
            SizedBox(
              height: 370,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final listing = _featured[index];
                  return SizedBox(
                    width: 324,
                    child: _FeaturedHomeCard(
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

  String _firstName() {
    final auth = FirebaseAuth.instance.currentUser;
    final raw = (auth?.displayName?.trim().isNotEmpty == true
            ? auth!.displayName!
            : auth?.email?.split('@').first.replaceAll(RegExp(r'[._]'), ' ')) ??
        '';
    if (raw.trim().isEmpty) {
      return 'there';
    }
    final part = raw.trim().split(' ').first;
    return part[0].toUpperCase() + part.substring(1);
  }
}

class _WelcomeSection extends StatelessWidget {
  final String firstName;

  const _WelcomeSection({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to your new city,\n$firstName!',
          style: AppTheme.headline(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            height: 1.18,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your relocation is on track. Let’s tackle the next steps.',
          style: AppTheme.body(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}


class _QuickActions extends StatelessWidget {
  final VoidCallback onFindRoomTap;
  final VoidCallback onFlatmatesTap;
  final VoidCallback onMarketplaceTap;

  const _QuickActions({
    required this.onFindRoomTap,
    required this.onFlatmatesTap,
    required this.onMarketplaceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PrimaryActionCard(
          icon: Icons.bed_rounded,
          title: 'Find a Room',
          subtitle: 'Browse 400+ verified listings',
          onTap: onFindRoomTap,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SecondaryActionCard(
                icon: Icons.groups_rounded,
                iconColor: AppColors.secondary,
                iconBackground: AppColors.secondaryContainer.withValues(
                  alpha: 0.18,
                ),
                title: 'Match Flatmates',
                subtitle: 'Find your vibe',
                onTap: onFlatmatesTap,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SecondaryActionCard(
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.primary,
                iconBackground: AppColors.primary.withValues(alpha: 0.08),
                title: 'Marketplace',
                subtitle: 'Furnish your space',
                onTap: onMarketplaceTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.onPrimary, size: 30),
                const SizedBox(height: 26),
                Text(
                  title,
                  style: AppTheme.headline(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: AppTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryFixedDim,
                        ),
                      ),
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.onPrimary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(
          color: AppColors.surfaceContainerLowest,
          radiusValue: 20,
          shadowAlpha: 0.045,
          blur: 20,
          offsetY: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 25),
            ),
            const Spacer(),
            Text(
              title,
              style: AppTheme.headline(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.headline(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionLabel,
                style: AppTheme.body(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedHomeCard extends StatelessWidget {
  final ListingModel listing;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const _FeaturedHomeCard({
    required this.listing,
    required this.isSaved,
    required this.onTap,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.cardDecoration(
          color: AppColors.surfaceContainerLowest,
          radiusValue: 22,
          shadowAlpha: 0.05,
          blur: 24,
          offsetY: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    listing.imageUrls.isEmpty
                        ? Container(
                            color: AppColors.surfaceContainerHigh,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.home_work_outlined,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: listing.imageUrls.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.surfaceContainerHigh,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.home_work_outlined,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                          ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withValues(
                            alpha: 0.96,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 15,
                              color: AppColors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Verified',
                              style: AppTheme.body(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: onSaveTap,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest.withValues(
                              alpha: 0.86,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSaved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isSaved
                                ? AppColors.tertiary
                                : AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: AppTheme.headline(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            children: [
                              TextSpan(text: listing.priceLabel),
                              TextSpan(
                                text: listing.price > 0 ? ' /mo' : '',
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
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_border_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _ratingLabel(listing),
                            style: AppTheme.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.slate500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate500,
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
      ),
    );
  }

  String _ratingLabel(ListingModel listing) {
    final highlightsCount = listing.highlights.isEmpty ? 0 : listing.highlights.length;
    final rating = (4.6 + (highlightsCount.clamp(0, 4) * 0.1)).clamp(4.6, 4.9);
    return rating.toStringAsFixed(1);
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 370,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (_, index) {
          return Container(
            width: 324,
            decoration: AppTheme.cardDecoration(
              color: AppColors.surfaceContainerLowest,
              radiusValue: 22,
              shadowAlpha: 0.04,
              blur: 18,
              offsetY: 8,
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
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 20,
        shadowAlpha: 0.04,
        blur: 18,
        offsetY: 8,
      ),
      child: Text(
        'Featured verified homes will appear here once listings are available.',
        style: AppTheme.body(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
          height: 1.6,
        ),
      ),
    );
  }
}
