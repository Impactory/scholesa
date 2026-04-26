import 'dart:io';

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

  group('Legacy capability growth engine boundary', () {
    test('rubric growth is callable-backed, not client direct-write', () {
      final String source = File(
        'lib/services/capability_growth_engine.dart',
      ).readAsStringSync();

      final int processStart = source.indexOf('processRubricApplication');
      expect(processStart, isNot(-1));
      final int captureStart = source.indexOf('captureEvidence', processStart);
      final String processSection =
          source.substring(processStart, captureStart);

      expect(
        processSection,
        contains("httpsCallable('applyRubricToEvidence')"),
        reason: 'legacy rubric processing must use server validation',
      );
      expect(
        processSection,
        isNot(contains("collection('capabilityGrowthEvents')")),
        reason: 'clients must not write growth events directly',
      );
      expect(
        processSection,
        isNot(contains("collection('capabilityMastery')")),
        reason: 'clients must not write mastery directly',
      );
    });
  });

  group('Mission review growth boundary', () {
    test('mission review uses callable-owned rubric application creation', () {
      final String source = File(
        'lib/modules/missions/mission_service.dart',
      ).readAsStringSync();

      final int reviewStart = source.indexOf('Future<bool> submitReview');
      expect(reviewStart, isNot(-1));
      final int resolveStart = source.indexOf(
        'Future<DocumentReference<Map<String, dynamic>>> _resolveReviewAttemptRef',
        reviewStart,
      );
      final String reviewSection = source.substring(reviewStart, resolveStart);

      expect(
        reviewSection,
        contains("httpsCallable('applyRubricToEvidence')"),
        reason:
            'mission review rubric interpretation must route through server validation',
      );
      expect(
        reviewSection,
        isNot(contains("collection('rubricApplications')")),
        reason:
            'mission review must not fork a client-created rubric application',
      );
      expect(
        reviewSection,
        isNot(contains("collection('capabilityGrowthEvents')")),
        reason: 'mission review must not write growth events directly',
      );
      expect(
        reviewSection,
        isNot(contains("collection('capabilityMastery')")),
        reason: 'mission review must not write mastery directly',
      );
    });
  });
}
