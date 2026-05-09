import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final String? statusText;
  final bool showLoader;

  const SplashScreen({super.key, this.statusText, this.showLoader = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _loaderOpacity;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.1, end: 0.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surfaceContainerLow],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 0.92 + (_pulseController.value * 0.04),
                        colors: [
                          AppColors.primary.withValues(alpha: _glowPulse.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: const Alignment(0.75, -0.68),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer.withValues(alpha: 0.34),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(-0.85, 0.72),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentSoft.withValues(alpha: 0.34),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Column(
                        children: [
                          const Spacer(),
                          Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SlideTransition(
                            position: _textSlide,
                            child: Opacity(
                              opacity: _textOpacity.value,
                              child: Column(
                                children: [
                                  Text(
                                    'Triozy',
                                    style: AppTheme.headline(
                                      color: AppColors.primary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 280,
                                    ),
                                    child: Text(
                                      widget.statusText ??
                                          'Curating your premium relocation experience.',
                                      textAlign: TextAlign.center,
                                      style: AppTheme.body(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (widget.showLoader) ...[
                            Opacity(
                              opacity: _loaderOpacity.value,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 64,
                                ),
                                child: Column(
                                  children: [
                                    LinearProgressIndicator(
                                      backgroundColor: AppColors.outlineVariant
                                          .withValues(alpha: 0.3),
                                      color: AppColors.primary,
                                      minHeight: 2,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'INITIALIZING',
                                      style: AppTheme.label(
                                        fontSize: 11,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),
                          ] else ...[
                            const SizedBox(height: 48),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
