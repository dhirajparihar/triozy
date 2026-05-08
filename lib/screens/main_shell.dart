import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/location_provider.dart';
import '../services/fcm_service.dart';
import '../services/permission_center.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/top_app_bar.dart';
import 'chat_list_screen.dart';
import 'home_screen.dart';
import 'post_listing_screen.dart';
import 'search_results_screen.dart';
import 'services_screen.dart';
import 'user_profile_screen.dart';

enum _LocationDialogAction { skip, openSettings }

class MainShell extends StatefulWidget {
  final bool isWorker;
  final bool isGuest;

  const MainShell({super.key, this.isWorker = false, this.isGuest = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();
  final GlobalKey<SearchResultsScreenState> _exploreKey =
      GlobalKey<SearchResultsScreenState>();

  int _currentIndex = 0;
  DateTime? _lastBackPressedAt;
  bool _isLocationDialogOpen = false;
  String? _profileName;

  late final List<Widget> _screens = [
    HomeScreen(
      key: _homeScreenKey,
      onSearchTapped: () {
        setState(() => _currentIndex = 1);
      },
      onExploreTapped: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SearchResultsScreen(initialQuery: ''),
          ),
        );
      },
      onPropertyTypeSelected: (propertyType) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SearchResultsScreen(initialPropertyType: propertyType),
          ),
        );
      },
    ),
    const ServicesScreen(),
    const ChatListScreen(showScaffold: false),
    UserProfileScreen(isGuest: widget.isGuest),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.fetchLocation().then((_) {
        if (locationProvider.hasError && mounted) {
          _showLocationDialog();
        }
      });

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        context.read<ChatProvider>().initialize(uid);
        // Fetch profile name from Firestore as a fallback when displayName is empty
        AuthService()
            .getUserData(uid)
            .then((data) {
              if (mounted && data != null) {
                final name = (data['name'] ?? '').toString().trim();
                if (name.isNotEmpty) {
                  setState(() => _profileName = name);
                }
              }
            })
            .catchError((_) {});
      }

      FCMService().initialize();
    });
  }

  void _showLocationDialog() {
    if (_isLocationDialogOpen || !mounted) {
      return;
    }
    _isLocationDialogOpen = true;

    showDialog<_LocationDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.location_off, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Enable Location'),
            ],
          ),
          content: const Text(
            'Triozy uses your city to surface more relevant rooms, flatmates, and marketplace listings.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _LocationDialogAction.skip),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _LocationDialogAction.openSettings,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    ).then((action) async {
      _isLocationDialogOpen = false;
      if (action == _LocationDialogAction.openSettings) {
        await PermissionCenter.openSettings();
      }
    });
  }

  Future<bool> _refreshLocationAndPromptIfFailed() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.refreshLocation();
    if (!mounted) {
      return true;
    }
    if (locationProvider.hasError) {
      _showLocationDialog();
      return true;
    }
    _homeScreenKey.currentState?.refreshFromShell();
    return false;
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tap again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openPostListing() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PostListingScreen()),
    );
    if (result == true && mounted) {
      _homeScreenKey.currentState?.refreshFromShell();
      _exploreKey.currentState?.focusAndSearch('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final unreadCount = context.watch<ChatProvider>().totalUnreadCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: _currentIndex == 0
                    ? MediaQuery.of(context).padding.top + 76
                    : MediaQuery.of(context).padding.top,
                bottom: MediaQuery.of(context).padding.bottom + 76,
              ),
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
            if (_currentIndex == 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TriozyTopAppBar(
                  location: locationProvider.address,
                  userDisplayName:
                      FirebaseAuth.instance.currentUser?.displayName ??
                      _profileName ??
                      (FirebaseAuth.instance.currentUser?.email != null
                          ? FirebaseAuth.instance.currentUser!.email!
                                .split('@')
                                .first
                                .replaceAll(RegExp(r'[._]'), ' ')
                          : null),
                  avatarUrl: FirebaseAuth.instance.currentUser?.photoURL,
                  showAvatar: _currentIndex != 3,
                  onAvatarTap: () => setState(() => _currentIndex = 3),
                  onLocationTap: () {
                    _refreshLocationAndPromptIfFailed();
                  },
                  unreadCount: unreadCount,
                  onChatTap: () => setState(() => _currentIndex = 2),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNavBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
              ),
            ),
            if (_currentIndex <= 1)
              Positioned(
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 92,
                child: FloatingActionButton(
                  onPressed: _openPostListing,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
