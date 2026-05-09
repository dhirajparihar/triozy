import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
      children: [
        _HeaderCard(user: user),
        const SizedBox(height: 24),
        _TileGroup(
          children: [
            _TileItem(
              icon: Icons.list_alt_rounded,
              label: 'My Listings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                );
              },
            ),
            _TileItem(
              icon: Icons.favorite_border_rounded,
              label: 'Saved Listings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SavedListingsScreen(),
                  ),
                );
              },
            ),
            _TileItem(
              icon: Icons.person_outline_rounded,
              label: 'Personal Info',
              onTap: () {},
            ),
            _TileItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Payments',
              onTap: () {},
            ),
            _TileItem(
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 48),
        Center(
          child: TextButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: Text(
              'Log Out',
              style: AppTheme.body(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
        ? 'Sarah Jenkins' // Placeholder matching design, since missing
        : user.displayName!.trim();

    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: AppColors.surfaceContainerHigh,
          backgroundImage: user.photoURL != null
              ? NetworkImage(user.photoURL!)
              : null,
          child: user.photoURL == null
              ? const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 50,
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: AppTheme.headline(fontSize: 28, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Text(
          'Member since October 2023',
          style: AppTheme.body(fontSize: 15, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHigh.withValues(
              alpha: 0.5,
            ),
            foregroundColor: AppColors.onSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Edit Profile',
            style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: children
            .expand(
              (item) => [
                item,
                if (item != children.last)
                  Divider(
                    height: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
              ],
            )
            .toList(),
      ),
    );
  }
}

class _TileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TileItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: AppColors.onSurfaceVariant),
      title: Text(
        label,
        style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.onSurfaceVariant,
        size: 20,
      ),
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
              const Icon(
                Icons.lock_person_outlined,
                color: AppColors.primary,
                size: 34,
              ),
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
