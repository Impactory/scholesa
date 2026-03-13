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
  });
}
