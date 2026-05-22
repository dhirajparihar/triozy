import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'about_triozy_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'my_listings_screen.dart';
import 'policy_screen.dart';
import 'saved_listings_screen.dart';

/// Profile screen for authenticated or guest users.
class UserProfileScreen extends StatefulWidget {
  final bool isGuest;

  const UserProfileScreen({super.key, this.isGuest = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final StreamSubscription<User?> _userChangesSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to Firebase Auth user profile changes so the avatar refreshes
    // when photoURL or displayName is updated elsewhere in the app.
    _userChangesSubscription =
        FirebaseAuth.instance.userChanges().listen((_) {
      if (mounted) {
        debugPrint('UserProfileScreen userChanges event fired');
        setState(() {});
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _userChangesSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    await FirebaseAuth.instance.currentUser?.reload();
    debugPrint('Returned from EditProfileScreen, refreshed photoURL: ${FirebaseAuth.instance.currentUser?.photoURL?.trim()}');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('UserProfileScreen build currentUser photoURL: ${user?.photoURL?.trim()}');
    // Show guest or authenticated profile based on auth state.
    if (widget.isGuest || user == null) {
      return Container(
        color: const Color(0xFFF3F0FB),
        child: _GuestProfile(
          onExitGuest: () => context.read<SessionService>().exitGuestMode(),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF3F0FB),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
        children: [
        _HeaderCard(
          user: user,
          onEditProfile: _handleEditProfile,
        ),
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
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                );
              },
            ),
            _TileItem(
              icon: Icons.share,
              label: 'Share App',
              onTap: () => _shareApp(context),
            ),
            _TileItem(
              icon: Icons.star_border,
              label: 'Rate Us on Play Store',
              onTap: () => _rateUs(context),
            ),
            _TileItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PolicyScreen(type: PolicyType.privacy),
                  ),
                );
              },
            ),
            _TileItem(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PolicyScreen(type: PolicyType.terms),
                  ),
                );
              },
            ),
            _TileItem(
              icon: Icons.info_outline,
              label: 'About Triozy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AboutTriozyScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 48),
        Center(
          child: TextButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
            label: Text(
              'Log Out',
              style: AppTheme.body(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    // Confirm logout before signing out from Firebase.
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

  Future<void> _shareApp(BuildContext context) async {
    const shareText =
        'Hey! Check out Triozy — the all-in-one app for city movers. Find rooms, PGs, flatmates & second-hand items easily. Download here: https://play.google.com/store/apps/details?id=com.triozy.triozy_app';
    await Share.share(shareText);
  }

  Future<void> _rateUs(BuildContext context) async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.triozy.triozy_app',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open Play Store');
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Play Store. Please try again later.'),
        ),
      );
    }
  }
}

class _HeaderCard extends StatelessWidget {
  /// User avatar, name, and edit profile button.
  final User user;
  final Future<void> Function() onEditProfile;

  const _HeaderCard({required this.user, required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    // Fallback to placeholder if displayName is empty.
    final displayName = (user.displayName ?? '').trim().isEmpty
        ? 'Sarah Jenkins' // Placeholder matching design, since missing
        : user.displayName!.trim();
    final photoUrl = user.photoURL?.trim();
    assert(() {
      debugPrint('UserProfileScreen avatar photoUrl: $photoUrl');
      return true;
    }());
    final initials = _extractInitials(displayName);

    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: const BoxDecoration(
            color: Color(0xFF5E35B1),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.hardEdge,
          child: photoUrl?.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Center(
                    child: Text(
                      initials,
                      style: AppTheme.headline(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  errorWidget: (_, error, stackTrace) {
                    debugPrint('Profile avatar failed to load: $error');
                    return Center(
                      child: Text(
                        initials,
                        style: AppTheme.headline(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                )
              : Center(
                  child: Text(
                    initials,
                    style: AppTheme.headline(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: AppTheme.headline(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3D1F8C),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onEditProfile,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF7C5CBF)),
            foregroundColor: const Color(0xFF7C5CBF),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            'Edit Profile',
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7C5CBF),
            ),
          ),
        ),
      ],
    );
  }
}

String _extractInitials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return '';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class _TileGroup extends StatelessWidget {
  /// Container for a vertical list of tappable menu items.
  final List<_TileItem> children;

  const _TileGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D7F5), width: 0.5),
      ),
      child: Column(
        children: children
            .expand(
              (item) => [
                item,
                if (item != children.last)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFF0ECFA),
                  ),
              ],
            )
            .toList(),
      ),
    );
  }
}

class _TileItem extends StatelessWidget {
  /// Single menu option with icon and label.
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
      leading: Icon(icon, color: const Color(0xFF7C5CBF)),
      title: Text(
        label,
        style: AppTheme.body(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF2D2D2D),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFB0A0D0),
        size: 20,
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  /// Guest mode profile prompting user to sign in.
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
