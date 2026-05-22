import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/cloudinary_service.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/session_service.dart';
import 'services/chat_service.dart';
import 'providers/location_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/main_shell.dart';
import 'screens/account_deletion_screen.dart';

// === App bootstrap ===========================================================

/// App entry point.
///
/// Initializes Firebase (with platform-aware options), enables Firestore
/// persistence on mobile, then mounts the root widget tree.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Expose the Flutter widget tree to the browser DOM
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  if (Firebase.apps.isEmpty) {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }
  }
  if (!kIsWeb) {
    // Enable offline caching for native platforms.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
  runApp(const TriozyApp());
}

// === Root widget =============================================================

/// Root widget that wires services/providers and routes.
///
/// Keeps service singletons at the top of the tree and delegates initial
/// routing to the deep-link gate.
class TriozyApp extends StatelessWidget {
  const TriozyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services (singletons)
        // Singleton services — available everywhere via context.read<T>()
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<CloudinaryService>(create: (_) => CloudinaryService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<ChatService>(create: (_) => ChatService()),
        ChangeNotifierProvider<SessionService>(create: (_) => SessionService()),
        ChangeNotifierProvider<ChatProvider>(
          create: (ctx) => ChatProvider(ctx.read<ChatService>()),
        ),

        // Derived/shared state
        // Shared location state — depends on LocationService
        ChangeNotifierProxyProvider<LocationService, LocationProvider>(
          create: (ctx) => LocationProvider(ctx.read<LocationService>()),
          update: (_, locationService, previous) =>
              previous ?? LocationProvider(locationService),
        ),
      ],
      child: MaterialApp(
        title: 'Triozy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Route only the special-case deep link here; everything else uses home.
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri != null &&
              uri.pathSegments.length == 1 &&
              uri.pathSegments[0] == 'account-delete') {
            return MaterialPageRoute(
              builder: (_) => const AccountDeletionScreen(),
              settings: settings,
            );
          }
          return null;
        },
        home: const _DeepLinkGate(),
      ),
    );
  }
}

// === Startup gates ===========================================================

/// Checks the web URL on startup for supported deep links and otherwise
/// falls through to the normal auth flow.
///
/// Also enforces a minimum splash duration and decides whether to show
/// onboarding for first-time users.
class _DeepLinkGate extends StatefulWidget {
  const _DeepLinkGate();

  @override
  State<_DeepLinkGate> createState() => _DeepLinkGateState();
}

class _DeepLinkGateState extends State<_DeepLinkGate> {
  Widget? _entryScreen;
  bool _animationCompleted = false;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Web deep links are resolved once at startup.
      _entryScreen = _resolveWebEntryScreen();
    }
    _checkFirstTime();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForAppUpdate());
    // Enforce a minimum display duration for the splash screen so the neat animation plays fully
    // without flickering or jumping when loading data super fast.
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() {
          _animationCompleted = true;
        });
      }
    });
  }

  Future<void> _checkFirstTime() async {
    // Uses shared prefs so onboarding only shows once per install.
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isFirstTime = prefs.getBool('isFirstTime') ?? true;
      });
    }
  }

  Future<void> _checkForAppUpdate() async {
    // Play Store in-app updates are Android-only.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // Ignore update check failures so startup is not blocked outside Play Store.
    }
  }

  Widget? _resolveWebEntryScreen() {
    // Support /account-delete via path or hash fragment routing.
    final path = Uri.base.path;
    final fragment = Uri.base.fragment;
    if (path == '/account-delete' || fragment == '/account-delete') {
      return const AccountDeletionScreen();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_animationCompleted) {
      return const SplashScreen(
        statusText: 'Preparing your next-city move...',
        showLoader: true,
      );
    }

    if (_entryScreen != null) {
      return _entryScreen!;
    }

    if (_isFirstTime) {
      return const OnboardingScreen();
    }

    return const AuthGate();
  }
}

// === Auth and profile routing ===============================================

/// AuthGate listens to Firebase auth state and routes accordingly.
///
/// Guests are routed to a limited MainShell, signed-out users see the
/// welcome screen, and signed-in users continue to role routing.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in → Welcome screen
        if (!snapshot.hasData || snapshot.data == null) {
          if (session.isGuest) {
            return const MainShell(isWorker: false, isGuest: true);
          }
          return const WelcomeScreen();
        }

        // Logged in → check role and redirect
        return const _RoleRouter();
      },
    );
  }
}

/// Streams the user doc from Firestore and routes based on profile state.
///
/// This gate auto-creates a starter user document on first login and keeps
/// the current tab stable by only rebuilding when the route decision changes.
/// Only rebuilds the child widget when the routing decision actually changes
/// (isProfileComplete), preventing unnecessary MainShell rebuilds that would
/// reset the current tab index.
class _RoleRouter extends StatefulWidget {
  const _RoleRouter();

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  // Cache the last route key so we only rebuild when the route changes
  String? _lastRouteKey;
  Widget? _currentScreen;
  bool _isCreatingUser = false;

  /// Derive a simple key from the routing-relevant fields
  String _routeKey(Map<String, dynamic> userData) {
    // Today, routing only depends on profile completeness.
    final isComplete = userData['isProfileComplete'] as bool? ?? false;
    return '$isComplete';
  }

  Widget _buildScreen(Map<String, dynamic> userData) {
    final isProfileComplete = userData['isProfileComplete'] as bool? ?? false;

    if (!isProfileComplete) {
      return const CompleteProfileScreen();
    }

    return const MainShell(isWorker: false);
  }

  Future<void> _autoCreateUser() async {
    // Creates the starter Firestore doc for new users.
    if (_isCreatingUser) return;
    _isCreatingUser = true;
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final authService = context.read<AuthService>();
      await authService.ensureStarterUser(
        user: user,
        email: user.email,
        displayName: user.displayName,
      );
    } catch (_) {
      if (mounted) setState(() => _isCreatingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: authService.userDataStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _currentScreen == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data;

        // New user: create the starter Firestore user document, then continue.
        if (userData == null) {
          _autoCreateUser();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final newKey = _routeKey(userData);

        // Only rebuild if the routing decision changed
        if (newKey != _lastRouteKey) {
          _lastRouteKey = newKey;
          _currentScreen = _buildScreen(userData);
        }

        return _currentScreen!;
      },
    );
  }
}
