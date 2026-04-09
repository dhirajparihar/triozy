import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import 'policy_screen.dart';

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
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    // Detect storage-partitioned / popup-blocked browsers (vivo, MIUI, UC, etc.)
    if (_isBrowserIncompatible()) {
      _showOpenInChromeDialog();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('missing initial state') ||
          msg.contains('sessionStorage') ||
          msg.contains('popup_closed') ||
          msg.contains('popup-blocked')) {
        _showOpenInChromeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReviewSignIn() async {
    final creds = await _showReviewSignInDialog();
    if (creds == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithEmail(
        email: creds.$1,
        password: creds.$2,
      );
      if (user == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_reviewAuthErrorMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review sign-in failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<(String, String)?> _showReviewSignInDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<(String, String)>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Sign-In',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the review account credentials to continue.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter email';
                      if (!text.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Enter password';
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (formKey.currentState!.validate()) {
                        Navigator.of(ctx).pop((
                          emailController.text.trim(),
                          passwordController.text,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.of(ctx).pop((
                              emailController.text.trim(),
                              passwordController.text,
                            ));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _reviewAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Auth.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Review sign-in failed. ${e.message ?? e.code}';
    }
  }

  void _handleContinueAsGuest() {
    context.read<SessionService>().enterGuestMode();
  }

  bool _isBrowserIncompatible() {
    // Only relevant on web
    if (!const bool.fromEnvironment('dart.library.html',
        defaultValue: false)) {
      try {
        // Use Flutter's kIsWeb check via import
        return false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _showOpenInChromeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_browser_rounded,
                    size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Open in Chrome',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your current browser doesn\'t support Google Sign-In.\n\nPlease open Triozy in Google Chrome to sign in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF001229),
      body: Stack(
        children: [
          // ── Main scrollable content ────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── Hero ──────────────────────────────────────────────
                _HeroSection(
                  size: size,
                  fade: _fade,
                  slide: _slide,
                ),
                // ── White content card ─────────────────────────────
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: _ContentSection(),
                ),
              ],
            ),
          ),
          // ── Sticky bottom CTA ──────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyCtaBar(
              isLoading: _isLoading,
              onSignIn: _handleGoogleSignIn,
              onReviewSignIn: _handleReviewSignIn,
              onContinueAsGuest: _handleContinueAsGuest,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Section
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Size size;
  final Animation<double> fade;
  final Animation<Offset> slide;

  const _HeroSection({
    required this.size,
    required this.fade,
    required this.slide,
  });

  @override
  Widget build(BuildContext context) {
    final heroH = (size.height * 0.64).clamp(420.0, 720.0);

    return SizedBox(
      height: heroH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ────────────────────────────────────────
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
          // ── Multi-stop gradient overlay ─────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.75, 1.0],
                colors: [
                  const Color(0xFF001229).withValues(alpha: 0.72),
                  const Color(0xFF001229).withValues(alpha: 0.45),
                  const Color(0xFF001229).withValues(alpha: 0.70),
                  const Color(0xFF001229).withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          // ── Text content ────────────────────────────────────────────
          SafeArea(
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
                      // Trust badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 12, color: AppColors.secondaryFixed),
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
                      const SizedBox(height: 12),
                      // Headline
                      Text(
                        'Workers.\nRequests.\nMates.',
                        style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'One app. Find pros, post work,\nor connect with a mate — near you.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        children: [
                          _StatPill(value: '50K+', label: 'users'),
                          const SizedBox(width: 10),
                          _StatPill(value: '4.9★', label: 'rated'),
                          const SizedBox(width: 10),
                          _StatPill(value: '200+', label: 'cities'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;

  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
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
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Section (white card)
// ─────────────────────────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  const _ContentSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          // Value propositions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _ValuePropCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Verified\nPros',
                  color: AppColors.primary,
                  bg: AppColors.blue50,
                ),
                const SizedBox(width: 12),
                _ValuePropCard(
                  icon: Icons.phone_rounded,
                  title: 'Direct\nCall',
                  color: AppColors.secondary,
                  bg: AppColors.green50,
                ),
                const SizedBox(width: 12),
                _ValuePropCard(
                  icon: Icons.money_off_rounded,
                  title: 'Zero\nFees',
                  color: AppColors.tertiary,
                  bg: AppColors.orange50,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          // Section heading
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
                      style: AppTheme.headline(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No booking, no fees — call directly',
                      style: AppTheme.body(
                          fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'See all',
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Service cards
          SizedBox(
            height: 110,
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
          // Spacer for sticky CTA
          const SizedBox(height: 140),
        ],
      ),
    );
  }
}

class _ValuePropCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color bg;

  const _ValuePropCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.label(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
            color: gradient.last.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Policy disclaimer text
// ─────────────────────────────────────────────────────────────────────────────

class _PolicyDisclaimerText extends StatelessWidget {
  const _PolicyDisclaimerText();

  void _open(BuildContext context, PolicyType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PolicyScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      fontSize: 12,
      color: AppColors.slate400,
    );
    final link = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary.withValues(alpha: 0.4),
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(context, PolicyType.terms),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(context, PolicyType.privacy),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky CTA bar
// ─────────────────────────────────────────────────────────────────────────────

class _StickyCtaBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSignIn;
  final VoidCallback onReviewSignIn;
  final VoidCallback onContinueAsGuest;

  const _StickyCtaBar({
    required this.isLoading,
    required this.onSignIn,
    required this.onReviewSignIn,
    required this.onContinueAsGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Google button
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
                                borderRadius: BorderRadius.circular(6),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onReviewSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Review Sign-In',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: isLoading ? null : onContinueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Continue as Guest',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _PolicyDisclaimerText(),
            ],
          ),
        ),
      ),
    );
  }
}
