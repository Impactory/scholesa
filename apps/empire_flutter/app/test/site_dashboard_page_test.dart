import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_dashboard_page.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _savedFileName;
String? _savedFileContent;

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required FirestoreService firestoreService,
  required AppState appState,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: appState),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      home: const SiteDashboardPage(),
    ),
  );
}

void main() {
  setUp(() {
    _savedFileName = null;
    _savedFileContent = null;
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('site dashboard hides disconnected pillar telemetry card',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telemetry KPIs'), findsOneWidget);
    expect(find.text('Waiting for first data sync from MiloOS telemetry.'), findsOneWidget);
    expect(find.text('Pillar Progress (Site Average)'), findsNothing);
  });

  testWidgets('site dashboard exports a real report when activity exists',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('siteOpsEvents').doc('event-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'action': 'Check-in',
        'createdAt': DateTime(2026, 3, 18, 10).millisecondsSinceEpoch,
      },
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      _savedFileName = fileName;
      _savedFileContent = content;
      return '/tmp/$fileName';
    };

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        appState: _buildSiteState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text('Site report exported.'), findsOneWidget);
    expect(_savedFileName, contains('site-dashboard'));
    expect(_savedFileContent, contains('Check-in'));
  });
}