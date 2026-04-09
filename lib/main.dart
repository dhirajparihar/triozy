import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/session_service.dart';
import 'providers/location_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_shell.dart';
import 'screens/worker_setup_screen.dart';
import 'screens/worker_profile_screen.dart';
import 'screens/account_deletion_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const TriozyApp());
}

class TriozyApp extends StatelessWidget {
  const TriozyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Singleton services — available everywhere via context.read<T>()
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<LocationService>(create: (_) => LocationService()),
        ChangeNotifierProvider<SessionService>(
          create: (_) => SessionService(),
        ),

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
          if (uri != null && uri.pathSegments.length == 2 && uri.pathSegments[0] == 'worker') {
            final workerId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (_) => WorkerProfileScreen(workerId: workerId),
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

/// Checks the web URL on startup for deep links (e.g. /#/worker/uid)
/// and navigates directly to that screen, otherwise falls through to AuthGate.
class _DeepLinkGate extends StatefulWidget {
  const _DeepLinkGate();

  @override
  State<_DeepLinkGate> createState() => _DeepLinkGateState();
}

class _DeepLinkGateState extends State<_DeepLinkGate> {
  Widget? _entryScreen;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _entryScreen = _resolveWebEntryScreen();
    }
  }

  Widget? _resolveWebEntryScreen() {
    final path = Uri.base.path;
    final fragment = Uri.base.fragment; // e.g. "/worker/abc123"
    if (path == '/account-delete' || fragment == '/account-delete') {
      return const AccountDeletionScreen();
    }

    final uri = Uri.tryParse(fragment);
    if (uri != null && uri.pathSegments.length == 2 && uri.pathSegments[0] == 'worker') {
      final workerId = uri.pathSegments[1];
      return WorkerProfileScreen(workerId: workerId);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => _entryScreen ?? const AuthGate();
}

/// AuthGate listens to Firebase auth state and routes accordingly
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
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Triozy',
                    style: AppTheme.headline(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue700,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
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

/// Streams the user doc from Firestore and routes based on role/profile state.
/// Only rebuilds the child widget when the routing decision actually changes
/// (role or isProfileComplete), preventing unnecessary MainShell rebuilds
/// that would reset the current tab index.
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
    final role = userData['role'] as String? ?? 'customer';
    final isComplete = userData['isProfileComplete'] as bool? ?? false;
    return '${role}_$isComplete';
  }

  Widget _buildScreen(Map<String, dynamic> userData) {
    final role = userData['role'] as String? ?? 'customer';
    final isProfileComplete = userData['isProfileComplete'] as bool? ?? false;

    if (role == 'worker') {
      if (!isProfileComplete) {
        return const WorkerSetupScreen();
      } else {
        return const MainShell(isWorker: true);
      }
    } else {
      return const MainShell(isWorker: false);
    }
  }

  Future<void> _autoCreateUser() async {
    if (_isCreatingUser) return;
    _isCreatingUser = true;
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final authService = context.read<AuthService>();
      await authService.saveUser(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        role: 'customer',
        photoUrl: user.photoURL,
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
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final userData = snapshot.data;

        // New user: auto-create Firestore doc as customer, show spinner
        if (userData == null) {
          _autoCreateUser();
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
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
