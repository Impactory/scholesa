import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_mission_review_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/missions/missions_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/modules/parent/parent_billing_page.dart';
import 'package:scholesa_app/modules/parent/parent_child_page.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_schedule_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

final ThemeData _workflowTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

String? _savedFileName;
String? _savedFileContent;

class _StubParentService extends ParentService {
  _StubParentService({
    required super.firestoreService,
    required super.parentId,
    required this.stubLearnerSummaries,
    required this.stubBillingSummary,
  });

  final List<LearnerSummary> stubLearnerSummaries;
  final BillingSummary? stubBillingSummary;

  @override
  List<LearnerSummary> get learnerSummaries => stubLearnerSummaries;

  @override
  BillingSummary? get billingSummary => stubBillingSummary;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadParentData() async {}
}

AppState _buildParentState({
  String userId = 'parent-1',
  String email = 'parent001.demo@scholesa.org',
  String displayName = 'Parent One',
}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

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

AppState _buildLearnerWorkflowState({
  required String userId,
  required String email,
  required String displayName,
}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

AppState _buildEducatorWorkflowState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

Future<void> _seedParentData(FakeFirebaseFirestore firestore) async {
  final DateTime now = DateTime.now();
  final DateTime anchor = DateTime(now.year, now.month, now.day, 12);
  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'role': 'parent',
    'displayName': 'Parent One',
    'learnerIds': <String>['learner-1'],
  });
  await firestore
      .collection('guardianLinks')
      .doc('link-1')
      .set(<String, dynamic>{
    'parentId': 'parent-1',
    'learnerId': 'learner-1',
  });
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Ava Learner',
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Unaffiliated Learner',
    'parentIds': <String>['other-parent'],
  });
  await firestore
      .collection('learnerProgress')
      .doc('learner-1')
      .set(<String, dynamic>{
    'level': 4,
    'totalXp': 1200,
    'missionsCompleted': 5,
    'currentStreak': 7,
    'futureSkillsProgress': 0.8,
    'leadershipProgress': 0.6,
    'impactProgress': 0.4,
  });
  await firestore
      .collection('activities')
      .doc('activity-1')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Build a Robot',
    'description': 'Linked Update',
    'type': 'mission',
    'emoji': '🤖',
    'timestamp': Timestamp.fromDate(anchor.subtract(const Duration(hours: 2))),
  });
  await firestore
      .collection('activities')
      .doc('activity-2')
      .set(<String, dynamic>{
    'learnerId': 'learner-2',
    'title': 'Hidden Project',
    'description': 'Hidden Update',
    'type': 'mission',
    'emoji': '🕶',
    'timestamp': Timestamp.fromDate(anchor.subtract(const Duration(hours: 1))),
  });
  await firestore.collection('events').doc('event-1').set(<String, dynamic>{
    'learnerId': 'learner-1',
    'title': 'Robotics Studio',
    'description': 'Prototype review',
    'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 1))),
    'type': 'future_skills',
    'location': 'Lab 1',
  });
  await firestore.collection('events').doc('event-2').set(<String, dynamic>{
    'learnerId': 'learner-2',
    'title': 'Hidden Session',
    'description': 'Should not appear',
    'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 2))),
    'type': 'future_skills',
    'location': 'Hidden Lab',
  });
  await firestore
      .collection('attendanceRecords')
      .doc('attendance-1')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'status': 'present',
    'recordedAt': Timestamp.fromDate(anchor.subtract(const Duration(days: 1))),
  });
  await firestore.collection('portfolioItems').doc('learner-1-activity-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'title': 'Build a Robot',
      'description': 'Linked Update',
      'pillarCodes': const <String>['future_skills'],
      'verificationStatus': 'reviewed',
      'progressionDescriptors': const <String>[
        'Learner justifies prototype choices with direct evidence.',
      ],
      'checkpointMappings': const <Map<String, dynamic>>[
        <String, dynamic>{
          'phase': 'review',
          'guidance':
              'Confirm the learner can explain the tradeoff independently.',
        },
      ],
      'createdAt':
          Timestamp.fromDate(anchor.subtract(const Duration(hours: 2))),
      'updatedAt':
          Timestamp.fromDate(anchor.subtract(const Duration(hours: 1))),
    },
  );
  await firestore
      .collection('capabilityMastery')
      .doc('learner-1-future-capability')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'siteId': 'site-1',
    'capabilityId': 'future-capability',
    'pillarCode': 'future_skills',
    'latestLevel': 4,
    'highestLevel': 4,
    'updatedAt': Timestamp.fromDate(anchor.subtract(const Duration(days: 1))),
  });
  await firestore
      .collection('capabilityMastery')
      .doc('learner-1-leadership-capability')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'siteId': 'site-1',
    'capabilityId': 'leadership-capability',
    'pillarCode': 'leadership',
    'latestLevel': 2,
    'highestLevel': 2,
    'updatedAt': Timestamp.fromDate(anchor.subtract(const Duration(days: 2))),
  });
  await firestore
      .collection('capabilityMastery')
      .doc('learner-1-impact-capability')
      .set(<String, dynamic>{
    'learnerId': 'learner-1',
    'siteId': 'site-1',
    'capabilityId': 'impact-capability',
    'pillarCode': 'impact',
    'latestLevel': 1,
    'highestLevel': 1,
    'updatedAt': Timestamp.fromDate(anchor.subtract(const Duration(days: 3))),
  });
}

