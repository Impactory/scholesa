import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_mission_review_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/missions/missions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _StubMissionService extends MissionService {
  _StubMissionService({
    this.failFirstLoad = false,
    this.submitShouldSucceed = true,
    List<MissionSubmission> submissions = const <MissionSubmission>[],
  })  : _submissions = List<MissionSubmission>.from(submissions),
        _seedSubmissions = List<MissionSubmission>.from(submissions),
        super(
          firestoreService: FirestoreService(
            firestore: FakeFirebaseFirestore(),
            auth: _MockFirebaseAuth(),
          ),
          learnerId: 'educator-1',
        );

  final bool failFirstLoad;
  final bool submitShouldSucceed;

  final List<String?> requestedSiteIds = <String?>[];
  int loadCallCount = 0;
  int submitCallCount = 0;

  bool _loading = false;
  String? _errorState;
  List<MissionSubmission> _submissions;
  final List<MissionSubmission> _seedSubmissions;
  int _reviewedTodayState = 0;

  @override
  bool get isLoading => _loading;

  @override
  String? get error => _errorState;

  @override
  List<MissionSubmission> get pendingReviews => _submissions;

  @override
  int get reviewedToday => _reviewedTodayState;

  @override
  Future<void> loadPendingReviews({String? educatorId, String? siteId}) async {
    loadCallCount += 1;
    requestedSiteIds.add(siteId);
    _loading = false;
    if (failFirstLoad && loadCallCount == 1) {
      _errorState = 'Unable to load mission review queue right now.';
      _submissions = <MissionSubmission>[];
      _reviewedTodayState = 0;
    } else {
      _errorState = null;
      _submissions = List<MissionSubmission>.from(_seedSubmissions);
      _reviewedTodayState = 1;
    }
    notifyListeners();
  }

  @override
  Future<bool> submitReview({
    required String submissionId,
    required int rating,
    required String feedback,
    required String reviewerId,
    String status = 'reviewed',
    String? aiFeedbackDraft,
    String? rubricId,
    String? rubricTitle,
    List<Map<String, dynamic>> rubricScores = const <Map<String, dynamic>>[],
  }) async {
    submitCallCount += 1;
    if (!submitShouldSucceed) {
      _errorState = 'Failed to submit review: backend unavailable';
      notifyListeners();
      return false;
    }
    _submissions = _submissions
        .where((MissionSubmission item) => item.id != submissionId)
        .toList();
    _reviewedTodayState += 1;
    _errorState = null;
    notifyListeners();
    return true;
  }
}

AppState _buildAppState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

AppState _buildLearnerState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Avery Chen',
    'role': 'learner',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

MissionSubmission _submission() {
  return MissionSubmission(
    id: 'submission-1',
    missionId: 'mission-1',
    missionTitle: 'Robotics Reflection',
    learnerId: 'learner-1',
    learnerName: 'Avery Chen',
    pillar: 'future_skills',
    submittedAt: DateTime(2026, 3, 18, 9, 30),
    status: 'pending',
    submissionText: 'I tested the robot with two sensor loops.',
  );
}

Widget _buildHarness(MissionService missionService) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildAppState()),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
    ],
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      home: const EducatorMissionReviewPage(),
    ),
  );
}

Widget _buildLearnerHarness({
  required FirestoreService firestoreService,
  required MissionService missionService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: const MissionsPage(),
    ),
  );
}

Future<void> _seedCompletedMissionReadyForReview(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('users').doc('learner-1').set(
    <String, dynamic>{
      'displayName': 'Avery Chen',
      'role': 'learner',
      'siteIds': <String>['site-1'],
    },
  );
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'sessionOccurrenceId': 'occurrence-1',
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
}

Future<void> _seedReviewRubricAndEvidence(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'rubricId': 'rubric-1',
      'rubricTitle': 'Prototype Rubric',
    },
    SetOptions(merge: true),
  );
  await firestore.collection('rubrics').doc('rubric-1').set(
    <String, dynamic>{
      'title': 'Prototype Rubric',
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
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'sessionOccurrenceId': 'occurrence-1',
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
  await firestore.collection('evidenceRecords').doc('evidence-stale').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'sessionOccurrenceId': 'occurrence-older',
      'capabilityId': 'cap-prototype-evidence',
      'capabilityLabel': 'Prototype evidence',
      'capabilityPillarCode': 'future_skills',
      'observationNote':
          'Older observation that should stay outside this review.',
      'artifactUrls': const <String>['https://example.com/older.png'],
      'nextVerificationPrompt': 'Revisit the previous prototype evidence.',
      'portfolioCandidate': true,
      'growthStatus': 'captured',
      'observedAt': Timestamp.fromDate(DateTime(2026, 3, 11, 8, 45)),
    },
  );
}

