import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class TriozyTopAppBar extends StatelessWidget {
  final String? location;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLocationTap;

  const TriozyTopAppBar({
    super.key,
    this.location,
    this.avatarUrl,
    this.onAvatarTap,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final wordmarkSize = width < 360 ? 16.0 : 18.0;
            return Container(
              height: MediaQuery.of(context).padding.top + 60,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE8ECF0), width: 0.5),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: onLocationTap,
                            behavior: HitTestBehavior.opaque,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: width * 0.38,
                                minHeight: 36,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.blue50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: AppColors.slate500,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location ?? 'Locating...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12.5,
                                          color: AppColors.slate500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.slate500,
                                      size: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
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
                  ),
                  IgnorePointer(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: AppColors.blue700.withValues(alpha: 0.18),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.surfaceContainerHigh,
                                child: const Icon(
                                  Icons.handyman_rounded,
                                  color: AppColors.blue700,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Triozy',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w900,
                            fontSize: wordmarkSize,
                            color: AppColors.blue700,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
