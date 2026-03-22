import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/modules/attendance/attendance_models.dart';
import 'package:scholesa_app/modules/attendance/attendance_service.dart';
import 'package:scholesa_app/modules/checkin/checkin_models.dart';
import 'package:scholesa_app/modules/checkin/checkin_service.dart';
import 'package:scholesa_app/modules/habits/habit_models.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/missions/mission_models.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/offline/sync_coordinator.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockApiClient extends Mock implements ApiClient {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

void main() {
  group('Persistence blockers regression', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService firestoreService;
    late _MockFirebaseAuth auth;
    late _MockUser user;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = _MockFirebaseAuth();
      user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('site-staff-1');
      when(() => user.email).thenReturn('staff@example.com');
      when(() => user.displayName).thenReturn('Site Staff');
      firestoreService = FirestoreService(
        firestore: firestore,
        auth: auth,
      );
    });

    test('checkin service persists check-in/check-out/late to checkins',
        () async {
      final CheckinService service = CheckinService(
        firestoreService: firestoreService,
        siteId: 'site-1',
      );

      final bool checkedIn = await service.checkIn(
        learnerId: 'learner-1',
        learnerName: 'Learner One',
        visitorId: 'visitor-1',
        visitorName: 'Visitor One',
      );
      final bool checkedOut = await service.checkOut(
        learnerId: 'learner-1',
        learnerName: 'Learner One',
        visitorId: 'visitor-1',
        visitorName: 'Visitor One',
      );
      final bool markedLate = await service.markLate(
        learnerId: 'learner-2',
        learnerName: 'Learner Two',
      );

      expect(checkedIn, isTrue);
      expect(checkedOut, isTrue);
      expect(markedLate, isTrue);

      final records = await firestore.collection('checkins').get();
      expect(records.docs.length, 3);

      final types =
          records.docs.map((doc) => doc.data()['type'] as String?).toList();
      expect(types, contains('checkin'));
      expect(types, contains('checkout'));
      expect(types, contains('late'));
    });

    test('mission service persists mission assignment status transitions',
        () async {
      final MissionService service = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
      );

      await firestore.collection('missionAssignments').doc('assignment-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'status': 'not_started',
          'progress': 0.0,
        },
      );

      await firestore.collection('missions').doc('mission-1').set(
        <String, dynamic>{
          'title': 'Mission One',
          'description': 'Description',
          'pillarCode': 'future_skills',
          'difficulty': 'beginner',
          'xpReward': 100,
        },
      );

      await firestore
          .collection('missions')
          .doc('mission-1')
          .collection('steps')
          .doc('step-1')
          .set(
        <String, dynamic>{
          'title': 'Step One',
          'order': 1,
          'isCompleted': false,
        },
      );

      await service.loadMissions();

      final bool started = await service.startMission('mission-1');
      expect(started, isTrue);

      DocumentSnapshot<Map<String, dynamic>> assignmentDoc = await firestore
          .collection('missionAssignments')
          .doc('assignment-1')
          .get();
      expect(assignmentDoc.data()?['status'], 'in_progress');

      final bool completedStep =
          await service.completeStep('mission-1', 'step-1');
      expect(completedStep, isTrue);

      assignmentDoc = await firestore
          .collection('missionAssignments')
          .doc('assignment-1')
          .get();
      expect(assignmentDoc.data()?['status'], 'completed');
      expect((assignmentDoc.data()?['progress'] as num?)?.toDouble(), 1.0);

      final bool completedMission = await service.completeMission('mission-1');
      expect(completedMission, isTrue);

      assignmentDoc = await firestore
          .collection('missionAssignments')
          .doc('assignment-1')
          .get();
      expect(assignmentDoc.data()?['status'], 'completed');
    });

    test(
        'mission service persists educator grading with ai feedback and rubric support',
        () async {
      final MissionService service = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
      );

      await firestore.collection('missionAssignments').doc('assignment-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'completed',
          'progress': 1.0,
        },
      );

      await firestore.collection('missionAttempts').doc('attempt-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'submitted',
          'proofBundleId': 'learner-1_mission-1',
          'proofBundleSummary': <String, dynamic>{
            'isReady': true,
            'checkpointCount': 1,
            'hasExplainItBack': true,
            'hasOralCheck': true,
            'hasMiniRebuild': true,
            'hasLearnerAiDisclosure': true,
            'aiAssistanceUsed': true,
            'hasAiAssistanceDetails': true,
          },
        },
      );

      await firestore
          .collection('proofOfLearningBundles')
          .doc('learner-1_mission-1')
          .set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'explainItBack': 'I can explain why I chose this prototype path.',
          'oralCheckResponse': 'I can talk through the reasoning aloud.',
          'miniRebuildPlan':
              'I would rebuild the tradeoff test with a second example.',
          'aiAssistanceUsed': true,
          'aiAssistanceDetails':
              'AI helped brainstorm alternatives, but I chose and explained the final design.',
          'versionHistory': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'checkpoint-1',
              'summary': 'Prototype checkpoint',
              'createdAt': Timestamp.now(),
            },
          ],
        },
      );

      await firestore.collection('missionSubmissions').doc('submission-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'pending',
          'submittedAt': Timestamp.now(),
          'submissionText': 'Prototype upload with reflection notes.',
        },
      );

      await firestore.collection('evidenceRecords').doc('evidence-1').set(
        <String, dynamic>{
          'learnerId': 'learner-1',
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
          'observedAt': Timestamp.now(),
        },
      );

      final bool reviewed = await service.submitReview(
        submissionId: 'submission-1',
        rating: 4,
        feedback:
            'Great iteration. Tighten the evidence trail and explain the tradeoffs in your next revision.',
        reviewerId: 'educator-9',
        status: 'approved',
        aiFeedbackDraft:
            'Great iteration. Add a clearer evidence trail and explain the tradeoffs in your next revision.',
        rubricId: 'rubric-1',
        rubricTitle: 'Prototype Rubric',
        rubricScores: const <Map<String, dynamic>>[
          <String, dynamic>{
            'criterionId': 'evidence',
            'label': 'Evidence',
            'capabilityId': 'cap-prototype-evidence',
            'capabilityTitle': 'Prototype evidence',
            'pillarCode': 'future_skills',
            'score': 4,
            'maxScore': 4,
          },
          <String, dynamic>{
            'criterionId': 'reflection',
            'label': 'Reflection',
            'capabilityId': 'cap-prototype-evidence',
            'capabilityTitle': 'Prototype evidence',
            'pillarCode': 'future_skills',
            'score': 3,
            'maxScore': 4,
          },
        ],
      );

      if (!reviewed) {
        fail(service.error ?? 'submitReview returned false');
      }

      final DocumentSnapshot<Map<String, dynamic>> submissionDoc =
          await firestore
              .collection('missionSubmissions')
              .doc('submission-1')
              .get();
      expect(submissionDoc.data()?['status'], 'approved');
      expect(submissionDoc.data()?['rating'], 4);
      expect(submissionDoc.data()?['rubricId'], 'rubric-1');
      expect(submissionDoc.data()?['rubricTitle'], 'Prototype Rubric');
      expect(submissionDoc.data()?['rubricTotalScore'], 7);
      expect(submissionDoc.data()?['rubricMaxScore'], 8);
      expect(
          submissionDoc.data()?['aiFeedbackDraft'], contains('evidence trail'));
      expect(submissionDoc.data()?['aiFeedbackEdited'], isTrue);
      expect(submissionDoc.data()?['aiFeedbackBy'], 'educator-9');
      expect(submissionDoc.data()?['aiFeedbackAt'], isNotNull);

      final DocumentSnapshot<Map<String, dynamic>> assignmentDoc =
          await firestore
              .collection('missionAssignments')
              .doc('assignment-1')
              .get();
      expect(assignmentDoc.data()?['reviewStatus'], 'approved');
      expect(assignmentDoc.data()?['lastSubmissionId'], 'attempt-1');
      expect(assignmentDoc.data()?['gradedBy'], 'educator-9');
      expect(assignmentDoc.data()?['rubricTotalScore'], 7);
      expect(assignmentDoc.data()?['aiFeedbackBy'], 'educator-9');
      expect(assignmentDoc.data()?['aiFeedbackAt'], isNotNull);

      final DocumentSnapshot<Map<String, dynamic>> attemptDoc =
          await firestore.collection('missionAttempts').doc('attempt-1').get();
      expect(attemptDoc.data()?['status'], 'reviewed');
      expect(attemptDoc.data()?['reviewStatus'], 'approved');
      expect(attemptDoc.data()?['reviewedBy'], 'educator-9');
      expect(attemptDoc.data()?['rubricId'], 'rubric-1');
      expect(attemptDoc.data()?['aiFeedbackEdited'], isTrue);
      expect(attemptDoc.data()?['aiFeedbackBy'], 'educator-9');
      expect(attemptDoc.data()?['aiFeedbackAt'], isNotNull);

      final DocumentSnapshot<Map<String, dynamic>> rubricApplicationDoc =
          await firestore
              .collection('rubricApplications')
              .doc('attempt-1')
              .get();
      expect(rubricApplicationDoc.exists, isTrue);
      expect(rubricApplicationDoc.data()?['missionAttemptId'], 'attempt-1');
      expect(rubricApplicationDoc.data()?['rubricId'], 'rubric-1');
      expect(
        (rubricApplicationDoc.data()?['scores'] as List?)?.length,
        2,
      );

      final DocumentSnapshot<Map<String, dynamic>> portfolioDoc =
          await firestore.collection('portfolioItems').doc('evidence-1').get();
      expect(portfolioDoc.exists, isTrue);
      expect(portfolioDoc.data()?['proofOfLearningStatus'], 'verified');
      expect(portfolioDoc.data()?['aiAssistanceUsed'], isTrue);
      expect(portfolioDoc.data()?['aiFeedbackBy'], 'educator-9');
      expect(portfolioDoc.data()?['aiFeedbackAt'], isNotNull);
      expect(
        portfolioDoc.data()?['aiAssistanceDetails'],
        contains('brainstorm alternatives'),
      );
      expect(portfolioDoc.data()?['aiDisclosureStatus'], 'learner-ai-verified');

      final bool humanOnlyReviewed = await service.submitReview(
        submissionId: 'submission-1',
        rating: 4,
        feedback:
            'Human-only follow-up. Keep tightening the evidence trail with one more concrete example.',
        reviewerId: 'educator-9',
        status: 'approved',
        rubricId: 'rubric-1',
        rubricTitle: 'Prototype Rubric',
        rubricScores: const <Map<String, dynamic>>[
          <String, dynamic>{
            'criterionId': 'evidence',
            'label': 'Evidence',
            'capabilityId': 'cap-prototype-evidence',
            'capabilityTitle': 'Prototype evidence',
            'pillarCode': 'future_skills',
            'score': 4,
            'maxScore': 4,
          },
          <String, dynamic>{
            'criterionId': 'reflection',
            'label': 'Reflection',
            'capabilityId': 'cap-prototype-evidence',
            'capabilityTitle': 'Prototype evidence',
            'pillarCode': 'future_skills',
            'score': 3,
            'maxScore': 4,
          },
        ],
      );

      if (!humanOnlyReviewed) {
        fail(service.error ?? 'second submitReview returned false');
      }

      final DocumentSnapshot<Map<String, dynamic>> submissionDocAfterClear =
          await firestore
              .collection('missionSubmissions')
              .doc('submission-1')
              .get();
      expect(
        submissionDocAfterClear.data()?['aiFeedbackDraft'],
        isNull,
        reason: 'submission aiFeedbackDraft should clear',
      );
      expect(
        submissionDocAfterClear.data()?['aiFeedbackEdited'],
        isNull,
        reason: 'submission aiFeedbackEdited should clear',
      );
      expect(
        submissionDocAfterClear.data()?['aiFeedbackBy'],
        isNull,
        reason: 'submission aiFeedbackBy should clear',
      );
      expect(
        submissionDocAfterClear.data()?['aiFeedbackAt'],
        isNull,
        reason: 'submission aiFeedbackAt should clear',
      );

      final DocumentSnapshot<Map<String, dynamic>> assignmentDocAfterClear =
          await firestore
              .collection('missionAssignments')
              .doc('assignment-1')
              .get();
      expect(
        assignmentDocAfterClear.data()?['aiFeedbackDraft'],
        isNull,
        reason: 'assignment aiFeedbackDraft should clear',
      );
      expect(
        assignmentDocAfterClear.data()?['aiFeedbackEdited'],
        isNull,
        reason: 'assignment aiFeedbackEdited should clear',
      );
      expect(
        assignmentDocAfterClear.data()?['aiFeedbackBy'],
        isNull,
        reason: 'assignment aiFeedbackBy should clear',
      );
      expect(
        assignmentDocAfterClear.data()?['aiFeedbackAt'],
        isNull,
        reason: 'assignment aiFeedbackAt should clear',
      );

      final DocumentSnapshot<Map<String, dynamic>> attemptDocAfterClear =
          await firestore.collection('missionAttempts').doc('attempt-1').get();
      expect(
        attemptDocAfterClear.data()?['aiFeedbackDraft'],
        isNull,
        reason: 'attempt aiFeedbackDraft should clear',
      );
      expect(
        attemptDocAfterClear.data()?['aiFeedbackEdited'],
        isNull,
        reason: 'attempt aiFeedbackEdited should clear',
      );
      expect(
        attemptDocAfterClear.data()?['aiFeedbackBy'],
        isNull,
        reason: 'attempt aiFeedbackBy should clear',
      );
      expect(
        attemptDocAfterClear.data()?['aiFeedbackAt'],
        isNull,
        reason: 'attempt aiFeedbackAt should clear',
      );

      final DocumentSnapshot<Map<String, dynamic>> portfolioDocAfterClear =
          await firestore.collection('portfolioItems').doc('evidence-1').get();
      expect(
        portfolioDocAfterClear.data()?['aiFeedbackBy'],
        isNull,
        reason: 'portfolio aiFeedbackBy should clear',
      );
      expect(
        portfolioDocAfterClear.data()?['aiFeedbackAt'],
        isNull,
        reason: 'portfolio aiFeedbackAt should clear',
      );
    });

    test(
        'mission service persists study flow controls and emits learner telemetry',
        () async {
      final MissionService service = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
      );
      final List<Map<String, dynamic>> telemetryPayloads =
          <Map<String, dynamic>>[];

      await firestore.collection('missionAssignments').doc('assignment-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.5,
        },
      );
      await firestore.collection('missionAssignments').doc('assignment-2').set(
        <String, dynamic>{
          'missionId': 'mission-2',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.25,
        },
      );
      await firestore.collection('missionAssignments').doc('assignment-3').set(
        <String, dynamic>{
          'missionId': 'mission-3',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.20,
        },
      );

      await firestore.collection('skills').doc('skill-robotics').set(
        <String, dynamic>{
          'name': 'Robotics',
          'pillarCode': 'future_skills',
        },
      );
      await firestore.collection('skills').doc('skill-design').set(
        <String, dynamic>{
          'name': 'Design',
          'pillarCode': 'impact',
        },
      );

      await firestore.collection('missions').doc('mission-1').set(
        <String, dynamic>{
          'title': 'Mission One',
          'description': 'Description',
          'pillarCode': 'future_skills',
          'difficulty': 'beginner',
          'xpReward': 100,
          'skillIds': <String>['skill-robotics'],
        },
      );
      await firestore.collection('missions').doc('mission-2').set(
        <String, dynamic>{
          'title': 'Mission Two',
          'description': 'Description 2',
          'pillarCode': 'future_skills',
          'difficulty': 'intermediate',
          'xpReward': 120,
          'skillIds': <String>['skill-robotics'],
        },
      );
      await firestore.collection('missions').doc('mission-3').set(
        <String, dynamic>{
          'title': 'Mission Three',
          'description': 'Description 3',
          'pillarCode': 'future_skills',
          'difficulty': 'intermediate',
          'xpReward': 140,
          'skillIds': <String>['skill-design'],
        },
      );

      await firestore.collection('missionSnapshots').doc('snapshot-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'skillIds': <String>['skill-robotics'],
          'pillarCodes': <String>['future_skills'],
          'bodyJson': <String, dynamic>{
            'misconceptionTags': <String>['loops', 'sequencing'],
          },
        },
      );
      await firestore.collection('missionSnapshots').doc('snapshot-2').set(
        <String, dynamic>{
          'missionId': 'mission-2',
          'skillIds': <String>['skill-robotics'],
          'pillarCodes': <String>['future_skills'],
          'bodyJson': <String, dynamic>{
            'scaffold': <String, dynamic>{
              'misconceptions': <String>['loops'],
            },
          },
        },
      );
      await firestore.collection('missionSnapshots').doc('snapshot-3').set(
        <String, dynamic>{
          'missionId': 'mission-3',
          'skillIds': <String>['skill-design'],
          'pillarCodes': <String>['future_skills'],
          'bodyJson': <String, dynamic>{
            'confusabilityTags': <String>['visual-design'],
          },
        },
      );

      await firestore
          .collection('missions')
          .doc('mission-1')
          .collection('steps')
          .doc('step-1')
          .set(
        <String, dynamic>{
          'title': 'Step One',
          'order': 1,
          'isCompleted': false,
        },
      );

      await service.loadMissions();

      await TelemetryService.runWithDispatcher(
        (Map<String, dynamic> payload) async {
          telemetryPayloads.add(Map<String, dynamic>.from(payload));
        },
        () async {
          expect(
            await service.rateFsrsReview(
              'mission-1',
              rating: FsrsRating.good,
            ),
            isTrue,
          );
          expect(await service.snoozeFsrsQueue('mission-1'), isTrue);
          expect(
            await service.rescheduleFsrsQueue('mission-1', days: 3),
            isTrue,
          );
          expect(await service.suspendFsrsQueue('mission-1'), isTrue);
          expect(
            await service.setInterleavingMode(
              'mission-1',
              mode: InterleavingMode.scaffoldedMixed,
            ),
            isTrue,
          );
          expect(await service.showWorkedExample('mission-1'), isTrue);
          expect(await service.showWorkedExample('mission-1'), isTrue);
        },
      );

      final DocumentSnapshot<Map<String, dynamic>> assignmentDoc =
          await firestore
              .collection('missionAssignments')
              .doc('assignment-1')
              .get();
      final Map<String, dynamic>? data = assignmentDoc.data();

      expect(data?['fsrsLastRating'], 'good');
      expect(data?['fsrsQueueState'], 'suspended');
      expect(data?.containsKey('nextReviewAt'), isFalse);
      expect(data?['interleavingMode'], 'scaffoldedMixed');
      expect(data?['recommendedInterleavingMissionIds'], contains('mission-2'));
      expect(
          (data?['recommendedInterleavingMissionIds'] as List<dynamic>).first,
          'mission-2');
      expect(data?['workedExampleShown'], true);
      expect(data?['workedExampleFadeStage'], 2);
      expect(data?['workedExamplePromptLevel'], 'partialSteps');

      final List<String> emittedEvents = telemetryPayloads
          .map((Map<String, dynamic> payload) => payload['event'] as String?)
          .whereType<String>()
          .toList();
      expect(emittedEvents, contains('fsrs.review.rated'));
      expect(emittedEvents, contains('fsrs.queue.snoozed'));
      expect(emittedEvents, contains('fsrs.queue.rescheduled'));
      expect(emittedEvents, contains('interleaving.mode.changed'));
      expect(emittedEvents, contains('worked_example.shown'));

      final Map<String, dynamic> fsrsPayload = telemetryPayloads.firstWhere(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'fsrs.review.rated',
      );
      expect(fsrsPayload['siteId'], 'site-1');
      expect(fsrsPayload['role'], 'learner');
      expect(fsrsPayload['metadata']['rating'], 'good');

      final Map<String, dynamic> interleavingPayload =
          telemetryPayloads.firstWhere(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'interleaving.mode.changed',
      );
      expect(interleavingPayload['metadata']['mode'], 'scaffoldedMixed');
      expect(
          interleavingPayload['metadata']['recommended_count'], greaterThan(0));
    });

    test('worked example support decays after sustained correct FSRS ratings',
        () async {
      final MissionService service = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
      );
      final List<Map<String, dynamic>> telemetryPayloads =
          <Map<String, dynamic>>[];

      await firestore.collection('missionAssignments').doc('assignment-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
          'status': 'in_progress',
          'progress': 0.5,
          'workedExampleFadeStage': 1,
          'workedExamplePromptLevel': 'fullModel',
          'workedExampleSuccessStreak': 0,
        },
      );
      await firestore.collection('missions').doc('mission-1').set(
        <String, dynamic>{
          'title': 'Mission One',
          'description': 'Description',
          'pillarCode': 'future_skills',
          'difficulty': 'beginner',
          'xpReward': 100,
        },
      );
      await firestore
          .collection('missions')
          .doc('mission-1')
          .collection('steps')
          .doc('step-1')
          .set(
        <String, dynamic>{
          'title': 'Step One',
          'order': 1,
          'isCompleted': false,
        },
      );

      await service.loadMissions();

      await TelemetryService.runWithDispatcher(
        (Map<String, dynamic> payload) async {
          telemetryPayloads.add(Map<String, dynamic>.from(payload));
        },
        () async {
          expect(
            await service.rateFsrsReview(
              'mission-1',
              rating: FsrsRating.good,
            ),
            isTrue,
          );
          expect(
            await service.rateFsrsReview(
              'mission-1',
              rating: FsrsRating.easy,
            ),
            isTrue,
          );
        },
      );

      final DocumentSnapshot<Map<String, dynamic>> assignmentDoc =
          await firestore
              .collection('missionAssignments')
              .doc('assignment-1')
              .get();
      final Map<String, dynamic>? data = assignmentDoc.data();

      expect(data?['workedExampleFadeStage'], 2);
      expect(data?['workedExamplePromptLevel'], 'partialSteps');
      expect(data?['workedExampleSuccessStreak'], 0);

      final Map<String, dynamic> fsrsPayload = telemetryPayloads.lastWhere(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'fsrs.review.rated',
      );
      expect(fsrsPayload['metadata']['worked_example_policy_action'], 'decay');
      expect(fsrsPayload['metadata']['worked_example_fade_stage'], 2);
      expect(fsrsPayload['metadata']['worked_example_prompt_level'],
          'partialSteps');
    });

    test('habit service wrappers persist creation and completion in Firestore',
        () async {
      final HabitService service = HabitService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
      );

      final createdHabit = await service.createHabit(
        title: 'Read 10 min',
        emoji: '📚',
        category: HabitCategory.learning,
      );

      expect(createdHabit, isNotNull);

      final habits = await firestore.collection('habits').get();
      expect(habits.docs.length, 1);
      expect(habits.docs.first.data()['title'], 'Read 10 min');

      final bool completed = await service.completeHabit(createdHabit!.id);
      expect(completed, isTrue);

      final logs = await firestore.collection('habitLogs').get();
      expect(logs.docs.length, 1);
      expect(logs.docs.first.data()['habitId'], createdHabit.id);
    });

    test('habit service keeps stale habits visible after refresh failure',
        () async {
      int loadCount = 0;
      final Habit seededHabit = Habit(
        id: 'habit-1',
        title: 'Read 10 min',
        emoji: '📚',
        category: HabitCategory.learning,
        frequency: HabitFrequency.daily,
        preferredTime: HabitTimePreference.anytime,
        targetMinutes: 10,
        createdAt: DateTime(2026, 1, 1),
        currentStreak: 4,
        longestStreak: 7,
        totalCompletions: 12,
        isActive: true,
      );
      final HabitLog seededLog = HabitLog(
        id: 'log-1',
        habitId: 'habit-1',
        completedAt: DateTime(2026, 1, 2),
        durationMinutes: 10,
      );
      final HabitService service = HabitService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
        snapshotLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return HabitLoadSnapshot(
              habits: <Habit>[seededHabit],
              recentLogs: <HabitLog>[seededLog],
            );
          }
          throw Exception('network down');
        },
      );

      await service.loadHabits();
      await service.loadHabits();

      expect(service.habits, hasLength(1));
      expect(service.habits.single.title, 'Read 10 min');
      expect(service.recentLogs, hasLength(1));
      expect(service.weeklySummary, isNotNull);
      expect(service.error, contains('Failed to load habits'));
      expect(service.isLoading, isFalse);
    });

    test(
        'mission service keeps stale missions and progress after refresh failure',
        () async {
      int loadCount = 0;
      final Mission seededMission = Mission(
        id: 'mission-1',
        title: 'Build a bridge',
        description: 'Prototype and explain load paths',
        pillar: Pillar.futureSkills,
        difficulty: DifficultyLevel.beginner,
        status: MissionStatus.inProgress,
        progress: 0.5,
        steps: const <MissionStep>[
          MissionStep(
            id: 'step-1',
            title: 'Sketch ideas',
            order: 1,
            isCompleted: true,
          ),
          MissionStep(
            id: 'step-2',
            title: 'Build prototype',
            order: 2,
          ),
        ],
        recommendedInterleavingMissionIds: const <String>['mission-2'],
        confusabilityBand: 'medium',
      );
      final MissionService service = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
        missionsLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return <Mission>[seededMission];
          }
          throw Exception('network down');
        },
      );

      await service.loadMissions();
      final LearnerProgress? initialProgress = service.progress;
      await service.loadMissions();

      expect(service.missions, hasLength(1));
      expect(service.missions.single.title, 'Build a bridge');
      expect(service.missions.single.recommendedInterleavingMissionIds,
          contains('mission-2'));
      expect(service.progress, isNotNull);
      expect(service.progress?.totalXp, initialProgress?.totalXp);
      expect(service.error, contains('Failed to load missions'));
      expect(service.isLoading, isFalse);
    });

    test('shared firestore message service uses messageThreads and threadId',
        () async {
      await firestore.collection('users').doc('site-staff-1').set(
        <String, dynamic>{'displayName': 'Site Staff'},
      );
      await firestore.collection('users').doc('parent-1').set(
        <String, dynamic>{'displayName': 'Parent One'},
      );
      await firestore.collection('messageThreads').doc('thread-1').set(
        <String, dynamic>{
          'participantIds': <String>['site-staff-1', 'parent-1'],
          'participantNames': <String>['Site Staff', 'Parent One'],
          'status': 'open',
        },
      );

      final String messageId = await firestoreService.sendMessage(
        conversationId: 'thread-1',
        content: 'Workflow update ready',
      );

      final DocumentSnapshot<Map<String, dynamic>> messageDoc =
          await firestore.collection('messages').doc(messageId).get();
      final Map<String, dynamic>? messageData = messageDoc.data();
      expect(messageData?['threadId'], 'thread-1');
      expect(messageData?['recipientId'], 'parent-1');
      expect(messageData?['body'], 'Workflow update ready');
      expect(messageData?['status'], 'sent');
      expect(messageData?['metadata']['threadId'], 'thread-1');

      final DocumentSnapshot<Map<String, dynamic>> threadDoc =
          await firestore.collection('messageThreads').doc('thread-1').get();
      expect(threadDoc.data()?['lastMessageSenderId'], 'site-staff-1');
      expect(threadDoc.data()?['status'], 'open');

      final QuerySnapshot<Map<String, dynamic>> conversations =
          await firestore.collection('conversations').get();
      expect(conversations.docs, isEmpty);
    });

    test(
        'attendance service keeps stale occurrences visible after refresh failure',
        () async {
      int loadCount = 0;
      final AttendanceService service = AttendanceService(
        apiClient: _MockApiClient(),
        syncCoordinator: _MockSyncCoordinator(),
        educatorId: 'educator-1',
        siteId: 'site-1',
        occurrencesLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return AttendanceOccurrencesSnapshot(
              occurrences: <SessionOccurrence>[
                SessionOccurrence(
                  id: 'occ-1',
                  sessionId: 'session-1',
                  siteId: 'site-1',
                  title: 'Robotics Lab',
                  startTime: DateTime(2026, 3, 21, 9),
                  endTime: DateTime(2026, 3, 21, 10),
                  learnerCount: 12,
                ),
              ],
            );
          }
          throw Exception('network down');
        },
      );

      await service.loadTodayOccurrences();
      await service.loadTodayOccurrences();

      expect(service.todayOccurrences, hasLength(1));
      expect(service.todayOccurrences.single.title, 'Robotics Lab');
      expect(service.error, contains('Failed to load occurrences'));
    });

    test(
        'checkin service keeps stale learner summaries visible after refresh failure',
        () async {
      int loadCount = 0;
      final CheckinService service = CheckinService(
        firestoreService: firestoreService,
        siteId: 'site-1',
        daySnapshotLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return CheckinDaySnapshot(
              learnerSummaries: <LearnerDaySummary>[
                const LearnerDaySummary(
                  learnerId: 'learner-1',
                  learnerName: 'Ava Learner',
                  currentStatus: CheckStatus.checkedIn,
                ),
              ],
              todayRecords: <CheckRecord>[
                CheckRecord(
                  id: 'record-1',
                  visitorId: 'visitor-1',
                  visitorName: 'Parent One',
                  learnerId: 'learner-1',
                  learnerName: 'Ava Learner',
                  siteId: 'site-1',
                  timestamp: DateTime(2026, 3, 21, 8, 30),
                  status: CheckStatus.checkedIn,
                ),
              ],
            );
          }
          throw Exception('network down');
        },
      );

      await service.loadTodayData();
      await service.loadTodayData();

      expect(service.learnerSummaries, hasLength(1));
      expect(service.learnerSummaries.single.learnerName, 'Ava Learner');
      expect(service.todayRecords, hasLength(1));
      expect(service.error, contains('Failed to load check-in data'));
    });
  });
}
