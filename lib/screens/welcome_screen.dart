import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'policy_screen.dart';

/// Entry screen for sign-in, guest mode, and onboarding links.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// Handles Google sign-in, guest mode, and intro UI state.
class _WelcomeScreenState extends State<WelcomeScreen> {
  late final AuthService _authService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
  }

  void _openAuthenticatedFlow() {
    // Reset stack to the authenticated app shell.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _handleGoogleSignIn() async {
    // Detect storage-partitioned / popup-blocked browsers
    if (_isBrowserIncompatible()) {
      _showOpenInChromeDialog();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        _openAuthenticatedFlow();
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
            content: const Text('Sign in failed. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleContinueAsGuest() {
    // Enable guest mode in the session service.
    context.read<SessionService>().enterGuestMode();
  }

  bool _isBrowserIncompatible() {
    // Only relevant on web
    if (!const bool.fromEnvironment('dart.library.html', defaultValue: false)) {
      try {
        return false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _showOpenInChromeDialog() {
    // Prompt web users to switch to Chrome for Google sign-in.
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
                child: const Icon(
                  Icons.open_in_browser_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dotPattern() {
    // Small decorative dot asset used in the background.
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/dots.png'), 
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _circleBlur() {
    // Soft blurred circle accent.
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF6C4DFF).withValues(alpha: 0.1),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F5FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: 60, left: 30, child: _dotPattern()),
            Positioned(top: 120, right: 40, child: _circleBlur()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),

                              // ── Top Banner / Logo ──────────────────────────────────────
                              Center(
                                child: Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C4DFF),
                                        Color(0xFF4B2EFF),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6C4DFF).withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Image.asset(
                                        'assets/logo.png',
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.home_work_rounded,
                                          size: 36,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ── Title and Subtitle ─────────────────────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(-8, -12),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFFB74D),
                                      size: 24,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.translate(
                                        offset: const Offset(0, 8),
                                        child: Text(
                                          'Welcome to ',
                                          style: GoogleFonts.caveat(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF6C4DFF),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Triozy',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                          letterSpacing: -1.5,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Transform.translate(
                                    offset: const Offset(8, 8),
                                    child: const Icon(
                                      Icons.favorite,
                                      color: Color(0xFF6C4DFF),
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'Helping students and working professionals find rooms, flatmates, and everything needed to settle into a new city.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── Hero Illustration ──────────────────────────────
                              Expanded(
                                child: Transform.translate(
                                  offset: const Offset(0, 32),
                                  child: Transform.scale(
                                    scale: 1.25,
                                    alignment: Alignment.bottomCenter,
                                    child: Image.asset(
                                      'assets/images/welcome_scene.png',
                                      fit: BoxFit.contain,
                                      alignment: Alignment.bottomCenter,
                                      errorBuilder: (_, _, _) => const SizedBox(),
                                    ),
                                  ),
                                ),
                              ),

                              // ── Bottom Action Buttons ──────────────────────────────────
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 12,
                                    shadowColor: const Color(0xFF6C4DFF).withValues(alpha: 0.4),
                                    backgroundColor: const Color(0xFF5B3FFF),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          children: [
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Image.network(
                                                  "https://img.icons8.com/color/48/000000/google-logo.png",
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Center(
                                                      child: Text(
                                                        'G',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: AppColors.primary,
                                                          height: 1,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const Expanded(
                                              child: Text(
                                                'Continue with Google',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _handleContinueAsGuest,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F172A),
                                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                                    elevation: 0,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6C4DFF).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          color: Color(0xFF6C4DFF),
                                          size: 20,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Continue as Guest',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF0F172A),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Policy Disclaimer ──────────────────────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: Color(0xFF6C4DFF),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Your data is safe with us. Always.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
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

/// Inline policy disclaimer with tappable links.
class _PolicyDisclaimerText extends StatelessWidget {
  const _PolicyDisclaimerText();

  void _open(BuildContext context, PolicyType type) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PolicyScreen(type: type)));
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.inter(
      fontSize: 12,
      color: AppColors.slate500,
    );
    final linkStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary.withValues(alpha: 0.3),
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By continuing, you agree to our\n'),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(context, PolicyType.terms),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(context, PolicyType.privacy),
          ),
        ],
      ),
    );
  }
}
