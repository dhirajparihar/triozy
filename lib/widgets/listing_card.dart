import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/listing_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shared listing card for housing, marketplace, and requirement posts.
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
    // Compute card sizing from screen width and compact mode.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactScreen = screenWidth < 380;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = isCompactScreen || width < 360;
        final imageHeight = compact
            ? (isNarrow ? 108.0 : 120.0)
            : (width < 380 ? 170.0 : 184.0);
        final horizontalPadding = isNarrow ? 12.0 : 16.0;
        final verticalPadding = compact ? (isNarrow ? 12.0 : 14.0) : 16.0;
        final titleSize = compact ? (isNarrow ? 13.0 : 14.0) : 16.0;
        final priceSize = compact ? (isNarrow ? 18.0 : 20.0) : 22.0;
        final maxHighlights = compact ? (isNarrow ? 1 : 2) : 3;
        // Trim highlights to keep the card tidy.
        final highlights = listing.highlights.take(maxHighlights).toList();

        if (listing.isRequirementPost || listing.needsRoommate) {
          // Render the flatmate/requirement variant for people-to-people posts.
          return _FlatmateCard(
            listing: listing,
            onTap: onTap,
            onSaveTap: onSaveTap,
            isSaved: isSaved,
            compact: compact,
          );
        }

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
                      child: ClipRRect(
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
                                  errorWidget: (_, _, _) => _imageFallback(),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      // Tag the card with the property type label.
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
                            // Highlight chips for quick-scannable features.
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

class _FlatmateCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final bool isSaved;
  final bool compact;

  const _FlatmateCard({
    required this.listing,
    required this.onTap,
    this.onSaveTap,
    this.isSaved = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Compact variant with avatar + quick details for roommate posts.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactScreen = screenWidth < 380;
    final isNarrow = isCompactScreen || compact;

    final displayName = listing.ownerName.trim().isEmpty ? 'User' : listing.ownerName.trim();
    final isLooking = listing.isRequirementPost;
    
    // Determine dynamic avatar background color based on ID
    final colors = [
      AppColors.pastelPurple,
      AppColors.pastelPeach,
      AppColors.pastelMint,
    ];
    final avatarBgColor = colors[listing.id.hashCode % colors.length];

    // Badge configuration
    final typeBadgeColor = listing.propertyTypeLabel.toLowerCase() == 'flat' 
      ? const Color(0xFFFFF2EC) 
      : const Color(0xFFF0F5FF);
    final typeBadgeTextColor = listing.propertyTypeLabel.toLowerCase() == 'flat' 
      ? const Color(0xFFF97316) 
      : const Color(0xFF3B82F6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        decoration: AppTheme.cardDecoration(
          color: AppColors.surfaceContainerLowest,
          radiusValue: isNarrow ? 16 : 20,
          shadowAlpha: 0.05,
          blur: 24,
          offsetY: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Avatar & Type Badge
            Column(
              children: [
                Container(
                  width: isNarrow ? 64 : 80,
                  height: isNarrow ? 64 : 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: avatarBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: listing.ownerPhotoUrl.isEmpty
                          ? Center(
                              child: Text(
                                displayName[0].toUpperCase(),
                                style: AppTheme.headline(fontSize: isNarrow ? 24 : 28, color: AppColors.primary),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: listing.ownerPhotoUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Center(
                                child: Text(
                                  displayName[0].toUpperCase(),
                                  style: AppTheme.headline(fontSize: isNarrow ? 24 : 28, color: AppColors.primary),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: isNarrow ? 8 : 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16, vertical: isNarrow ? 4 : 6),
                  decoration: BoxDecoration(
                    color: typeBadgeColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    listing.propertyTypeLabel,
                    style: AppTheme.label(
                      fontSize: isNarrow ? 10 : 12,
                      fontWeight: FontWeight.w800,
                      color: typeBadgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: isNarrow ? 12 : 16),
            // Right Column: Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headline(
                            fontSize: isNarrow ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (onSaveTap != null)
                        GestureDetector(
                          onTap: onSaveTap,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isSaved ? AppColors.tertiary : AppColors.textPrimary,
                                size: isNarrow ? 20 : 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                    SizedBox(height: isNarrow ? 2 : 4),
                  Row(
                    children: [
                        Icon(Icons.person_outline_rounded, size: isNarrow ? 12 : 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                          '${listing.requirementDetails?.genderPreference.isNotEmpty == true ? listing.requirementDetails!.genderPreference : 'Male'} • ',
                          style: AppTheme.body(fontSize: isNarrow ? 11 : 12, color: AppColors.textSecondary),
                      ),
                        Icon(Icons.work_outline_rounded, size: isNarrow ? 12 : 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Professional',
                            style: AppTheme.body(fontSize: isNarrow ? 11 : 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                    SizedBox(height: isNarrow ? 4 : 6),
                  Row(
                    children: [
                        Icon(Icons.location_on_outlined, size: isNarrow ? 12 : 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(fontSize: isNarrow ? 11 : 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                    SizedBox(height: isNarrow ? 8 : 12),
                  Container(
                      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 10, vertical: isNarrow ? 4 : 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.currency_rupee_rounded, size: isNarrow ? 12 : 14, color: AppColors.primary),
                          SizedBox(width: isNarrow ? 2 : 4),
                        Text(
                          isLooking ? 'Up to ₹${listing.price.toInt()}' : '₹${listing.price.toInt()}',
                            style: AppTheme.label(fontSize: isNarrow ? 12 : 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  /// Chip-like label used for property type and highlights.
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
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppTheme.radius(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: isCompact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
