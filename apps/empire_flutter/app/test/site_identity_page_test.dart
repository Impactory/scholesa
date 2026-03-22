import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_identity_page.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-1-admin',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness(Widget child) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
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

Future<List<Map<String, dynamic>>> _captureTelemetry(
  Future<void> Function() body,
) async {
  final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
  await TelemetryService.runWithDispatcher(
    (Map<String, dynamic> payload) async {
      events.add(Map<String, dynamic>.from(payload));
    },
    body,
  );
  return events;
}

void main() {
  testWidgets(
      'site identity shows a real load error instead of claiming all identities are resolved',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        SiteIdentityPage(
          identityLoader: (String _) async {
            throw StateError('identity backend unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(
      find.text('Identity matches are temporarily unavailable'),
      findsOneWidget,
    );
    expect(
      find.text('We could not load the identity review queue. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('All Identities Resolved'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('site identity keeps stale matches visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        SiteIdentityPage(
          identityLoader: (String _) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'match-1',
                  'status': 'unmatched',
                  'scholesaUserName': 'Ava Stone',
                  'providerUserId': 'ava.stone@classroom.test',
                  'provider': 'google_classroom',
                  'confidence': 0.91,
                  'scholesaUserId': 'learner-1',
                },
              ];
            }
            throw StateError('identity refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('No pending identity matches to review'), findsNothing);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh identity matches right now. Showing the last successful data. Bad state: identity refresh unavailable',
      ),
      findsOneWidget,
    );
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('No pending identity matches to review'), findsNothing);
  });

  testWidgets('site identity approve action re-reads authoritative queue before settling success',
      (WidgetTester tester) async {
    int loadCount = 0;
    final List<Map<String, dynamic>> backendRows = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'match-1',
        'status': 'unmatched',
        'scholesaUserName': 'Ava Stone',
        'providerUserId': 'ava.stone@classroom.test',
        'provider': 'google_classroom',
        'confidence': 0.91,
        'scholesaUserId': 'learner-1',
      },
    ];

    await tester.pumpWidget(
      _buildHarness(
        SiteIdentityPage(
          identityLoader: (String _) async {
            loadCount += 1;
            return backendRows
                .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          },
          identityResolver: (
            String id,
            String _,
            String decision,
            String? __,
          ) async {
            expect(id, 'match-1');
            expect(decision, 'link');
            backendRows[0]['status'] = 'linked';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ava Stone'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve Match'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('Ava Stone'), findsNothing);
    expect(find.text('All Identities Resolved'), findsOneWidget);
    expect(
      find.text('Matched Ava Stone with ava.stone@classroom.test'),
      findsOneWidget,
    );
  });

  testWidgets('site identity keeps stale queue visible when reload fails after approve',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        SiteIdentityPage(
          identityLoader: (String _) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'match-1',
                  'status': 'unmatched',
                  'scholesaUserName': 'Ava Stone',
                  'providerUserId': 'ava.stone@classroom.test',
                  'provider': 'google_classroom',
                  'confidence': 0.91,
                  'scholesaUserId': 'learner-1',
                },
              ];
            }
            throw StateError('identity queue reload unavailable');
          },
          identityResolver: (
            String id,
            String _,
            String decision,
            String? __,
          ) async {
            expect(id, 'match-1');
            expect(decision, 'link');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve Match'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('All Identities Resolved'), findsNothing);
    expect(
      find.text(
        'Unable to refresh identity matches right now. Showing the last successful data. Bad state: identity queue reload unavailable',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Match update was submitted, but the queue could not be reloaded. Retry to verify the current state.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('site identity logs approve telemetry with match context',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        _buildHarness(
          SiteIdentityPage(
            identityLoader: (String _) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'match-1',
                'status': 'unmatched',
                'scholesaUserName': 'Ava Stone',
                'providerUserId': 'ava.stone@classroom.test',
                'provider': 'google_classroom',
                'confidence': 0.91,
                'scholesaUserId': 'learner-1',
              },
            ],
            identityResolver: (
              String id,
              String _,
              String decision,
              String? __,
            ) async {
              expect(id, 'match-1');
              expect(decision, 'link');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve Match'));
      await tester.pump();
      await tester.pumpAndSettle();
    });

    expect(
      events.any((Map<String, dynamic> event) {
        final Map<String, dynamic> metadata =
            Map<String, dynamic>.from(event['metadata'] as Map);
        return event['event'] == 'cta.clicked' &&
            metadata['module'] == 'site_identity' &&
            metadata['cta_id'] == 'approve_identity_match' &&
            metadata['surface'] == 'identity_match_card' &&
            metadata['match_id'] == 'match-1' &&
            metadata['provider'] == 'Google Classroom';
      }),
      isTrue,
    );
  });

  testWidgets('site identity logs ignore telemetry with match context',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        _buildHarness(
          SiteIdentityPage(
            identityLoader: (String _) async => <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'match-1',
                'status': 'unmatched',
                'scholesaUserName': 'Ava Stone',
                'providerUserId': 'ava.stone@classroom.test',
                'provider': 'google_classroom',
                'confidence': 0.91,
                'scholesaUserId': 'learner-1',
              },
            ],
            identityResolver: (
              String id,
              String _,
              String decision,
              String? __,
            ) async {
              expect(id, 'match-1');
              expect(decision, 'ignore');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Ignore'));
      await tester.pump();
      await tester.pumpAndSettle();
    });

    expect(
      events.any((Map<String, dynamic> event) {
        final Map<String, dynamic> metadata =
            Map<String, dynamic>.from(event['metadata'] as Map);
        return event['event'] == 'cta.clicked' &&
            metadata['module'] == 'site_identity' &&
            metadata['cta_id'] == 'ignore_identity_match' &&
            metadata['surface'] == 'identity_match_card' &&
            metadata['match_id'] == 'match-1' &&
            metadata['provider'] == 'Google Classroom';
      }),
      isTrue,
    );
  });
}