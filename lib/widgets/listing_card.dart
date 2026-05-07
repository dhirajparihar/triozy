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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 10 : 12,
                isNarrow ? 12 : 14,
                isNarrow ? 10 : 12,
                isNarrow ? 12 : 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProfilePhoto(
                    photoUrl: listing.ownerPhotoUrl,
                    name: listing.ownerName,
                    size: isNarrow ? 104 : 128,
                  ),
                  SizedBox(width: isNarrow ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            fontSize: isNarrow ? 18 : 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MatchInfoRow(
                          icon: Icons.location_on,
                          text: listing.location,
                          fontSize: isNarrow ? 14 : 15,
                        ),
                        const SizedBox(height: 6),
                        _RentMatchRow(
                          rentText: '$rentLabel Rent',
                          matchText: '100% Match',
                          fontSize: isNarrow ? 14 : 15,
                        ),
                        const SizedBox(height: 6),
                        _MatchInfoRow(
                          icon: Icons.person_rounded,
                          text: preference.isEmpty
                              ? 'Looking for ${listing.propertyTypeLabel}'
                              : 'Looking for $preference',
                          fontSize: isNarrow ? 14 : 15,
                        ),
                        if (occupancy.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _MatchInfoRow(
                            icon: Icons.king_bed_rounded,
                            text: occupancy,
                            fontSize: isNarrow ? 14 : 15,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 10 : 12,
                vertical: isNarrow ? 10 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tap to view details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: isNarrow ? 38 : 44,
                      height: isNarrow ? 38 : 44,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_rounded,
                        color: AppColors.slate400,
                        size: isNarrow ? 18 : 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View',
                    style: AppTheme.body(
                      fontSize: isNarrow ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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

  String get _displayName {
    final name = listing.ownerName.trim();
    return name.isEmpty ? 'Triozy user' : name;
  }
}

class _MatchInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final double fontSize;

  const _MatchInfoRow({
    required this.icon,
    required this.text,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: fontSize + 5, color: AppColors.slate500),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
        ),
      ],
    );
  }
}

class _RentMatchRow extends StatelessWidget {
  final String rentText;
  final String matchText;
  final double fontSize;

  const _RentMatchRow({
    required this.rentText,
    required this.matchText,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.currency_rupee_rounded,
          size: fontSize + 5,
          color: AppColors.slate500,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            rentText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '|',
            style: AppTheme.body(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.slate500,
            ),
          ),
        ),
        Icon(
          Icons.extension_rounded,
          size: fontSize + 5,
          color: AppColors.slate500,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            matchText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
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
