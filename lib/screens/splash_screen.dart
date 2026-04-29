import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final String? statusText;
  final bool showLoader;

  const SplashScreen({super.key, this.statusText, this.showLoader = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _brandBlue = Color(0xFF2038A3);
  static const Color _brandBlueDeep = Color(0xFF172A7F);

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
    
    // Main Entrance Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Continuous Subtle Pulse Animation (runs in background)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.08, end: 0.16).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _brandBlue,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brandBlue, _brandBlueDeep],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient breathing/pulsing glow
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 0.95 + (_pulseController.value * 0.05),
                        colors: [
                          Colors.white.withValues(alpha: _glowPulse.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoWidth = (constraints.maxWidth * 0.58).clamp(
                    220.0,
                    360.0,
                  );

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Hero Logo with Scale & Fade & Float
                              Transform.scale(
                                scale: _logoScale.value,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: Offset.zero,
                                    end: const Offset(0, -0.015), // Gentle hover
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _pulseController,
                                      curve: Curves.easeInOutSine,
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: _logoOpacity.value,
                                    child: Image.asset(
                                      'assets/logo.png',
                                      width: logoWidth,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Subtitle with Fade & Slide up
                              SlideTransition(
                                position: _textSlide,
                                child: Opacity(
                                  opacity: _textOpacity.value,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Text(
                                      widget.statusText ??
                                          'Your local network for everything.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            height: 1.5,
                                            letterSpacing: 0.3,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.showLoader) ...[
                                const SizedBox(height: 32),
                                // Elegant Loader with Fade
                                Opacity(
                                  opacity: _loaderOpacity.value,
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
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
