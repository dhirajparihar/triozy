import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'my_listings_screen.dart';
import 'saved_listings_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final bool isGuest;

  const UserProfileScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (isGuest || user == null) {
      return _GuestProfile(
        onExitGuest: () => context.read<SessionService>().exitGuestMode(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        _HeaderCard(user: user),
        const SizedBox(height: 24),
        _SectionLabel(text: 'ACCOUNT'),
        const SizedBox(height: 12),
        _TileGroup(
          children: [
            _TileItem(
              icon: Icons.edit_outlined,
              label: 'Edit Profile',
              subtitle: 'Update your personal details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            _TileItem(
              icon: Icons.home_work_outlined,
              label: 'My Listings',
              subtitle: 'Manage rooms, flatmate, or item posts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                );
              },
            ),
            _TileItem(
              icon: Icons.favorite_border_rounded,
              label: 'Saved Items',
              subtitle: 'Review the listings you bookmarked',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedListingsScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionLabel(text: 'SUPPORT'),
        const SizedBox(height: 12),
        _TileGroup(
          children: [
            _TileItem(
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              subtitle: 'Contact support and FAQs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                );
              },
            ),
            _TileItem(
              icon: Icons.info_outline_rounded,
              label: 'About Triozy',
              subtitle: 'Read about the platform and policies',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Icons.logout_rounded),
          label: Text(
            'Log Out',
            style: AppTheme.body(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.28)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<AuthService>().signOut();
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final User user;

  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = (user.displayName ?? '').trim().isEmpty
        ? 'Triozy User'
        : user.displayName!.trim();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.blue50,
            backgroundImage:
                user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null
                ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTheme.headline(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'No email linked',
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Student & Professional Living',
                    style: AppTheme.label(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.label(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _TileGroup extends StatelessWidget {
  final List<_TileItem> children;

  const _TileGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: children
            .expand((item) => [item, if (item != children.last) const Divider(height: 1)])
            .toList(),
      ),
    );
  }
}

class _TileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TileItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.blue50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        label,
        style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.body(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  final VoidCallback onExitGuest;

  const _GuestProfile({required this.onExitGuest});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_person_outlined, color: AppColors.primary, size: 34),
              const SizedBox(height: 16),
              Text('Browsing as guest', style: AppTheme.headline(fontSize: 28)),
              const SizedBox(height: 10),
              Text(
                'Sign in to post listings, save rooms, and manage your move-in profile.',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onExitGuest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  'Sign In',
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
