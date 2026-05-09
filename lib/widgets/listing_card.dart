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
        final imageHeight = compact
            ? (isNarrow ? 108.0 : 120.0)
            : (width < 380 ? 170.0 : 184.0);
        final horizontalPadding = isNarrow ? 12.0 : 16.0;
        final verticalPadding = compact ? (isNarrow ? 12.0 : 14.0) : 16.0;
        final titleSize = compact ? (isNarrow ? 13.0 : 14.0) : 16.0;
        final priceSize = compact ? (isNarrow ? 18.0 : 20.0) : 22.0;
        final maxHighlights = compact ? (isNarrow ? 1 : 2) : 3;
        final highlights = listing.isRequirementPost
            ? _requirementHighlights(limit: maxHighlights)
            : listing.highlights.take(maxHighlights).toList();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: AppTheme.cardDecoration(
              color: AppColors.surfaceContainerLowest,
              radiusValue: 20,
              shadowAlpha: 0.08,
              blur: 26,
              offsetY: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: listing.isRequirementPost
                          ? _RequirementHeader(
                              listing: listing,
                              isNarrow: isNarrow,
                              compact: compact,
                            )
                          : ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: SizedBox(
                                height: imageHeight,
                                width: double.infinity,
                                child: listing.imageUrls.isEmpty
                                    ? _imageFallback()
                                    : CachedNetworkImage(
                                        imageUrl: listing.imageUrls.first,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) =>
                                            _imageFallback(),
                                      ),
                              ),
                            ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(
                        label: listing.propertyTypeLabel,
                        background: AppColors.surfaceContainerLowest.withValues(
                          alpha: 0.94,
                        ),
                        foreground: AppColors.primary,
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
                              color: AppColors.surfaceContainerLowest
                                  .withValues(alpha: 0.96),
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.shadow(
                                blur: 12,
                                offsetY: 4,
                                alpha: 0.05,
                              ),
                            ),
                            child: Icon(
                              isSaved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isSaved
                                  ? AppColors.tertiary
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
                          fontWeight: FontWeight.w700,
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
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (highlights.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: highlights.map((highlight) {
                            return _Badge(
                              label: highlight,
                              background: AppColors.secondaryContainer
                                  .withValues(alpha: 0.7),
                              foreground: AppColors.secondary,
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

  List<String> _requirementHighlights({required int limit}) {
    final details = listing.requirementDetails;
    final preference = (listing.genderPreference ?? '').trim();
    final occupancy = (details?.occupancy ?? '').trim();
    final highlights = <String>[];

    if (listing.price > 0) {
      final budget = listing.price % 1 == 0
          ? listing.price.toInt().toString()
          : listing.price.toStringAsFixed(0);
      highlights.add('Rs $budget budget');
    }
    if (preference.isNotEmpty) {
      highlights.add(preference);
    }
    if (occupancy.isNotEmpty) {
      highlights.add(occupancy);
    }

    return highlights.take(limit).toList();
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

class _RequirementHeader extends StatelessWidget {
  final ListingModel listing;
  final bool isNarrow;
  final bool compact;

  const _RequirementHeader({
    required this.listing,
    required this.isNarrow,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 12.0 : (isNarrow ? 14.0 : 16.0);
    final bottomPadding = compact ? 12.0 : 16.0;
    final avatarSize = compact ? 54.0 : (isNarrow ? 64.0 : 72.0);
    final displayName = listing.ownerName.trim().isEmpty
        ? 'Triozy user'
        : listing.ownerName.trim();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          52,
          horizontalPadding,
          bottomPadding,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceContainerLow,
              AppColors.secondaryContainer.withValues(alpha: 0.78),
            ],
          ),
        ),
        child: Row(
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
                location: listing.location,
                isNarrow: isNarrow,
                compact: compact,
              ),
            ),
          ],
        ),
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
              color: AppColors.secondary,
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
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ],
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
      color: AppColors.surfaceContainerLowest,
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
        borderRadius: AppTheme.radius(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
