import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/router/role_gate.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

AppState _buildAppState(UserRole role) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': '${role.name}-user-1',
    'email': '${role.name}-user-1@scholesa.test',
    'displayName': '${role.name} user',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildRouterHarness({
  required AppState appState,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ScholesaTheme.light,
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

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/educator/learner-supports',
    routes: <RouteBase>[
      GoRoute(
        path: '/educator/learner-supports',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[
            UserRole.educator,
            UserRole.site,
            UserRole.hq,
          ],
          child: Scaffold(
            body: Center(
              child: Text('Educator Learner Supports Route'),
            ),
          ),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('/educator/learner-supports denies learner and parent roles',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildRouterHarness(
        appState: _buildAppState(UserRole.learner),
        router: _buildRouter(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsOneWidget);
    expect(find.text('Your current role: learner'), findsOneWidget);
    expect(find.text('Educator Learner Supports Route'), findsNothing);

    await tester.pumpWidget(
      _buildRouterHarness(
        appState: _buildAppState(UserRole.parent),
        router: _buildRouter(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsOneWidget);
    expect(find.text('Your current role: parent'), findsOneWidget);
    expect(find.text('Educator Learner Supports Route'), findsNothing);
  });

  testWidgets('/educator/learner-supports allows educator, site, and HQ roles',
      (WidgetTester tester) async {
    for (final UserRole role in <UserRole>[
      UserRole.educator,
      UserRole.site,
      UserRole.hq,
    ]) {
      await tester.pumpWidget(
        _buildRouterHarness(
          appState: _buildAppState(role),
          router: _buildRouter(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsNothing);
      expect(find.text('Educator Learner Supports Route'), findsOneWidget);
    }
  });
}