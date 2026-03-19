import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/hq_admin/hq_curriculum_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

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
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
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
  await tester.tap(find.byType(FloatingActionButton).first);
  await tester.pumpAndSettle();

  await _enterDialogTextField(tester, 0, title);
  await _enterDialogTextField(
    tester,
    1,
    'Curriculum workflow coverage draft.',
  );
  await _enterDialogTextField(tester, 3, 'Systems thinking');
  await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
  await tester.pumpAndSettle();

  expect(find.text('Curriculum created'), findsOneWidget);
}

Future<void> _enterDialogTextField(
  WidgetTester tester,
  int index,
  String value,
) async {
  final Finder dialogFields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  final Finder field = dialogFields.at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('HQ curriculum maintenance workflows', () {
    testWidgets('curriculum status advances from draft to review to published',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);

      await _createDraftCurriculum(tester, 'Status Progression Curriculum');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status Progression Curriculum').first);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.text('Submit for Review').first,
      );

      await tester.tap(find.text('In Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status Progression Curriculum').first);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.text('Publish Curriculum').first,
      );

      final QuerySnapshot<Map<String, dynamic>> missions =
          await firestore.collection('missions').get();
      expect(missions.docs.length, 1);
      expect(missions.docs.first.data()['status'], 'published');
      expect(missions.docs.first.data()['published'], true);
      expect(missions.docs.first.data()['reviewSubmittedBy'], 'hq-user-1');
      expect(missions.docs.first.data()['publishedBy'], 'hq-user-1');
    });

    testWidgets(
        'create snapshot bumps mission version and creates snapshot entity',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      await _createDraftCurriculum(tester, 'Snapshot Workflow Curriculum');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snapshot Workflow Curriculum').first);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.text('Create Snapshot').first,
      );

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

    testWidgets(
        'apply rubric creates rubric entity and links mission to rubric',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      await _createDraftCurriculum(tester, 'Rubric Workflow Curriculum');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rubric Workflow Curriculum').first);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Apply Rubric'),
      );

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

    testWidgets('mark parent summary ready only records readiness metadata',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      await _createDraftCurriculum(
          tester, 'Parent Summary Readiness Curriculum');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent Summary Readiness Curriculum').first);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.text('Mark Parent Summary Ready').first,
      );

      final QuerySnapshot<Map<String, dynamic>> missions =
          await firestore.collection('missions').get();
      expect(missions.docs.length, 1);
      expect(missions.docs.first.data()['parentSummaryShared'], true);
      expect(missions.docs.first.data()['parentSummarySharedBy'], 'hq-user-1');
      expect(missions.docs.first.data()['parentSummarySharedAt'], isNotNull);
    });

    testWidgets('curriculum create persists content authoring metadata',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(tester, firestore: firestore, appState: appState);

      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();

      await _enterDialogTextField(tester, 0, 'Metadata Curriculum');
      await _enterDialogTextField(
        tester,
        1,
        'Curriculum metadata persistence coverage.',
      );
      await _enterDialogTextField(tester, 2, 'fractions, sequencing');
      await _enterDialogTextField(
        tester,
        3,
        'Systems thinking, Reflection',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> missions =
          await firestore.collection('missions').get();
      expect(missions.docs.length, 1);
      final Map<String, dynamic> data = missions.docs.first.data();
      expect(data['description'], 'Curriculum metadata persistence coverage.');
      expect(data['template'], 'Project sprint');
      expect(data['difficulty'], 'Intermediate');
      expect(data['mediaFormat'], 'Mixed media');
      expect(data['approvalStatus'], 'draft');
      expect(data['version'], '1.0');
      expect(
        data['misconceptionTags'],
        <String>['fractions', 'sequencing'],
      );
    });
  });
}
