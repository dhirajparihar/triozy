import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'housing_entry_screen.dart';
import 'marketplace_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  Future<void> _openHousing(BuildContext context) async {
    final route = await HousingEntryScreen.buildRoute();
    if (!context.mounted) {
      return;
    }
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ServiceInfo(
        icon: Icons.home_work_rounded,
        title: 'Housing',
        onTap: () => _openHousing(context),
      ),
      _ServiceInfo(
        icon: Icons.shopping_bag_rounded,
        title: 'Marketplace',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
        ),
      ),
    ];

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Services',
                  style: AppTheme.headline(
                    fontSize: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a service to start your next move.',
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              child: GridView.builder(
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 168,
                ),
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ServiceTile(icon: tile.icon, onTap: tile.onTap),
                      const SizedBox(height: 8),
                      Text(
                        tile.title,
                        style: AppTheme.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceInfo {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ServiceInfo({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ServiceTile({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 118,
        decoration: AppTheme.cardDecoration(
          color: AppColors.surfaceContainerLowest,
          radiusValue: 20,
          shadowAlpha: 0.06,
          blur: 18,
          offsetY: 8,
        ),
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.72),
              borderRadius: AppTheme.radius(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
        ),
      ),
    );
  }
}
