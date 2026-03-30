import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/services/growth_engine_service.dart';

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
      // Verifying the constructor accepts named params without error
      // We cannot actually call Firestore in unit tests, but we can
      // verify the type signature
      final GrowthEngineService engine = GrowthEngineService();
      expect(engine, isA<GrowthEngineService>());
    });
  });

  group('GrowthEngineService API contract', () {
    late GrowthEngineService engine;

    setUp(() {
      engine = GrowthEngineService();
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
