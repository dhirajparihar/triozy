import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

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
    final rawName = (userDisplayName ?? '').trim();
    final firstName = rawName.isEmpty ? '' : rawName.split(' ').first;
    final titleText = firstName.isEmpty ? 'Welcome' : 'Welcome, $firstName!';
    return SafeArea(
      bottom: false,
      child: ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE8ECF0), width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onLocationTap,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w900,
                              fontSize: 24.0,
                              color: AppColors.blue700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  location ?? 'Locating...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: AppColors.slate500,
                                size: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onChatTap != null) ...[
                    const SizedBox(width: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: onChatTap,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.15,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chat_rounded,
                              color: AppColors.secondary,
                              size: 18,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -2,
                            top: -4,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: unreadCount > 99 ? 7 : 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (showAvatar) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: avatarUrl != null
                              ? Image.network(
                                  avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _avatarPlaceholder(),
                                )
                              : _avatarPlaceholder(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Icon(Icons.person, color: AppColors.outline, size: 20),
    );
  }
}
