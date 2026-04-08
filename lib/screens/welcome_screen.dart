import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final AuthService _authService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }
      // AuthGate's StreamBuilder will detect the auth state change
      // and route the user automatically via _RoleRouter.
      // No manual navigation needed here.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero Section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand
                    Center(
                      child: Text(
                        'Triozy',
                        style: AppTheme.headline(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.blue700,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 14, color: AppColors.onSecondaryContainer),
                          const SizedBox(width: 6),
                          Text(
                            'TRUSTED BY 50K+ USERS',
                            style: AppTheme.label(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSecondaryContainer,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Headline
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Get things done\n',
                            style: AppTheme.headline(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                          TextSpan(
                            text: 'with Triozy.',
                            style: AppTheme.headline(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Find services, post requests, or connect with a mate — all near you.',
                      style: AppTheme.body(
                        fontSize: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Hero Image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 280,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Main image
                      Positioned(
                        right: 0,
                        top: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuCstkcuYupTO3tmIMZc-o47A-6Pf1HNFs_eT6LQBPgde4jDzeUpawXsbH7doMCDJwVbeMRb24q5R91HbKc-lJi0miumg0ec5B570PEq7xrO6Blgrl3obWBZ2TJk4bIZE_gDeWWd1-XzVMSpwunwhA_747Jx6x6z34FRlCC0S1dEdfUvmkyWrltf0pkQAKGvyl9pvLtSiZjKsRLNLbBgfwQjPbk-U0-YnTEegQBZ5j8-ACHrtJocuhZeVOjJvbSM58SmP2GWk2HIVyQ',
                            width: MediaQuery.of(context).size.width * 0.75,
                            height: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: MediaQuery.of(context).size.width * 0.75,
                              height: 260,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.image, size: 48, color: AppColors.outline),
                            ),
                          ),
                        ),
                      ),
                      // Glass card
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.55,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified,
                                        color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Certified Pros',
                                          style: AppTheme.headline(fontSize: 14)),
                                      Text('Vetted & Insured',
                                          style: AppTheme.body(
                                              fontSize: 12,
                                              color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Avatar stack
                              SizedBox(
                                height: 32,
                                child: Stack(
                                  children: [
                                    _avatarCircle(0, 'https://lh3.googleusercontent.com/aida-public/AB6AXuBfx7w53Yd2Ph46yGYjfTxQIzlDt5rYdwkY0MqSkSlLbhb4iawJkdAJi9i0WFUtsQkaBbgJfGUcAEOv7M00EWw4MlUBIYoCu33gpdCnH6I3p7Q5CFE1Dc_tmKFio1-_vumN8kXDg2b4tVnoD8oLWqWFjrNonI9R1UWDkeN1WFuhcPZsWAzU_P3Th_-OpbDUaUiQPBe5W9WaMUNZ4vS27V35X726EMTkixrantbPbOB3Gd4CqClZv7kdDg8eebbOrl185ZZlgg1_uGY'),
                                    _avatarCircle(22, 'https://lh3.googleusercontent.com/aida-public/AB6AXuDjYEQdInhQNMnKdtFS2AkUCjO6uK1flINsuyHo5JVKoWNfNys13_1xwauSf_l-KRjnGlIBITbiO5TbE-ufunQ5HaC9RiakZ0lAYEnCfExEiDr8He86os5CX6dUO9xucM8Fx8jUvsPB4cCeNO53okmYefBqnvbrCnRDmqXoYf2X032YoXXrbRL6yg5ucDvj8YsPru_M-V4csZfYEZbPT4h2z8juMFQCGiSfZFQYT7cCWAXzq4DbmONWLqbr93wysd1Rady67x5KzwQ'),
                                    _avatarCircle(44, 'https://lh3.googleusercontent.com/aida-public/AB6AXuA6jlnz25TJbgaWn1KeA_Nm3VxBj69bNJt9XkEwBIEM1xguSOSwR-Wmg2f8B9iazF0SQesdgCymGVFVV4ULlL8fwuD71o3WeN9V2hi3M1jK2SEp8pgupXVdFQGHwVVs0B6t3S4nzn8FDAtFWMt-59sqXHreO6F9RlR4NQMRgLxo24iQ_VjyPgbxtcsi1pIl2HwSMEb8gVqvKMLdn_zqy8GctNmxXk6j1qMmJAHq18Z6LiHPpsrTVV8soB5CcugiOyzimVldLnCXn6g'),
                                    Positioned(
                                      left: 66,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.surfaceContainerHigh,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Center(
                                          child: Text('+12',
                                              style: AppTheme.body(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Value props strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _valueProp(Icons.verified_user_rounded, 'Verified\nPros'),
                    const SizedBox(width: 8),
                    _valueProp(Icons.phone_rounded, 'Direct\nCall'),
                    const SizedBox(width: 8),
                    _valueProp(Icons.money_off_rounded, 'Zero\nFees'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // CTA Section - Google Sign In
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
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
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
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
                                    style: AppTheme.headline(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      style: AppTheme.body(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Popular Services Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Popular Services',
                            style: AppTheme.headline(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Call professionals directly — no booking, no fees',
                            style: AppTheme.body(fontSize: 14, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 130,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _serviceCard(Icons.electrical_services_rounded, 'Electrician',
                            AppColors.blue600, AppColors.blue50),
                        _serviceCard(Icons.plumbing_rounded, 'Plumber',
                            AppColors.secondary, AppColors.green50),
                        _serviceCard(Icons.ac_unit_rounded, 'AC Repair',
                            AppColors.tertiary, AppColors.orange50),
                        _serviceCard(Icons.format_paint_rounded, 'Painter',
                            AppColors.primary, AppColors.primaryContainer),
                        _serviceCard(Icons.carpenter, 'Carpenter',
                            const Color(0xFF795548), const Color(0xFFFBE9E7)),
                        _serviceCard(Icons.face_retouching_natural, 'Makeup Artist',
                            const Color(0xFFAD1457), const Color(0xFFFCE4EC)),
                        _serviceCard(Icons.water_drop_rounded, 'Water Supplier',
                            AppColors.blue700, AppColors.blue50),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarCircle(double left, String url) {
    return Positioned(
      left: left,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.surfaceContainerHigh,
              child: const Icon(Icons.person, size: 16, color: AppColors.outline),
            ),
          ),
        ),
      ),
    );
  }

  Widget _valueProp(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTheme.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(IconData icon, String label, Color iconColor, Color bgColor) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          Text(
            label,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