Future<String> _submitMissionForReview(
  WidgetTester tester, {
  required FirestoreService firestoreService,
  required MissionService missionService,
}) async {
  await tester.pumpWidget(
    _buildLearnerHarness(
      firestoreService: firestoreService,
      missionService: missionService,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();

  await tester.tap(find.text('In Progress'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();

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

  await tester.scrollUntilVisible(
    find.text('Submit for Review'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Submit for Review'));
  await tester.pump();
  await tester.pumpAndSettle();

  final QuerySnapshot<Map<String, dynamic>> attempts =
      await firestoreService.firestore.collection('missionAttempts').get();
  expect(attempts.docs, hasLength(1));
  return attempts.docs.single.id;
}

Future<void> _pumpPage(
  WidgetTester tester,
  MissionService missionService,
) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(_buildHarness(missionService));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'educator mission review page shows explicit load error and retries with active site scope',
      (WidgetTester tester) async {
    final _StubMissionService missionService = _StubMissionService(
      failFirstLoad: true,
      submissions: <MissionSubmission>[_submission()],
    );

    await _pumpPage(tester, missionService);

    expect(
      find.text('Unable to load mission review queue right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('All caught up!'), findsNothing);
    expect(missionService.requestedSiteIds, <String?>['site-1']);

    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(missionService.requestedSiteIds, <String?>['site-1', 'site-1']);
    expect(find.text('Robotics Reflection'), findsOneWidget);
    expect(
      find.text('Unable to load mission review queue right now.'),
      findsNothing,
    );
  });

  testWidgets(
      'educator mission review page surfaces failed approval instead of silent no-op',
      (WidgetTester tester) async {
    final _StubMissionService missionService = _StubMissionService(
      submissions: <MissionSubmission>[_submission()],
      submitShouldSucceed: false,
    );

    await _pumpPage(tester, missionService);

    await tester.tap(find.text('Robotics Reflection'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(missionService.submitCallCount, 1);
    expect(find.text('Unable to submit review right now.'), findsOneWidget);
    expect(find.text('Mission approved!'), findsNothing);
    expect(find.text('Request Revision'), findsOneWidget);
  });

  testWidgets(
      'educator mission review consumes learner-submitted canonical attempts from the live learner route',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCompletedMissionReadyForReview(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService learnerMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final String attemptId = await _submitMissionForReview(
      tester,
      firestoreService: firestoreService,
      missionService: learnerMissionService,
    );

    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await tester.pumpWidget(_buildHarness(educatorMissionService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Mission ready for review'), findsOneWidget);
    expect(find.text('Avery Chen'), findsWidgets);

    await tester.tap(find.text('Mission ready for review').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Your explanation matches the prototype evidence. Keep tracing tradeoffs.',
    );
    await tester.scrollUntilVisible(
      find.text('Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> attemptDoc =
        await firestore.collection('missionAttempts').doc(attemptId).get();
    final DocumentSnapshot<Map<String, dynamic>> submissionDoc =
        await firestore.collection('missionSubmissions').doc(attemptId).get();
    final DocumentSnapshot<Map<String, dynamic>> assignmentDoc = await firestore
        .collection('missionAssignments')
        .doc('assignment-1')
        .get();

    expect(attemptDoc.data()?['reviewStatus'], 'approved');
    expect(attemptDoc.data()?['status'], 'reviewed');
    expect(
      attemptDoc.data()?['feedback'],
      'Your explanation matches the prototype evidence. Keep tracing tradeoffs.',
    );
    expect(submissionDoc.exists, isFalse);
    expect(
      assignmentDoc.data()?['reviewStatus'],
      'approved',
    );
    expect(assignmentDoc.data()?['lastSubmissionId'], attemptId);
  });

  testWidgets(
      'educator mission review applies rubric scoring and growth linkage from the live review page',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCompletedMissionReadyForReview(firestore);
    await _seedReviewRubricAndEvidence(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService learnerMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final String attemptId = await _submitMissionForReview(
      tester,
      firestoreService: firestoreService,
      missionService: learnerMissionService,
    );

    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await tester.pumpWidget(_buildHarness(educatorMissionService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mission ready for review').first);
    await tester.pumpAndSettle();

    expect(find.text('Prototype Rubric'), findsOneWidget);
    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('Reflection'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Reflection'),
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

    final DocumentSnapshot<Map<String, dynamic>> attemptDoc =
        await firestore.collection('missionAttempts').doc(attemptId).get();
    final DocumentSnapshot<Map<String, dynamic>> submissionDoc =
        await firestore.collection('missionSubmissions').doc(attemptId).get();
    final DocumentSnapshot<Map<String, dynamic>> assignmentDoc = await firestore
        .collection('missionAssignments')
        .doc('assignment-1')
        .get();
    final DocumentSnapshot<Map<String, dynamic>> rubricApplicationDoc =
        await firestore.collection('rubricApplications').doc(attemptId).get();
    final DocumentSnapshot<Map<String, dynamic>> masteryDoc = await firestore
        .collection('capabilityMastery')
        .doc('learner-1_cap-prototype-evidence')
        .get();
    final QuerySnapshot<Map<String, dynamic>> growthEvents = await firestore
        .collection('capabilityGrowthEvents')
        .where('missionAttemptId', isEqualTo: attemptId)
        .get();
    final DocumentSnapshot<Map<String, dynamic>> evidenceDoc =
        await firestore.collection('evidenceRecords').doc('evidence-1').get();
    final DocumentSnapshot<Map<String, dynamic>> portfolioDoc =
        await firestore.collection('portfolioItems').doc('evidence-1').get();

    expect(attemptDoc.data()?['status'], 'reviewed');
    expect(attemptDoc.data()?['reviewStatus'], 'approved');
    expect(attemptDoc.data()?['rubricId'], 'rubric-1');
    expect(attemptDoc.data()?['rubricTitle'], 'Prototype Rubric');
    expect(attemptDoc.data()?['rubricTotalScore'], 7);
    expect(attemptDoc.data()?['rubricMaxScore'], 8);
    expect(submissionDoc.exists, isFalse);
    expect(assignmentDoc.data()?['reviewStatus'], 'approved');
    expect(assignmentDoc.data()?['rubricTotalScore'], 7);
    expect(rubricApplicationDoc.exists, isTrue);
    expect(rubricApplicationDoc.data()?['missionAttemptId'], attemptId);
    expect((rubricApplicationDoc.data()?['scores'] as List?)?.length, 2);
    expect(masteryDoc.exists, isTrue);
    expect(masteryDoc.data()?['latestMissionAttemptId'], attemptId);
    expect(masteryDoc.data()?['latestLevel'], 4);
    expect(growthEvents.docs, hasLength(1));
    expect(growthEvents.docs.single.data()['level'], 4);
    expect(evidenceDoc.data()?['growthStatus'], 'updated');
    expect(evidenceDoc.data()?['linkedMissionAttemptId'], attemptId);
    expect(portfolioDoc.exists, isTrue);
    expect(portfolioDoc.data()?['missionAttemptId'], attemptId);
    expect(portfolioDoc.data()?['proofOfLearningStatus'], 'verified');
    expect(portfolioDoc.data()?['aiAssistanceUsed'], isFalse);
    expect(portfolioDoc.data()?['aiDisclosureStatus'], 'learner-ai-not-used');
  });

  testWidgets(
      'educator mission review excludes stale live evidence from other session occurrences',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCompletedMissionReadyForReview(firestore);
    await _seedReviewRubricAndEvidence(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService learnerMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final String attemptId = await _submitMissionForReview(
      tester,
      firestoreService: firestoreService,
      missionService: learnerMissionService,
    );

    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await tester.pumpWidget(_buildHarness(educatorMissionService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mission ready for review').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Reflection'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('4/4').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/4').at(1));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Growth should only link the live evidence from the reviewed session.',
    );
    await tester.scrollUntilVisible(
      find.text('Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> currentEvidence =
        await firestore.collection('evidenceRecords').doc('evidence-1').get();
    final DocumentSnapshot<Map<String, dynamic>> staleEvidence = await firestore
        .collection('evidenceRecords')
        .doc('evidence-stale')
        .get();
    final DocumentSnapshot<Map<String, dynamic>> stalePortfolio =
        await firestore
            .collection('portfolioItems')
            .doc('evidence-stale')
            .get();
    final QuerySnapshot<Map<String, dynamic>> growthEvents = await firestore
        .collection('capabilityGrowthEvents')
        .where('missionAttemptId', isEqualTo: attemptId)
        .get();

    expect(currentEvidence.data()?['linkedMissionAttemptId'], attemptId);
    expect(staleEvidence.data()?['growthStatus'], 'captured');
    expect(staleEvidence.data()?['linkedMissionAttemptId'], isNull);
    expect(stalePortfolio.exists, isFalse);
    expect(
      growthEvents.docs.single.data()['linkedEvidenceRecordIds'],
      contains('evidence-1'),
    );
    expect(
      growthEvents.docs.single.data()['linkedEvidenceRecordIds'],
      isNot(contains('evidence-stale')),
    );
  });
}
