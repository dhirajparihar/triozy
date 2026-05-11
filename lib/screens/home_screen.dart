import 'dart:async';

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
import 'requirement_form_screen.dart';

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

  Future<void> _openRoomRequirement() async {
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RequirementFormScreen()),
    );
    if (published == true && mounted) {
      _loadData();
    }
  }

  void _openPgListings() {
    widget.onPropertyTypeSelected?.call(PropertyType.pg);
  }

  Future<void> _openFlatmates() async {
    if (_hasPostedHousingListing) {
      widget.onPropertyTypeSelected?.call(PropertyType.flat);
      return;
    }

    final route = await HousingEntryScreen.buildRoute();
    if (!mounted) {
      return;
    }
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        children: [
          _HeroSection(
            onSearchTap: widget.onSearchTapped ?? widget.onExploreTapped,
          ),
          const SizedBox(height: 12),
          _QuickActions(
            hasPublishedRequirement: _hasPublishedRequirement,
            onFindRoomTap:
                _hasPublishedRequirement ? _openPgListings : _openRoomRequirement,
            onFlatmatesTap: _openFlatmates,
            onMarketplaceTap: () =>
                widget.onPropertyTypeSelected?.call(PropertyType.item),
            onAllServicesTap: widget.onSearchTapped ?? widget.onExploreTapped,
          ),
          const SizedBox(height: 30),
          _SectionHeader(
            title: 'Explore',
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

}

class _HeroSection extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const _HeroSection({this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F9FF), Color(0xFFEAF1FF)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move to a new city without starting from zero.',
            style: AppTheme.headline(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: _AnimatedSearchPrompt()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSearchPrompt extends StatefulWidget {
  const _AnimatedSearchPrompt();

  @override
  State<_AnimatedSearchPrompt> createState() => _AnimatedSearchPromptState();
}

class _AnimatedSearchPromptState extends State<_AnimatedSearchPrompt> {
  static const List<String> _terms = [
    'PGs',
    'rooms',
    'flatmates',
    'essentials',
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _index = (_index + 1) % _terms.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.body(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.onSurfaceVariant,
      height: 1.45,
    );

    return Row(
      children: [
        Text('Search for ', style: style),
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.45),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: Text(
              _terms[_index],
              key: ValueKey(_terms[_index]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}


class _QuickActions extends StatelessWidget {
  final bool hasPublishedRequirement;
  final VoidCallback onFindRoomTap;
  final VoidCallback onFlatmatesTap;
  final VoidCallback onMarketplaceTap;
  final VoidCallback? onAllServicesTap;

  const _QuickActions({
    required this.hasPublishedRequirement,
    required this.onFindRoomTap,
    required this.onFlatmatesTap,
    required this.onMarketplaceTap,
    this.onAllServicesTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    final gap = compact ? 10.0 : 12.0;
    final shortCardHeight = compact ? 108.0 : 116.0;
    final tallCardHeight = compact ? 158.0 : 170.0;
    final tallestCardHeight = compact ? 174.0 : 188.0;
    final allServicesHeight = compact ? 94.0 : 102.0;
    final eyebrowSize = compact ? 14.0 : 15.0;
    final titleSize = compact ? 17.0 : 18.0;
    final allServicesTitleSize = compact ? 20.0 : 21.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your need',
          style: AppTheme.headline(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF42526A),
            height: 1.15,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _ServiceActionCard(
                    height: shortCardHeight,
                    eyebrow: hasPublishedRequirement
                        ? 'Looking for'
                        : 'Publish Requirement',
                    title: hasPublishedRequirement ? 'PG' : 'Room',
                    icon: Icons.meeting_room_rounded,
                    iconColor: const Color(0xFF3A86FF),
                    onTap: onFindRoomTap,
                    alignIconBottom: true,
                    compact: compact,
                    eyebrowSize: eyebrowSize,
                    titleSize: titleSize,
                  ),
                  SizedBox(height: gap),
                  _ServiceActionCard(
                    height: tallCardHeight,
                    eyebrow: 'Your daily essentials',
                    title: 'Marketplace',
                    icon: Icons.shopping_bag_rounded,
                    iconColor: const Color(0xFF3A86FF),
                    onTap: onMarketplaceTap,
                    alignIconBottom: true,
                    compact: compact,
                    eyebrowSize: eyebrowSize,
                    titleSize: titleSize,
                  ),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  _ServiceActionCard(
                    height: tallestCardHeight,
                    eyebrow: 'Match',
                    title: 'Flatmates',
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF3A86FF),
                    onTap: onFlatmatesTap,
                    alignIconBottom: true,
                    compact: compact,
                    eyebrowSize: eyebrowSize,
                    titleSize: titleSize,
                  ),
                  SizedBox(height: gap),
                  _ServiceActionCard(
                    height: allServicesHeight,
                    title: 'All\nServices',
                    icon: Icons.apps_rounded,
                    iconColor: const Color(0xFF3A86FF),
                    onTap: onAllServicesTap,
                    showIcon: false,
                    compact: compact,
                    titleSize: allServicesTitleSize,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceActionCard extends StatelessWidget {
  final double height;
  final String? eyebrow;
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool alignIconBottom;
  final bool showIcon;
  final bool compact;
  final double? eyebrowSize;
  final double? titleSize;

  const _ServiceActionCard({
    required this.height,
    this.eyebrow,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.alignIconBottom = false,
    this.showIcon = true,
    this.compact = false,
    this.eyebrowSize,
    this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = alignIconBottom
        ? (compact ? 60.0 : 68.0)
        : (compact ? 46.0 : 50.0);
    final iconGlyphSize = alignIconBottom
        ? (compact ? 30.0 : 34.0)
        : (compact ? 24.0 : 26.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(compact ? 20 : 24),
          border: Border.all(
            color: const Color(0xFFE5E7EB).withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14213D).withValues(alpha: 0.035),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (showIcon)
              Positioned(
                right: alignIconBottom ? -6 : 2,
                bottom: alignIconBottom ? -4 : null,
                top: alignIconBottom ? null : 6,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: iconGlyphSize,
                  ),
                ),
              ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: showIcon && !alignIconBottom ? 46 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          eyebrow!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            fontSize: eyebrowSize ?? 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF536178),
                            height: 1.22,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headline(
                          fontSize: titleSize ?? 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          height: 1.08,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
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
