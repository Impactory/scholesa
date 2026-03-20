import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_integrations_health_page.dart';

AppState _buildHqState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-admin-1',
    'email': 'hq-admin@scholesa.test',
    'displayName': 'HQ Admin',
    'role': 'hq',
    'activeSiteId': 'hq',
    'siteIds': <String>['hq'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness({required Widget child}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      locale: const Locale('en'),
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
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'HQ integrations health shows an explicit load error instead of fake empty telemetry copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: HqIntegrationsHealthPage(
          integrationsLoader: () async {
            throw StateError('integrations backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Integrations health is temporarily unavailable'),
        findsOneWidget);
    expect(
      find.text('We could not load integrations health. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No integration telemetry available'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'HQ integrations health keeps the last successful data visible when refresh fails',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        child: HqIntegrationsHealthPage(
          integrationsLoader: () async {
            loadCount += 1;
            if (loadCount > 1) {
              throw StateError('latest sync job fetch failed');
            }
            return <String, dynamic>{
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'siteId': 'site-1',
                  'siteName': 'Site One',
                  'provider': 'github',
                  'status': 'healthy',
                  'updatedAt': '2026-03-17T10:00:00.000Z',
                },
              ],
              'connections': const <Map<String, dynamic>>[],
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site One'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Unable to refresh integrations health right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Site One'), findsOneWidget);
  });

  testWidgets('HQ integrations health shows a visible error when retry fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: HqIntegrationsHealthPage(
          integrationsLoader: () async => <String, dynamic>{
            'syncJobs': <Map<String, dynamic>>[
              <String, dynamic>{
                'siteId': 'site-1',
                'siteName': 'Site One',
                'provider': 'github',
                'status': 'error',
                'updatedAt': '2026-03-17T10:00:00.000Z',
              },
            ],
            'connections': const <Map<String, dynamic>>[],
          },
          retryIntegrationRunner: (String siteId, String providerKey) async {
            throw StateError('retry rejected');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Site One'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to retry this integration right now.'),
        findsOneWidget);
  });

  testWidgets('HQ integrations health restores expanded site cards on reopen',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    Widget buildPage() {
      return HqIntegrationsHealthPage(
        sharedPreferences: prefs,
        integrationsLoader: () async => <String, dynamic>{
          'syncJobs': <Map<String, dynamic>>[
            <String, dynamic>{
              'siteId': 'site-1',
              'siteName': 'Site One',
              'provider': 'github',
              'status': 'error',
              'updatedAt': '2026-03-17T10:00:00.000Z',
            },
          ],
          'connections': const <Map<String, dynamic>>[],
        },
      );
    }

    await tester.pumpWidget(
      _buildHarness(
        child: buildPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsNothing);

    await tester.tap(find.text('Site One'));
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildHarness(
        child: buildPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);
  });
}