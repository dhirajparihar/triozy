import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/top_app_bar.dart';
import '../providers/location_provider.dart';
import 'home_screen.dart';
import 'search_results_screen.dart';
import 'requests_screen.dart';
import 'mate_screen.dart';
import 'user_profile_screen.dart';
import 'worker_dashboard_screen.dart';
import 'add_request_screen.dart';
import 'add_mate_screen.dart';
import 'worker_setup_screen.dart';

class MainShell extends StatefulWidget {
  final bool isWorker;
  final bool isGuest;

  const MainShell({super.key, this.isWorker = false, this.isGuest = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPressedAt;
  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();

  late final List<Widget> _screens = [
    HomeScreen(
      key: _homeScreenKey,
      onSearchTapped: () => setState(() => _currentIndex = 1),
      onRequestsTapped: () => setState(() => _currentIndex = 2),
      onMatesTapped: () => setState(() => _currentIndex = 3),
    ),
    const SearchResultsScreen(),
    const RequestsScreen(),
    const MateScreen(),
    widget.isWorker
        ? const WorkerDashboardScreen()
        : UserProfileScreen(isGuest: widget.isGuest),
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

  void _showChangeLocationSheet() {
    final locationProvider = context.read<LocationProvider>();
    final controller = TextEditingController(
      text:
          locationProvider.address == 'Locating...' ||
              locationProvider.address == 'Location unavailable'
          ? ''
          : locationProvider.address,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Location',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use GPS or enter your city/area/pincode.',
                style: TextStyle(fontSize: 13, color: AppColors.outline),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'e.g. Jakkur, Bengaluru',
                  prefixIcon: const Icon(Icons.search_rounded),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) async {
                  final value = controller.text.trim();
                  Navigator.pop(ctx);
                  if (value.isEmpty) return;
                  await _applyManualLocation(value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _useCurrentLocation();
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Use Current'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final value = controller.text.trim();
                        Navigator.pop(ctx);
                        if (value.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a location'),
                            ),
                          );
                          return;
                        }
                        await _applyManualLocation(value);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      await context.read<LocationProvider>().refreshLocation();
      _homeScreenKey.currentState?.refreshFromShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update location: $e')));
    }
  }

  Future<void> _applyManualLocation(String value) async {
    try {
      await context.read<LocationProvider>().setLocationFromAddress(value);
      _homeScreenKey.currentState?.refreshFromShell();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location updated to ${context.read<LocationProvider>().address}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update location: $e')));
    }
  }

  void _handleBackNavigation() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    final now = DateTime.now();
    const exitWindow = Duration(seconds: 2);
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= exitWindow;

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    _homeScreenKey.currentState?.refreshFromShell();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tap again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openWorkerRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to register as a service provider.'),
        ),
      );
      return;
    }

    await context.read<AuthService>().saveUser(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      role: 'worker',
      photoUrl: user.photoURL,
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WorkerSetupScreen()),
      (route) => false,
    );
  }

  void _onGlobalFabTap() {
    if (_currentIndex == 0 || _currentIndex == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddRequestScreen()),
      );
      return;
    }

    if (_currentIndex == 1) {
      _openWorkerRegistration();
      return;
    }

    if (_currentIndex == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddMateScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                bottom: MediaQuery.of(context).padding.bottom + 72,
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
                onAvatarTap: () => setState(() => _currentIndex = 4),
                onLocationTap: _showChangeLocationSheet,
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
            // Shared FAB for Home, Search, Requests and Mates (kept above nav)
            if (_currentIndex >= 0 && _currentIndex <= 3)
              Positioned(
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 74,
                child: Builder(
                  builder: (_) {
                    const fabSize = 56.0;
                    return GestureDetector(
                      onTap: _onGlobalFabTap,
                      child: Container(
                        width: fabSize,
                        height: fabSize,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryContainer,
                              AppColors.primary,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
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
