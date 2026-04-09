import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scholesa_app/offline/offline_queue.dart';
import 'package:scholesa_app/offline/sync_coordinator.dart';
import 'package:scholesa_app/services/firestore_service.dart';

// ── Mocks ──────────────────────────────────────────────────
class MockOfflineQueue extends Mock implements OfflineQueue {}

class MockConnectivity extends Mock implements Connectivity {}

class MockFirestoreService extends Mock implements FirestoreService {}

/// Test subclass that records processOperation calls instead of hitting Firestore
class TestableSyncCoordinator extends SyncCoordinator {
  TestableSyncCoordinator({
    required super.queue,
    required super.firestoreService,
    super.connectivity,
    super.onSyncError,
    this.shouldThrow = false,
  });

  final List<QueuedOp> processedOps = <QueuedOp>[];
  final bool shouldThrow;

  @override
  Future<void> processOperation(QueuedOp op) async {
    if (shouldThrow) {
      throw Exception('Simulated Firestore failure');
    }
    processedOps.add(op);
  }
}

void main() {
  late MockOfflineQueue mockQueue;
  late MockFirestoreService mockFirestore;
  late MockConnectivity mockConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityController;

  setUpAll(() {
    registerFallbackValue(OpStatus.pending);
    registerFallbackValue(OpType.attendanceRecord);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockQueue = MockOfflineQueue();
    mockFirestore = MockFirestoreService();
    mockConnectivity = MockConnectivity();
    connectivityController = StreamController<List<ConnectivityResult>>();

    when(() => mockQueue.init()).thenAnswer((_) async {});
    when(() => mockQueue.pendingCount).thenReturn(0);
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => <ConnectivityResult>[ConnectivityResult.wifi]);
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
  });

  tearDown(() {
    connectivityController.close();
  });

  group('SyncCoordinator', () {
    // ── State management ─────────────────────────────────
    test('starts online and not syncing after init', () async {
      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[]);

      await coordinator.init();

      expect(coordinator.isOnline, isTrue);
      expect(coordinator.isSyncing, isFalse);
      coordinator.dispose();
    });

    test('detects offline connectivity on init', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
          (_) async => <ConnectivityResult>[ConnectivityResult.none]);

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      await coordinator.init();

      expect(coordinator.isOnline, isFalse);
      coordinator.dispose();
    });

    test('updates isOnline when connectivity changes', () async {
      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[]);

      await coordinator.init();
      expect(coordinator.isOnline, isTrue);

      connectivityController.add(<ConnectivityResult>[ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isOnline, isFalse);

      connectivityController
          .add(<ConnectivityResult>[ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isOnline, isTrue);

      coordinator.dispose();
    });

    // ── syncPending ──────────────────────────────────────
    test('syncPending returns early when offline', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
          (_) async => <ConnectivityResult>[ConnectivityResult.none]);

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      await coordinator.init();
      final SyncResult result = await coordinator.syncPending();

      expect(result.synced, 0);
      expect(result.failed, 0);
      verifyNever(() => mockQueue.getPending());
      coordinator.dispose();
    });

    test('syncPending returns 0 when queue is empty', () async {
      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[]);

      await coordinator.init();
      final SyncResult result = await coordinator.syncPending();

      expect(result.synced, 0);
      expect(result.failed, 0);
      expect(result.pending, 0);
      coordinator.dispose();
    });

    test('syncPending processes ops and marks them synced', () async {
      final QueuedOp op1 = QueuedOp(
        type: OpType.attendanceRecord,
        payload: <String, dynamic>{'learnerId': 'l1'},
      );
      final QueuedOp op2 = QueuedOp(
        type: OpType.messageSend,
        payload: <String, dynamic>{'text': 'hello'},
      );

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[op1, op2]);
      when(() =>
              mockQueue.updateStatus(any(), any(), error: any(named: 'error')))
          .thenAnswer((_) async {});

      await coordinator.init();
      final SyncResult result = await coordinator.syncPending();

      expect(result.synced, 2);
      expect(result.failed, 0);
      expect(coordinator.processedOps, hasLength(2));
      verify(() => mockQueue.updateStatus(op1.id, OpStatus.synced)).called(1);
      verify(() => mockQueue.updateStatus(op2.id, OpStatus.synced)).called(1);
      coordinator.dispose();
    });

    test('syncPending skips ops at retry limit (retryCount >= 3)', () async {
      final QueuedOp op = QueuedOp(
        type: OpType.attendanceRecord,
        payload: <String, dynamic>{'learnerId': 'l1'},
      );
      op.retryCount = 3;

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[op]);

      await coordinator.init();
      final SyncResult result = await coordinator.syncPending();

      expect(result.synced, 0);
      expect(result.failed, 1);
      expect(coordinator.processedOps, isEmpty);
      verifyNever(() => mockQueue.updateStatus(any(), OpStatus.synced));
      coordinator.dispose();
    });

    test('syncPending marks op as failed on processOperation error', () async {
      final QueuedOp op = QueuedOp(
        type: OpType.messageSend,
        payload: <String, dynamic>{'text': 'hello'},
      );

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
        onSyncError: (_) {},
        shouldThrow: true,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[op]);
      when(() =>
              mockQueue.updateStatus(any(), any(), error: any(named: 'error')))
          .thenAnswer((_) async {});

      await coordinator.init();
      final SyncResult result = await coordinator.syncPending();

      expect(result.synced, 0);
      expect(result.failed, 1);
      verify(() => mockQueue.updateStatus(
            op.id,
            OpStatus.failed,
            error: any(named: 'error'),
          )).called(1);
      coordinator.dispose();
    });

    // ── queueOperation ───────────────────────────────────
    test('queueOperation enqueues and triggers sync when online', () async {
      final QueuedOp op = QueuedOp(
        type: OpType.incidentSubmit,
        payload: <String, dynamic>{'desc': 'test'},
      );

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.enqueue(any(), any())).thenAnswer((_) async => op);
      // After enqueue, syncPending will be called; return an empty list so
      // there's nothing to process (the op was already "synced" conceptually)
      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[]);

      await coordinator.init();
      final QueuedOp queued = await coordinator.queueOperation(
        OpType.incidentSubmit,
        <String, dynamic>{'desc': 'test'},
      );

      expect(queued.type, OpType.incidentSubmit);
      verify(() => mockQueue.enqueue(OpType.incidentSubmit, any())).called(1);
      coordinator.dispose();
    });

    // ── Connectivity triggers sync ───────────────────────
    test('auto-syncs when coming back online', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
          (_) async => <ConnectivityResult>[ConnectivityResult.none]);

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[]);

      await coordinator.init();
      expect(coordinator.isOnline, isFalse);

      connectivityController.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isOnline, isTrue);
      verify(() => mockQueue.getPending()).called(greaterThanOrEqualTo(1));
      coordinator.dispose();
    });

    // ── retryFailed ──────────────────────────────────────
    test('retryFailed resets failed ops to pending and re-syncs', () async {
      final QueuedOp failedOp = QueuedOp(
        type: OpType.messageSend,
        payload: <String, dynamic>{'text': 'retry me'},
      );
      failedOp.status = OpStatus.failed;

      final TestableSyncCoordinator coordinator = TestableSyncCoordinator(
        queue: mockQueue,
        firestoreService: mockFirestore,
        connectivity: mockConnectivity,
      );

      when(() => mockQueue.getAll()).thenReturn(<QueuedOp>[failedOp]);
      when(() => mockQueue.getPending()).thenReturn(<QueuedOp>[]);
      when(() =>
              mockQueue.updateStatus(any(), any(), error: any(named: 'error')))
          .thenAnswer((_) async {});

      await coordinator.init();
      await coordinator.retryFailed();

      verify(() => mockQueue.updateStatus(failedOp.id, OpStatus.pending))
          .called(1);
      coordinator.dispose();
    });

    // ── SyncResult ───────────────────────────────────────
    test('SyncResult holds correct values', () {
      final SyncResult r = SyncResult(synced: 5, failed: 2, pending: 3);
      expect(r.synced, 5);
      expect(r.failed, 2);
      expect(r.pending, 3);
    });
  });

  // ── Evidence chain collection targeting ─────────────────────
  group('Evidence chain collection targeting', () {
    test('observationCapture OpType targets evidenceRecords (not observationRecords)', () {
      // Read the source file to verify the correct collection name.
      // This test guards against regression of the offline/online
      // collection mismatch bug where observations synced from offline
      // went to the wrong collection.
      final String source = File(
        'lib/offline/sync_coordinator.dart',
      ).readAsStringSync();

      final int obsCaseIdx = source.indexOf('OpType.observationCapture');
      expect(obsCaseIdx, isNot(-1), reason: 'observationCapture case must exist');

      final String obsSection = source.substring(obsCaseIdx, obsCaseIdx + 250);
      expect(
        obsSection,
        contains("'evidenceRecords'"),
        reason: 'offline observation sync must target evidenceRecords collection',
      );
      expect(
        obsSection,
        isNot(contains("'observationRecords'")),
        reason: 'must NOT target observationRecords (legacy mismatch)',
      );
    });

    test('bosEventIngest routes through Cloud Function (not direct Firestore)', () {
      final String source = File(
        'lib/offline/sync_coordinator.dart',
      ).readAsStringSync();

      final int bosCaseIdx = source.indexOf('OpType.bosEventIngest');
      expect(bosCaseIdx, isNot(-1), reason: 'bosEventIngest case must exist');

      final String bosSection = source.substring(bosCaseIdx, bosCaseIdx + 400);
      expect(
        bosSection,
        contains('bosIngestEvent'),
        reason: 'Must route through bosIngestEvent Cloud Function for FDM, sanitization, COPPA',
      );
    });

    test('proofBundleUpdate requires non-empty bundleId', () {
      final String source = File(
        'lib/offline/sync_coordinator.dart',
      ).readAsStringSync();

      final int proofIdx = source.indexOf('OpType.proofBundleUpdate');
      expect(proofIdx, isNot(-1));

      final String proofSection = source.substring(proofIdx, proofIdx + 400);
      expect(
        proofSection,
        contains('StateError'),
        reason: 'proofBundleUpdate must throw on empty bundleId',
      );
    });

    test('all evidence chain OpTypes exist in enum', () {
      // Guard against accidental removal of evidence chain op types
      final List<String> requiredOps = <String>[
        'checkpointSubmit',
        'reflectionSubmit',
        'peerFeedbackSubmit',
        'proofBundleCreate',
        'proofBundleUpdate',
        'rubricApplication',
        'rubricApply',
        'capabilityGrowthEvent',
        'portfolioItemCreate',
        'observationCapture',
        'aiCoachLog',
        'bosEventIngest',
      ];

      for (final String opName in requiredOps) {
        final bool exists =
            OpType.values.any((OpType op) => op.name == opName);
        expect(exists, isTrue, reason: 'OpType.$opName must exist');
      }
    });
  });
}
