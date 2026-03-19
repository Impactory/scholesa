import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_role_switcher_page.dart';

AppState _buildHqState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-1',
    'email': 'hq-1@scholesa.test',
    'displayName': 'HQ One',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness(AppState appState) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/switcher'),
                child: const Text('Open role switcher'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/switcher',
        builder: (BuildContext context, GoRouterState state) =>
            const HqRoleSwitcherPage(),
      ),
    ],
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
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
    ),
  );
}

void main() {
  testWidgets('HQ role switcher activates learner impersonation and returns to launcher',
      (WidgetTester tester) async {
    final AppState appState = _buildHqState();

    await tester.pumpWidget(_buildHarness(appState));
    await tester.tap(find.text('Open role switcher'));
    await tester.pumpAndSettle();

    expect(find.text('Role Impersonation'), findsOneWidget);
    expect(find.text('Your actual role'), findsOneWidget);
    expect(find.text('HQ'), findsOneWidget);

    await tester.ensureVisible(find.text('Learner').first);
    await tester.tap(find.text('Learner').first);
    await tester.pumpAndSettle();

    expect(find.text('Open role switcher'), findsOneWidget);
    expect(appState.impersonatingRole, UserRole.learner);
    expect(appState.role, UserRole.learner);
  });

  testWidgets('HQ role switcher exits impersonation from the current role panel',
      (WidgetTester tester) async {
    final AppState appState = _buildHqState();
    appState.setImpersonation(UserRole.educator);

    await tester.pumpWidget(_buildHarness(appState));
    await tester.tap(find.text('Open role switcher'));
    await tester.pumpAndSettle();

    expect(find.text('Viewing as educator'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(find.byTooltip('Exit impersonation'));
    await tester.pumpAndSettle();

    expect(find.text('Viewing as educator'), findsNothing);
    expect(appState.impersonatingRole, isNull);
    expect(appState.role, UserRole.hq);
  });
}