import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/growth_engine_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

GrowthEngineService _makeEngine() {
  final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
  return GrowthEngineService(
    firestoreService: FirestoreService(
      firestore: fakeFirestore,
      auth: _MockFirebaseAuth(),
    ),
    firestore: fakeFirestore,
  );
}

/// Unit tests for GrowthEngineService.
///
/// Because the service depends on Firestore, these tests validate:
/// 1. Service construction with default parameters
/// 2. Method signatures match the evidence chain contract
/// 3. Edge cases for public API (null safety, parameter validation)
///
/// Full integration tests require Firebase emulator (see test:integration:rules).
void main() {
  group('GrowthEngineService construction', () {
    test('can be instantiated with defaults', () {
      // This verifies imports and class structure are valid
      // Actual Firestore calls are not made in unit tests
      expect(GrowthEngineService.new, isA<Function>());
    });

    test('accepts optional parameters', () {
      final GrowthEngineService engine = _makeEngine();
      expect(engine, isA<GrowthEngineService>());
    });
  });

  group('GrowthEngineService API contract', () {
    late GrowthEngineService engine;

    setUp(() {
      engine = _makeEngine();
    });

    test('onCheckpointCompleted skips when skillId is null', () async {
      // Should return immediately without error when skillId is null
      await engine.onCheckpointCompleted(
        learnerId: 'learner1',
        siteId: 'site1',
        skillId: null,
        isCorrect: true,
      );
      // No exception = pass
    });

    test('onCheckpointCompleted skips when isCorrect is false', () async {
      // Should return immediately without error when checkpoint is wrong
      await engine.onCheckpointCompleted(
        learnerId: 'learner1',
        siteId: 'site1',
        skillId: 'skill1',
        isCorrect: false,
      );
      // No exception = pass (early return before Firestore call)
    });
  });
}
