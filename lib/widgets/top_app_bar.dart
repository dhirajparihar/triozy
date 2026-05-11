import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TriozyTopAppBar extends StatelessWidget {
  final String? userDisplayName;
  final String? location;
  final String? avatarUrl;
  final bool showAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLocationTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onManualLocationEntry;
  final VoidCallback? onAutoDetectLocation;
  final int unreadCount;

  const TriozyTopAppBar({
    super.key,
    this.userDisplayName,
    this.location,
    this.avatarUrl,
    this.showAvatar = true,
    this.onAvatarTap,
    this.onLocationTap,
    this.onChatTap,
    this.onManualLocationEntry,
    this.onAutoDetectLocation,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cityLabel = _cityLabel(location);
    final greeting = _getGreeting();
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    final greetingFontSize = isSmallScreen ? 15.0 : 18.0;
    final locationFontSize = isSmallScreen ? 11.0 : 12.0;
    final dropdownIconSize = isSmallScreen ? 12.0 : 14.0;
    final avatarSize = isSmallScreen ? 34.0 : 38.0;
    final appBarHeight = isSmallScreen ? 52.0 : 56.0;
    final topPadding = isSmallScreen ? 6.0 : 8.0;
    final bottomPadding = isSmallScreen ? 1.0 : 2.0;

    return SafeArea(
      bottom: false,
      child: Container(
        constraints: BoxConstraints(minHeight: appBarHeight),
        padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
        color: AppColors.background,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showLocationBottomSheet(context),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      greeting,
                      style: AppTheme.headline(
                        fontSize: greetingFontSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 1.0 : 2.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            cityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: locationFontSize,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                          size: dropdownIconSize,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (showAvatar)
              _AvatarButton(
                avatarUrl: avatarUrl,
                onTap: onAvatarTap,
                showChatDot: unreadCount > 0,
                size: avatarSize,
              ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
    } else {
      timeGreeting = 'Good evening';
    }
    
    if (userDisplayName != null && userDisplayName!.trim().isNotEmpty) {
      final firstName = userDisplayName!.trim().split(' ').first;
      return '$timeGreeting, $firstName';
    }
    return timeGreeting;
  }

  String _cityLabel(String? rawLocation) {
    final cleaned = (rawLocation ?? '').trim();
    if (cleaned.isEmpty) {
      return 'Your city';
    }
    final firstSegment = cleaned
        .split(',')
        .map((part) => part.trim())
        .firstWhere((part) => part.isNotEmpty, orElse: () => cleaned);
    return firstSegment;
  }

  void _showLocationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Location',
              style: AppTheme.headline(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24),
            _LocationOption(
              icon: Icons.edit_location_outlined,
              title: 'Enter Location Manually',
              onTap: () {
                Navigator.pop(context);
                onManualLocationEntry?.call();
              },
            ),
            SizedBox(height: 12),
            _LocationOption(
              icon: Icons.my_location,
              title: 'Auto Detect Location',
              onTap: () {
                Navigator.pop(context);
                onAutoDetectLocation?.call();
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LocationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LocationOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: AppTheme.body(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onTap;
  final bool showChatDot;
  final double size;

  const _AvatarButton({
    required this.avatarUrl,
    required this.onTap,
    required this.showChatDot,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerLow,
              border: Border.all(
                color: AppColors.surfaceContainerLowest,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ),
        if (showChatDot)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.background,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE9EEF8),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.52,
        color: const Color(0xFF78B9C8),
      ),
    );
  }
}
