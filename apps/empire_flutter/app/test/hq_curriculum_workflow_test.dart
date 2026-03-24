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
  Widget page = const HqCurriculumPage(),
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
        home: page,
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
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Progression descriptors (one per line)',
        ),
        'Emerging: needs prompting to connect evidence to the claim.\nSecure: explains how the artifact proves the capability.\nAdvanced: transfers the capability to a new build challenge.',
      );
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Checkpoint mappings (phase: guidance)',
        ),
        'checkpoint: Ask the learner to point to the exact artifact that proves current understanding.\nreflection: Capture what they would improve before portfolio curation.',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Rubric'));
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> rubrics =
          await firestore.collection('rubrics').get();
      expect(rubrics.docs.length, 1);
      expect(rubrics.docs.first.data()['title'], 'HQ Rubric A');
      expect(rubrics.docs.first.data()['progressionDescriptors'], <String>[
        'Emerging: needs prompting to connect evidence to the claim.',
        'Secure: explains how the artifact proves the capability.',
        'Advanced: transfers the capability to a new build challenge.',
      ]);
      expect(rubrics.docs.first.data()['checkpointMappings'], <Map<String, dynamic>>[
        <String, dynamic>{
          'phaseKey': 'checkpoint',
          'phaseLabel': 'Checkpoint',
          'guidance': 'Ask the learner to point to the exact artifact that proves current understanding.',
        },
        <String, dynamic>{
          'phaseKey': 'reflection',
          'phaseLabel': 'Reflection',
          'guidance': 'Capture what they would improve before portfolio curation.',
        },
      ]);

      final QuerySnapshot<Map<String, dynamic>> missions =
          await firestore.collection('missions').get();
      expect(missions.docs.length, 1);
      expect(missions.docs.first.data()['rubricId'], rubrics.docs.first.id);
      expect(missions.docs.first.data()['progressionDescriptors'], <String>[
        'Emerging: needs prompting to connect evidence to the claim.',
        'Secure: explains how the artifact proves the capability.',
        'Advanced: transfers the capability to a new build challenge.',
      ]);
      expect(missions.docs.first.data()['checkpointMappings'], <Map<String, dynamic>>[
        <String, dynamic>{
          'phaseKey': 'checkpoint',
          'phaseLabel': 'Checkpoint',
          'guidance': 'Ask the learner to point to the exact artifact that proves current understanding.',
        },
        <String, dynamic>{
          'phaseKey': 'reflection',
          'phaseLabel': 'Reflection',
          'guidance': 'Capture what they would improve before portfolio curation.',
        },
      ]);
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

    testWidgets(
        'curriculum page shows explicit unavailable state on failed first load',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async {
            throw Exception('curricula unavailable');
          },
          trainingCyclesLoader: () async => const <Map<String, dynamic>>[],
        ),
      );

      expect(
          find.text('Curricula are temporarily unavailable'), findsOneWidget);
      expect(
        find.text(
            'We could not load curricula right now. Retry to check the current state.'),
        findsOneWidget,
      );
      expect(find.text('No published curricula'), findsNothing);
    });

    testWidgets(
        'curriculum page keeps stale curricula visible after refresh failure',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      int curriculaCalls = 0;
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async {
            curriculaCalls += 1;
            if (curriculaCalls > 1) {
              throw Exception('curricula refresh failed');
            }
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'curriculum-1',
                'title': 'Published Capability Sprint',
                'description': 'Capability-first published curriculum',
                'pillar': 'Future Skills',
                'template': 'Project sprint',
                'difficulty': 'Intermediate',
                'mediaFormat': 'Mixed media',
                'version': '1.0',
                'approvalStatus': 'approved',
                'status': 'published',
                'updatedAt': DateTime(2026, 3, 20).toIso8601String(),
              },
            ];
          },
          trainingCyclesLoader: () async => const <Map<String, dynamic>>[],
        ),
      );

      expect(find.text('Published Capability Sprint'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Unable to refresh curricula right now. Showing the last successful data.'),
        findsOneWidget,
      );
      expect(find.text('Published Capability Sprint'), findsOneWidget);
    });

    testWidgets(
        'training cycles sheet shows explicit unavailable state on failed load',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async => const <Map<String, dynamic>>[],
          trainingCyclesLoader: () async {
            throw Exception('training cycles unavailable');
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.school_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Training cycles are temporarily unavailable'),
          findsOneWidget);
      expect(
        find.text(
            'We could not load training cycles right now. Retry to check the current state.'),
        findsOneWidget,
      );
      expect(find.text('No training cycles yet'), findsNothing);
    });

    testWidgets(
        'training cycles sheet keeps stale cycles visible after refresh failure',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      int cycleCalls = 0;
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async => const <Map<String, dynamic>>[],
          trainingCyclesLoader: () async {
            cycleCalls += 1;
            if (cycleCalls > 1) {
              throw Exception('training cycle refresh failed');
            }
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'cycle-1',
                'title': 'Term Launch Cohort',
                'trainingType': 'term_launch',
                'audience': 'educators',
                'termLabel': 'Term 2',
                'status': 'scheduled',
                'updatedAt': DateTime(2026, 3, 20).toIso8601String(),
              },
            ];
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.school_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Term Launch Cohort'), findsOneWidget);
      expect(
        find.text(
            'Unable to refresh training cycles right now. Showing the last successful data.'),
        findsOneWidget,
      );
      expect(find.text('Term Launch Cohort'), findsOneWidget);
    });

    testWidgets('session capability readiness shows blocked and ready sessions',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async => const <Map<String, dynamic>>[],
          trainingCyclesLoader: () async => const <Map<String, dynamic>>[],
          sessionReadinessLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'session-blocked',
              'title': 'Impact Studio',
              'pillar': 'Impact & Innovation',
              'pillarCode': 'IMP',
              'siteId': 'site-1',
              'educatorName': 'A. Educator',
              'startTime': DateTime(2026, 4, 12, 9).toIso8601String(),
              'mappedCapabilityCount': 0,
            },
            <String, dynamic>{
              'id': 'session-ready',
              'title': 'Systems Lab',
              'pillar': 'Future Skills',
              'pillarCode': 'FS',
              'siteId': 'site-1',
              'educatorName': 'B. Educator',
              'startTime': DateTime(2026, 4, 12, 11).toIso8601String(),
              'mappedCapabilityCount': 2,
            },
          ],
        ),
      );

      expect(find.text('Upcoming session capability coverage'), findsOneWidget);
      expect(find.text('Impact Studio'), findsOneWidget);
      expect(find.text('Systems Lab'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('0 mapped capabilities'), findsOneWidget);
      expect(find.text('2 mapped capabilities'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Create mapped curriculum'),
          findsOneWidget);
    });

    testWidgets('blocked session action opens mapped curriculum workflow',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async => const <Map<String, dynamic>>[],
          trainingCyclesLoader: () async => const <Map<String, dynamic>>[],
          sessionReadinessLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'session-blocked',
              'title': 'Agency Seminar',
              'pillar': 'Leadership & Agency',
              'pillarCode': 'LEAD',
              'siteId': 'site-1',
              'educatorName': 'C. Educator',
              'startTime': DateTime(2026, 4, 12, 9).toIso8601String(),
              'mappedCapabilityCount': 0,
            },
          ],
        ),
      );

      final Finder createButton =
          find.widgetWithText(OutlinedButton, 'Create mapped curriculum');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('New Curriculum'), findsWidgets);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('HQ mapping request queue shows open school escalations',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: HqCurriculumPage(
          curriculaLoader: () async => const <Map<String, dynamic>>[],
          trainingCyclesLoader: () async => const <Map<String, dynamic>>[],
          sessionReadinessLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'session-blocked',
              'title': 'Impact Studio',
              'pillar': 'Impact & Innovation',
              'pillarCode': 'IMP',
              'siteId': 'site-1',
              'startTime': DateTime(2026, 4, 12, 9).toIso8601String(),
              'mappedCapabilityCount': 0,
            },
          ],
          mappingRequestLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'request-1',
              'sessionId': 'session-blocked',
              'sessionTitle': 'Impact Studio',
              'pillar': 'Impact & Innovation',
              'siteId': 'site-1',
              'requesterName': 'Site Admin',
              'requesterRole': 'site',
              'submittedAt': DateTime(2026, 4, 11, 8).toIso8601String(),
              'message':
                  'Educators are blocked from live evidence capture until mapping is added.',
            },
          ],
        ),
      );

      expect(find.text('HQ mapping requests'), findsOneWidget);
      expect(find.text('Impact Studio'), findsNWidgets(2));
      expect(find.text('Awaiting mapping'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Open mapping workflow'),
          findsOneWidget);
    });

    testWidgets('HQ mapping request resolution updates support request status',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AppState appState = _buildHqState();
      await firestore.collection('supportRequests').doc('request-1').set(
        <String, dynamic>{
          'requestType': 'session_capability_mapping',
          'siteId': 'site-1',
          'userName': 'Site Admin',
          'role': 'site',
          'subject': 'Session capability mapping request: Future Skills Lab',
          'message': 'Mapping needed before studio capture.',
          'status': 'open',
          'submittedAt': Timestamp.fromDate(DateTime(2026, 4, 11, 8)),
          'metadata': <String, dynamic>{
            'sessionId': 'session-ready',
            'sessionTitle': 'Future Skills Lab',
            'pillar': 'Future Skills',
          },
        },
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: appState,
        page: const HqCurriculumPage(
          curriculaLoader: null,
          trainingCyclesLoader: null,
          sessionReadinessLoader: null,
        ),
      );

      await firestore.collection('sessions').doc('session-ready').set(
        <String, dynamic>{
          'siteId': 'site-1',
          'title': 'Future Skills Lab',
          'pillar': 'Future Skills',
          'startTime':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        },
      );
      await firestore.collection('capabilities').doc('capability-1').set(
        <String, dynamic>{
          'title': 'Systems thinking',
          'pillarCode': 'FS',
          'siteId': 'site-1',
        },
      );
      await firestore.collection('capabilities').doc('capability-2').set(
        <String, dynamic>{
          'title': 'Reflection',
          'pillarCode': 'FS',
        },
      );
      await firestore.collection('missions').doc('mission-1').set(
        <String, dynamic>{
          'title': 'Future Skills Mission',
          'pillar': 'Future Skills',
          'pillarCode': 'FS',
          'siteId': 'site-1',
          'capabilityIds': <String>['capability-1'],
          'capabilityTitles': <String>['Systems thinking'],
          'status': 'draft',
        },
      );

      await tester.tap(find.byIcon(Icons.refresh_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Ready to resolve'), findsOneWidget);

      final Finder resolveButton =
          find.widgetWithText(FilledButton, 'Resolve request');
      await tester.ensureVisible(resolveButton);
      await tester.tap(resolveButton);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Resolution note (optional)'),
        'Mapped Future Skills coverage to the studio mission and refreshed readiness.',
      );
      await tester
          .tap(find.widgetWithText(FilledButton, 'Resolve request').last);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mapping request resolved'), findsOneWidget);
      expect(find.text('Future Skills Lab'), findsOneWidget);

      final DocumentSnapshot<Map<String, dynamic>> requestDoc =
          await firestore.collection('supportRequests').doc('request-1').get();
      expect(requestDoc.data()?['status'], 'resolved');
      expect(requestDoc.data()?['resolvedBy'], 'hq-user-1');
      expect(requestDoc.data()?['resolutionSupportingCapabilityCount'], 2);
      expect(
        requestDoc.data()?['resolutionSupportingCapabilityTitles'],
        containsAll(<String>['Systems thinking', 'Reflection']),
      );
      expect(
        requestDoc.data()?['resolutionSummary'],
        contains('2 mapped capabilities'),
      );
      expect(
        requestDoc.data()?['resolutionSupportingCurriculumTitles'],
        contains('Future Skills Mission'),
      );
      expect(
        requestDoc.data()?['resolutionSupportingCurriculumIds'],
        contains('mission-1'),
      );
      expect(
        requestDoc.data()?['resolutionOperatorNote'],
        'Mapped Future Skills coverage to the studio mission and refreshed readiness.',
      );
    });
  });
}
