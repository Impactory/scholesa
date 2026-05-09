import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/auth/recent_login_store.dart';
import 'package:scholesa_app/ui/auth/login_page.dart';
import 'package:scholesa_app/ui/landing/landing_page.dart';

class _FakeAuthService extends Fake implements AuthService {}

class _FakeRecentLoginStore extends RecentLoginStore {}

Widget _buildLoginHarness() {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<AuthService>.value(value: _FakeAuthService()),
      ChangeNotifierProvider<AppState>(create: (_) => AppState()),
      ChangeNotifierProvider<RecentLoginStore>.value(
        value: _FakeRecentLoginStore(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
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
      home: const LoginPage(),
    ),
  );
}

void main() {
  testWidgets('landing page shows core public messaging and navigates to login',
      (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/welcome',
      routes: <RouteBase>[
        GoRoute(
          path: '/welcome',
          builder: (BuildContext context, GoRouterState state) =>
              const LandingPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('Login Screen'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Capability learning, made visible'), findsOneWidget);
    expect(find.text('Scholesa'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);

    await tester.tap(find.text('Sign In').first);
    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);
  });

  testWidgets('login page validates required email and password fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildLoginHarness());
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });
}
