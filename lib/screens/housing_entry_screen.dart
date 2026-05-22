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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.real_estate_agent_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                Text(
                    'What are you\nlooking for?',
                  style: AppTheme.headline(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.2,
                      letterSpacing: -0.5,
                  ),
                ),
                  const SizedBox(height: 12),
                Text(
                    'Tell us what you need so we can personalize your housing feed and match you with the right people.',
                  style: AppTheme.body(
                      fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                      height: 1.5,
                  ),
                ),
                  const SizedBox(height: 48),
                _HousingChoiceCard(
                  icon: Icons.meeting_room_rounded,
                    title: 'I need a room',
                    subtitle: 'Find available rooms and connect with potential flatmates.',
                  onTap: () =>
                      _openFlow(context, screen: const RequirementFormScreen()),
                ),
                  const SizedBox(height: 16),
                _HousingChoiceCard(
                  icon: Icons.groups_rounded,
                    title: 'I need a flatmate',
                    subtitle: 'List your place and find someone great to share it with.',
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _HousingChoiceCard extends StatelessWidget {
  /// Card-style action for selecting a housing entry path.
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: AppTheme.headline(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTheme.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
