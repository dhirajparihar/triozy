import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/top_app_bar.dart';
import '../providers/location_provider.dart';
import 'home_screen.dart';
import 'search_results_screen.dart';
import 'jobs_screen.dart';
import 'user_profile_screen.dart';
import 'worker_dashboard_screen.dart';
import 'add_job_screen.dart';

class MainShell extends StatefulWidget {
  final bool isWorker;
  const MainShell({super.key, this.isWorker = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(onSearchTapped: () => setState(() => _currentIndex = 1)),
    const SearchResultsScreen(),
    const JobsScreen(),
    widget.isWorker ? const WorkerDashboardScreen() : const UserProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Trigger shared location fetch (no-op if already loaded)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locProvider = context.read<LocationProvider>();
      locProvider.fetchLocation().then((_) {
        if (locProvider.hasError && mounted) {
          _showLocationDialog();
        }
      });
    });
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Text('Enable Location'),
          ],
        ),
        content: const Text(
          'Triozy needs your location to find nearby service professionals. Please enable location services and grant permission.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Skip', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<LocationProvider>().refreshLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 64,
              bottom: MediaQuery.of(context).padding.bottom + 80,
            ),
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          // Top App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TriozyTopAppBar(
              location: locationProvider.address,
              avatarUrl: FirebaseAuth.instance.currentUser?.photoURL,
              onAvatarTap: () => setState(() => _currentIndex = 3),
            ),
          ),
          // FAB on Home screen
          if (_currentIndex == 0)
            Positioned(
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 112,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddJobScreen()),
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          // Bottom Nav Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}
