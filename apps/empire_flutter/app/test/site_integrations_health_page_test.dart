import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/site/site_integrations_health_page.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

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
}