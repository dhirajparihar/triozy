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
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cityLabel = _cityLabel(location);

    return SafeArea(
      bottom: false,
      child: Container(
        height: 68,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        color: AppColors.background,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onLocationTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        cityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headline(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
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
              ),
          ],
        ),
      ),
    );
  }

  String _cityLabel(String? rawLocation) {
    final cleaned = (rawLocation ?? '').trim();
    if (cleaned.isEmpty) {
      return 'Moving to your city';
    }
    final firstSegment = cleaned
        .split(',')
        .map((part) => part.trim())
        .firstWhere((part) => part.isNotEmpty, orElse: () => cleaned);
    return 'Moving to $firstSegment';
  }
}

class _AvatarButton extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onTap;
  final bool showChatDot;

  const _AvatarButton({
    required this.avatarUrl,
    required this.onTap,
    required this.showChatDot,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
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
      child: const Icon(
        Icons.person_rounded,
        size: 20,
        color: Color(0xFF78B9C8),
      ),
    );
  }
}
