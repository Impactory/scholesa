import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/offline/offline_queue.dart';

/// Tests that the sync coordinator handles evidence chain OpTypes correctly.
/// Validates that evidence chain ops serialize/deserialize for offline sync.
void main() {
  group('Evidence chain sync coordinator op types', () {
    test('checkpoint submit op has correct payload structure', () {
      final QueuedOp op = QueuedOp(
        type: OpType.checkpointSubmit,
        payload: <String, dynamic>{
          'missionId': 'mission1',
          'learnerId': 'learner1',
          'siteId': 'site1',
          'question': 'Explain photosynthesis',
          'learnerResponse': 'Plants use sunlight to make food',
          'isCorrect': true,
          'explainItBackRequired': true,
        },
      );

      final Map<String, dynamic> json = op.toJson();
      expect(json['type'], 'checkpointSubmit');
      expect(json['payload']['explainItBackRequired'], true);
      expect(json['idempotencyKey'], isNotEmpty);
    });

    test('proof bundle create op preserves verification methods', () {
      final QueuedOp op = QueuedOp(
        type: OpType.proofBundleCreate,
        payload: <String, dynamic>{
          'learnerId': 'learner1',
          'siteId': 'site1',
          'portfolioItemId': 'pi1',
          'capabilityId': 'cap1',
          'hasExplainItBack': true,
          'hasOralCheck': true,
          'hasMiniRebuild': false,
          'explainItBackExcerpt': 'The learner explained...',
          'oralCheckExcerpt': 'Oral demonstration showed...',
        },
      );

      final QueuedOp restored = QueuedOp.fromJson(op.toJson());
      expect(restored.type, OpType.proofBundleCreate);
      expect(restored.payload['siteId'], 'site1');
      expect(restored.payload['hasExplainItBack'], true);
      expect(restored.payload['hasOralCheck'], true);
      expect(restored.payload['hasMiniRebuild'], false);
    });

    test('rubric apply op includes educator attribution', () {
      final QueuedOp op = QueuedOp(
        type: OpType.rubricApply,
        payload: <String, dynamic>{
          'learnerId': 'learner1',
          'capabilityId': 'cap-problem-solving',
          'educatorId': 'educator1',
          'rubricLevel': 'proficient',
          'siteId': 'site1',
          'evidenceIds': <String>['ev1', 'ev2'],
          'feedback': 'Strong demonstration of problem decomposition',
        },
      );

      expect(op.payload['educatorId'], 'educator1');
      expect(op.payload['rubricLevel'], 'proficient');
      expect(op.payload['evidenceIds'], hasLength(2));
    });

    test('all evidence chain ops have unique idempotency keys', () {
      final Set<String> keys = <String>{};
      for (final OpType type in <OpType>[
        OpType.checkpointSubmit,
        OpType.reflectionSubmit,
        OpType.aiCoachLog,
        OpType.peerFeedbackSubmit,
        OpType.portfolioItemCreate,
        OpType.proofBundleCreate,
        OpType.proofBundleUpdate,
        OpType.rubricApply,
      ]) {
        final QueuedOp op = QueuedOp(
          type: type,
          payload: <String, dynamic>{'test': true},
        );
        keys.add(op.idempotencyKey!);
      }
      // All 8 should have unique idempotency keys
      expect(keys.length, 8);
    });
  });
}
