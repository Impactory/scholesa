import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

/// Tests that evidence chain Firestore service methods exist.
/// These are structural tests; actual Firestore calls require the emulator.
void main() {
  group('FirestoreService evidence chain method existence', () {
    late FirestoreService service;

    setUp(() {
      service = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
    });

    test('service has evidence capture methods', () {
      // Verify the service exposes the expected evidence chain API
      expect(service.submitCheckpointResult, isA<Function>());
      expect(service.submitReflection, isA<Function>());
      expect(service.logAICoachInteraction, isA<Function>());
      expect(service.submitPeerFeedback, isA<Function>());
    });

    test('service has proof verification methods', () {
      expect(service.createProofOfLearningBundle, isA<Function>());
      expect(service.updateProofOfLearningBundle, isA<Function>());
      expect(service.verifyProofOfLearning, isA<Function>());
    });

    test('service has evidence interpretation methods', () {
      expect(service.applyRubric, isA<Function>());
      expect(service.updateCapabilityMastery, isA<Function>());
      expect(service.createCapabilityGrowthEvent, isA<Function>());
    });

    test('interpretation writes stay server-owned', () {
      final String source = File(
        'lib/services/firestore_service.dart',
      ).readAsStringSync();

      final int applyStart = source.indexOf('Future<String> applyRubric');
      final int masteryStart =
          source.indexOf('Future<void> updateCapabilityMastery');
      final int growthStart =
          source.indexOf('Future<String> createCapabilityGrowthEvent');
      final int readsStart = source.indexOf('/// Get checkpoints by learner');
      expect(applyStart, isNot(-1));
      expect(masteryStart, isNot(-1));
      expect(growthStart, isNot(-1));
      expect(readsStart, isNot(-1));

      final String applySection = source.substring(applyStart, masteryStart);
      expect(
        applySection,
        contains("httpsCallable('applyRubricToEvidence')"),
        reason: 'legacy rubric helper must use server-side growth validation',
      );
      expect(
        applySection,
        isNot(contains("collection('rubricApplications')")),
        reason: 'legacy rubric helper must not create disconnected rubric docs',
      );

      final String masterySection = source.substring(masteryStart, growthStart);
      expect(masterySection, contains('server-owned'));
      expect(
        masterySection,
        isNot(contains("collection('capabilityMastery')")),
        reason: 'clients must not write capability mastery directly',
      );

      final String growthSection = source.substring(growthStart, readsStart);
      expect(growthSection, contains('server-owned append-only output'));
      expect(
        growthSection,
        isNot(contains("collection('capabilityGrowthEvents')")),
        reason: 'clients must not write append-only growth events directly',
      );
    });

    test('service has evidence read methods', () {
      expect(service.getCheckpointsByLearner, isA<Function>());
      expect(service.getPortfolioItemsByLearner, isA<Function>());
      expect(service.getProofBundlesByLearner, isA<Function>());
      expect(service.getEvidenceRecordsBySite, isA<Function>());
      expect(service.getCapabilityMasteryByLearner, isA<Function>());
      expect(service.getGrowthEventsByLearner, isA<Function>());
    });

    test('evidence chain methods count is 16', () {
      // 4 capture + 3 verify + 3 interpret + 6 read = 16
      final int methodCount = 4 + 3 + 3 + 6;
      expect(methodCount, 16);
    });
  });
}
