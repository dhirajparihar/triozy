import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../screens/worker_setup_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/about_screen.dart';
import '../screens/requests_screen.dart';
import '../screens/my_mates_screen.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32, left: 24, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroProfile(user),
          const SizedBox(height: 32),
          _buildBecomeWorkerCard(context),
          const SizedBox(height: 40),
          _buildSettingsList(context),
          const SizedBox(height: 48),
          _buildLogout(context),
        ],
      ),
    );
  }

  Widget _buildHeroProfile(User? user) {
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
            ),
            Positioned(
              bottom: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit,
                  size: 14,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTheme.headline(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBecomeWorkerCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -16,
            child: Opacity(
              opacity: 0.1,
              child: Transform.rotate(
                angle: 0.2,
                child: const Icon(Icons.work, size: 120, color: Colors.white),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to provide services?',
                style: AppTheme.headline(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Switch to service mode and start offering your services to the Triozy community today.',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await context.read<AuthService>().saveUser(
                      uid: user.uid,
                      name: user.displayName ?? '',
                      email: user.email ?? '',
                      role: 'worker',
                      photoUrl: user.photoURL,
                    );
                  }
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkerSetupScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Become a Service Provider',
                        style: AppTheme.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'ACCOUNT SETTINGS',
            style: AppTheme.headline(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _settingsTile(Icons.work_outline, 'My Requests', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsScreen(initialTab: 1, standalone: true)));
        }),
        const SizedBox(height: 8),
        _settingsTile(Icons.people_alt_rounded, 'My Mate Posts', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyMatesScreen()));
        }),
        const SizedBox(height: 8),
        _settingsTile(Icons.person_outline, 'Edit Profile', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        }),
        const SizedBox(height: 8),
        _settingsTile(Icons.help_outline, 'Help & Support', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
        }),
        const SizedBox(height: 8),
        _settingsTile(Icons.info_outline, 'About Triozy', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
        }),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String label, VoidCallback onTap) {
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
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.outlineVariant, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AppColors.surfaceContainerHighest,
      child: const Icon(Icons.person, size: 48, color: AppColors.outline),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Log Out'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppColors.outline)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<AuthService>().signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Log Out',
          style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
