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

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Welcome'))),
      ),
      GoRoute(
        path: '/site/sessions',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: Scaffold(
            body: Center(
              child: Text('Site Sessions Route'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/site/scheduling',
        redirect: (BuildContext context, GoRouterState state) =>
            '/site/sessions',
      ),
    ],
  );
}

void main() {
  testWidgets('/site/sessions denies non-site roles',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildRouterHarness(
        appState: _buildAppState(UserRole.educator),
        router: _buildRouter('/site/sessions'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsOneWidget);
    expect(
      find.text("You don't have permission to access this page."),
      findsOneWidget,
    );
    expect(find.text('Your current role: educator'), findsOneWidget);
    expect(find.text('Site Sessions Route'), findsNothing);
  });

  testWidgets('/site/sessions allows site and HQ roles',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildRouterHarness(
        appState: _buildAppState(UserRole.site),
        router: _buildRouter('/site/sessions'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsNothing);
    expect(find.text('Site Sessions Route'), findsOneWidget);

    await tester.pumpWidget(
      _buildRouterHarness(
        appState: _buildAppState(UserRole.hq),
        router: _buildRouter('/site/sessions'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsNothing);
    expect(find.text('Site Sessions Route'), findsOneWidget);
  });

  testWidgets('/site/scheduling redirects to /site/sessions',
      (WidgetTester tester) async {
    final GoRouter router = _buildRouter('/site/scheduling');
    await tester.pumpWidget(
      _buildRouterHarness(
        appState: _buildAppState(UserRole.site),
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site Sessions Route'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/site/sessions');
  });
}