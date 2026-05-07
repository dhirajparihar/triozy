import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'housing_feed_screen.dart';
import 'post_listing_screen.dart';
import 'requirement_form_screen.dart';

class HousingEntryScreen extends StatelessWidget {
  const HousingEntryScreen({super.key});

  static Future<Route<void>> buildRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    final hasPostedListing =
        user != null && await DatabaseService().hasUserPostedListing(user.uid);

    return MaterialPageRoute<void>(
      builder: (_) => hasPostedListing
          ? const HousingFeedScreen()
          : const _HousingChoiceScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _HousingChoiceScreen();
  }
}

class _HousingChoiceScreen extends StatelessWidget {
  const _HousingChoiceScreen();

  Future<void> _openFlow(BuildContext context, {required Widget screen}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    if (result != true || !context.mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HousingFeedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        title: const Text('Housing'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose how you want to start',
                  textAlign: TextAlign.center,
                  style: AppTheme.headline(
                    fontSize: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "We'll use this first step to guide you into the right housing flow. After your first listing, future visits will open the Housing feed directly.",
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                _HousingChoiceCard(
                  icon: Icons.meeting_room_rounded,
                  title: 'Room',
                  subtitle: 'Looking for a room',
                  onTap: () =>
                      _openFlow(context, screen: const RequirementFormScreen()),
                ),
                const SizedBox(height: 14),
                _HousingChoiceCard(
                  icon: Icons.groups_rounded,
                  title: 'Flatmate',
                  subtitle:
                      'Looking for a flatmate while already having a room/flat',
                  onTap: () => _openFlow(
                    context,
                    screen: const PostListingScreen(
                      initialPropertyType: PropertyType.flat,
                      initialPurpose: ListingPurpose.needRoommate,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _HousingChoiceCard(
                  icon: Icons.apartment_rounded,
                  title: 'List PG',
                  subtitle: 'For PG owners to list their property',
                  onTap: () => _openFlow(
                    context,
                    screen: const PostListingScreen(
                      initialPropertyType: PropertyType.pg,
                      initialPurpose: ListingPurpose.offerProperty,
                    ),
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

class _HousingChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HousingChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.body(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
