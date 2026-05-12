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
    
    final greetingFontSize = isSmallScreen ? 18.0 : 22.0;
    final locationFontSize = isSmallScreen ? 12.0 : 13.0;
    final dropdownIconSize = isSmallScreen ? 14.0 : 16.0;
    final avatarSize = isSmallScreen ? 40.0 : 44.0;
    final appBarHeight = isSmallScreen ? 56.0 : 62.0;
    final topPadding = isSmallScreen ? 6.0 : 8.0;
    final bottomPadding = isSmallScreen ? 2.0 : 4.0;

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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            greeting,
                            style: AppTheme.headline(
                              fontSize: greetingFontSize,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getGreetingEmoji(),
                          style: TextStyle(fontSize: greetingFontSize),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 2.0 : 3.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: locationFontSize + 2,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            cityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: locationFontSize,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
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

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '👋';
    return '🌙';
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Select Location',
              style: AppTheme.headline(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
            SizedBox(height: 24),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accentLavender,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 14),
            Text(
              title,
              style: AppTheme.body(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
    this.size = 44,
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
              color: AppColors.accentLavender,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
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
      color: AppColors.accentLavender,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.52,
        color: AppColors.primary.withValues(alpha: 0.6),
      ),
    );
  }
}
