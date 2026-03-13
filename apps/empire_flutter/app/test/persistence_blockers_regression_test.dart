import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/modules/checkin/checkin_service.dart';
import 'package:scholesa_app/modules/habits/habit_models.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/missions/mission_models.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

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
            'score': 4,
            'maxScore': 4,
          },
          <String, dynamic>{
            'criterionId': 'reflection',
            'label': 'Reflection',
            'score': 3,
            'maxScore': 4,
          },
        ],
      );

      expect(reviewed, isTrue);

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
      expect(submissionDoc.data()?['aiFeedbackDraft'], contains('evidence trail'));
      expect(submissionDoc.data()?['aiFeedbackEdited'], isTrue);

      final DocumentSnapshot<Map<String, dynamic>> assignmentDoc =
          await firestore
              .collection('missionAssignments')
              .doc('assignment-1')
              .get();
      expect(assignmentDoc.data()?['reviewStatus'], 'approved');
      expect(assignmentDoc.data()?['lastSubmissionId'], 'submission-1');
      expect(assignmentDoc.data()?['gradedBy'], 'educator-9');
      expect(assignmentDoc.data()?['rubricTotalScore'], 7);

      final DocumentSnapshot<Map<String, dynamic>> attemptDoc = await firestore
          .collection('missionAttempts')
          .doc('attempt-1')
          .get();
      expect(attemptDoc.data()?['reviewStatus'], 'approved');
      expect(attemptDoc.data()?['rubricId'], 'rubric-1');
      expect(attemptDoc.data()?['aiFeedbackEdited'], isTrue);

      final DocumentSnapshot<Map<String, dynamic>> rubricApplicationDoc =
          await firestore
              .collection('rubricApplications')
              .doc('submission-1')
              .get();
      expect(rubricApplicationDoc.exists, isTrue);
      expect(rubricApplicationDoc.data()?['missionAttemptId'], 'submission-1');
      expect(rubricApplicationDoc.data()?['rubricId'], 'rubric-1');
      expect(
        (rubricApplicationDoc.data()?['scores'] as List?)?.length,
        2,
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
      expect((data?['recommendedInterleavingMissionIds'] as List<dynamic>).first,
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

      final Map<String, dynamic> interleavingPayload = telemetryPayloads.firstWhere(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'interleaving.mode.changed',
      );
      expect(interleavingPayload['metadata']['mode'], 'scaffoldedMixed');
      expect(interleavingPayload['metadata']['recommended_count'], greaterThan(0));
    });

    test(
        'worked example support decays after sustained correct FSRS ratings',
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

      final DocumentSnapshot<Map<String, dynamic>> assignmentDoc = await firestore
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
  });
}
