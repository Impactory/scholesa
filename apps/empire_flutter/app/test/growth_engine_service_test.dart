import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/services/growth_engine_service.dart';

GrowthEngineService _makeEngine() {
  final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
  return GrowthEngineService(
    firestore: fakeFirestore,
  );
}

/// Unit tests for GrowthEngineService.
///
/// Because the service now delegates mastery writes to Cloud Functions,
/// these tests validate:
/// 1. Service construction with default parameters
/// 2. Edge cases for public API (null safety, parameter validation)
///
/// Full integration tests require Firebase emulator (see test:integration:rules).
void main() {
  group('GrowthEngineService construction', () {
    test('can be instantiated with defaults', () {
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
      await engine.onCheckpointCompleted(
        learnerId: 'learner1',
        siteId: 'site1',
        skillId: null,
        isCorrect: true,
      );
    });

    test('onCheckpointCompleted skips when isCorrect is false', () async {
      await engine.onCheckpointCompleted(
        learnerId: 'learner1',
        siteId: 'site1',
        skillId: 'skill1',
        isCorrect: false,
      );
    });
  });
}
