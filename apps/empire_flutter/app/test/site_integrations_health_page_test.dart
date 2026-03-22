import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/site/site_integrations_health_page.dart';
import 'package:scholesa_app/services/telemetry_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _FailingRosterImportRepository extends RosterImportRepository {
  _FailingRosterImportRepository({required super.firestore});

  @override
  Future<void> markReviewed({
    required String id,
    required String reviewerId,
    String? reviewNotes,
  }) async {
    throw StateError('roster review write failed');
  }
}

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin-1@scholesa.test',
    'displayName': 'Site Admin One',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({required Widget child}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
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
  testWidgets('site integrations health page shows load error instead of fake empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: SiteIntegrationsHealthPage(
          healthLoader: (_) async => throw Exception('health unavailable'),
          rosterImportRepository:
              RosterImportRepository(firestore: FakeFirebaseFirestore()),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load integrations health'), findsOneWidget);
    expect(
      find.text('Unable to load integrations health right now.'),
      findsOneWidget,
    );
    expect(find.text('No connected integrations found'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'site integrations health page keeps stale connections visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        child: SiteIntegrationsHealthPage(
          healthLoader: (_) async {
            loadCount += 1;
            if (loadCount == 1) {
              return <String, dynamic>{
                'connections': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'google-classroom-1',
                    'provider': 'google_classroom',
                    'status': 'active',
                  },
                ],
                'syncJobs': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'provider': 'google_classroom',
                    'status': 'completed',
                    'createdAt': DateTime(2026, 3, 20, 9),
                  },
                ],
              };
            }
            throw StateError('integrations refresh unavailable');
          },
          rosterImportRepository:
              RosterImportRepository(firestore: FakeFirebaseFirestore()),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Google Classroom'), findsOneWidget);
    expect(find.text('No connected integrations found'), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Showing last loaded integrations data. Unable to refresh integrations health right now. Showing the last successful data. Bad state: integrations refresh unavailable',
      ),
      findsOneWidget,
    );
    expect(find.text('Google Classroom'), findsOneWidget);
    expect(find.text('No connected integrations found'), findsNothing);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('site integrations health page shows a visible error when connect fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: SiteIntegrationsHealthPage(
          healthLoader: (_) async => <String, dynamic>{
            'connections': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'google-classroom-1',
                'provider': 'google_classroom',
                'status': 'disconnected',
              },
            ],
            'syncJobs': <Map<String, dynamic>>[],
          },
          connectionStatusUpdater: (_, __) async {
            throw StateError('integration update failed');
          },
          rosterImportRepository:
              RosterImportRepository(firestore: FakeFirebaseFirestore()),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to update integration right now.'), findsOneWidget);
    expect(find.text('Google Classroom connected'), findsNothing);
  });

  testWidgets('site integrations health page logs connect integration telemetry',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        _buildHarness(
          child: SiteIntegrationsHealthPage(
            healthLoader: (_) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'google-classroom-1',
                  'provider': 'google_classroom',
                  'status': 'disconnected',
                },
              ],
              'syncJobs': <Map<String, dynamic>>[],
            },
            connectionStatusUpdater: (_, __) async {},
            rosterImportRepository:
                RosterImportRepository(firestore: FakeFirebaseFirestore()),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Connect'));
      await tester.pump();
      await tester.pumpAndSettle();
    });

    expect(
      events.any((Map<String, dynamic> event) {
        final Map<String, dynamic> metadata =
            Map<String, dynamic>.from(event['metadata'] as Map);
        return event['event'] == 'cta.clicked' &&
            metadata['module'] == 'site_integrations_health' &&
            metadata['cta_id'] == 'connect_integration' &&
            metadata['surface'] == 'integration_card' &&
            metadata['integration_id'] == 'google-classroom-1';
      }),
      isTrue,
    );
  });

  testWidgets('site integrations health page logs force sync telemetry',
      (WidgetTester tester) async {
    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        _buildHarness(
          child: SiteIntegrationsHealthPage(
            healthLoader: (_) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'google-classroom-1',
                  'provider': 'google_classroom',
                  'status': 'active',
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'provider': 'google_classroom',
                  'status': 'completed',
                  'createdAt': DateTime(2026, 3, 20, 9),
                },
              ],
            },
            syncJobTrigger: (_, __) async {},
            rosterImportRepository:
                RosterImportRepository(firestore: FakeFirebaseFirestore()),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Force Sync'));
      await tester.pump();
      await tester.pumpAndSettle();
    });

    expect(
      events.any((Map<String, dynamic> event) {
        final Map<String, dynamic> metadata =
            Map<String, dynamic>.from(event['metadata'] as Map);
        return event['event'] == 'cta.clicked' &&
            metadata['module'] == 'site_integrations_health' &&
            metadata['cta_id'] == 'force_sync_integration' &&
            metadata['surface'] == 'integration_options_sheet' &&
            metadata['integration_id'] == 'google-classroom-1';
      }),
      isTrue,
    );
  });

  testWidgets('site integrations health page shows a visible error when roster review fails',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('rosterImports').doc('import-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'status': 'pending_provisioning',
        'provider': 'google_classroom',
        'sourceName': 'Advisory Import',
        'sourceId': 'source-1',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        child: SiteIntegrationsHealthPage(
          healthLoader: (_) async => <String, dynamic>{
            'connections': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'google-classroom-1',
                'provider': 'google_classroom',
                'status': 'active',
              },
            ],
            'syncJobs': <Map<String, dynamic>>[],
          },
          rosterImportRepository:
              _FailingRosterImportRepository(firestore: firestore),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Mark reviewed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to mark roster row reviewed right now.'),
      findsOneWidget,
    );
    expect(find.text('Roster row marked reviewed'), findsNothing);
  });
}