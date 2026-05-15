import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/auth/recent_login_store.dart';
import 'package:scholesa_app/router/app_router.dart';
import 'package:scholesa_app/ui/auth/login_page.dart';
import 'package:scholesa_app/ui/landing/landing_page.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;
}

class _FakeAuthService extends Fake implements AuthService {
  String? email;
  String? password;
  int submitCount = 0;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    submitCount += 1;
  }
}

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
  late UrlLauncherPlatform originalUrlLauncher;

  setUp(() {
    originalUrlLauncher = UrlLauncherPlatform.instance;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
  });

  test('web initial location preserves public direct login routes', () {
    expect(
      appInitialLocation(
        isWeb: true,
        unauthenticatedEntry: '/welcome',
        baseUri: Uri.parse('https://scholesa.com/login'),
      ),
      '/login',
    );
    expect(
      appInitialLocation(
        isWeb: true,
        unauthenticatedEntry: '/welcome',
        baseUri: Uri.parse('https://scholesa.com/login?next=%2Flearner'),
      ),
      '/login?next=%2Flearner',
    );
  });

  test('web initial location falls back to welcome at root', () {
    expect(
      appInitialLocation(
        isWeb: true,
        unauthenticatedEntry: '/welcome',
        baseUri: Uri.parse('https://scholesa.com/'),
      ),
      '/welcome',
    );
  });

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
    expect(find.text('Summer Camp 2026'), findsOneWidget);
    expect(find.text('Reserve Summer Camp'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);

    await tester.tap(find.text('Sign In').first);
    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);
  });

  testWidgets('proof flow CTA opens the public video asset',
      (WidgetTester tester) async {
    final _FakeUrlLauncherPlatform urlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = urlLauncher;

    final GoRouter router = GoRouter(
      initialLocation: '/welcome',
      routes: <RouteBase>[
        GoRoute(
          path: '/welcome',
          builder: (BuildContext context, GoRouterState state) =>
              const LandingPage(),
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

    final Finder proofFlowCta = find.text('See the Proof Flow');
    await tester.ensureVisible(proofFlowCta);
    await tester.pumpAndSettle();

    await tester.tap(proofFlowCta);
    await tester.pump();

    expect(urlLauncher.launchedUrls, hasLength(1));
    expect(urlLauncher.launchedUrls.single, endsWith('/videos/proof-flow.mp4'));
  });

  testWidgets('summer camp CTA opens the public camp route',
      (WidgetTester tester) async {
    final _FakeUrlLauncherPlatform urlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = urlLauncher;

    final GoRouter router = GoRouter(
      initialLocation: '/welcome',
      routes: <RouteBase>[
        GoRoute(
          path: '/welcome',
          builder: (BuildContext context, GoRouterState state) =>
              const LandingPage(),
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

    final Finder summerCampCta = find.text('Reserve Summer Camp').first;
    await tester.ensureVisible(summerCampCta);
    await tester.pumpAndSettle();

    await tester.tap(summerCampCta);
    await tester.pump();

    expect(urlLauncher.launchedUrls, hasLength(1));
    expect(urlLauncher.launchedUrls.single, endsWith('/en/summer-camp-2026'));
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

  testWidgets('login page submits email and password credentials',
      (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<AuthService>.value(value: authService),
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'builder@scholesa.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(authService.submitCount, 1);
    expect(authService.email, 'builder@scholesa.test');
    expect(authService.password, 'Test123!');
  });
}
