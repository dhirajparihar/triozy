import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Intro carousel shown before first authenticated session.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      title: 'Find your rooms and PGs',
      description:
          'Discover curated, high-quality spaces designed for young professionals and students.',
      imageAsset: 'assets/onboarding/home.png',
      badgeTitle: 'Verified Properties Only',
      badgeIcon: Icons.verified_outlined,
    ),
    _OnboardingSlide(
      title: 'Match with the right flatmates',
      description:
          'Connect with verified professionals and students who share your vibe and lifestyle.',
      imageAsset: 'assets/onboarding/flatmates.png',
    ),
    _OnboardingSlide(
      title: 'buy/sell essentials on marketplace',
      description:
          'Get pre-loved furniture and electronics delivered to your new doorstep, vetted by the community.',
      imageAsset: 'assets/onboarding/essentials.png',
      badgeEyebrow: 'PRE-LOVED ESSENTIALS',
      badgeTitle: 'Community Vetted',
      badgeIcon: Icons.verified_outlined,
    ),
  ];

  Future<void> _completeOnboarding() async {
    // Persist the onboarding flag before navigating into the app.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Triozy',
                    style: AppTheme.headline(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                    ),
                    child: Text(
                      'Skip',
                      style: AppTheme.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image with optional badge
                        Expanded(
                          child: Stack(
                            alignment: Alignment.bottomLeft,
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                margin: EdgeInsets.only(
                                  bottom: slide.badgeTitle != null ? 24 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(32),
                                  image: DecorationImage(
                                    image: AssetImage(slide.imageAsset),
                                    fit: BoxFit.cover,
                                    // Fallback for missing images during dev
                                    onError: (exception, stackTrace) {},
                                  ),
                                ),
                              ),
                              if (slide.badgeTitle != null)
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: AppTheme.shadow(
                                        blur: 16,
                                        offsetY: 8,
                                        alpha: 0.05,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (slide.badgeEyebrow != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              slide.badgeEyebrow!,
                                              style: AppTheme.label(
                                                fontSize: 10,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (slide.badgeIcon != null) ...[
                                              Icon(
                                                slide.badgeIcon,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Text(
                                              slide.badgeTitle!,
                                              style: AppTheme.body(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Text Content
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: AppTheme.headline(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final selected = index == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: selected ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        if (isLastPage) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Get Started' : 'Next',
                        style: AppTheme.button(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for a single onboarding carousel slide.
class _OnboardingSlide {
  final String title;
  final String description;
  final String imageAsset;
  final String? badgeEyebrow;
  final String? badgeTitle;
  final IconData? badgeIcon;

  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.imageAsset,
    this.badgeEyebrow,
    this.badgeTitle,
    this.badgeIcon,
  });
}
