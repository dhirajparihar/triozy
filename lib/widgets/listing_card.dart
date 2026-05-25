import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../models/chat_model.dart';
import '../screens/chat_detail_screen.dart';

import '../models/listing_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ListingCard extends StatefulWidget {
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
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactScreen = screenWidth < 380;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = isCompactScreen || width < 360;
        final imageHeight = widget.compact
            ? (isNarrow ? 108.0 : 120.0)
            : (width < 380 ? 170.0 : 184.0);
        final horizontalPadding = isNarrow ? 12.0 : 16.0;
        final verticalPadding = widget.compact ? (isNarrow ? 12.0 : 14.0) : 16.0;
        final titleSize = widget.compact ? (isNarrow ? 13.0 : 14.0) : 16.0;
        final priceSize = widget.compact ? (isNarrow ? 18.0 : 20.0) : 22.0;
        final maxHighlights = widget.compact ? (isNarrow ? 1 : 2) : 3;
        final highlights = listing.highlights.take(maxHighlights).toList();

        if (listing.isRequirementPost ||
            (listing.needsRoommate && listing.propertyType != PropertyType.room)) {
          return _FlatmateCard(
            listing: listing,
            onTap: widget.onTap,
            onSaveTap: widget.onSaveTap,
            isSaved: widget.isSaved,
            compact: widget.compact,
          );
        }

        final useAirbnbStyle = listing.type == ListingType.housing;

        if (useAirbnbStyle) {
          final loc = listing.location.trim();
          final String displayTitle;
          if (listing.propertyType == PropertyType.room) {
            final gender = (listing.genderPreference ?? '').trim();
            displayTitle = gender.isEmpty ||
                    gender.toLowerCase() == 'anyone' ||
                    gender.toLowerCase() == 'any'
                ? (loc.isNotEmpty ? 'Roommate needed in $loc' : 'Roommate needed')
                : (loc.isNotEmpty ? '$gender roommate needed in $loc' : '$gender roommate needed');
          } else {
            displayTitle = listing.title;
          }

          final detailsList = <String>[];
          if (listing.furnishing != null && listing.furnishing!.trim().isNotEmpty) {
            detailsList.add(listing.furnishing!.trim());
          }
          if (listing.highlights.isNotEmpty) {
            detailsList.addAll(
              listing.highlights
                  .where((h) =>
                      !h.contains('Looking for') &&
                      !h.contains('Mobile') &&
                      !h.contains('Chat'))
                  .take(6),
            );
          }
          final defaultLabel = listing.propertyType == PropertyType.room
              ? '1 room'
              : listing.propertyTypeLabel;
          final amenitiesText = detailsList.isEmpty ? defaultLabel : detailsList.join(' · ');

          final detailsParts = <String>[];
          if (loc.isNotEmpty) detailsParts.add(loc);
          detailsParts.add(amenitiesText);
          final detailsText = detailsParts.join(' | ');

          return GestureDetector(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: listing.imageUrls.isEmpty
                        ? _imageFallback()
                        : Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: listing.imageUrls.length,
                                onPageChanged: (i) => setState(() => _pageIndex = i),
                                itemBuilder: (context, index) {
                                  final url = listing.imageUrls[index];
                                  if (url.startsWith('assets/')) {
                                    return Image.asset(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, __, ___) => _imageFallback(),
                                    );
                                  }
                                  return CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorWidget: (_, __, ___) => _imageFallback(),
                                  );
                                },
                              ),
                              Positioned(
                                left: 12,
                                top: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    listing.propertyTypeLabel,
                                    style: AppTheme.label(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.onSaveTap != null)
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: GestureDetector(
                                    onTap: widget.onSaveTap,
                                    behavior: HitTestBehavior.opaque,
                                    child: Icon(
                                      widget.isSaved
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: widget.isSaved
                                          ? const Color(0xFFFF385C)
                                          : Colors.white,
                                      size: 26,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 6.0,
                                          color: Colors.black38,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (listing.imageUrls.length > 1)
                                Positioned(
                                  bottom: 12,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      listing.imageUrls.length,
                                      (i) {
                                        final selected = i == _pageIndex;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: selected ? 7 : 5,
                                          height: selected ? 7 : 5,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headline(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detailsText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '₹${listing.price.toInt().toString().replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  )}',
                              style: AppTheme.headline(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ).copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ' / month',
                              style: AppTheme.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: widget.onTap,
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
                // Image carousel
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: listing.imageUrls.isEmpty
                        ? _imageFallback()
                        : Stack(
                            children: [
                              // Images
                              PageView.builder(
                                controller: _pageController,
                                itemCount: listing.imageUrls.length,
                                onPageChanged: (i) => setState(() => _pageIndex = i),
                                itemBuilder: (context, index) {
                                  final url = listing.imageUrls[index];
                                  if (url.startsWith('assets/')) {
                                    return Image.asset(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: imageHeight,
                                      errorBuilder: (_, __, ___) => _imageFallback(),
                                    );
                                  }
                                  return CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: imageHeight,
                                    errorWidget: (_, __, ___) => _imageFallback(),
                                  );
                                },
                              ),

                              // Top-left badge overlay
                              Positioned(
                                left: 12,
                                top: 12,
                                child: listing.isFeatured
                                    ? _Badge(
                                        label: 'Superhost',
                                        background: AppColors.surfaceContainerLowest
                                            .withValues(alpha: 0.9),
                                        foreground: AppColors.onSurface,
                                      )
                                    : _Badge(
                                        label: listing.propertyTypeLabel,
                                        background: AppColors.surfaceContainerLowest
                                            .withValues(alpha: 0.94),
                                        foreground: AppColors.primary,
                                      ),
                              ),

                              // Top-right save (heart) overlay
                              if (widget.onSaveTap != null)
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: GestureDetector(
                                    onTap: widget.onSaveTap,
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLowest
                                            .withValues(alpha: 0.96),
                                        shape: BoxShape.circle,
                                        boxShadow: AppTheme.shadow(
                                            blur: 12, offsetY: 4, alpha: 0.05),
                                      ),
                                      child: Icon(
                                        widget.isSaved
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: widget.isSaved ? AppColors.tertiary : AppColors.onSurface,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),

                              // Dots indicator bottom center
                              if (listing.imageUrls.length > 1)
                                Positioned(
                                  bottom: 10,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      listing.imageUrls.length,
                                      (i) {
                                        final selected = i == _pageIndex;
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          width: selected ? 10 : 8,
                                          height: selected ? 10 : 8,
                                          decoration: BoxDecoration(
                                            color: selected ? Colors.white : Colors.white54,
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                

                // Textual details
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, verticalPadding, horizontalPadding, verticalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        listing.priceLabel,
                        style: AppTheme.headline(
                            fontSize: priceSize,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing.title,
                        maxLines: widget.compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                            fontSize: titleSize, fontWeight: FontWeight.w700, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (context) {
                        final loc = listing.location.trim();
                        final amenities = highlights;
                        final detailsParts = <String>[];
                        if (loc.isNotEmpty) detailsParts.add(loc);
                        if (amenities.isNotEmpty) detailsParts.add(amenities.join(' · '));
                        final detailsText = detailsParts.join(' | ');

                        return Text(
                          detailsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        );
                      }),
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

class _FlatmateCard extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final bool isSaved;
  final bool compact;

  const _FlatmateCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onSaveTap,
    this.isSaved = false,
    this.compact = false,
  });

  @override
  State<_FlatmateCard> createState() => _FlatmateCardState();
}

class _FlatmateCardState extends State<_FlatmateCard> {
  String? _ownerPhone;

  @override
  void initState() {
    super.initState();
    _loadOwnerPhone();
  }

  Future<void> _loadOwnerPhone() async {
    if (widget.listing.phonePublic != true) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.listing.ownerId)
          .get();
      if (!mounted) return;
      final phone = userDoc.data()?['phoneNumber'] as String?;
      if (phone != null && phone.isNotEmpty) {
        setState(() => _ownerPhone = phone);
      }
    } catch (_) {}
  }

  Future<void> _launchPhone() async {
    if (_ownerPhone == null) return;
    final uri = Uri.parse('tel:$_ownerPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startChat() async {
    final listing = widget.listing;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to contact the listing owner')),
      );
      return;
    }
    if (currentUser.uid == listing.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your listing')),
      );
      return;
    }

    try {
      final conversationId = await context.read<ChatProvider>().createOrGetChat(
        otherUserId: listing.ownerId,
        chatType: listing.isMarketplacePost
            ? ChatType.marketplace.value
            : ChatType.listing.value,
        referenceId: listing.id,
        listingTitle: listing.title,
        otherUserName: listing.ownerName,
        otherUserPhotoUrl: listing.ownerPhotoUrl,
        currentUserName: currentUser.displayName,
        currentUserPhotoUrl: currentUser.photoURL,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversationId: conversationId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final onTap = widget.onTap;
    final compact = widget.compact;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final isNarrow = isCompact || compact;

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
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: isNarrow ? 116.0 : 132.0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _FlatmatePhoto(listing: listing),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isNarrow ? 10 : 12,
                        isNarrow ? 10 : 14,
                        isNarrow ? 8 : 10,
                        isNarrow ? 8 : 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (displayName.isNotEmpty) ...[
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.headline(
                                fontSize: isCompact ? 14 : 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF3F3F3F),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (listing.location.trim().isNotEmpty) ...[
                            _FlatmateInfoLine(
                              icon: Icons.location_on_rounded,
                              text: listing.location.trim(),
                              fontSize: isCompact ? 11 : 12,
                            ),
                            const SizedBox(height: 5),
                          ],
                          if (listing.price > 0) ...[
                            _FlatmateInfoLine(
                              icon: Icons.currency_rupee_rounded,
                              text: '${listing.price.toInt()} Rent',
                              fontSize: isCompact ? 11 : 12,
                            ),
                            const SizedBox(height: 5),
                          ],
                          if ((listing.genderPreference ?? '').trim().isNotEmpty)
                            _FlatmateInfoLine(
                              icon: Icons.person_rounded,
                              text: 'Looking for ${(listing.genderPreference ?? '').trim()}',
                              fontSize: isCompact ? 11 : 12,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEDEDED)),
            SizedBox(
              height: isNarrow ? 42 : 46,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 12),
                child: Row(
                  children: [
                    if ((listing.availableFrom ?? '').trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          (listing.availableFrom ?? '').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8E8E8E),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (_ownerPhone != null) ...[
                      _FlatmateActionButton(
                        icon: Icons.phone_rounded,
                        enabled: true,
                        onTap: _launchPhone,
                      ),
                      SizedBox(width: isNarrow ? 10 : 14),
                    ],
                    _FlatmateActionButton(
                      icon: Icons.chat_bubble_rounded,
                      enabled: true,
                      onTap: _startChat,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatmatePhoto extends StatelessWidget {
  final ListingModel listing;

  const _FlatmatePhoto({required this.listing});

  @override
  Widget build(BuildContext context) {
    final photoUrl = listing.ownerPhotoUrl.trim().isNotEmpty
        ? listing.ownerPhotoUrl.trim()
        : (listing.imageUrls.isNotEmpty ? listing.imageUrls.first.trim() : '');

    if (photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('assets/')) {
        return Image.asset(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        errorWidget: (_, _, __) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = listing.ownerName.trim().isNotEmpty
        ? listing.ownerName.trim()[0].toUpperCase()
        : '';
    return Container(
      color: const Color(0xFFF6F2EE),
      alignment: Alignment.center,
      child: initial.isEmpty
          ? const Icon(Icons.person_rounded, size: 48, color: Color(0xFFB0B0B0))
          : Text(
              initial,
              style: AppTheme.headline(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
    );
  }
}

class _FlatmateInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final double fontSize;

  const _FlatmateInfoLine({required this.icon, required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: fontSize + 5, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(fontSize: fontSize, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _FlatmateActionButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _FlatmateActionButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.outline,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({required this.label, required this.background, required this.foreground});

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
        style: AppTheme.label(fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w800, color: foreground),
      ),
    );
  }
}
