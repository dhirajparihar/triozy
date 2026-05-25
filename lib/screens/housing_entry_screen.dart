import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'flatmate_room_details_screen.dart';
import 'housing_feed_screen.dart';
import 'requirement_form_screen.dart';

/// Entry screen that routes users into the correct housing flow.
class HousingEntryScreen extends StatelessWidget {
  const HousingEntryScreen({super.key});

  static Future<Route<void>> buildRoute() async {
    // If the user already posted, jump straight to the feed.
    final user = FirebaseAuth.instance.currentUser;
    final hasPostedHousingListing =
        user != null &&
        await DatabaseService().hasUserPostedHousingListing(user.uid);

    return MaterialPageRoute<void>(
      builder: (_) => hasPostedHousingListing
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
    // Push a flow and return to housing feed on success.
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What are you\nlooking for?',
              style: AppTheme.headline(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tell us what you need so we can personalize your housing feed and match you with the right people.',
              style: AppTheme.body(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),
            _HousingChoiceCard(
              title: 'I need a room',
              subtitle: 'Find available rooms and connect with potential flatmates.',
              icon: Icons.meeting_room_rounded,
              iconColor: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFFEFF6FF),
              onTap: () =>
                  _openFlow(context, screen: const RequirementFormScreen()),
            ),
            const SizedBox(height: 16),
            _HousingChoiceCard(
              title: 'I need a flatmate',
              subtitle: 'List your place and find someone great to share it with.',
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFFECFDF5),
              onTap: () => _openFlow(
                context,
                screen: const FlatmateRoomDetailsScreen(),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HousingFeedScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Skip for now',
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HousingChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _HousingChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
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
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.headline(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
