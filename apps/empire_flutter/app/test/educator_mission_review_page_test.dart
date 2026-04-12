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
      'progressionDescriptors': <String>[
        'Secure: explain how the prototype evidence supports the claim.',
      ],
      'checkpointMappings': <Map<String, dynamic>>[
        <String, dynamic>{
          'phaseKey': 'checkpoint',
          'phaseLabel': 'Checkpoint',
          'guidance':
              'Ask the learner to identify the exact artifact that proves current understanding.',
        },
      ],
    },
    SetOptions(merge: true),
  );
  await firestore.collection('rubrics').doc('rubric-1').set(
    <String, dynamic>{
      'title': 'Prototype Rubric',
      'progressionDescriptors': <String>[
        'Secure: explain how the prototype evidence supports the claim.',
      ],
      'checkpointMappings': <Map<String, dynamic>>[
        <String, dynamic>{
          'phaseKey': 'checkpoint',
          'phaseLabel': 'Checkpoint',
          'guidance':
              'Ask the learner to identify the exact artifact that proves current understanding.',
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

Future<void> _seedUnmappedReviewEvidence(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('evidenceRecords').doc('evidence-unmapped').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'sessionOccurrenceId': 'occurrence-1',
      'capabilityLabel': 'Prototype evidence',
      'capabilityMapped': false,
      'capabilityPillarCode': 'future_skills',
      'observationNote':
          'Unmapped live observation captured before HQ mapping was available.',
      'artifactUrls': const <String>['https://example.com/unmapped.png'],
      'nextVerificationPrompt':
          'Connect this observation to the review rubric.',
      'portfolioCandidate': true,
      'growthStatus': 'captured',
      'observedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 8, 55)),
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
    expect(find.text('Progression descriptors'), findsOneWidget);
    expect(
      find.text(
          'Secure: explain how the prototype evidence supports the claim.'),
      findsOneWidget,
    );
    expect(find.text('Verification criteria'), findsOneWidget);
    expect(
      find.text(
          'Checkpoint: Ask the learner to identify the exact artifact that proves current understanding.'),
      findsOneWidget,
    );
    expect(find.text('Evidence'), findsWidgets);
    expect(find.text('Reflection'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Reflection').last,
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
      find.widgetWithText(ElevatedButton, 'Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
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
    // capabilityMastery + capabilityGrowthEvents are now written server-side
    // by the applyRubricToEvidence Cloud Function, not the client batch.
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
    expect(rubricApplicationDoc.data()?['progressionDescriptors'], <String>[
      'Secure: explain how the prototype evidence supports the claim.',
    ]);
    expect((rubricApplicationDoc.data()?['checkpointMappings'] as List?)?.length,
        1);
    expect(evidenceDoc.data()?['growthStatus'], 'updated');
    expect(evidenceDoc.data()?['linkedMissionAttemptId'], attemptId);
    expect(portfolioDoc.exists, isTrue);
    expect(portfolioDoc.data()?['missionAttemptId'], attemptId);
    expect(portfolioDoc.data()?['proofOfLearningStatus'], 'verified');
    expect(portfolioDoc.data()?['progressionDescriptors'], <String>[
      'Secure: explain how the prototype evidence supports the claim.',
    ]);
    expect((portfolioDoc.data()?['checkpointMappings'] as List?)?.length, 1);
    expect(portfolioDoc.data()?['aiAssistanceUsed'], isFalse);
    expect(portfolioDoc.data()?['aiDisclosureStatus'], 'learner-ai-not-used');
  });

  testWidgets(
      'educator mission review requires explicit rubric scoring before review decisions unlock',
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

    final String attemptId = await _submitMissionForReview(
      tester,
      firestoreService: firestoreService,
      missionService: learnerMissionService,
    );

    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await _pumpPage(tester, educatorMissionService);

    await tester.tap(find.text('Mission ready for review').first);
    await tester.pumpAndSettle();

    expect(find.text('Evidence-backed review'), findsOneWidget);
    expect(
      find.text(
          'Score every rubric criterion before approving or requesting revision.'),
      findsOneWidget,
    );

    final OutlinedButton lockedRevisionButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Request Revision'),
    );
    final ElevatedButton lockedApproveButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Approve'),
    );
    expect(lockedRevisionButton.onPressed, isNull);
    expect(lockedApproveButton.onPressed, isNull);

    await tester.scrollUntilVisible(
      find.text('Reflection').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('0/4').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/4').at(1));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Rubric scoring complete. Review decision can update capability growth.'),
      findsOneWidget,
    );

    final OutlinedButton unlockedRevisionButton =
        tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Request Revision'),
    );
    final ElevatedButton unlockedApproveButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Approve'),
    );
    expect(unlockedRevisionButton.onPressed, isNotNull);
    expect(unlockedApproveButton.onPressed, isNotNull);

    await tester.enterText(
      find.byType(TextField).last,
      'Explicit rubric scoring is complete and ready for capability review.',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> attemptDoc =
        await firestore.collection('missionAttempts').doc(attemptId).get();

    expect(attemptDoc.data()?['reviewStatus'], 'approved');
    expect(attemptDoc.data()?['rubricTotalScore'], 3);
    expect(attemptDoc.data()?['rubricMaxScore'], 8);
  });

  testWidgets(
      'educator mission review falls back to HQ checkpoint guidance when live evidence prompt is absent',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCompletedMissionReadyForReview(firestore);
    await _seedReviewRubricAndEvidence(firestore);
    await firestore.collection('evidenceRecords').doc('evidence-1').set(
      <String, dynamic>{
        'nextVerificationPrompt': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService learnerMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );

    await _submitMissionForReview(
      tester,
      firestoreService: firestoreService,
      missionService: learnerMissionService,
    );

    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await _pumpPage(tester, educatorMissionService);

    await tester.tap(find.text('Mission ready for review').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reflection').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('4/4').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/4').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Use HQ criteria.');
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> portfolioDoc =
        await firestore.collection('portfolioItems').doc('evidence-1').get();

    expect(
      portfolioDoc.data()?['verificationPrompt'],
      'Checkpoint: Ask the learner to identify the exact artifact that proves current understanding.',
    );
    expect(
      portfolioDoc.data()?['verificationPromptSource'],
      'hq_checkpoint_mapping',
    );
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
      find.text('Reflection').last,
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
      find.widgetWithText(ElevatedButton, 'Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
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

    expect(currentEvidence.data()?['linkedMissionAttemptId'], attemptId);
    expect(staleEvidence.data()?['growthStatus'], 'captured');
    expect(staleEvidence.data()?['linkedMissionAttemptId'], isNull);
    expect(stalePortfolio.exists, isFalse);
  });

  testWidgets(
      'educator mission review carries structured live evidence into reviewed portfolio output when learner proof is absent',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCompletedMissionReadyForReview(firestore);
    await _seedReviewRubricAndEvidence(firestore);
    await firestore.collection('evidenceRecords').doc('evidence-1').set(
      <String, dynamic>{
        'checkpointSummary':
            'Checkpoint response connected the threshold choice to observed test data.',
        'reflectionNote':
            'Learner said they now understand why the slower calibration was more stable.',
        'aiAssistanceUsed': true,
        'aiAssistanceDetails':
            'AI suggested two calibration approaches, but the learner tested both and justified the final selection.',
      },
      SetOptions(merge: true),
    );
    await firestore
        .collection('missionAttempts')
        .doc('attempt-live-evidence')
        .set(
      <String, dynamic>{
        'missionId': 'mission-1',
        'missionTitle': 'Mission ready for review',
        'learnerId': 'learner-1',
        'siteId': 'site-1',
        'sessionOccurrenceId': 'occurrence-1',
        'status': 'submitted',
        'submittedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 10, 15)),
        'submissionText': 'Educator-captured evidence is ready for review.',
      },
    );

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await _pumpPage(tester, educatorMissionService);

    await tester.tap(find.text('Mission ready for review').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Reflection').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('4/4').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/4').at(1));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Reviewing educator-captured checkpoint and AI disclosure evidence.',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> evidenceDoc =
        await firestore.collection('evidenceRecords').doc('evidence-1').get();
    final DocumentSnapshot<Map<String, dynamic>> portfolioDoc =
        await firestore.collection('portfolioItems').doc('evidence-1').get();

    expect(
        evidenceDoc.data()?['linkedMissionAttemptId'], 'attempt-live-evidence');
    expect(portfolioDoc.exists, isTrue);
    expect(portfolioDoc.data()?['missionAttemptId'], 'attempt-live-evidence');
    expect(portfolioDoc.data()?['proofOfLearningStatus'], 'not-available');
    expect(portfolioDoc.data()?['artifactUrls'],
        contains('https://example.com/prototype.png'));
    expect(portfolioDoc.data()?['aiAssistanceUsed'], isTrue);
    expect(
        portfolioDoc.data()?['aiDisclosureStatus'], 'educator-observed-ai-use');
    expect(
      portfolioDoc.data()?['aiAssistanceDetails'],
      'AI suggested two calibration approaches, but the learner tested both and justified the final selection.',
    );
    expect(
      portfolioDoc.data()?['checkpointSummary'],
      'Checkpoint response connected the threshold choice to observed test data.',
    );
    expect(
      portfolioDoc.data()?['reflectionNote'],
      'Learner said they now understand why the slower calibration was more stable.',
    );
    expect(
      portfolioDoc.data()?['description'],
      contains(
          'Checkpoint response connected the threshold choice to observed test data.'),
    );
    expect(
      portfolioDoc.data()?['description'],
      contains(
          'Learner said they now understand why the slower calibration was more stable.'),
    );
  });

  testWidgets(
      'educator mission review maps current-occurrence unmapped live evidence into the reviewed capability',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedCompletedMissionReadyForReview(firestore);
    await _seedReviewRubricAndEvidence(firestore);
    await _seedUnmappedReviewEvidence(firestore);
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
      find.text('Reflection').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('4/4').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3/4').at(1));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'The unmapped live evidence from this occurrence should be claimed into the rubric capability.',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Approve'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pump();
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> unmappedEvidence =
        await firestore
            .collection('evidenceRecords')
            .doc('evidence-unmapped')
            .get();
    final DocumentSnapshot<Map<String, dynamic>> unmappedPortfolio =
        await firestore
            .collection('portfolioItems')
            .doc('evidence-unmapped')
            .get();

    expect(unmappedEvidence.data()?['capabilityId'], 'cap-prototype-evidence');
    expect(unmappedEvidence.data()?['capabilityMapped'], isTrue);
    expect(unmappedEvidence.data()?['linkedMissionAttemptId'], attemptId);
    expect(unmappedEvidence.data()?['growthStatus'], 'updated');
    expect(unmappedPortfolio.exists, isTrue);
    expect(unmappedPortfolio.data()?['missionAttemptId'], attemptId);
  });
}
