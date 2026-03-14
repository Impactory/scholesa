import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/site/site_integrations_health_page.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

AppState _buildSiteAdminState() {
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

Widget _buildHarness({
  required AppState appState,
  required Widget child,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      home: child,
    ),
  );
}

void main() {
  testWidgets('site admin can review queued roster imports',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final RosterImportRepository rosterImportRepository =
        RosterImportRepository(firestore: firestore);
    final AppState appState = _buildSiteAdminState();

    await firestore.collection('rosterImports').doc('import-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'sessionId': 'session-1',
        'educatorId': 'educator-1',
        'status': 'pending_provisioning',
        'source': 'csv_import',
        'rowNumber': 2,
        'displayName': 'CSV Learner',
        'email': 'csv-learner@example.com',
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: appState,
        child: SiteIntegrationsHealthPage(
          healthLoader: (String siteId) async => <String, dynamic>{
            'connections': <Map<String, dynamic>>[],
            'syncJobs': <Map<String, dynamic>>[],
          },
          rosterImportRepository: rosterImportRepository,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Roster Review Queue'), findsOneWidget);
    expect(find.text('CSV Learner'), findsOneWidget);
    expect(find.text('Mark reviewed'), findsOneWidget);

    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();

    final reviewedDoc =
        await firestore.collection('rosterImports').doc('import-1').get();
    expect(reviewedDoc.data()?['status'], 'reviewed');
    expect(reviewedDoc.data()?['reviewedBy'], 'site-admin-1');
    expect(reviewedDoc.data()?['reviewedAt'], isNotNull);

    expect(find.text('Roster row marked reviewed'), findsOneWidget);
  });
}