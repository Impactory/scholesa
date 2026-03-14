import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

void main() {
  test('item response submit persists calibration record and telemetry',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final ItemResponseRepository repository =
        ItemResponseRepository(firestore: firestore);
    final List<Map<String, dynamic>> telemetryPayloads =
        <Map<String, dynamic>>[];

    await TelemetryService.runWithDispatcher((Map<String, dynamic> payload) async {
      telemetryPayloads.add(payload);
    }, () async {
      final String responseId = await repository.submit(
        ItemResponseModel(
          id: '',
          siteId: 'site-1',
          learnerId: 'learner-1',
          instrumentId: 'diagnostic-1',
          itemId: 'item-1',
          response: 'B',
          isCorrect: true,
          score: 1,
          timeSpentMs: 4200,
          confidenceLevel: 4,
        ),
      );

      final responseDoc =
          await firestore.collection('itemResponses').doc(responseId).get();
      expect(responseDoc.exists, isTrue);

      final calibrationDoc = await firestore
          .collection('metacognitiveCalibrationRecords')
          .doc(responseId)
          .get();
      expect(calibrationDoc.exists, isTrue);
      expect(calibrationDoc.data()?['siteId'], 'site-1');
      expect(calibrationDoc.data()?['learnerId'], 'learner-1');
      expect(calibrationDoc.data()?['sourceType'], 'item_response');
      expect(calibrationDoc.data()?['instrumentId'], 'diagnostic-1');
      expect(calibrationDoc.data()?['itemId'], 'item-1');
      expect(calibrationDoc.data()?['confidenceLevel'], 4);
      expect(calibrationDoc.data()?['confidenceScore'], 0.8);
      expect(calibrationDoc.data()?['accuracyScore'], 1.0);
      expect(calibrationDoc.data()?['calibrationDelta'], closeTo(-0.2, 0.0001));

      expect(
        telemetryPayloads.where(
          (Map<String, dynamic> payload) =>
              payload['event'] == 'calibration.recorded',
        ),
        hasLength(1),
      );
    });
  });

  test('listByLearner returns newest calibration records first', () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final MetacognitiveCalibrationRepository repository =
        MetacognitiveCalibrationRepository(firestore: firestore);

    await repository.upsert(
      MetacognitiveCalibrationRecordModel(
        id: 'older',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sourceType: 'item_response',
        sourceId: 'older',
        instrumentId: 'diagnostic-1',
        itemId: 'item-1',
        confidenceLevel: 2,
        confidenceScore: 0.4,
        accuracyScore: 0.0,
        calibrationDelta: 0.4,
        createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
      ),
    );

    await repository.upsert(
      MetacognitiveCalibrationRecordModel(
        id: 'newer',
        siteId: 'site-1',
        learnerId: 'learner-1',
        sourceType: 'item_response',
        sourceId: 'newer',
        instrumentId: 'diagnostic-2',
        itemId: 'item-3',
        confidenceLevel: 5,
        confidenceScore: 1.0,
        accuracyScore: 1.0,
        calibrationDelta: 0.0,
        createdAt: Timestamp.fromMillisecondsSinceEpoch(2000),
      ),
    );

    final records = await repository.listByLearner(
      siteId: 'site-1',
      learnerId: 'learner-1',
    );

    expect(records.map((record) => record.id).toList(), <String>['newer', 'older']);
  });
}