Future<void> _seedParentSessionCouplingData(
  FakeFirebaseFirestore firestore,
) async {
  final DateTime now = DateTime.now();
  final DateTime linkedStart = now.add(const Duration(days: 1, hours: 2));
  final DateTime hiddenStart = now.add(const Duration(days: 1, hours: 4));

  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'role': 'parent',
    'displayName': 'Parent One',
    'learnerIds': <String>['learner-1'],
  });
  await firestore
      .collection('guardianLinks')
      .doc('link-1')
      .set(<String, dynamic>{
    'parentId': 'parent-1',
    'learnerId': 'learner-1',
    'siteId': 'site-1',
  });
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Ava Learner',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Hidden Learner',
    'siteIds': <String>['site-1'],
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-1')
      .set(<String, dynamic>{
    'sessionId': 'session-1',
    'learnerId': 'learner-1',
    'status': 'active',
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-2')
      .set(<String, dynamic>{
    'sessionId': 'session-2',
    'learnerId': 'learner-2',
    'status': 'active',
  });
  await firestore
      .collection('sessionOccurrences')
      .doc('occ-1')
      .set(<String, dynamic>{
    'sessionId': 'session-1',
    'siteId': 'site-1',
    'title': 'Prototype Studio',
    'startTime': Timestamp.fromDate(linkedStart),
    'endTime': Timestamp.fromDate(linkedStart.add(const Duration(hours: 1))),
    'roomName': 'Innovation Lab',
  });
  await firestore
      .collection('sessionOccurrences')
      .doc('occ-2')
      .set(<String, dynamic>{
    'sessionId': 'session-2',
    'siteId': 'site-1',
    'title': 'Hidden Session',
    'startTime': Timestamp.fromDate(hiddenStart),
    'endTime': Timestamp.fromDate(hiddenStart.add(const Duration(hours: 1))),
    'roomName': 'Hidden Lab',
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required Widget home,
  ParentService? parentService,
  AppState? appState,
}) async {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
  final ParentService resolvedParentService = parentService ??
      ParentService(
        firestoreService: firestoreService,
        parentId: 'parent-1',
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(
          value: appState ?? _buildParentState(),
        ),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<ParentService>.value(
            value: resolvedParentService),
        Provider<LearningRuntimeProvider?>.value(value: null),
      ],
      child: MaterialApp(
        theme: _workflowTheme,
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
        home: home,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _pumpProvisioningPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
}) async {
  final _MockFirebaseAuth auth = _MockFirebaseAuth();
  final ProvisioningService service = ProvisioningService(
    apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
    firestore: firestore,
    auth: auth,
    useProvisioningApi: false,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
        ChangeNotifierProvider<ProvisioningService>.value(value: service),
      ],
      child: MaterialApp(
        theme: _workflowTheme,
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
        home: const ProvisioningPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _pumpMissionWorkflowPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required AppState appState,
  required MissionService missionService,
  required Widget home,
}) async {
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<MissionService>.value(value: missionService),
        Provider<LearningRuntimeProvider?>.value(value: null),
      ],
      child: MaterialApp(
        theme: _workflowTheme,
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
        home: home,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _seedMissionReviewData(
  FakeFirebaseFirestore firestore, {
  required String learnerId,
}) async {
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': learnerId,
      'siteId': 'site-1',
      'status': 'in_progress',
      'progress': 1.0,
    },
  );
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'title': 'Mission ready for review',
      'description': 'Capture proof of learning before review.',
      'pillarCode': 'future_skills',
      'difficulty': 'beginner',
      'xpReward': 120,
      'rubricId': 'rubric-1',
      'rubricTitle': 'Prototype Rubric',
      'progressionDescriptors': const <String>[
        'Learner explains why the prototype choice fits the observed evidence.',
        'Learner identifies a tradeoff and defends the decision with examples.',
      ],
      'checkpointMappings': const <Map<String, dynamic>>[
        <String, dynamic>{
          'phase': 'review',
          'guidance':
              'Ask the learner to justify the prototype path without prompts.',
        },
      ],
    },
  );
  await firestore
      .collection('missions')
      .doc('mission-1')
      .collection('steps')
      .doc('step-1')
      .set(
    <String, dynamic>{
      'title': 'Prototype',
      'order': 1,
      'isCompleted': true,
      'completedAt': '2026-03-18T10:00:00.000Z',
    },
  );
  await firestore.collection('rubrics').doc('rubric-1').set(
    <String, dynamic>{
      'title': 'Prototype Rubric',
      'progressionDescriptors': const <String>[
        'Learner explains why the prototype choice fits the observed evidence.',
        'Learner identifies a tradeoff and defends the decision with examples.',
      ],
      'checkpointMappings': const <Map<String, dynamic>>[
        <String, dynamic>{
          'phase': 'review',
          'guidance':
              'Ask the learner to justify the prototype path without prompts.',
        },
      ],
      'criteria': <Map<String, dynamic>>[
        <String, dynamic>{
          'criterionId': 'evidence',
          'label': 'Evidence',
          'capabilityId': 'cap-prototype-evidence',
          'capabilityTitle': 'Prototype evidence',
          'pillarCode': 'future_skills',
          'maxScore': 4,
        },
        <String, dynamic>{
          'criterionId': 'reflection',
          'label': 'Reflection',
          'capabilityId': 'cap-prototype-evidence',
          'capabilityTitle': 'Prototype evidence',
          'pillarCode': 'future_skills',
          'maxScore': 4,
        },
      ],
    },
  );
  await firestore.collection('evidenceRecords').doc('evidence-1').set(
    <String, dynamic>{
      'learnerId': learnerId,
      'siteId': 'site-1',
      'capabilityId': 'cap-prototype-evidence',
      'capabilityLabel': 'Prototype evidence',
      'capabilityPillarCode': 'future_skills',
      'observationNote':
          'Learner connected prototype choices to observed tradeoffs.',
      'artifactUrls': const <String>['https://example.com/prototype.png'],
      'nextVerificationPrompt':
          'Explain why this prototype path best matched the evidence.',
      'portfolioCandidate': true,
      'growthStatus': 'captured',
      'observedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 8, 45)),
    },
  );
}

