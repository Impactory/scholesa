import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/settings/settings_page.dart';
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

Widget _buildHarness({required List<SingleChildWidget> providers}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
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
      home: const SettingsPage(),
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
      'settings launches data export support email and the store rating flow',
      (WidgetTester tester) async {
    final AppState state = _buildAppState();
    final ThemeService themeService = ThemeService();
    final _FakeUrlLauncherPlatform launcherPlatform =
        _FakeUrlLauncherPlatform();
    final UrlLauncherPlatform previousLauncherPlatform =
        UrlLauncherPlatform.instance;
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    UrlLauncherPlatform.instance = launcherPlatform;

    try {
      await tester.pumpWidget(
        _buildHarness(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<ThemeService>.value(value: themeService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Download My Data'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_tileTapTarget('Download My Data'));
      await tester.pumpAndSettle();

      expect(find.text('Download My Data'), findsWidgets);
      expect(
        launcherPlatform.launchedUrls,
        contains(
          predicate<String>(
            (String value) => value.startsWith('mailto:support@scholesa.com?'),
          ),
        ),
      );
      expect(
        find.text(
          'Data export requests are not available in the app yet. Contact support with your site ID to request your data.',
        ),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.text('Help & Support'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_tileTapTarget('Help & Support'));
      await tester.pumpAndSettle();

      expect(
        launcherPlatform.launchedUrls
            .where(
              (String value) =>
                  value.startsWith('mailto:support@scholesa.com?'),
            )
            .length,
        greaterThanOrEqualTo(2),
      );

      await tester.scrollUntilVisible(
        find.text('Rate the App'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_tileTapTarget('Rate the App'));
      await tester.pumpAndSettle();

      expect(find.text('Rate the App'), findsOneWidget);
      expect(
        launcherPlatform.launchedUrls,
        contains('market://details?id=com.scholesa.app'),
      );
      expect(
        find.text(
          'In-app rating is not available yet. Please rate Scholesa in your app store when the listing is live.',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      UrlLauncherPlatform.instance = previousLauncherPlatform;
    }
  });

  testWidgets('settings feedback launches support email instead of fake submit',
      (WidgetTester tester) async {
    final AppState state = _buildAppState();
    final ThemeService themeService = ThemeService();
    final _FakeUrlLauncherPlatform launcherPlatform =
        _FakeUrlLauncherPlatform();
    final UrlLauncherPlatform previousLauncherPlatform =
        UrlLauncherPlatform.instance;
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    UrlLauncherPlatform.instance = launcherPlatform;

    try {
      await tester.pumpWidget(
        _buildHarness(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<ThemeService>.value(value: themeService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Send Feedback'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(_tileTapTarget('Send Feedback'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'Please improve the dashboard export flow.');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(
        launcherPlatform.launchedUrls,
        contains(
          predicate<String>(
            (String value) => value.startsWith('mailto:support@scholesa.com?'),
          ),
        ),
      );
      expect(
        find.text(
          'Feedback submission is not available in the app yet. Contact support if you need follow-up.',
        ),
        findsNothing,
      );
      expect(find.text('Feedback sent'), findsNothing);
    } finally {
      UrlLauncherPlatform.instance = previousLauncherPlatform;
    }
  });
}
