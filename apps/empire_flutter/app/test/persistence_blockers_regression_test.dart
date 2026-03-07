import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/modules/checkin/checkin_service.dart';
import 'package:scholesa_app/modules/habits/habit_models.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

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

      DocumentSnapshot<Map<String, dynamic>> assignmentDoc =
          await firestore.collection('missionAssignments').doc('assignment-1').get();
      expect(assignmentDoc.data()?['status'], 'in_progress');

      final bool completedStep = await service.completeStep('mission-1', 'step-1');
      expect(completedStep, isTrue);

      assignmentDoc =
          await firestore.collection('missionAssignments').doc('assignment-1').get();
      expect(assignmentDoc.data()?['status'], 'completed');
      expect((assignmentDoc.data()?['progress'] as num?)?.toDouble(), 1.0);

      final bool completedMission = await service.completeMission('mission-1');
      expect(completedMission, isTrue);

      assignmentDoc =
          await firestore.collection('missionAssignments').doc('assignment-1').get();
      expect(assignmentDoc.data()?['status'], 'completed');
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
