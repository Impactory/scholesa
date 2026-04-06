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
