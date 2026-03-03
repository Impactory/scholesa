import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_curriculum_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

AppState _buildHqState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-user-1',
    'email': 'hq@scholesa.dev',
    'displayName': 'HQ Admin',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required AppState appState,
}) async {
  final FirestoreService firestoreService = FirestoreService(firestore: firestore);
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      child: MaterialApp(
        theme: _testTheme,
        home: const HqCurriculumPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _createDraftCurriculum(WidgetTester tester, String title) async {
  await tester.tap(find.text('New Curriculum'));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'Title'), title);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
  await tester.pumpAndSettle();

  expect(find.text('Curriculum created'), findsOneWidget);
}

void main() {
  group('HQ curriculum maintenance workflows', () {
    testWidgets('create snapshot bumps mission version and creates snapshot entity',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      await _createDraftCurriculum(tester, 'Snapshot Workflow Curriculum');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snapshot Workflow Curriculum').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Snapshot'));
      await tester.pumpAndSettle();

      expect(find.text('Snapshot created'), findsOneWidget);

      final QuerySnapshot<Map<String, dynamic>> snapshotDocs =
          await firestore.collection('missionSnapshots').get();
      expect(snapshotDocs.docs.length, 1);

      final QuerySnapshot<Map<String, dynamic>> missions =
          await firestore.collection('missions').get();
      expect(missions.docs.length, 1);
      expect(missions.docs.first.data()['version'], '1.0.1');
      expect(missions.docs.first.data()['latestSnapshotId'],
          snapshotDocs.docs.first.id);
    });

    testWidgets('apply rubric creates rubric entity and links mission to rubric',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      await _createDraftCurriculum(tester, 'Rubric Workflow Curriculum');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rubric Workflow Curriculum').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Apply Rubric'));
      await tester.pumpAndSettle();

      expect(find.text('Create Rubric'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Rubric title'),
        'HQ Rubric A',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Criteria (comma-separated)'),
        'Clarity, Agency, Impact',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Rubric'));
      await tester.pumpAndSettle();

      expect(find.text('Rubric applied to this curriculum'), findsOneWidget);

      final QuerySnapshot<Map<String, dynamic>> rubrics =
          await firestore.collection('rubrics').get();
      expect(rubrics.docs.length, 1);
      expect(rubrics.docs.first.data()['title'], 'HQ Rubric A');

      final QuerySnapshot<Map<String, dynamic>> missions =
          await firestore.collection('missions').get();
      expect(missions.docs.length, 1);
      expect(missions.docs.first.data()['rubricId'], rubrics.docs.first.id);
      expect(missions.docs.first.data()['status'], 'review');
      expect(missions.docs.first.data()['rubricApplied'], true);
    });
  });
}
