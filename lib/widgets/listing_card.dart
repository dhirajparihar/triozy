import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/listing_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final bool isSaved;
  final bool compact;

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onSaveTap,
    this.isSaved = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 360;
        if (listing.isRequirementPost) {
          return _RequirementListingCard(
            listing: listing,
            onTap: onTap,
            isNarrow: isNarrow,
          );
        }

        final imageHeight = compact
            ? (isNarrow ? 108.0 : 120.0)
            : (width < 380 ? 166.0 : 180.0);
        final horizontalPadding = isNarrow ? 12.0 : 14.0;
        final verticalPadding = compact ? (isNarrow ? 12.0 : 14.0) : 16.0;
        final titleSize = compact ? (isNarrow ? 13.0 : 14.0) : 16.0;
        final priceSize = compact ? (isNarrow ? 18.0 : 20.0) : 22.0;
        final maxHighlights = compact ? (isNarrow ? 1 : 2) : 3;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: listing.imageUrls.isEmpty
                            ? _imageFallback()
                            : CachedNetworkImage(
                                imageUrl: listing.imageUrls.first,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => _imageFallback(),
                              ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Badge(
                            label: listing.propertyTypeLabel,
                            background: Colors.white.withValues(alpha: 0.92),
                            foreground: AppColors.primary,
                          ),
                          if (listing.isRequirementPost) ...[
                            const SizedBox(height: 6),
                            _Badge(
                              label: listing.purposeLabel,
                              background: AppColors.primary.withValues(
                                alpha: 0.92,
                              ),
                              foreground: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onSaveTap != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: GestureDetector(
                          onTap: onSaveTap,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSaved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border,
                              color: isSaved
                                  ? AppColors.error
                                  : AppColors.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        listing.priceLabel,
                        style: AppTheme.headline(
                          fontSize: priceSize,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing.title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.slate500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (listing.highlights.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: listing.highlights.take(maxHighlights).map((
                            highlight,
                          ) {
                            return _Badge(
                              label: highlight,
                              background: AppColors.blue50,
                              foreground: AppColors.blue700,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Center(
        child: Icon(
          Icons.home_work_rounded,
          size: 40,
          color: AppColors.outline,
        ),
      ),
    );
  }
}

class _RequirementListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  final bool isNarrow;

  const _RequirementListingCard({
    required this.listing,
    required this.onTap,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final details = listing.requirementDetails;
    final preference = (listing.genderPreference ?? '').trim();
    final occupancy = (details?.occupancy ?? '').trim();
    final rentLabel = listing.priceLabel
        .replaceFirst('Up to ', '')
        .replaceFirst('Rs ', '');

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final useStackedHeader = cardWidth < 270;
        final fillsHeight = constraints.hasBoundedHeight;
        final isCompactHeight = fillsHeight && constraints.maxHeight <= 380;
        final avatarSize = isCompactHeight
            ? (cardWidth < 320 ? 62.0 : 70.0)
            : (cardWidth < 320 ? 74.0 : 86.0);
        final topPadding = isCompactHeight
            ? (isNarrow ? 12.0 : 14.0)
            : (isNarrow ? 14.0 : 18.0);
        final titleGap = isCompactHeight ? 10.0 : 14.0;
        final metaGap = isCompactHeight ? 12.0 : 16.0;
        final chipSpacing = isCompactHeight ? 6.0 : 8.0;
        final chipLimit = isCompactHeight ? 3 : 4;

        final infoChips = <Widget>[
          _InfoChip(
            icon: Icons.currency_rupee_rounded,
            label: '$rentLabel budget',
            compact: isCompactHeight,
          ),
          _InfoChip(
            icon: Icons.person_rounded,
            label: preference.isEmpty
                ? 'Needs ${listing.propertyTypeLabel}'
                : preference,
            compact: isCompactHeight,
          ),
          if (occupancy.isNotEmpty)
            _InfoChip(
              icon: Icons.king_bed_rounded,
              label: occupancy,
              compact: isCompactHeight,
            ),
          const _InfoChip(
            icon: Icons.extension_rounded,
            label: '100% match',
          ),
        ];

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            height: fillsHeight ? constraints.maxHeight : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (fillsHeight)
                    Expanded(
                      child: ClipRect(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: _RequirementCardTop(
                            listing: listing,
                            displayName: _displayName,
                            location: listing.location,
                            isNarrow: isNarrow,
                            useStackedHeader: useStackedHeader,
                            avatarSize: avatarSize,
                            topPadding: topPadding,
                            titleGap: titleGap,
                            metaGap: metaGap,
                            chipSpacing: chipSpacing,
                            compact: isCompactHeight,
                            chips: infoChips.take(chipLimit).toList(),
                          ),
                        ),
                      ),
                    )
                  else
                    _RequirementCardTop(
                      listing: listing,
                      displayName: _displayName,
                      location: listing.location,
                      isNarrow: isNarrow,
                      useStackedHeader: useStackedHeader,
                      avatarSize: avatarSize,
                      topPadding: topPadding,
                      titleGap: titleGap,
                      metaGap: metaGap,
                      chipSpacing: chipSpacing,
                      compact: isCompactHeight,
                      chips: infoChips,
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isNarrow ? 12 : 16,
                      isCompactHeight ? 10 : 14,
                      isNarrow ? 12 : 16,
                      isCompactHeight ? 12 : 16,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 12 : 14,
                        vertical: isCompactHeight ? 10 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View profile details',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body(
                                    fontSize: isCompactHeight
                                        ? 13
                                        : (isNarrow ? 13 : 14),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                if (!isCompactHeight) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Open listing and start the conversation.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: isCompactHeight ? 40 : (isNarrow ? 42 : 46),
                            height: isCompactHeight
                                ? 40
                                : (isNarrow ? 42 : 46),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _displayName {
    final name = listing.ownerName.trim();
    return name.isEmpty ? 'Triozy user' : name;
  }
}

class _RequirementCardTop extends StatelessWidget {
  final ListingModel listing;
  final String displayName;
  final String location;
  final bool isNarrow;
  final bool useStackedHeader;
  final double avatarSize;
  final double topPadding;
  final double titleGap;
  final double metaGap;
  final double chipSpacing;
  final bool compact;
  final List<Widget> chips;

  const _RequirementCardTop({
    required this.listing,
    required this.displayName,
    required this.location,
    required this.isNarrow,
    required this.useStackedHeader,
    required this.avatarSize,
    required this.topPadding,
    required this.titleGap,
    required this.metaGap,
    required this.chipSpacing,
    required this.compact,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        topPadding,
        topPadding,
        topPadding,
        compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blue50,
            AppColors.primaryFixed.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Badge(
            label: listing.purposeLabel,
            background: Colors.white.withValues(alpha: 0.94),
            foreground: AppColors.primary,
          ),
          SizedBox(height: compact ? 10 : 14),
          if (useStackedHeader)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfilePhoto(
                  photoUrl: listing.ownerPhotoUrl,
                  name: listing.ownerName,
                  size: avatarSize,
                ),
                SizedBox(height: compact ? 10 : 14),
                _RequirementIdentity(
                  name: displayName,
                  location: location,
                  isNarrow: isNarrow,
                  compact: compact,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfilePhoto(
                  photoUrl: listing.ownerPhotoUrl,
                  name: listing.ownerName,
                  size: avatarSize,
                ),
                SizedBox(width: compact ? 12 : 16),
                Expanded(
                  child: _RequirementIdentity(
                    name: displayName,
                    location: location,
                    isNarrow: isNarrow,
                    compact: compact,
                  ),
                ),
              ],
            ),
          SizedBox(height: metaGap),
          Text(
            listing.title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: compact ? 13 : (isNarrow ? 14 : 15),
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.35,
            ),
          ),
          SizedBox(height: titleGap),
          Wrap(
            spacing: chipSpacing,
            runSpacing: chipSpacing,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _RequirementIdentity extends StatelessWidget {
  final String name;
  final String location;
  final bool isNarrow;
  final bool compact;

  const _RequirementIdentity({
    required this.name,
    required this.location,
    required this.isNarrow,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.body(
            fontSize: compact ? (isNarrow ? 16 : 18) : (isNarrow ? 18 : 21),
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: compact ? 14 : 16,
              color: AppColors.slate500,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  fontSize: compact ? 12 : (isNarrow ? 13 : 14),
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: AppColors.primary),
          SizedBox(width: compact ? 4 : 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 116 : 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  final String photoUrl;
  final String name;
  final double size;

  const _ProfilePhoto({
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
            ? _fallback(initial)
            : CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(initial),
              ),
      ),
    );
  }

  Widget _fallback(String initial) {
    return Container(
      color: AppColors.blue50,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTheme.headline(fontSize: 22, color: AppColors.primary),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
