import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/offline/offline_queue.dart';

void main() {
  group('QueuedOp', () {
    test('creates with defaults', () {
      final QueuedOp op = QueuedOp(
        type: OpType.attendanceRecord,
        payload: <String, dynamic>{'learnerId': 'learner1'},
      );

      expect(op.id, isNotEmpty);
      expect(op.type, equals(OpType.attendanceRecord));
      expect(op.status, equals(OpStatus.pending));
      expect(op.retryCount, equals(0));
      expect(op.idempotencyKey, isNotEmpty);
    });

    test('serializes to JSON', () {
      final QueuedOp op = QueuedOp(
        type: OpType.presenceCheckin,
        payload: <String, dynamic>{'siteId': 'site1', 'learnerId': 'learner1'},
      );

      final Map<String, dynamic> json = op.toJson();

      expect(json['type'], equals('presenceCheckin'));
      expect(json['payload']['siteId'], equals('site1'));
      expect(json['status'], equals('pending'));
    });

    test('deserializes from JSON', () {
      final Map<String, Object?> json = <String, Object?>{
        'id': 'op123',
        'type': 'attendanceRecord',
        'payload': <String, String>{'learnerId': 'learner1'},
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'idempotencyKey': 'key123',
        'status': 'synced',
        'retryCount': 2,
        'lastError': null,
      };

      final QueuedOp op = QueuedOp.fromJson(json);

      expect(op.id, equals('op123'));
      expect(op.type, equals(OpType.attendanceRecord));
      expect(op.status, equals(OpStatus.synced));
      expect(op.retryCount, equals(2));
    });
  });

  group('OpType', () {
    test('has all required types from docs/68', () {
      expect(OpType.values, contains(OpType.attendanceRecord));
      expect(OpType.values, contains(OpType.presenceCheckin));
      expect(OpType.values, contains(OpType.presenceCheckout));
      expect(OpType.values, contains(OpType.incidentSubmit));
      expect(OpType.values, contains(OpType.messageSend));
      expect(OpType.values, contains(OpType.attemptSaveDraft));
    });
  });
}
