import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/site/site_integrations_health_page.dart';
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
        'Unable to refresh integrations health right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Google Classroom'), findsOneWidget);
    expect(find.text('No connected integrations found'), findsNothing);
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