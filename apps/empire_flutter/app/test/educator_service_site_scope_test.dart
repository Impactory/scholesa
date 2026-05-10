import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  group('EducatorService site scoping', () {
    test('loadTodaySchedule only includes active site records', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      final DateTime now = DateTime.now();
      final DateTime anchor = DateTime(now.year, now.month, now.day, 12);
      final Timestamp start =
          Timestamp.fromDate(anchor.add(const Duration(hours: 1)));
      final Timestamp end =
          Timestamp.fromDate(anchor.add(const Duration(hours: 2)));

      await firestore.collection('sessionOccurrences').doc('occ-site-a').set(
        <String, dynamic>{
          'educatorId': 'educator-1',
          'siteId': 'site-a',
          'title': 'Site A class',
          'startTime': start,
          'endTime': end,
          'status': 'upcoming',
        },
      );

      await firestore.collection('sessionOccurrences').doc('occ-site-b').set(
        <String, dynamic>{
          'educatorId': 'educator-1',
          'siteId': 'site-b',
          'title': 'Site B class',
          'startTime': start,
          'endTime': end,
          'status': 'upcoming',
        },
      );

      final EducatorService service = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-1',
        siteId: 'site-a',
      );

      await service.loadTodaySchedule();

      expect(service.todayClasses.length, 1);
      expect(service.todayClasses.first.id, 'occ-site-a');
      expect(service.todayClasses.first.title, 'Site A class');
    });

    test('loadTodaySchedule keeps stale classes visible after refresh failure',
        () async {
      int loadCount = 0;
      final EducatorService service = EducatorService(
        firestoreService: FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        ),
        educatorId: 'educator-1',
        siteId: 'site-a',
        todayScheduleLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return TodayScheduleSnapshot(
              todayClasses: <TodayClass>[
                TodayClass(
                  id: 'occ-site-a',
                  sessionId: 'session-1',
                  title: 'Site A class',
                  startTime: DateTime(2026, 3, 21, 9),
                  endTime: DateTime(2026, 3, 21, 10),
                  enrolledCount: 12,
                  presentCount: 9,
                  status: 'upcoming',
                ),
              ],
              dayStats: const EducatorDayStats(
                totalClasses: 1,
                completedClasses: 0,
                totalLearners: 12,
                presentLearners: 9,
                missionsToReview: 2,
                unreadMessages: 1,
              ),
            );
          }
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message:
                'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
          );
        },
      );

      await service.loadTodaySchedule();
      await service.loadTodaySchedule();

      expect(service.todayClasses, hasLength(1));
      expect(service.todayClasses.single.title, 'Site A class');
      expect(service.dayStats, isNotNull);
      expect(service.dayStats?.totalClasses, 1);
      expect(
        service.error,
        "Today's educator schedule could not load right now. Refresh, or check again after the app reconnects.",
      );
      expect(service.error, isNot(contains('console.firebase.google.com')));
      expect(service.error, isNot(contains('failed-precondition')));
    });

    test('loadSessions keeps stale sessions visible after refresh failure',
        () async {
      int loadCount = 0;
      final EducatorService service = EducatorService(
        firestoreService: FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        ),
        educatorId: 'educator-1',
        siteId: 'site-a',
        sessionsLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return EducatorSessionsSnapshot(
              sessions: <EducatorSession>[
                EducatorSession(
                  id: 'session-1',
                  title: 'Launch Lab',
                  pillar: 'future_skills',
                  startTime: DateTime(2026, 3, 21, 9),
                  endTime: DateTime(2026, 3, 21, 10),
                  location: 'Studio A',
                  enrolledCount: 12,
                  maxCapacity: 16,
                  status: 'upcoming',
                ),
              ],
            );
          }
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message:
                'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
          );
        },
      );

      await service.loadSessions();
      await service.loadSessions();

      expect(service.sessions, hasLength(1));
      expect(service.sessions.single.title, 'Launch Lab');
      expect(
        service.error,
        'Session list could not load right now. Refresh, or check again after the app reconnects.',
      );
      expect(service.error, isNot(contains('console.firebase.google.com')));
      expect(service.error, isNot(contains('failed-precondition')));
    });

    test('loadLearners only includes learners in active site', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      await firestore.collection('enrollments').doc('enr-1').set(
        <String, dynamic>{
          'educatorId': 'educator-1',
          'learnerId': 'learner-a',
          'siteId': 'site-a',
        },
      );

      await firestore.collection('enrollments').doc('enr-2').set(
        <String, dynamic>{
          'educatorId': 'educator-1',
          'learnerId': 'learner-b',
          'siteId': 'site-b',
        },
      );

      await firestore.collection('users').doc('learner-a').set(
        <String, dynamic>{
          'displayName': 'Learner A',
          'email': 'a@test.dev',
          'siteIds': <String>['site-a'],
        },
      );

      await firestore.collection('users').doc('learner-b').set(
        <String, dynamic>{
          'displayName': 'Learner B',
          'email': 'b@test.dev',
          'siteIds': <String>['site-b'],
        },
      );

      final EducatorService service = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-1',
        siteId: 'site-a',
      );

      await service.loadLearners();

      expect(service.learners.length, 1);
      expect(service.learners.first.id, 'learner-a');
      expect(service.learners.first.name, 'Learner A');
    });

    test('loadLearners uses reviewed capability mastery for pillar progress',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      await firestore.collection('enrollments').doc('enr-1').set(
        <String, dynamic>{
          'educatorId': 'educator-1',
          'learnerId': 'learner-a',
          'siteId': 'site-a',
        },
      );

      await firestore.collection('users').doc('learner-a').set(
        <String, dynamic>{
          'displayName': 'Learner A',
          'email': 'a@test.dev',
          'siteIds': <String>['site-a'],
          'futureSkillsProgress': 0.95,
          'leadershipProgress': 0.91,
          'impactProgress': 0.89,
        },
      );

      await firestore.collection('capabilityMastery').doc('mastery-future').set(
        <String, dynamic>{
          'learnerId': 'learner-a',
          'siteId': 'site-a',
          'capabilityId': 'future-capability',
          'pillarCode': 'future_skills',
          'latestLevel': 1,
          'highestLevel': 1,
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 23)),
        },
      );
      await firestore
          .collection('capabilityMastery')
          .doc('mastery-leadership')
          .set(
        <String, dynamic>{
          'learnerId': 'learner-a',
          'siteId': 'site-a',
          'capabilityId': 'leadership-capability',
          'pillarCode': 'leadership',
          'latestLevel': 2,
          'highestLevel': 2,
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 23)),
        },
      );

      final EducatorService service = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-1',
        siteId: 'site-a',
      );

      await service.loadLearners();

      expect(service.learners, hasLength(1));
      expect(service.learners.single.futureSkillsProgress, 0.25);
      expect(service.learners.single.leadershipProgress, 0.5);
      expect(service.learners.single.impactProgress, 0);
    });

    test('loadLearners keeps stale learners visible after refresh failure',
        () async {
      int loadCount = 0;
      final EducatorService service = EducatorService(
        firestoreService: FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        ),
        educatorId: 'educator-1',
        siteId: 'site-a',
        learnersLoader: () async {
          loadCount += 1;
          if (loadCount == 1) {
            return const EducatorLearnersSnapshot(
              learners: <EducatorLearner>[
                EducatorLearner(
                  id: 'learner-a',
                  name: 'Learner A',
                  email: 'a@test.dev',
                  attendanceRate: 91,
                  missionsCompleted: 4,
                  pillarProgress: <String, double>{
                    'future_skills': 0.52,
                    'leadership': 0.41,
                    'impact': 0.39,
                  },
                  enrolledSessionIds: <String>['session-1'],
                ),
              ],
            );
          }
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message:
                'The query requires an index. You can create it here: https://console.firebase.google.com/project/demo/firestore/indexes',
          );
        },
      );

      await service.loadLearners();
      await service.loadLearners();

      expect(service.learners, hasLength(1));
      expect(service.learners.single.name, 'Learner A');
      expect(
        service.error,
        'Learner roster could not load right now. Refresh, or check again after the app reconnects.',
      );
      expect(service.error, isNot(contains('console.firebase.google.com')));
      expect(service.error, isNot(contains('failed-precondition')));
    });

    test('createSession persists join code and teacher role variants',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      final EducatorService service = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-1',
        siteId: 'site-a',
      );

      final EducatorSession? created = await service.createSession(
        title: 'Launch Lab',
        pillar: 'Future Skills',
        startTime: DateTime(2026, 3, 13, 9),
        endTime: DateTime(2026, 3, 13, 10),
        coTeacherIds: const <String>['educator-2', 'educator-3'],
        aideIds: const <String>['aide-1'],
        joinCode: 'LAB123',
      );

      expect(created, isNotNull);
      expect(created!.joinCode, 'LAB123');
      expect(created.teacherIds, const <String>['educator-1']);
      expect(
        created.coTeacherIds,
        const <String>['educator-2', 'educator-3'],
      );
      expect(created.aideIds, const <String>['aide-1']);

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await firestore.collection('sessions').get();
      expect(snapshot.docs.length, 1);

      final Map<String, dynamic> data = snapshot.docs.single.data();
      expect(data['siteId'], 'site-a');
      expect(data['joinCode'], 'LAB123');
      expect(data['teacherIds'], const <String>['educator-1']);
      expect(
        data['coTeacherIds'],
        const <String>['educator-2', 'educator-3'],
      );
      expect(data['aideIds'], const <String>['aide-1']);
      expect(
        data['educatorIds'],
        const <String>['aide-1', 'educator-1', 'educator-2', 'educator-3'],
      );
      expect(data['joinCodeCreatedAt'], isNotNull);
    });

    test('importRosterCsv enrolls known learners and queues unknown rows',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final FirestoreService firestoreService = FirestoreService(
        firestore: firestore,
        auth: _MockFirebaseAuth(),
      );

      await firestore.collection('sessions').doc('session-1').set(
        <String, dynamic>{
          'siteId': 'site-a',
          'educatorId': 'educator-1',
          'educatorIds': const <String>['educator-1'],
          'title': 'Launch Lab',
          'enrolledCount': 0,
        },
      );
      await firestore.collection('users').doc('learner-a').set(
        <String, dynamic>{
          'displayName': 'Known Learner',
          'email': 'known@example.com',
          'role': 'learner',
          'siteIds': const <String>['site-a'],
        },
      );

      final EducatorService service = EducatorService(
        firestoreService: firestoreService,
        educatorId: 'educator-1',
        siteId: 'site-a',
      );

      final RosterImportOutcome? outcome = await service.importRosterCsv(
        sessionId: 'session-1',
        csvContent:
            'name,email\nKnown Learner,known@example.com\nNew Learner,new@example.com',
      );

      expect(outcome, isNotNull);
      expect(outcome!.totalRows, 2);
      expect(outcome.importedCount, 1);
      expect(outcome.queuedCount, 1);
      expect(outcome.duplicateCount, 0);
      expect(outcome.queuedEmails, contains('new@example.com'));

      final QuerySnapshot<Map<String, dynamic>> enrollments =
          await firestore.collection('enrollments').get();
      expect(enrollments.docs, hasLength(1));
      expect(enrollments.docs.first.data()['learnerId'], 'learner-a');
      expect(enrollments.docs.first.data()['sessionId'], 'session-1');

      final QuerySnapshot<Map<String, dynamic>> queuedRows =
          await firestore.collection('rosterImports').get();
      expect(queuedRows.docs, hasLength(1));
      expect(queuedRows.docs.first.data()['email'], 'new@example.com');
      expect(queuedRows.docs.first.data()['status'], 'pending_provisioning');

      final DocumentSnapshot<Map<String, dynamic>> sessionDoc =
          await firestore.collection('sessions').doc('session-1').get();
      expect(sessionDoc.data()?['enrolledCount'], 1);
      expect(sessionDoc.data()?['lastRosterSyncAt'], isNotNull);
    });
  });
}
