import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'policy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'About Triozy',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Logo & Version
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.handyman, size: 48, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Triozy',
              style: AppTheme.headline(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: AppTheme.body(fontSize: 14, color: AppColors.outline),
            ),
            const SizedBox(height: 32),

            // Mission
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Our Mission', style: AppTheme.headline(fontSize: 20)),
                  const SizedBox(height: 12),
                  Text(
                    'Triozy connects you with trusted, verified professionals for all your service needs — from home maintenance to personal care. We\'re building a world where expert help is just a tap away.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _statCard('1K+', 'Users', Icons.people_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('100+', 'Professionals', Icons.verified),
                ),
                const SizedBox(width: 12),
                Expanded(child: _statCard('20', 'Services', Icons.category)),
              ],
            ),
            const SizedBox(height: 32),

            // Info tiles
            Text(
              'INFORMATION',
              style: AppTheme.headline(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 16),

            _infoTile(Icons.description_outlined, 'Terms of Service', onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const PolicyScreen(type: PolicyType.terms)));
            }),
            const SizedBox(height: 8),
            _infoTile(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const PolicyScreen(type: PolicyType.privacy)));
            }),
            const SizedBox(height: 8),
            _infoTile(Icons.gavel_outlined, 'Licenses'),

            const SizedBox(height: 40),
            Text(
              'Made with ❤️ in India',
              style: AppTheme.body(fontSize: 14, color: AppColors.outline),
            ),
            const SizedBox(height: 4),
            Text(
              '© 2026 Triozy. All rights reserved.',
              style: AppTheme.body(
                fontSize: 12,
                color: AppColors.outlineVariant,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.headline(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.body(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.outline, size: 24),
        ],
      ),
    ),
    );
  }
}
