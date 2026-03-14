import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

void main() {
  test('ai draft request, review, and pending views persist with telemetry',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final AiDraftRepository repository =
        AiDraftRepository(firestore: firestore);
    final List<Map<String, dynamic>> telemetryPayloads =
        <Map<String, dynamic>>[];

    await TelemetryService.runWithDispatcher((Map<String, dynamic> payload) async {
      telemetryPayloads.add(payload);
    }, () async {
      final String requestedId = await repository.createRequest(
        requesterId: 'educator-1',
        siteId: 'site-1',
        title: 'Mission feedback draft',
        prompt: 'Draft strengths-based feedback for learner work.',
      );

      final String secondDraftId = await repository.createRequest(
        requesterId: 'educator-2',
        siteId: 'site-2',
        title: 'Second draft',
        prompt: 'Draft a parent update.',
      );

      final requestedDoc =
          await firestore.collection('aiDrafts').doc(requestedId).get();
      expect(requestedDoc.exists, isTrue);
      expect(requestedDoc.data()?['requesterId'], 'educator-1');
      expect(requestedDoc.data()?['siteId'], 'site-1');
      expect(requestedDoc.data()?['status'], 'requested');

      final mine = await repository.listMine('educator-1');
      expect(mine, hasLength(1));
      expect(mine.first.id, requestedId);
      expect(mine.first.title, 'Mission feedback draft');

      final pending = await repository.listPending();
      expect(pending.map((draft) => draft.id).toSet(),
          <String>{requestedId, secondDraftId});

      await repository.review(
        id: requestedId,
        reviewerId: 'hq-1',
        status: 'approved',
        notes: 'Human-reviewed and safe to use.',
      );

      final reviewedDoc =
          await firestore.collection('aiDrafts').doc(requestedId).get();
      expect(reviewedDoc.data()?['status'], 'approved');
      expect(reviewedDoc.data()?['reviewerId'], 'hq-1');
      expect(reviewedDoc.data()?['reviewNotes'], 'Human-reviewed and safe to use.');

      final pendingAfterReview = await repository.listPending();
      expect(pendingAfterReview, hasLength(1));
      expect(pendingAfterReview.first.id, secondDraftId);
      expect(pendingAfterReview.first.requesterId, 'educator-2');

      expect(
        telemetryPayloads.where(
          (Map<String, dynamic> payload) =>
              payload['event'] == 'aiDraft.requested' &&
              payload['siteId'] == 'site-1' &&
              payload['metadata'] is Map<String, dynamic>,
        ),
        hasLength(1),
      );
      expect(
        telemetryPayloads.where(
          (Map<String, dynamic> payload) =>
              payload['event'] == 'aiDraft.reviewed' &&
              (payload['metadata'] as Map<String, dynamic>)['status'] ==
                  'approved',
        ),
        hasLength(1),
      );
    });
  });
}