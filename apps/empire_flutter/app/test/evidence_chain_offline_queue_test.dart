import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/offline/offline_queue.dart';

void main() {
  group('Evidence chain OpType values', () {
    test('all evidence chain operation types exist', () {
      expect(OpType.values, contains(OpType.checkpointSubmit));
      expect(OpType.values, contains(OpType.reflectionSubmit));
      expect(OpType.values, contains(OpType.aiCoachLog));
      expect(OpType.values, contains(OpType.peerFeedbackSubmit));
      expect(OpType.values, contains(OpType.portfolioItemCreate));
      expect(OpType.values, contains(OpType.proofBundleCreate));
      expect(OpType.values, contains(OpType.proofBundleUpdate));
      expect(OpType.values, contains(OpType.rubricApply));
    });

    test('total OpType count is 19 (6 original + 4 ops + 8 evidence chain + 1 BOS)', () {
      expect(OpType.values.length, 19);
    });

    test('bosEventIngest exists in OpType enum', () {
      expect(OpType.values, contains(OpType.bosEventIngest));
    });
  });

  group('bosEventIngest QueuedOp', () {
    test('bosEventIngest serializes correctly', () {
      final QueuedOp op = QueuedOp(
        type: OpType.bosEventIngest,
        payload: <String, dynamic>{
          'eventType': 'checkpoint_submitted',
          'siteId': 'site1',
          'actorRole': 'learner',
          'gradeBand': 'G4_6',
          'payload': <String, dynamic>{
            'missionId': 'mission1',
            'schemaVersion': '2.0.0',
          },
        },
      );

      expect(op.type, OpType.bosEventIngest);
      final Map<String, dynamic> json = op.toJson();
      expect(json['type'], 'bosEventIngest');
      expect(json['payload']['eventType'], 'checkpoint_submitted');
      expect(json['payload']['siteId'], 'site1');
    });

    test('bosEventIngest round-trips through JSON', () {
      final QueuedOp original = QueuedOp(
        type: OpType.bosEventIngest,
        payload: <String, dynamic>{
          'eventType': 'ai_help_used',
          'siteId': 'site2',
          'actorRole': 'learner',
          'gradeBand': 'G7_9',
          'payload': <String, dynamic>{
            'mode': 'hint',
          },
        },
      );
      final Map<String, dynamic> json = original.toJson();
      final QueuedOp restored = QueuedOp.fromJson(json);
      expect(restored.type, OpType.bosEventIngest);
      expect(restored.payload['eventType'], 'ai_help_used');
    });
  });

  group('Evidence chain QueuedOp creation', () {
    test('checkpointSubmit serializes correctly', () {
      final QueuedOp op = QueuedOp(
        type: OpType.checkpointSubmit,
        payload: <String, dynamic>{
          'missionId': 'mission1',
          'learnerId': 'learner1',
          'siteId': 'site1',
          'question': 'What is 2+2?',
          'learnerResponse': '4',
          'isCorrect': true,
        },
      );

      expect(op.type, OpType.checkpointSubmit);
      final Map<String, dynamic> json = op.toJson();
      expect(json['type'], 'checkpointSubmit');
      expect(json['payload']['missionId'], 'mission1');
    });

    test('reflectionSubmit serializes correctly', () {
      final QueuedOp op = QueuedOp(
        type: OpType.reflectionSubmit,
        payload: <String, dynamic>{
          'learnerId': 'learner1',
          'siteId': 'site1',
          'prompt': 'What did you learn?',
          'response': 'I learned about ecosystems.',
        },
      );

      final Map<String, dynamic> json = op.toJson();
      expect(json['type'], 'reflectionSubmit');
      expect(json['payload']['response'], contains('ecosystems'));
    });

    test('proofBundleCreate includes proof methods', () {
      final QueuedOp op = QueuedOp(
        type: OpType.proofBundleCreate,
        payload: <String, dynamic>{
          'learnerId': 'learner1',
          'siteId': 'site1',
          'portfolioItemId': 'pi1',
          'hasExplainItBack': true,
          'hasOralCheck': false,
          'hasMiniRebuild': false,
        },
      );

      expect(op.type, OpType.proofBundleCreate);
      expect(op.payload['siteId'], 'site1');
      expect(op.payload['hasExplainItBack'], true);
    });

    test('rubricApply includes educator attribution', () {
      final QueuedOp op = QueuedOp(
        type: OpType.rubricApply,
        payload: <String, dynamic>{
          'learnerId': 'learner1',
          'capabilityId': 'cap1',
          'educatorId': 'educator1',
          'rubricLevel': 'proficient',
          'siteId': 'site1',
        },
      );

      expect(op.type, OpType.rubricApply);
      expect(op.payload['rubricLevel'], 'proficient');
      expect(op.payload['educatorId'], 'educator1');
    });

    test('evidence chain ops round-trip through JSON', () {
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
        final QueuedOp original = QueuedOp(
          type: type,
          payload: <String, dynamic>{'test': true},
        );
        final Map<String, dynamic> json = original.toJson();
        final QueuedOp restored = QueuedOp.fromJson(json);
        expect(restored.type, type, reason: 'Round-trip failed for $type');
        expect(restored.payload['test'], true);
      }
    });
  });
}
