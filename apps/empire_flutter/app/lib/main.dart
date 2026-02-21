import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'auth/app_state.dart';
import 'auth/auth_service.dart';
import 'ui/theme/scholesa_theme.dart';
import 'ui/splash/splash_screen.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'services/session_bootstrap.dart';
import 'offline/offline_queue.dart';
import 'offline/sync_coordinator.dart';
import 'router/app_router.dart';
import 'modules/hq_admin/hq_admin.dart';
import 'modules/checkin/checkin.dart';
import 'modules/missions/missions.dart';
import 'modules/habits/habits.dart';
import 'modules/messages/messages.dart';
import 'modules/parent/parent.dart';
import 'modules/educator/educator.dart';
// Firebase options
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await Hive.initFlutter();

  // Initialize Firebase with proper options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Configure emulators if enabled
  if (AppConfig.useEmulators) {
    try {
      final List<String> authParts = AppConfig.authEmulatorHost.split(':');
      await FirebaseAuth.instance.useAuthEmulator(
        authParts[0],
        int.parse(authParts[1]),
      );
    } catch (e) {
      debugPrint('Failed to connect to auth emulator: $e');
    }
  }

  runApp(const ScholesaApp());
}

class ScholesaApp extends StatefulWidget {
  const ScholesaApp({super.key});

  @override
  State<ScholesaApp> createState() => _ScholesaAppState();
}

class _ScholesaAppState extends State<ScholesaApp> {
  static const Duration _minNativeSplashDuration = Duration(milliseconds: 1600);

  late final AppState _appState;
  late final FirestoreService _firestoreService;
  late final StorageService _storageService;
  late final OfflineQueue _offlineQueue;
  late final SyncCoordinator _syncCoordinator;
  late final AuthService _authService;
  late final SessionBootstrap _sessionBootstrap;
  GoRouter? _router;

  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final DateTime initStart = DateTime.now();

    try {
      // Create core services
      _appState = AppState();
      _firestoreService = FirestoreService();
      _storageService = StorageService.instance;
      _offlineQueue = OfflineQueue();
      
      // Initialize offline queue
      await _offlineQueue.init();
      
      _syncCoordinator = SyncCoordinator(
        queue: _offlineQueue,
        firestoreService: _firestoreService,
      );
      await _syncCoordinator.init();

      _authService = AuthService(
        auth: FirebaseAuth.instance,
        firestoreService: _firestoreService,
        appState: _appState,
      );

      _sessionBootstrap = SessionBootstrap(
        auth: FirebaseAuth.instance,
        firestoreService: _firestoreService,
        appState: _appState,
      );

      // Bootstrap session if user is already logged in
      await _sessionBootstrap.initialize();

      // Start listening to auth changes
      _sessionBootstrap.listenToAuthChanges();

      _router = createAppRouter(_appState);

      if (!kIsWeb) {
        final Duration elapsed = DateTime.now().difference(initStart);
        final Duration remaining = _minNativeSplashDuration - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('App initialization failed: $e');
      setState(() {
        _initError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _syncCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ScholesaTheme.light,
        darkTheme: ScholesaTheme.dark,
        themeMode: ThemeMode.system,
        home: _ErrorBootstrapScreen(
          error: _initError!,
          onRetry: () {
            setState(() {
              _initError = null;
              _isInitialized = false;
            });
            _initializeApp();
          },
        ),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ScholesaTheme.light,
        darkTheme: ScholesaTheme.dark,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      );
    }

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider.value(value: _appState),
        ChangeNotifierProvider.value(value: _syncCoordinator),
        Provider.value(value: _firestoreService),
        Provider.value(value: _storageService),
        Provider.value(value: _authService),
        // HQ Admin services
        ChangeNotifierProvider(
          create: (_) => UserAdminService(firestoreService: _firestoreService),
        ),
        // Site Check-in services
        ChangeNotifierProvider(
          create: (_) => CheckinService(
            firestoreService: _firestoreService, 
            siteId: _appState.activeSiteId ?? 'default_site',
          ),
        ),
        // Learner Missions services
        ChangeNotifierProvider(
          create: (_) => MissionService(
            firestoreService: _firestoreService, 
            learnerId: _appState.userId ?? '',
          ),
        ),
        // Learner Habits services
        ChangeNotifierProvider(
          create: (_) => HabitService(
            firestoreService: _firestoreService, 
            learnerId: _appState.userId ?? '',
          ),
        ),
        // Messages services
        ChangeNotifierProvider(
          create: (_) => MessageService(
            firestoreService: _firestoreService, 
            userId: _appState.userId ?? '',
          ),
        ),
        // Parent services
        ChangeNotifierProvider(
          create: (_) => ParentService(
            firestoreService: _firestoreService, 
            parentId: _appState.userId ?? '',
          ),
        ),
        // Educator services
        ChangeNotifierProvider(
          create: (_) => EducatorService(
            firestoreService: _firestoreService, 
            educatorId: _appState.userId ?? '',
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Scholesa',
        debugShowCheckedModeBanner: false,
        theme: ScholesaTheme.light,
        darkTheme: ScholesaTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router!,
      ),
    );
  }
}

class _ErrorBootstrapScreen extends StatelessWidget {

  const _ErrorBootstrapScreen({
    required this.error,
    required this.onRetry,
  });
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to start Scholesa',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
