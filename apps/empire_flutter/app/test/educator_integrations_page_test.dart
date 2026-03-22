import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_integrations_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildEducatorState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required EducatorService educatorService,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      ChangeNotifierProvider<EducatorService>.value(value: educatorService),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: child,
    ),
  );
}

EducatorService _buildEducatorService() {
  final FirestoreService firestoreService = FirestoreService(
    firestore: FakeFirebaseFirestore(),
    auth: _MockFirebaseAuth(),
  );
  return EducatorService(
    firestoreService: firestoreService,
    educatorId: 'educator-1',
    siteId: 'site-1',
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
      'educator integrations page shows explicit load error and retries successfully',
      (WidgetTester tester) async {
    final EducatorService educatorService = _buildEducatorService();
    int loadCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        child: EducatorIntegrationsPage(
          healthLoader: (String siteId) async {
            loadCalls += 1;
            if (loadCalls == 1) {
              throw Exception('health unavailable');
            }
            return <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'classlink-1',
                  'provider': 'classlink',
                  'status': 'active',
                  'siteId': siteId,
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'job-1',
                  'provider': 'classlink',
                  'status': 'completed',
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                },
              ],
            };
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load integrations right now.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No integrations configured yet'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.text('ClassLink'), findsOneWidget);
    expect(find.text('Unable to load integrations right now.'), findsNothing);
  });

  testWidgets(
      'educator integrations page surfaces sync failure instead of pretending success',
      (WidgetTester tester) async {
    final EducatorService educatorService = _buildEducatorService();

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        child: EducatorIntegrationsPage(
          healthLoader: (String siteId) async => <String, dynamic>{
            'connections': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'classlink-1',
                'provider': 'classlink',
                'status': 'active',
                'siteId': siteId,
              },
            ],
            'syncJobs': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'job-1',
                'provider': 'classlink',
                'status': 'completed',
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              },
            ],
          },
          syncJobTrigger: (_, __) async {
            throw Exception('sync unavailable');
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Unable to queue sync right now.'), findsOneWidget);
    expect(find.textContaining('sync queued'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'educator integrations page keeps stale integrations visible when sync queues but refresh fails',
      (WidgetTester tester) async {
    final EducatorService educatorService = _buildEducatorService();
    int loadCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        child: EducatorIntegrationsPage(
          healthLoader: (String siteId) async {
            loadCalls += 1;
            if (loadCalls == 1) {
              return <String, dynamic>{
                'connections': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'classlink-1',
                    'provider': 'classlink',
                    'status': 'active',
                    'siteId': siteId,
                  },
                ],
                'syncJobs': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'job-1',
                    'provider': 'classlink',
                    'status': 'completed',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  },
                ],
              };
            }
            throw Exception('integrations refresh unavailable');
          },
          syncJobTrigger: (_, __) async {},
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ClassLink'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.text('ClassLink'), findsOneWidget);
    expect(
      find.text('Sync was queued, but integrations could not be refreshed. Retry to verify the current state.'),
      findsOneWidget,
    );
    expect(find.text('Unable to queue sync right now.'), findsNothing);
    expect(find.textContaining('sync queued'), findsNothing);
  });

  testWidgets('educator integrations page logs sync menu telemetry',
      (WidgetTester tester) async {
    final EducatorService educatorService = _buildEducatorService();

    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        _buildHarness(
          educatorService: educatorService,
          child: EducatorIntegrationsPage(
            healthLoader: (String siteId) async => <String, dynamic>{
              'connections': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'classlink-1',
                  'provider': 'classlink',
                  'status': 'active',
                  'siteId': siteId,
                },
              ],
              'syncJobs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'job-1',
                  'provider': 'classlink',
                  'status': 'completed',
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                },
              ],
            },
            syncJobTrigger: (_, __) async {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Now'));
      await tester.pump();
      await tester.pumpAndSettle();
    });

    expect(
      events.any((Map<String, dynamic> event) {
        final Map<String, dynamic> metadata =
            Map<String, dynamic>.from(event['metadata'] as Map);
        return event['event'] == 'cta.clicked' &&
            metadata['module'] == 'educator_integrations' &&
            metadata['cta_id'] == 'integration_menu_action' &&
            metadata['integration_name'] == 'ClassLink' &&
            metadata['action'] == 'Sync';
      }),
      isTrue,
    );
  });
}
