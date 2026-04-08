import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

// ─── Reusable glass surface ────────────────────────────────────────────────────
class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;
  final Color borderColor;

  const _Glass({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 14,
    this.tint = const Color(0x14FFFFFF),
    this.borderColor = const Color(0x26FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Screen ────────────────────────────────────────────────────────────────────
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AuthService _authService;
  bool _isLoading = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF020C18),
      body: Stack(
        children: [
          // ── Full-screen backdrop (image + gradient) ────────────────
          _FullscreenBackdrop(size: size),

          // ── Scrollable content ─────────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _HeroContent(size: size, fade: _fade, slide: _slide),
                _GlassContentPanel(),
              ],
            ),
          ),

          // ── Sticky glass CTA bar ───────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlassCtaBar(
              isLoading: _isLoading,
              onSignIn: _handleGoogleSignIn,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full-screen backdrop ──────────────────────────────────────────────────────
class _FullscreenBackdrop extends StatelessWidget {
  final Size size;
  const _FullscreenBackdrop({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image
          Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCstkcuYupTO3tmIMZc-o47A-6Pf1HNFs_eT6LQBPgde4jDzeUpawXsbH7doMCDJwVbeMRb24q5R91HbKc-lJi0miumg0ec5B570PEq7xrO6Blgrl3obWBZ2TJk4bIZE_gDeWWd1-XzVMSpwunwhA_747Jx6x6z34FRlCC0S1dEdfUvmkyWrltf0pkQAKGvyl9pvLtSiZjKsRLNLbBgfwQjPbk-U0-YnTEegQBZ5j8-ACHrtJocuhZeVOjJvbSM58SmP2GWk2HIVyQ',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF001A41), Color(0xFF0047A3)],
                ),
              ),
            ),
          ),
          // Dark base gradient — strong at bottom so glass panels pop
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.30, 0.60, 1.0],
                colors: [
                  Color(0xAA020C18),
                  Color(0x55020C18),
                  Color(0xBB020C18),
                  Color(0xF5020C18),
                ],
              ),
            ),
          ),
          // Subtle blue glow orb (top-right)
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A73E8).withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle accent glow (bottom-left)
          Positioned(
            bottom: 120,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF006E2C).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero text content ─────────────────────────────────────────────────────────
class _HeroContent extends StatelessWidget {
  final Size size;
  final Animation<double> fade;
  final Animation<Offset> slide;

  const _HeroContent({
    required this.size,
    required this.fade,
    required this.slide,
  });

  @override
  Widget build(BuildContext context) {
    final heroH = (size.height * 0.64).clamp(440.0, 620.0);
    return SizedBox(
      height: heroH,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wordmark
                  Text(
                    'Triozy',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const Spacer(),
                  // Trust badge — glass pill
                  _Glass(
                    borderRadius: BorderRadius.circular(999),
                    blur: 10,
                    tint: const Color(0x18FFFFFF),
                    borderColor: const Color(0x30FFFFFF),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 13, color: AppColors.secondaryFixed),
                          const SizedBox(width: 6),
                          Text(
                            'TRUSTED BY 50K+ USERS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Headline
                  Text(
                    'Workers.\nRequests.\nMates.',
                    style: GoogleFonts.inter(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'One app. Find pros, post work,\nor connect with a mate — near you.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats — glass pills row
                  Row(
                    children: [
                      _GlassStatPill(value: '50K+', label: 'users'),
                      const SizedBox(width: 10),
                      _GlassStatPill(value: '4.9★', label: 'rated'),
                      const SizedBox(width: 10),
                      _GlassStatPill(value: '200+', label: 'cities'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassStatPill extends StatelessWidget {
  final String value;
  final String label;
  const _GlassStatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      borderRadius: BorderRadius.circular(14),
      blur: 12,
      tint: const Color(0x12FFFFFF),
      borderColor: const Color(0x28FFFFFF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glass content panel ───────────────────────────────────────────────────────
class _GlassContentPanel extends StatelessWidget {
  const _GlassContentPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(36),
        topRight: Radius.circular(36),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x10FFFFFF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(36),
              topRight: Radius.circular(36),
            ),
            border: const Border(
              top: BorderSide(color: Color(0x25FFFFFF), width: 1),
              left: BorderSide(color: Color(0x18FFFFFF), width: 1),
              right: BorderSide(color: Color(0x18FFFFFF), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Value props row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _GlassValueProp(
                      icon: Icons.verified_user_rounded,
                      title: 'Verified\nPros',
                      iconColor: const Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 12),
                    _GlassValueProp(
                      icon: Icons.phone_rounded,
                      title: 'Direct\nCall',
                      iconColor: const Color(0xFF6EE7B7),
                    ),
                    const SizedBox(width: 12),
                    _GlassValueProp(
                      icon: Icons.money_off_rounded,
                      title: 'Zero\nFees',
                      iconColor: const Color(0xFFFBBF24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Popular Services',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'No booking, no fees — call directly',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'See all',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF60A5FA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Service cards
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    _ServiceCard(
                      icon: Icons.electrical_services_rounded,
                      label: 'Electrician',
                      gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    _ServiceCard(
                      icon: Icons.plumbing_rounded,
                      label: 'Plumber',
                      gradient: [Color(0xFF1B5E20), Color(0xFF43A047)],
                    ),
                    _ServiceCard(
                      icon: Icons.ac_unit_rounded,
                      label: 'AC Repair',
                      gradient: [Color(0xFF4A148C), Color(0xFF9C27B0)],
                    ),
                    _ServiceCard(
                      icon: Icons.format_paint_rounded,
                      label: 'Painter',
                      gradient: [Color(0xFF01579B), Color(0xFF039BE5)],
                    ),
                    _ServiceCard(
                      icon: Icons.carpenter,
                      label: 'Carpenter',
                      gradient: [Color(0xFF4E342E), Color(0xFF8D6E63)],
                    ),
                    _ServiceCard(
                      icon: Icons.face_retouching_natural,
                      label: 'Makeup',
                      gradient: [Color(0xFF880E4F), Color(0xFFE91E63)],
                    ),
                    _ServiceCard(
                      icon: Icons.water_drop_rounded,
                      label: 'Water',
                      gradient: [Color(0xFF006064), Color(0xFF00ACC1)],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassValueProp extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;

  const _GlassValueProp({
    required this.icon,
    required this.title,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _Glass(
        borderRadius: BorderRadius.circular(18),
        blur: 10,
        tint: const Color(0x0EFFFFFF),
        borderColor: const Color(0x20FFFFFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;

  const _ServiceCard({
    required this.icon,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner glass sheen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 50,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Glass CTA bar ─────────────────────────────────────────────────────────────
class _GlassCtaBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSignIn;

  const _GlassCtaBar({required this.isLoading, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0x18FFFFFF),
            border: Border(
              top: BorderSide(color: Color(0x28FFFFFF), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'G',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Continue with Google',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'By continuing you agree to our Terms & Privacy Policy',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
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