Future<void> _submitMissionForReview(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required AppState learnerState,
  required MissionService missionService,
}) async {
  await _pumpMissionWorkflowPage(
    tester,
    firestore: firestore,
    appState: learnerState,
    missionService: missionService,
    home: const MissionsPage(),
  );
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('In Progress'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  await tester.scrollUntilVisible(
    find.text('No AI support used for this mission'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('No AI support used for this mission'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Explain-it-back summary'),
    'I explained how the control loop reacts to sensor input.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Oral check reflection'),
    'I described the trade-off between speed and stability.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Mini-rebuild plan'),
    'I would rebuild the sensor branch first and retest the response.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Version checkpoint summary'),
    'Completed the working prototype before review.',
  );

  await tester.scrollUntilVisible(
    find.text('Save Checkpoint'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Save Checkpoint'));
  await tester.pump();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  await tester.scrollUntilVisible(
    find.text('Submit for Review'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Submit for Review'));
  await tester.pump();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _approveSubmittedMission(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required MissionService missionService,
}) async {
  await _pumpMissionWorkflowPage(
    tester,
    firestore: firestore,
    appState: _buildEducatorWorkflowState(),
    missionService: missionService,
    home: const EducatorMissionReviewPage(),
  );

  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.data == 'Reflection' &&
          widget.style?.fontWeight == FontWeight.w600,
    ),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('4/4').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('3/4').at(1));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField).last,
    'Great iteration. Tighten the evidence trail and explain the tradeoffs in your next revision.',
  );

  await tester.scrollUntilVisible(
    find.text('Approve'),
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Approve'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _savedFileName = null;
    _savedFileContent = null;
    ExportService.instance.debugSaveTextFile = null;
  });

  group('Parent surface workflows', () {
    test('parent callable parser leaves missing current level empty', () {
      expect(ParentService.currentLevelFromBundleValue(null), 0);
      expect(ParentService.currentLevelFromBundleValue(0), 0);
      expect(ParentService.currentLevelFromBundleValue(-2), 0);
      expect(ParentService.currentLevelFromBundleValue(2.6), 3);
    });

    test('parent service fallback builds linked schedule and portfolio data',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);
      await _seedParentSessionCouplingData(firestore);

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final ParentService service = ParentService(
        firestoreService: firestoreService,
        parentId: 'parent-1',
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await service.loadParentData();

      expect(service.error, isNull);
      expect(service.learnerSummaries, hasLength(1));
      final LearnerSummary learner = service.learnerSummaries.first;
      expect(
        learner.upcomingEvents.map((UpcomingEvent event) => event.title),
        contains('Prototype Studio'),
      );
      expect(
        learner.upcomingEvents.map((UpcomingEvent event) => event.title),
        isNot(contains('Hidden Session')),
      );
      expect(
        learner.portfolioItemsPreview
            .map((PortfolioPreviewItem item) => item.title),
        contains('Build a Robot'),
      );
      expect(learner.currentLevel, 2);
      expect(learner.growthSummary.averageLevel, closeTo(7 / 3, 0.001));
      expect(learner.pillarProgress['futureSkills'], closeTo(1.0, 0.001));
      expect(learner.pillarProgress['leadership'], closeTo(0.5, 0.001));
      expect(learner.pillarProgress['impact'], closeTo(0.25, 0.001));
    });

    testWidgets('summary page only renders linked learner activity',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSummaryPage(),
      );

      expect(find.text('Ava Learner'), findsOneWidget);
      expect(find.text('Build a Robot'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);
      expect(find.text('View Child Detail'), findsOneWidget);
      expect(find.text('View Consent'), findsOneWidget);
      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    });

    testWidgets(
        'child page shows learners linked through provisioning guardian links',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await _pumpProvisioningPage(tester, firestore: firestore);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nia Passport',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nia.passport@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parents').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Pat Passport');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pat.passport@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '555-0115');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'nia.passport@example.com')
          .get();
      expect(learnerUsers.docs, hasLength(1));
      final String learnerId = learnerUsers.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'pat.passport@example.com')
          .get();
      expect(parentUsers.docs, hasLength(1));
      final String parentId = parentUsers.docs.single.id;

      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pat Passport').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nia Passport').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pump();
      await tester.pumpAndSettle();

      await firestore.collection('learnerProgress').doc(learnerId).set(
        <String, dynamic>{
          'level': 4,
          'totalXp': 980,
          'missionsCompleted': 6,
          'currentStreak': 5,
          'futureSkillsProgress': 0.7,
          'leadershipProgress': 0.55,
          'impactProgress': 0.45,
        },
      );
      await firestore.collection('activities').doc('linked-activity-1').set(
        <String, dynamic>{
          'learnerId': learnerId,
          'title': 'Prototype Reflection',
          'description': 'Linked through provisioning',
          'type': 'reflection',
          'emoji': '🧠',
          'timestamp': Timestamp.fromDate(now),
        },
      );
      await firestore.collection('events').doc('linked-event-1').set(
        <String, dynamic>{
          'learnerId': learnerId,
          'title': 'Studio Review',
          'description': 'Evidence conference',
          'dateTime': Timestamp.fromDate(now.add(const Duration(days: 1))),
          'type': 'session',
          'location': 'Lab 2',
        },
      );
      await firestore.collection('portfolioItems').doc('linked-artifact-1').set(
        <String, dynamic>{
          'learnerId': learnerId,
          'title': 'Prototype Artifact',
          'description': 'Verified artifact',
          'verificationStatus': 'reviewed',
          'createdAt':
              Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
          'updatedAt':
              Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        },
      );

      await firestore.collection('users').doc('hidden-learner-1').set(
        <String, dynamic>{
          'role': 'learner',
          'displayName': 'Hidden Learner',
          'siteIds': <String>['site-1'],
        },
      );
      await firestore.collection('activities').doc('hidden-activity-1').set(
        <String, dynamic>{
          'learnerId': 'hidden-learner-1',
          'title': 'Hidden Project',
          'description': 'Should not appear',
          'type': 'mission',
          'emoji': '🕶',
          'timestamp': Timestamp.fromDate(now.add(const Duration(minutes: 1))),
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final ParentService parentService = ParentService(
        firestoreService: firestoreService,
        parentId: parentId,
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: _buildParentState(
          userId: parentId,
          email: 'pat.passport@example.com',
          displayName: 'Pat Passport',
        ),
        parentService: parentService,
        home: ParentChildPage(learnerId: learnerId),
      );

      expect(find.text('Nia Passport'), findsOneWidget);
      expect(find.text('Prototype Reflection'), findsOneWidget);
      expect(find.text('Studio Review'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);
      expect(find.text('Export Passport'), findsOneWidget);
      expect(find.text('View Consent'), findsOneWidget);
    });

    testWidgets(
        'summary page shows learners and activity linked through provisioning guardian links',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await _pumpProvisioningPage(tester, firestore: firestore);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nia Evidence',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nia.parent-summary@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parents').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Pat Guardian');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pat.parent-summary@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '555-0113');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'nia.parent-summary@example.com')
          .get();
      expect(learnerUsers.docs, hasLength(1));
      final String learnerId = learnerUsers.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'pat.parent-summary@example.com')
          .get();
      expect(parentUsers.docs, hasLength(1));
      final String parentId = parentUsers.docs.single.id;

      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pat Guardian').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nia Evidence').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pump();
      await tester.pumpAndSettle();

      await firestore.collection('activities').doc('linked-activity-1').set(
        <String, dynamic>{
          'learnerId': learnerId,
          'title': 'Prototype Reflection',
          'description': 'Linked through provisioning',
          'type': 'reflection',
          'emoji': '🧠',
          'timestamp': Timestamp.fromDate(now),
        },
      );
      await firestore.collection('users').doc('hidden-learner-1').set(
        <String, dynamic>{
          'role': 'learner',
          'displayName': 'Hidden Learner',
          'siteIds': <String>['site-1'],
        },
      );
      await firestore.collection('activities').doc('hidden-activity-1').set(
        <String, dynamic>{
          'learnerId': 'hidden-learner-1',
          'title': 'Hidden Project',
          'description': 'Should not appear',
          'type': 'mission',
          'emoji': '🕶',
          'timestamp': Timestamp.fromDate(now.add(const Duration(minutes: 1))),
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final ParentService parentService = ParentService(
        firestoreService: firestoreService,
        parentId: parentId,
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: _buildParentState(
          userId: parentId,
          email: 'pat.parent-summary@example.com',
          displayName: 'Pat Guardian',
        ),
        parentService: parentService,
        home: const ParentSummaryPage(),
      );

      expect(find.text('Nia Evidence'), findsOneWidget);
      expect(find.text('Prototype Reflection'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);
      expect(find.text('View Child Detail'), findsOneWidget);
    });

    testWidgets('schedule page shows linked session details and reminder flow',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSchedulePage(),
      );

      expect(find.text('Hidden Session'), findsNothing);

      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Next Session Details'), findsOneWidget);
      expect(find.textContaining('Robotics Studio\nLocation: Lab 1'),
          findsOneWidget);
      expect(find.textContaining('Location: Lab 1'), findsOneWidget);

      expect(
          find.widgetWithText(TextButton, 'Request Reminder'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Request Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Session reminder request submitted.'), findsOneWidget);

      final List<Map<String, dynamic>> supportRequests = (await firestore
              .collection('supportRequests')
              .get())
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
      expect(
        supportRequests.any(
          (Map<String, dynamic> request) =>
              request['requestType'] == 'session_reminder' &&
              request['source'] == 'parent_schedule_request_session_reminder' &&
              request['metadata']?['sessionTitle'] == 'Robotics Studio',
        ),
        isTrue,
      );
    });

    testWidgets(
        'schedule page derives upcoming sessions from linked enrollments',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentSessionCouplingData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentSchedulePage(),
      );

      expect(find.text('Hidden Session'), findsNothing);
      expect(find.text('Details'), findsOneWidget);

      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Next Session Details'), findsOneWidget);
      expect(
        find.textContaining('Prototype Studio\nLocation: Innovation Lab'),
        findsOneWidget,
      );
      expect(find.textContaining('Location: Innovation Lab'), findsOneWidget);
      expect(find.textContaining('Hidden Lab'), findsNothing);
    });

    testWidgets(
        'schedule page submits reminder requests for provisioning-linked families',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await _pumpProvisioningPage(tester, firestore: firestore);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nia Schedule',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nia.parent-schedule@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parents').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Pat Schedule');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pat.parent-schedule@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '555-0117');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'nia.parent-schedule@example.com')
          .get();
      expect(learnerUsers.docs, hasLength(1));
      final String learnerId = learnerUsers.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'pat.parent-schedule@example.com')
          .get();
      expect(parentUsers.docs, hasLength(1));
      final String parentId = parentUsers.docs.single.id;

      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pat Schedule').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nia Schedule').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pump();
      await tester.pumpAndSettle();

      await firestore.collection('enrollments').doc('enrollment-linked-1').set(
        <String, dynamic>{
          'sessionId': 'session-linked-1',
          'learnerId': learnerId,
          'status': 'active',
        },
      );
      await firestore
          .collection('sessionOccurrences')
          .doc('occurrence-linked-1')
          .set(
        <String, dynamic>{
          'sessionId': 'session-linked-1',
          'siteId': 'site-1',
          'title': 'Prototype Studio',
          'startTime': Timestamp.fromDate(now.add(const Duration(days: 1))),
          'endTime': Timestamp.fromDate(
            now.add(const Duration(days: 1, hours: 1)),
          ),
          'roomName': 'Innovation Lab',
        },
      );
      await firestore.collection('users').doc('hidden-learner-1').set(
        <String, dynamic>{
          'role': 'learner',
          'displayName': 'Hidden Learner',
          'siteIds': <String>['site-1'],
        },
      );
      await firestore.collection('enrollments').doc('enrollment-hidden-1').set(
        <String, dynamic>{
          'sessionId': 'session-hidden-1',
          'learnerId': 'hidden-learner-1',
          'status': 'active',
        },
      );
      await firestore
          .collection('sessionOccurrences')
          .doc('occurrence-hidden-1')
          .set(
        <String, dynamic>{
          'sessionId': 'session-hidden-1',
          'siteId': 'site-1',
          'title': 'Hidden Session',
          'startTime': Timestamp.fromDate(
            now.add(const Duration(days: 1, hours: 2)),
          ),
          'endTime': Timestamp.fromDate(
            now.add(const Duration(days: 1, hours: 3)),
          ),
          'roomName': 'Hidden Lab',
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final ParentService parentService = ParentService(
        firestoreService: firestoreService,
        parentId: parentId,
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: _buildParentState(
          userId: parentId,
          email: 'pat.parent-schedule@example.com',
          displayName: 'Pat Schedule',
        ),
        parentService: parentService,
        home: const ParentSchedulePage(),
      );

      expect(find.text('Hidden Session'), findsNothing);
      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Next Session Details'), findsOneWidget);
      expect(
        find.textContaining('Prototype Studio\nLocation: Innovation Lab'),
        findsOneWidget,
      );
      expect(
          find.widgetWithText(TextButton, 'Request Reminder'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Request Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Session reminder request submitted.'), findsOneWidget);

      final List<Map<String, dynamic>> supportRequests = (await firestore
              .collection('supportRequests')
              .get())
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
      expect(
        supportRequests.any(
          (Map<String, dynamic> request) =>
              request['requestType'] == 'session_reminder' &&
              request['source'] == 'parent_schedule_request_session_reminder' &&
              request['userId'] == parentId &&
              request['metadata']?['sessionTitle'] == 'Prototype Studio' &&
              request['metadata']?['location'] == 'Innovation Lab' &&
              request['metadata']?['learnerName'] == 'Nia Schedule',
        ),
        isTrue,
      );
    });

    testWidgets('portfolio page persists portfolio share requests in app',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentPortfolioPage(),
      );

      expect(find.text('Build a Robot'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);
      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);

      await tester.ensureVisible(find.text('Build a Robot').first);
      await tester.tap(find.text('Build a Robot').first);
      await tester.pumpAndSettle();

      expect(find.text('Request Share'), findsOneWidget);
      expect(find.text('Download Summary'), findsOneWidget);

      await tester.tap(find.text('Request Share'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio share request submitted.'), findsOneWidget);

      final List<Map<String, dynamic>> supportRequests = (await firestore
              .collection('supportRequests')
              .get())
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
      expect(
        supportRequests.any(
          (Map<String, dynamic> request) =>
              request['requestType'] == 'portfolio_share' &&
              request['source'] == 'parent_portfolio_request_share' &&
              request['metadata']?['itemTitle'] == 'Build a Robot',
        ),
        isTrue,
      );
    });

    testWidgets(
        'portfolio page submits share requests for provisioning-linked families',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final DateTime now = DateTime.now();

      await _pumpProvisioningPage(tester, firestore: firestore);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nia Portfolio',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nia.parent-portfolio@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parents').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Pat Portfolio');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pat.parent-portfolio@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '555-0119');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'nia.parent-portfolio@example.com')
          .get();
      expect(learnerUsers.docs, hasLength(1));
      final String learnerId = learnerUsers.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'pat.parent-portfolio@example.com')
          .get();
      expect(parentUsers.docs, hasLength(1));
      final String parentId = parentUsers.docs.single.id;

      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pat Portfolio').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nia Portfolio').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pump();
      await tester.pumpAndSettle();

      await firestore.collection('portfolioItems').doc('linked-artifact-1').set(
        <String, dynamic>{
          'learnerId': learnerId,
          'title': 'Prototype Artifact',
          'description': 'Provisioning-linked portfolio evidence',
          'pillarCodes': const <String>['future_skills'],
          'verificationStatus': 'reviewed',
          'createdAt':
              Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
          'updatedAt':
              Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        },
      );
      await firestore.collection('portfolioItems').doc('hidden-artifact-1').set(
        <String, dynamic>{
          'learnerId': 'hidden-learner-1',
          'title': 'Hidden Project',
          'description': 'Should not appear',
          'pillarCodes': const <String>['impact'],
          'verificationStatus': 'reviewed',
          'createdAt':
              Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
          'updatedAt':
              Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        },
      );
      await firestore.collection('users').doc('hidden-learner-1').set(
        <String, dynamic>{
          'role': 'learner',
          'displayName': 'Hidden Learner',
          'siteIds': <String>['site-1'],
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final ParentService parentService = ParentService(
        firestoreService: firestoreService,
        parentId: parentId,
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: _buildParentState(
          userId: parentId,
          email: 'pat.parent-portfolio@example.com',
          displayName: 'Pat Portfolio',
        ),
        parentService: parentService,
        home: const ParentPortfolioPage(),
      );

      expect(find.text('Prototype Artifact'), findsOneWidget);
      expect(find.text('Hidden Project'), findsNothing);

      await tester.ensureVisible(find.text('Prototype Artifact').first);
      await tester.tap(find.text('Prototype Artifact').first);
      await tester.pumpAndSettle();

      expect(find.text('Request Share'), findsOneWidget);
      await tester.tap(find.text('Request Share'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio share request submitted.'), findsOneWidget);

      final List<Map<String, dynamic>> supportRequests = (await firestore
              .collection('supportRequests')
              .get())
          .docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
      expect(
        supportRequests.any(
          (Map<String, dynamic> request) =>
              request['requestType'] == 'portfolio_share' &&
              request['source'] == 'parent_portfolio_request_share' &&
              request['userId'] == parentId &&
              request['metadata']?['itemTitle'] == 'Prototype Artifact' &&
              request['metadata']?['itemId'] == 'linked-artifact-1',
        ),
        isTrue,
      );
    });

    testWidgets(
        'portfolio page shows reviewed artifacts created through live learner and educator workflow for provisioning-linked families',
        (WidgetTester tester) async {
      ExportService.instance.debugSaveTextFile = ({
        required String fileName,
        required String content,
        required String mimeType,
      }) async {
        _savedFileName = fileName;
        _savedFileContent = content;
        return '/tmp/$fileName';
      };

      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await _pumpProvisioningPage(tester, firestore: firestore);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nia Reviewed Portfolio',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nia.reviewed-portfolio@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parents').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Pat Reviewed Portfolio',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pat.reviewed-portfolio@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '555-0120');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'nia.reviewed-portfolio@example.com')
          .get();
      expect(learnerUsers.docs, hasLength(1));
      final String learnerId = learnerUsers.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'pat.reviewed-portfolio@example.com')
          .get();
      expect(parentUsers.docs, hasLength(1));
      final String parentId = parentUsers.docs.single.id;

      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pat Reviewed Portfolio').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nia Reviewed Portfolio').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pump();
      await tester.pumpAndSettle();

      await _seedMissionReviewData(firestore, learnerId: learnerId);
      await firestore.collection('users').doc('hidden-reviewed-learner').set(
        <String, dynamic>{
          'role': 'learner',
          'displayName': 'Hidden Reviewed Learner',
          'siteIds': <String>['site-1'],
        },
      );
      await firestore
          .collection('portfolioItems')
          .doc('hidden-reviewed-artifact')
          .set(
        <String, dynamic>{
          'learnerId': 'hidden-reviewed-learner',
          'title': 'Hidden reviewed artifact',
          'description': 'Should stay hidden from the linked parent.',
          'pillarCodes': const <String>['impact'],
          'verificationStatus': 'reviewed',
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      await _submitMissionForReview(
        tester,
        firestore: firestore,
        learnerState: _buildLearnerWorkflowState(
          userId: learnerId,
          email: 'nia.reviewed-portfolio@example.com',
          displayName: 'Nia Reviewed Portfolio',
        ),
        missionService: MissionService(
          firestoreService: firestoreService,
          learnerId: learnerId,
        ),
      );
      final Object? learnerReviewFlowException = tester.takeException();
      expect(learnerReviewFlowException, isNull);

      await _approveSubmittedMission(
        tester,
        firestore: firestore,
        missionService: MissionService(
          firestoreService: firestoreService,
          learnerId: 'educator-1',
        ),
      );
      final Object? educatorReviewFlowException = tester.takeException();
      expect(educatorReviewFlowException, isNull);

      final ParentService parentService = ParentService(
        firestoreService: firestoreService,
        parentId: parentId,
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: _buildParentState(
          userId: parentId,
          email: 'pat.reviewed-portfolio@example.com',
          displayName: 'Pat Reviewed Portfolio',
        ),
        parentService: parentService,
        home: const ParentPortfolioPage(),
      );

      expect(
        find.text('Mission ready for review • Prototype evidence'),
        findsOneWidget,
      );
      expect(find.text('Hidden reviewed artifact'), findsNothing);
      expect(find.text('Evidence linked'), findsWidgets);
      expect(find.text('Reviewed'), findsWidgets);
      expect(find.text('Proof verified'), findsWidgets);
      expect(find.text('Learner declared no AI support used'), findsWidgets);

      await tester.tap(
          find.text('Mission ready for review • Prototype evidence').first);
      await tester.pumpAndSettle();

      expect(find.text('Capability Evidence'), findsOneWidget);
      expect(find.text('Prototype evidence'), findsWidgets);
      expect(find.text('Verification Prompt'), findsOneWidget);
      expect(
        find.text('Explain why this prototype path best matched the evidence.'),
        findsOneWidget,
      );
      expect(find.text('Verification Criteria'), findsOneWidget);
      expect(
        find.text(
            'Review: Ask the learner to justify the prototype path without prompts.'),
        findsOneWidget,
      );
      expect(find.text('Progression Descriptors'), findsOneWidget);
      expect(
        find.text(
          'Learner explains why the prototype choice fits the observed evidence. • Learner identifies a tradeoff and defends the decision with examples.',
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Download Summary'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Download Summary'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_savedFileName, isNotNull);
      expect(_savedFileContent, contains('Mission Attempt ID:'));
      expect(
        _savedFileContent,
        contains(
            'Verification Criteria: Review: Ask the learner to justify the prototype path without prompts.'),
      );
      expect(
        _savedFileContent,
        contains(
            'Progression Descriptors: Learner explains why the prototype choice fits the observed evidence. • Learner identifies a tradeoff and defends the decision with examples.'),
      );
    });

    testWidgets(
        'child passport shows reviewed claims created through live learner and educator workflow for provisioning-linked families',
        (WidgetTester tester) async {
      ExportService.instance.debugSaveTextFile = ({
        required String fileName,
        required String content,
        required String mimeType,
      }) async {
        _savedFileName = fileName;
        _savedFileContent = content;
        return '/tmp/$fileName';
      };

      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await _pumpProvisioningPage(tester, firestore: firestore);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nia Passport Evidence',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nia.passport-evidence@example.com',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parents').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Pat Passport Evidence');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pat.passport-evidence@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '555-0121');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pump();
      await tester.pumpAndSettle();

      final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'nia.passport-evidence@example.com')
          .get();
      expect(learnerUsers.docs, hasLength(1));
      final String learnerId = learnerUsers.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: 'pat.passport-evidence@example.com')
          .get();
      expect(parentUsers.docs, hasLength(1));
      final String parentId = parentUsers.docs.single.id;

      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pat Passport Evidence').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nia Passport Evidence').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pump();
      await tester.pumpAndSettle();

      await _seedMissionReviewData(firestore, learnerId: learnerId);
      await firestore.collection('users').doc('hidden-passport-learner').set(
        <String, dynamic>{
          'role': 'learner',
          'displayName': 'Hidden Passport Learner',
          'siteIds': <String>['site-1'],
        },
      );
      await firestore
          .collection('capabilityMastery')
          .doc('hidden-passport-learner_hidden-capability')
          .set(
        <String, dynamic>{
          'learnerId': 'hidden-passport-learner',
          'siteId': 'site-1',
          'capabilityId': 'hidden-capability',
          'pillarCode': 'future_skills',
          'latestLevel': 4,
          'highestLevel': 4,
          'latestMissionAttemptId': 'hidden-attempt',
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 10, 0)),
        },
      );
      await firestore.collection('evidenceRecords').doc('hidden-evidence').set(
        <String, dynamic>{
          'learnerId': 'hidden-passport-learner',
          'siteId': 'site-1',
          'capabilityId': 'hidden-capability',
          'capabilityLabel': 'Hidden reviewed capability',
          'linkedMissionAttemptId': 'hidden-attempt',
          'observedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9, 0)),
        },
      );
      await firestore
          .collection('portfolioItems')
          .doc('hidden-passport-item')
          .set(
        <String, dynamic>{
          'learnerId': 'hidden-passport-learner',
          'title': 'Hidden passport artifact',
          'description': 'Should stay hidden from the linked parent.',
          'pillarCodes': const <String>['future_skills'],
          'capabilityIds': const <String>['hidden-capability'],
          'capabilityTitles': const <String>['Hidden reviewed capability'],
          'verificationStatus': 'reviewed',
          'missionAttemptId': 'hidden-attempt',
          'proofOfLearningStatus': 'verified',
          'aiDisclosureStatus': 'learner-ai-not-used',
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9, 5)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9, 10)),
        },
      );
      await firestore.collection('missionAttempts').doc('hidden-attempt').set(
        <String, dynamic>{
          'learnerId': 'hidden-passport-learner',
          'missionId': 'hidden-mission',
          'sessionOccurrenceId': 'hidden-occurrence',
          'proofBundleSummary': <String, dynamic>{
            'hasExplainItBack': true,
            'hasOralCheck': true,
            'hasMiniRebuild': true,
            'hasLearnerAiDisclosure': true,
            'aiAssistanceUsed': false,
          },
        },
      );

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      await _submitMissionForReview(
        tester,
        firestore: firestore,
        learnerState: _buildLearnerWorkflowState(
          userId: learnerId,
          email: 'nia.passport-evidence@example.com',
          displayName: 'Nia Passport Evidence',
        ),
        missionService: MissionService(
          firestoreService: firestoreService,
          learnerId: learnerId,
        ),
      );
      final Object? learnerReviewFlowException = tester.takeException();
      expect(learnerReviewFlowException, isNull);

      await _approveSubmittedMission(
        tester,
        firestore: firestore,
        missionService: MissionService(
          firestoreService: firestoreService,
          learnerId: 'educator-1',
        ),
      );
      final Object? educatorReviewFlowException = tester.takeException();
      expect(educatorReviewFlowException, isNull);

      final QuerySnapshot<Map<String, dynamic>> missionAttempts =
          await firestore
              .collection('missionAttempts')
              .where('learnerId', isEqualTo: learnerId)
              .get();
      expect(missionAttempts.docs, hasLength(1));
      final String missionAttemptId = missionAttempts.docs.single.id;

      final QuerySnapshot<Map<String, dynamic>> portfolioItems = await firestore
          .collection('portfolioItems')
          .where('learnerId', isEqualTo: learnerId)
          .where('missionAttemptId', isEqualTo: missionAttemptId)
          .get();
      expect(portfolioItems.docs, hasLength(1));
      final String portfolioItemId = portfolioItems.docs.single.id;

      final ParentService parentService = ParentService(
        firestoreService: firestoreService,
        parentId: parentId,
        bundleLoader: () async => <LearnerSummary>[],
        billingLoader: () async => null,
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        appState: _buildParentState(
          userId: parentId,
          email: 'pat.passport-evidence@example.com',
          displayName: 'Pat Passport Evidence',
        ),
        parentService: parentService,
        home: ParentChildPage(learnerId: learnerId),
      );
      final Object? parentChildPumpException = tester.takeException();
      expect(parentChildPumpException, isNull);

      expect(find.text('Nia Passport Evidence'), findsOneWidget);
      expect(find.text('Ideation Passport'), findsOneWidget);
      expect(find.text('Prototype evidence'), findsWidgets);
      expect(find.text('Hidden reviewed capability'), findsNothing);
      expect(
        find.textContaining(
          'Proof of Learning: Verified • AI Disclosure: Learner declared no AI support used',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
            'Verification Criteria: Review: Ask the learner to justify the prototype path without prompts.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
            'Progression Descriptors: Learner explains why the prototype choice fits the observed evidence. • Learner identifies a tradeoff and defends the decision with examples.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Export Passport'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_savedFileName, 'ideation-passport-$learnerId.txt');
      expect(_savedFileContent, contains('Prototype evidence'));
      expect(
        _savedFileContent,
        contains('Reviewed/Verified Artifacts'),
      );
      expect(
        _savedFileContent,
        contains('Artifact Review Status: Reviewed'),
      );
      expect(
        _savedFileContent,
        contains(
            'Verification Criteria: Review: Ask the learner to justify the prototype path without prompts.'),
      );
      expect(
        _savedFileContent,
        contains(
            'Progression Descriptors: Learner explains why the prototype choice fits the observed evidence. • Learner identifies a tradeoff and defends the decision with examples.'),
      );
      expect(
          _savedFileContent, contains('Portfolio Item IDs: $portfolioItemId'));
      expect(_savedFileContent,
          contains('Mission Attempt IDs: $missionAttemptId'));
    });

    testWidgets('portfolio page downloads a real summary file',
        (WidgetTester tester) async {
      ExportService.instance.debugSaveTextFile = ({
        required String fileName,
        required String content,
        required String mimeType,
      }) async {
        _savedFileName = fileName;
        _savedFileContent = content;
        return '/tmp/$fileName';
      };
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentPortfolioPage(),
      );

      await tester.ensureVisible(find.text('Build a Robot').first);
      await tester.tap(find.text('Build a Robot').first);
      await tester.pumpAndSettle();

      expect(find.text('Download Summary'), findsOneWidget);

      await tester.tap(find.text('Download Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Portfolio summary downloaded.'), findsOneWidget);
      expect(_savedFileName, 'portfolio-summary-learner-1-activity-1.txt');
      expect(_savedFileContent,
          contains('Portfolio Item ID: learner-1-activity-1'));
      expect(_savedFileContent, contains('Title: Build a Robot'));
      expect(_savedFileContent, contains('Description: Linked Update'));
    });

    testWidgets('portfolio page copies summary when file export is unsupported',
        (WidgetTester tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final Object? args = methodCall.arguments;
            if (args is Map) {
              copiedText = args['text'] as String?;
            }
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      ExportService.instance.debugSaveTextFile = ({
        required String fileName,
        required String content,
        required String mimeType,
      }) async {
        throw UnsupportedError(
            'File export is not supported on this platform.');
      };

      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentPortfolioPage(),
      );

      await tester.ensureVisible(find.text('Build a Robot').first);
      await tester.tap(find.text('Build a Robot').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download Summary'));
      await tester.pumpAndSettle();

      expect(
          find.text('Portfolio summary copied for sharing.'), findsOneWidget);
      expect(copiedText, contains('Portfolio Item ID: learner-1-activity-1'));
      expect(copiedText, contains('Title: Build a Robot'));
      expect(copiedText, contains('Description: Linked Update'));
    });

    testWidgets(
        'portfolio page prefers direct artifact proof and ai provenance over mission fallback',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      final DateTime now = DateTime.now();
      final DateTime anchor = DateTime(now.year, now.month, now.day, 10);

      await firestore.collection('portfolioItems').doc('artifact-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'title': 'Prototype Evidence',
          'description': 'Reviewed prototype artifact with direct provenance.',
          'pillarCodes': const <String>['future_skills'],
          'verificationStatus': 'reviewed',
          'evidenceRecordIds': const <String>['evidence-1'],
          'capabilityTitles': const <String>['Prototype evidence'],
          'missionAttemptId': 'attempt-1',
          'verificationPrompt':
              'Explain why this prototype path best matched the evidence.',
          'progressionDescriptors': const <String>[
            'Learner explains why the prototype path fits the collected evidence.',
          ],
          'checkpointMappings': const <Map<String, dynamic>>[
            <String, dynamic>{
              'phase': 'review',
              'guidance':
                  'Verify the learner can defend the choice without scaffolds.',
            },
          ],
          'proofOfLearningStatus': 'verified',
          'aiDisclosureStatus': 'learner-ai-not-used',
          'createdAt': Timestamp.fromDate(anchor),
          'updatedAt':
              Timestamp.fromDate(anchor.add(const Duration(minutes: 5))),
        },
      );

      await firestore.collection('missionAttempts').doc('attempt-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'missionId': 'mission-1',
          'sessionOccurrenceId': 'session-1',
          'proofBundleSummary': <String, dynamic>{
            'hasExplainItBack': false,
            'hasOralCheck': false,
            'hasMiniRebuild': false,
            'hasLearnerAiDisclosure': false,
            'aiAssistanceUsed': false,
          },
        },
      );

      await firestore.collection('interactionEvents').doc('event-ai-1').set(
        <String, dynamic>{
          'actorId': 'learner-1',
          'sessionOccurrenceId': 'session-1',
          'eventType': 'ai_help_used',
          'createdAt':
              Timestamp.fromDate(anchor.add(const Duration(minutes: 1))),
        },
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentPortfolioPage(),
      );

      expect(find.text('Prototype Evidence'), findsOneWidget);
      expect(find.text('Proof verified'), findsWidgets);
      expect(find.text('Learner declared no AI support used'), findsWidgets);
      expect(
        find.text('Learner AI use detected without explain-back evidence'),
        findsNothing,
      );

      await tester.tap(find.text('Prototype Evidence').first);
      await tester.pumpAndSettle();

      expect(find.text('Capability Evidence'), findsOneWidget);
      expect(find.text('Prototype evidence'), findsWidgets);
      expect(find.text('Verification Prompt'), findsOneWidget);
      expect(
        find.text('Explain why this prototype path best matched the evidence.'),
        findsOneWidget,
      );
      expect(find.text('Verification Criteria'), findsOneWidget);
      expect(
        find.text(
            'Review: Verify the learner can defend the choice without scaffolds.'),
        findsOneWidget,
      );
      expect(find.text('Progression Descriptors'), findsOneWidget);
      expect(
        find.text(
            'Learner explains why the prototype path fits the collected evidence.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'child passport prefers direct artifact proof and ai provenance over mission fallback',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      final DateTime now = DateTime.now();
      final DateTime anchor = DateTime(now.year, now.month, now.day, 11);

      await firestore
          .collection('capabilityMastery')
          .doc('learner-1_cap-1')
          .set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'capabilityId': 'cap-1',
          'pillarCode': 'future_skills',
          'latestLevel': 3,
          'highestLevel': 3,
          'latestMissionAttemptId': 'attempt-1',
          'updatedAt': Timestamp.fromDate(anchor),
        },
      );

      await firestore.collection('evidenceRecords').doc('evidence-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'capabilityId': 'cap-1',
          'capabilityLabel': 'Prototype evidence',
          'linkedMissionAttemptId': 'attempt-1',
          'observedAt':
              Timestamp.fromDate(anchor.subtract(const Duration(hours: 1))),
        },
      );

      await firestore.collection('portfolioItems').doc('artifact-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'title': 'Prototype Evidence',
          'description': 'Reviewed prototype artifact with direct provenance.',
          'pillarCodes': const <String>['future_skills'],
          'capabilityIds': const <String>['cap-1'],
          'capabilityTitles': const <String>['Prototype evidence'],
          'verificationStatus': 'reviewed',
          'missionAttemptId': 'attempt-1',
          'progressionDescriptors': const <String>[
            'Learner explains why the prototype path fits the collected evidence.',
          ],
          'checkpointMappings': const <Map<String, dynamic>>[
            <String, dynamic>{
              'phase': 'review',
              'guidance':
                  'Verify the learner can defend the choice without scaffolds.',
            },
          ],
          'proofOfLearningStatus': 'verified',
          'aiDisclosureStatus': 'learner-ai-not-used',
          'createdAt': Timestamp.fromDate(anchor),
          'updatedAt':
              Timestamp.fromDate(anchor.add(const Duration(minutes: 5))),
        },
      );

      await firestore.collection('missionAttempts').doc('attempt-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
          'missionId': 'mission-1',
          'sessionOccurrenceId': 'session-1',
          'proofBundleSummary': <String, dynamic>{
            'hasExplainItBack': false,
            'hasOralCheck': false,
            'hasMiniRebuild': false,
            'hasLearnerAiDisclosure': false,
            'aiAssistanceUsed': false,
          },
        },
      );

      await firestore.collection('interactionEvents').doc('event-ai-1').set(
        <String, dynamic>{
          'actorId': 'learner-1',
          'sessionOccurrenceId': 'session-1',
          'eventType': 'ai_help_used',
          'createdAt':
              Timestamp.fromDate(anchor.add(const Duration(minutes: 1))),
        },
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentChildPage(learnerId: 'learner-1'),
      );

      expect(find.text('Ideation Passport'), findsOneWidget);
      expect(find.text('Prototype evidence'), findsWidgets);
      expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
      expect(
        find.textContaining(
          'Proof of Learning: Verified • AI Disclosure: Learner declared no AI support used',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
            'Verification Criteria: Review: Verify the learner can defend the choice without scaffolds.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
            'Progression Descriptors: Learner explains why the prototype path fits the collected evidence.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
            'Learner AI use detected without explain-back evidence'),
        findsNothing,
      );
    });

    testWidgets(
        'billing page shows explicit unavailable state when no billing data exists',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      await _pumpPage(
        tester,
        firestore: firestore,
        home: const ParentBillingPage(),
      );

      expect(find.text('No billing data yet'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsNothing);
      expect(
        find.text('Statements are shared by your site or HQ billing team.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Billing plan unavailable'), findsOneWidget);
      expect(find.text('All paid'), findsNothing);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets(
        'billing page keeps populated invoices and plan controls read-only',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedParentData(firestore);

      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
      final ParentService parentService = _StubParentService(
        firestoreService: firestoreService,
        parentId: 'parent-1',
        stubLearnerSummaries: <LearnerSummary>[
          LearnerSummary(
            learnerId: 'learner-1',
            learnerName: 'Ava Learner',
            currentLevel: 4,
            totalXp: 1200,
            missionsCompleted: 5,
            currentStreak: 7,
            attendanceRate: 1.0,
          ),
        ],
        stubBillingSummary: BillingSummary(
          currentBalance: 199.0,
          nextPaymentAmount: 199.0,
          nextPaymentDate: DateTime(2026, 4, 1),
          subscriptionPlan: 'Family Plan',
          recentPayments: <PaymentHistory>[
            PaymentHistory(
              id: 'INV-2026-03',
              amount: 199.0,
              date: DateTime(2026, 3, 1),
              status: 'due',
              description: 'Visa ending 4242',
            ),
            PaymentHistory(
              id: 'INV-2026-02',
              amount: 149.0,
              date: DateTime(2026, 2, 1),
              status: 'paid',
              description: 'Visa ending 4242',
            ),
          ],
        ),
      );

      await _pumpPage(
        tester,
        firestore: firestore,
        parentService: parentService,
        home: const ParentBillingPage(),
      );

      expect(find.text('INV-2026-03'), findsOneWidget);
      expect(find.text('NEXT-DUE'), findsOneWidget);
      expect(find.text('Pay Now'), findsNothing);
      expect(find.text('View'), findsNothing);
      expect(find.text('Request Invoice Help'), findsNWidgets(2));

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      expect(find.text('FAMILY PLAN'), findsOneWidget);
      expect(find.text('Request Payment Method Update'), findsOneWidget);
      expect(find.text('Request Plan Change'), findsOneWidget);
      expect(find.text('Manage Plan'), findsNothing);
    });
  });
}
