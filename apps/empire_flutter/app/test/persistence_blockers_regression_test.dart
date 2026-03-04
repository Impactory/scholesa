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

void main() {
  group('Persistence blockers regression', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService firestoreService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );
    });

    test('checkin service persists check-in/check-out/late to presenceRecords',
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

      final records = await firestore.collection('presenceRecords').get();
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
  });
}
