import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
      final Timestamp start = Timestamp.fromDate(now.add(const Duration(hours: 1)));
      final Timestamp end = Timestamp.fromDate(now.add(const Duration(hours: 2)));

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
  });
}
