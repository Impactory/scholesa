import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/services/app_resilience.dart';
import 'package:scholesa_app/ui/auth/global_session_menu.dart';
import 'package:scholesa_app/ui/error/startup_issue_banner.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockAuthService extends Mock implements AuthService {}

const Key _globalSessionMenuButtonKey = ValueKey<String>(
  'global_session_menu_button',
);

AppState _buildAppState(UserRole role) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'user-${role.name}',
    'email': '${role.name}@scholesa.test',
    'displayName': '${role.displayName} User',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required AuthService authService,
  String initialLocation = '/protected',
  Widget protectedChild = const Scaffold(body: Center(child: Text('Protected'))),
}) {
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'global_session_menu_test');
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    navigatorKey: navigatorKey,
    routes: <RouteBase>[
      GoRoute(
        path: '/protected',
        builder: (BuildContext context, GoRouterState state) => protectedChild,
      ),
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Profile Screen'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Settings Screen'))),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Login Screen'))),
      ),
      GoRoute(
        path: '/welcome',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Welcome Screen'))),
      ),
    ],
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      Provider<AuthService>.value(value: authService),
    ],
    child: MaterialApp.router(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            if (child != null) child,
            GlobalSessionMenu(
              navigatorKey: navigatorKey,
            ),
          ],
        );
      },
      routerConfig: router,
    ),
  );
}

void main() {
  group('GlobalSessionMenu', () {
    testWidgets('shows an account menu for every authenticated role',
        (WidgetTester tester) async {
      final _MockAuthService authService = _MockAuthService();
      when(() => authService.signOut(source: any(named: 'source')))
          .thenAnswer((_) async {});

      for (final UserRole role in UserRole.values) {
        await tester.pumpWidget(
          _buildHarness(
            appState: _buildAppState(role),
            authService: authService,
            protectedChild: Scaffold(body: Center(child: Text(role.name))),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Account menu'), findsOneWidget,
            reason: 'global session menu should be visible for ${role.name}');
      }
    });

    testWidgets('signs out from a protected screen and returns to login',
        (WidgetTester tester) async {
      final _MockAuthService authService = _MockAuthService();
      when(() => authService.signOut(source: any(named: 'source')))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildHarness(
          appState: _buildAppState(UserRole.educator),
          authService: authService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_globalSessionMenuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sign out so another family member can switch accounts on this device?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      verify(() => authService.signOut(source: 'global_session_menu'))
          .called(1);
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('renders a direct sign out control on wide authenticated layouts',
        (WidgetTester tester) async {
      final _MockAuthService authService = _MockAuthService();
      when(() => authService.signOut(source: any(named: 'source')))
          .thenAnswer((_) async {});

      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildHarness(
          appState: _buildAppState(UserRole.educator),
          authService: authService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Sign Out'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      verify(() => authService.signOut(source: 'global_session_menu'))
          .called(1);
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('icon-only direct sign out still exposes explicit semantics',
        (WidgetTester tester) async {
      final _MockAuthService authService = _MockAuthService();
      when(() => authService.signOut(source: any(named: 'source')))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(
              value: _buildAppState(UserRole.educator),
            ),
            Provider<AuthService>.value(value: authService),
          ],
          child: MaterialApp(
            theme: ScholesaTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const <Locale>[
              Locale('en'),
              Locale('zh', 'CN'),
              Locale('zh', 'TW'),
            ],
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: SessionSignOutButton(showLabel: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Sign Out'), findsOneWidget);
    });

    testWidgets(
        'startup recovery banner and shared session chrome remain concurrently reachable',
        (WidgetTester tester) async {
      final _MockAuthService authService = _MockAuthService();
      when(() => authService.signOut(source: any(named: 'source')))
          .thenAnswer((_) async {});

      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final AppState appState = _buildAppState(UserRole.educator);

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<AuthService>.value(value: authService),
          ],
          child: MaterialApp(
            theme: ScholesaTheme.light,
            locale: const Locale('zh', 'TW'),
            supportedLocales: const <Locale>[
              Locale('en'),
              Locale('zh', 'CN'),
              Locale('zh', 'TW'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  const Center(child: Text('Protected')),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          StartupIssueBanner(
                            issues: <AppStartupIssue>[
                              AppStartupIssue(
                                serviceKey: 'firebase',
                                message:
                                    'Firebase services were unavailable during startup.',
                              ),
                              AppStartupIssue(
                                serviceKey: 'localStorage',
                                message:
                                    'Local storage was unavailable during startup.',
                              ),
                            ],
                            includeSafeArea: false,
                            padding: EdgeInsets.zero,
                            onDismiss: () {},
                          ),
                          const SizedBox(height: 12),
                          const GlobalSessionMenu(
                            includeSafeArea: false,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('登出'), findsOneWidget);
      expect(find.bySemanticsLabel('帳戶選單'), findsOneWidget);
      expect(find.text('Scholesa 以復原模式啟動'), findsOneWidget);
    });
  });
}
