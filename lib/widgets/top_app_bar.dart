import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class TriozyTopAppBar extends StatelessWidget {
  final String? location;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;

  const TriozyTopAppBar({
    super.key,
    this.location,
    this.avatarUrl,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).padding.top + 64,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.blue600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location ?? 'New York',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.slate500,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Triozy',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppColors.blue700,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarPlaceholder(),
                          )
                        : _avatarPlaceholder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.surfaceContainerHighest,
      child: const Icon(Icons.person, color: AppColors.outline, size: 24),
    );
  }
}
