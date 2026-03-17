import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/modules/profile/profile_page.dart';
import 'package:scholesa_app/modules/settings/settings_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/theme_service.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = <String>[];
  bool canLaunchResult = true;
  bool launchResult = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

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
    return launchResult;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => false;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;
}

class _MockAuthService extends Mock implements AuthService {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-user-1',
    'email': 'site-user-1@scholesa.test',
    'displayName': 'Site Lead',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <dynamic>[],
  });
  return state;
}

Widget _buildHarness({
  required List<SingleChildWidget> providers,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp.router(
      routerConfig: router,
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

Finder _tileTapTarget(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      )
      .first;
}

void main() {
  testWidgets(
      'profile help launches support email and legal entries show notice copy',
      (WidgetTester tester) async {
    final AppState state = _buildAppState();
    final _MockAuthService authService = _MockAuthService();
    final ThemeService themeService = ThemeService();
    final _FakeUrlLauncherPlatform launcherPlatform =
        _FakeUrlLauncherPlatform();
    final UrlLauncherPlatform previousLauncherPlatform =
        UrlLauncherPlatform.instance;
    final GoRouter router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const ProfilePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsPage(),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    UrlLauncherPlatform.instance = launcherPlatform;

    try {
      await tester.pumpWidget(
        _buildHarness(
          router: router,
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: state),
            Provider<AuthService>.value(value: authService),
            ChangeNotifierProvider<ThemeService>.value(value: themeService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_tileTapTarget('Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Open notification preferences and delivery channels.'),
          findsNothing);

      router.go('/profile');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Help & Support'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_tileTapTarget('Help & Support'));
      await tester.pumpAndSettle();

      expect(
        launcherPlatform.launchedUrls,
        contains(
          predicate<String>(
            (String value) => value.startsWith('mailto:support@scholesa.com?'),
          ),
        ),
      );
      expect(find.text('Open help docs and contact support.'), findsNothing);

      await tester.tap(_tileTapTarget('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service Notice'), findsOneWidget);
      expect(
        find.text(
          'Use of Scholesa requires compliance with site and platform safety standards.',
        ),
        findsOneWidget,
      );
      expect(find.text('Review terms and platform usage rules.'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(_tileTapTarget('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy Notice'), findsOneWidget);
      expect(
        find.text(
          'Your data is processed according to Scholesa privacy standards and your site policies.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Review data handling and privacy commitments.'),
        findsNothing,
      );
    } finally {
      UrlLauncherPlatform.instance = previousLauncherPlatform;
    }
  });

  testWidgets(
      'profile edit confirms the live update instead of a saved request',
      (WidgetTester tester) async {
    final AppState state = _buildAppState();
    final _MockAuthService authService = _MockAuthService();
    final ThemeService themeService = ThemeService();
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final _MockUser user = _MockUser();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: auth,
    );
    final GoRouter router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const ProfilePage(),
        ),
      ],
    );

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('site-user-1');
    when(() => user.email).thenReturn('site-user-1@scholesa.test');
    when(() => user.displayName).thenReturn('Site Lead');

    await firestore
        .collection('users')
        .doc('site-user-1')
        .set(<String, dynamic>{
      'displayName': 'Site Lead',
      'email': 'site-user-1@scholesa.test',
      'role': 'site',
      'activeSiteId': 'site-1',
      'siteIds': <String>['site-1'],
    });

    await tester.pumpWidget(
      _buildHarness(
        router: router,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: state),
          Provider<AuthService>.value(value: authService),
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
          Provider<FirestoreService>.value(value: firestoreService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Updated Site Lead');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Profile updated for Updated Site Lead'), findsOneWidget);
    expect(find.text('Profile update request saved for Updated Site Lead'),
        findsNothing);
    expect(find.text('Updated Site Lead'), findsWidgets);

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await firestore.collection('users').doc('site-user-1').get();
    expect(userDoc.data()!['displayName'], 'Updated Site Lead');
  });
}
