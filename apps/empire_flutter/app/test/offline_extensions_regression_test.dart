import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/modules/attendance/attendance_models.dart';
import 'package:scholesa_app/modules/attendance/attendance_service.dart';
import 'package:scholesa_app/modules/checkin/checkin_service.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/offline/offline_queue.dart';
import 'package:scholesa_app/offline/sync_coordinator.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/notification_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockOfflineQueue extends Mock implements OfflineQueue {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(OpType.attendanceRecord);
    registerFallbackValue(<String, dynamic>{});
  });

  group('Offline extensions regression', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService firestoreService;
    late _MockFirebaseAuth auth;
    late _MockSyncCoordinator syncCoordinator;
    late _MockApiClient apiClient;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = _MockFirebaseAuth();
      firestoreService = FirestoreService(
        firestore: firestore,
        auth: auth,
      );
      apiClient = _MockApiClient();
      syncCoordinator = _MockSyncCoordinator();
      when(() => syncCoordinator.isOnline).thenReturn(false);
      when(() => syncCoordinator.queueOperation(any(), any())).thenAnswer(
        (Invocation invocation) async => QueuedOp(
          type: invocation.positionalArguments[0] as OpType,
          payload: Map<String, dynamic>.from(
            invocation.positionalArguments[1] as Map<String, dynamic>,
          ),
        ),
      );
    });

    test('checkin service queues check-in and check-out when offline',
        () async {
      final CheckinService service = CheckinService(
        firestoreService: firestoreService,
        siteId: 'site-1',
        syncCoordinator: syncCoordinator,
      );

      final bool checkedIn = await service.checkIn(
        learnerId: 'learner-1',
        learnerName: 'Learner One',
        visitorId: 'visitor-1',
        visitorName: 'Visitor One',
      );
      final bool checkedOut = await service.checkOut(
        learnerId: 'learner-1',
        learnerName: 'Learner One',
        visitorId: 'visitor-1',
        visitorName: 'Visitor One',
      );

      expect(checkedIn, isTrue);
      expect(checkedOut, isTrue);
      verify(() =>
              syncCoordinator.queueOperation(OpType.presenceCheckin, any()))
          .called(1);
      verify(() =>
              syncCoordinator.queueOperation(OpType.presenceCheckout, any()))
          .called(1);
      expect((await firestore.collection('checkins').get()).docs, isEmpty);
      expect(service.todayRecords, hasLength(2));
    });

    test('message service queues direct messages when offline', () async {
      await firestore
          .collection('users')
          .doc('educator-1')
          .set(<String, dynamic>{
        'displayName': 'Educator One',
        'role': 'educator',
        'activeSiteId': 'site-1',
        'siteIds': <String>['site-1'],
      });
      await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
        'displayName': 'Parent One',
        'role': 'parent',
        'activeSiteId': 'site-1',
        'siteIds': <String>['site-1'],
      });

      final MessageService service = MessageService(
        firestoreService: firestoreService,
        userId: 'educator-1',
        syncCoordinator: syncCoordinator,
      );

      await NotificationService.runWithCallableInvoker(
        (_, __) async {},
        () async {
          await TelemetryService.runWithDispatcher(
            (_) async {},
            () async {
              final bool sent = await service.sendMessage(
                recipientId: 'parent-1',
                body: 'Queued while offline.',
              );
              expect(sent, isTrue);
            },
          );
        },
      );

      verify(() => syncCoordinator.queueOperation(OpType.messageSend, any()))
          .called(1);
      expect((await firestore.collection('messages').get()).docs, isEmpty);
      expect(service.messages, hasLength(1));
      expect(service.conversations, hasLength(1));
    });

    test('mission service queues proof bundle drafts when offline', () async {
      await firestore.collection('missionAssignments').doc('assignment-1').set(
        <String, dynamic>{
          'missionId': 'mission-1',
          'learnerId': 'learner-1',
          'siteId': 'site-1',
        },
      );

      final MissionService service = MissionService(
        firestoreService: firestoreService,
        learnerId: 'learner-1',
        syncCoordinator: syncCoordinator,
      );

      final MissionProofBundle? bundle = await service.saveProofBundleDraft(
        missionId: 'mission-1',
        explainItBack: 'Explain the core concept.',
        oralCheckResponse: 'I can talk through the model.',
        miniRebuildPlan: 'Rebuild with a new example.',
      );

      expect(bundle, isNotNull);
      expect(bundle!.siteId, 'site-1');
      verify(() =>
              syncCoordinator.queueOperation(OpType.attemptSaveDraft, any()))
          .called(1);
      expect(
        await firestore
            .collection('proofOfLearningBundles')
            .doc(bundle.id)
            .get(),
        isNot(predicate((dynamic doc) => doc.exists)),
      );
    });

    test('attendance service queues batch attendance when offline', () async {
      final AttendanceService service = AttendanceService(
        apiClient: apiClient,
        syncCoordinator: syncCoordinator,
        educatorId: 'educator-1',
        siteId: 'site-1',
      );

      final AttendanceBatchSaveResult result =
          await service.batchRecordAttendance(
        <AttendanceRecord>[
          AttendanceRecord(
            occurrenceId: 'occ-1',
            learnerId: 'learner-1',
            status: AttendanceStatus.present,
            recordedAt: DateTime.now(),
            recordedBy: 'educator-1',
          ),
          AttendanceRecord(
            occurrenceId: 'occ-1',
            learnerId: 'learner-2',
            status: AttendanceStatus.absent,
            recordedAt: DateTime.now(),
            recordedBy: 'educator-1',
          ),
        ],
      );

      expect(result, AttendanceBatchSaveResult.queued);
      verify(() =>
              syncCoordinator.queueOperation(OpType.attendanceRecord, any()))
          .called(2);
      expect((await firestore.collection('attendanceRecords').get()).docs,
          isEmpty);
    });

    test('sync coordinator replays queued message and proof draft ops',
        () async {
      final _MockOfflineQueue queue = _MockOfflineQueue();
      final SyncCoordinator coordinator = SyncCoordinator(
        queue: queue,
        firestoreService: firestoreService,
      );

      await coordinator.processOperation(
        QueuedOp(
          type: OpType.messageSend,
          payload: <String, dynamic>{
            'threadId': 'thread-1',
            'participantIds': <String>['educator-1', 'parent-1'],
            'participantNames': <String>['Educator One', 'Parent One'],
            'siteId': 'site-1',
            'title': 'Direct conversation',
            'body': 'Synced after reconnect.',
            'type': 'direct',
            'priority': 'normal',
            'senderId': 'educator-1',
            'senderName': 'Educator One',
            'recipientId': 'parent-1',
            'status': 'queued',
            'isRead': false,
            'queuedAtClient': DateTime.now().millisecondsSinceEpoch,
            'metadata': <String, dynamic>{'threadId': 'thread-1'},
          },
          idempotencyKey: 'message-op-1',
        ),
      );

      await coordinator.processOperation(
        QueuedOp(
          type: OpType.attemptSaveDraft,
          payload: <String, dynamic>{
            'docPath': 'proofOfLearningBundles/learner-1_mission-1',
            'missionId': 'mission-1',
            'learnerId': 'learner-1',
            'siteId': 'site-1',
            'explainItBack': 'Synced explanation',
            'oralCheckResponse': 'Synced oral check',
            'miniRebuildPlan': 'Synced rebuild plan',
            'versionHistory': <Map<String, dynamic>>[],
            'createdAtClient': DateTime.now().millisecondsSinceEpoch,
          },
          idempotencyKey: 'proof-op-1',
        ),
      );

      final thread =
          await firestore.collection('messageThreads').doc('thread-1').get();
      final message =
          await firestore.collection('messages').doc('message-op-1').get();
      final proof = await firestore
          .collection('proofOfLearningBundles')
          .doc('learner-1_mission-1')
          .get();

      expect(thread.exists, isTrue);
      expect(thread.data()!['lastMessagePreview'], 'Synced after reconnect.');
      expect(message.exists, isTrue);
      expect(message.data()!['status'], 'sent');
      expect(proof.exists, isTrue);
      expect(proof.data()!['explainItBack'], 'Synced explanation');
    });
  });
}
