import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late final DatabaseService _db;
  late final LocationService _locationService;
  late final AuthService _authService;
  WorkerModel? _worker;
  bool _loading = true;
  bool _isAvailable = true;
  bool _isUpdatingLocation = false;
  String? _locationStatus;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _locationService = context.read<LocationService>();
    _authService = context.read<AuthService>();
    _loadWorkerData();
  }

  Future<void> _loadWorkerData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final w = await _db.getWorker(uid);
      if (mounted && w != null) {
        setState(() {
          _worker = w;
          _isAvailable = w.isAvailable;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailability(bool val) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isAvailable = val);
    await _db.setWorkerAvailability(uid, val);
  }

  Future<void> _updateLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _isUpdatingLocation = true;
      _locationStatus = 'Detecting location...';
    });
    try {
      final position = await _locationService.getCurrentPosition();
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      await _locationService.saveWorkerLocation(
        uid,
        position.latitude,
        position.longitude,
      );
      // Also update the location string
      final workerSnap = await FirebaseFirestore.instance
          .collection('workers')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (workerSnap.docs.isNotEmpty) {
        await workerSnap.docs.first.reference.update({'location': address});
      }
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
          _locationStatus = '✓ Updated: $address';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated to: $address'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
          _locationStatus = 'Failed to update';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    final workerName = _worker?.name ?? user?.displayName ?? 'Professional';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentitySection(workerName),
                const SizedBox(height: 24),
                _buildMetricCard(),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 48),
                _buildLogout(context),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Center(
      child: TextButton(
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
                    _authService.signOut();
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
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        child: Text(
          'Log Out',
          style: AppTheme.headline(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING,';
    if (hour < 17) return 'GOOD AFTERNOON,';
    return 'GOOD EVENING,';
  }

  Widget _buildIdentitySection(String workerName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting,
              style: AppTheme.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              workerName,
              style: AppTheme.headline(fontSize: 30, letterSpacing: -1.0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _isAvailable ? 'AVAILABLE NOW' : 'OFFLINE',
              style: AppTheme.label(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _isAvailable ? AppColors.secondary : AppColors.outline,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 56,
              height: 32,
              child: Switch(
                value: _isAvailable,
                onChanged: _toggleAvailability,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.secondary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: AppColors.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.blue50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '${_worker?.totalJobs ?? 0}',
            style: AppTheme.headline(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Calls Received',
            style: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionCard(
                Icons.person_outline,
                'Edit Profile',
                'Update skills & info',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                Icons.headset_mic,
                'Help',
                'Support & FAQ',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _updateLocationCard(),
      ],
    );
  }

  Widget _updateLocationCard() {
    return GestureDetector(
      onTap: _isUpdatingLocation ? null : _updateLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                shape: BoxShape.circle,
              ),
              child: _isUpdatingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Location',
                    style: AppTheme.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _locationStatus ?? 'Tap to refresh your GPS location',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: _locationStatus?.startsWith('✓') == true
                          ? AppColors.secondary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTheme.body(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
