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
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final tiles = [
      _ServiceInfo(
        imageAsset: 'assets/images/Housing.png',
        title: 'Housing',
        onTap: () => _openHousing(context),
      ),
      _ServiceInfo(
        imageAsset: 'assets/images/Marketplace.png',
        title: 'Marketplace',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
        ),
      ),
      _ServiceInfo(
        imageAsset: 'assets/images/tiffin.png',
        title: 'Tiffin',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Coming soon!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
      _ServiceInfo(
        imageAsset: 'assets/images/cook.png',
        title: 'Cook',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Coming soon!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
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
                    fontSize: isCompact ? 28 : 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  return _ServiceTile(
                    imageAsset: tile.imageAsset,
                    title: tile.title,
                    onTap: tile.onTap,
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
  final String imageAsset;
  final String title;
  final VoidCallback onTap;

  const _ServiceInfo({
    required this.imageAsset,
    required this.title,
    required this.onTap,
  });
}

class _ServiceTile extends StatelessWidget {
  final String imageAsset;
  final String title;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.imageAsset,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported_rounded,
                    color: AppColors.outlineVariant,
                    size: 32,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, left: 4, right: 4),
              child: Text(
                title,
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
