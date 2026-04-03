import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 10,
              bottom: 14,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home,
                    label: 'HOME',
                    isSelected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.search,
                    label: 'SEARCH',
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.work_outline,
                    label: 'JOBS',
                    isSelected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person,
                    label: 'PROFILE',
                    isSelected: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue50 : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.blue700 : AppColors.slate400,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.blue700 : AppColors.slate400,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
