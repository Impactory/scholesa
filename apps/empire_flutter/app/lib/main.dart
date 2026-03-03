import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'services/api_client.dart';
import 'services/storage_service.dart';
import 'services/session_bootstrap.dart';
import 'services/telemetry_service.dart';
import 'services/theme_service.dart';
import 'offline/offline_queue.dart';
import 'offline/sync_coordinator.dart';
import 'runtime/global_ai_assistant_overlay.dart';
import 'router/app_router.dart';
import 'ui/localization/app_strings.dart';
import 'modules/hq_admin/hq_admin.dart';
import 'modules/checkin/checkin.dart';
import 'modules/provisioning/provisioning_service.dart';
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
    static final List<LocalizationsDelegate<dynamic>> _localizationDelegates =
      <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  static const List<Locale> _supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];
  static const Duration _minNativeSplashDuration = Duration(milliseconds: 1600);

  late final AppState _appState;
  late final FirestoreService _firestoreService;
  late final StorageService _storageService;
  late final OfflineQueue _offlineQueue;
  late final SyncCoordinator _syncCoordinator;
  late final AuthService _authService;
  late final SessionBootstrap _sessionBootstrap;
  late final ThemeService _themeService;
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root_router_navigator');
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
      _themeService = ThemeService();
      await _themeService.initialize();

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

      _router = createAppRouter(
        _appState,
        navigatorKey: _rootNavigatorKey,
      );

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
        onGenerateTitle: (BuildContext context) =>
            AppStrings.of(context, 'app.title'),
        debugShowCheckedModeBanner: false,
        theme: ScholesaTheme.light,
        darkTheme: ScholesaTheme.dark,
        themeMode: _themeService.themeMode,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
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
        onGenerateTitle: (BuildContext context) =>
            AppStrings.of(context, 'app.title'),
        debugShowCheckedModeBanner: false,
        theme: ScholesaTheme.light,
        darkTheme: ScholesaTheme.dark,
        themeMode: _themeService.themeMode,
        localizationsDelegates: _localizationDelegates,
        supportedLocales: _supportedLocales,
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
        ChangeNotifierProvider.value(value: _themeService),
        // HQ Admin services
        ChangeNotifierProvider(
          create: (_) => UserAdminService(firestoreService: _firestoreService),
        ),
        // Site Check-in services
        ChangeNotifierProxyProvider<AppState, CheckinService>(
          create: (_) => CheckinService(
            firestoreService: _firestoreService,
            siteId: '',
          ),
          update:
              (_, AppState appState, CheckinService? previousCheckinService) {
            final String siteId = _normalizeContextValue(appState.activeSiteId);
            if (previousCheckinService != null &&
                previousCheckinService.siteId == siteId) {
              return previousCheckinService;
            }

            final CheckinService service = CheckinService(
              firestoreService: _firestoreService,
              siteId: siteId,
            );
            if (siteId.isNotEmpty &&
                (appState.role == UserRole.site || appState.role == UserRole.hq)) {
              Future<void>.microtask(service.loadTodayData);
            }
            return service;
          },
        ),
        // Site provisioning services
        ChangeNotifierProvider(
          create: (_) => ProvisioningService(
            apiClient: ApiClient(),
            firestore: _firestoreService.firestore,
            auth: FirebaseAuth.instance,
          ),
        ),
        // Learner Missions services
        ChangeNotifierProxyProvider<AppState, MissionService>(
          create: (_) => MissionService(
            firestoreService: _firestoreService,
            learnerId: '',
          ),
          update: (_, AppState appState, MissionService? previousMission) {
            final String learnerId = _normalizeContextValue(appState.userId);
            if (previousMission != null && previousMission.learnerId == learnerId) {
              return previousMission;
            }
            final MissionService service = MissionService(
              firestoreService: _firestoreService,
              learnerId: learnerId,
            );
            if (learnerId.isNotEmpty &&
                (appState.role == UserRole.learner || appState.role == UserRole.hq)) {
              Future<void>.microtask(service.loadMissions);
            }
            return service;
          },
        ),
        // Learner Habits services
        ChangeNotifierProxyProvider<AppState, HabitService>(
          create: (_) => HabitService(
            firestoreService: _firestoreService,
            learnerId: '',
          ),
          update: (_, AppState appState, HabitService? previousHabitService) {
            final String learnerId = _normalizeContextValue(appState.userId);
            if (previousHabitService != null &&
                previousHabitService.learnerId == learnerId) {
              return previousHabitService;
            }
            final HabitService service = HabitService(
              firestoreService: _firestoreService,
              learnerId: learnerId,
            );
            if (learnerId.isNotEmpty &&
                (appState.role == UserRole.learner || appState.role == UserRole.hq)) {
              Future<void>.microtask(service.loadHabits);
            }
            return service;
          },
        ),
        // Messages services
        ChangeNotifierProxyProvider<AppState, MessageService>(
          create: (_) => MessageService(
            firestoreService: _firestoreService,
            userId: '',
          ),
          update: (_, AppState appState, MessageService? previousMessageService) {
            final String userId = _normalizeContextValue(appState.userId);
            if (previousMessageService != null &&
                previousMessageService.userId == userId) {
              return previousMessageService;
            }
            final MessageService service = MessageService(
              firestoreService: _firestoreService,
              userId: userId,
            );
            if (userId.isNotEmpty) {
              Future<void>.microtask(service.loadMessages);
            }
            return service;
          },
        ),
        // Parent services
        ChangeNotifierProxyProvider<AppState, ParentService>(
          create: (_) => ParentService(
            firestoreService: _firestoreService,
            parentId: '',
          ),
          update: (_, AppState appState, ParentService? previousParentService) {
            final String parentId = _normalizeContextValue(appState.userId);
            if (previousParentService != null &&
                previousParentService.parentId == parentId) {
              return previousParentService;
            }
            final ParentService service = ParentService(
              firestoreService: _firestoreService,
              parentId: parentId,
            );
            if (parentId.isNotEmpty &&
                (appState.role == UserRole.parent || appState.role == UserRole.hq)) {
              Future<void>.microtask(service.loadParentData);
            }
            return service;
          },
        ),
        // Educator services
        ChangeNotifierProxyProvider<AppState, EducatorService>(
          create: (_) => EducatorService(
            firestoreService: _firestoreService,
            educatorId: '',
          ),
          update:
              (_, AppState appState, EducatorService? previousEducatorService) {
            final String educatorId = _normalizeContextValue(appState.userId);
            if (previousEducatorService != null &&
                previousEducatorService.educatorId == educatorId) {
              return previousEducatorService;
            }
            final EducatorService service = EducatorService(
              firestoreService: _firestoreService,
              educatorId: educatorId,
            );
            if (educatorId.isNotEmpty &&
                (appState.role == UserRole.educator ||
                    appState.role == UserRole.site ||
                    appState.role == UserRole.hq)) {
              Future<void>.microtask(service.loadTodaySchedule);
            }
            return service;
          },
        ),
      ],
      child: Consumer<ThemeService>(
        builder:
            (BuildContext context, ThemeService themeService, Widget? child) {
          return MaterialApp.router(
            onGenerateTitle: (BuildContext context) =>
                AppStrings.of(context, 'app.title'),
            debugShowCheckedModeBanner: false,
            theme: ScholesaTheme.light,
            darkTheme: ScholesaTheme.dark,
            themeMode: themeService.themeMode,
            localizationsDelegates: _localizationDelegates,
            supportedLocales: _supportedLocales,
            builder: (BuildContext context, Widget? child) {
              return Stack(
                children: <Widget>[
                  if (child != null) child,
                  GlobalAiAssistantOverlay(
                    navigatorKey: _rootNavigatorKey,
                  ),
                ],
              );
            },
            routerConfig: _router!,
          );
        },
      ),
    );
  }

  String _normalizeContextValue(String? value) => value?.trim() ?? '';
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
                  AppStrings.of(context, 'app.bootstrapFailed'),
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
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: const <String, dynamic>{
                        'cta': 'bootstrap_retry',
                        'surface': 'error_bootstrap_screen',
                      },
                    );
                    onRetry();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(AppStrings.of(context, 'app.retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
