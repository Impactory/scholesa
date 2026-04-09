import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import 'offline_queue.dart';

/// Coordinates sync between offline queue and Firestore
class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator({
    required OfflineQueue queue,
    required FirestoreService firestoreService,
    Connectivity? connectivity,
    void Function(Object error)? onSyncError,
  })  : _queue = queue,
        _firestoreService = firestoreService,
        _connectivity = connectivity ?? Connectivity(),
        _onSyncError = onSyncError;
  final OfflineQueue _queue;
  final FirestoreService _firestoreService;
  final Connectivity _connectivity;
  final void Function(Object error)? _onSyncError;

  bool _isOnline = true;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _queue.pendingCount;

  /// Initialize and start listening for connectivity changes
  Future<void> init() async {
    await _queue.init();

    // Check initial connectivity
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    _updateConnectivity(results);

    // Listen for changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final bool wasOnline = _isOnline;
    _isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (_isOnline && !wasOnline) {
      // Just came online, trigger sync
      syncPending();
    }

    notifyListeners();
  }

  /// Queue an operation (called from modules)
  Future<QueuedOp> queueOperation(
      OpType type, Map<String, dynamic> payload) async {
    final QueuedOp op = await _queue.enqueue(type, payload);
    notifyListeners();

    // Try to sync immediately if online
    if (_isOnline && !_isSyncing) {
      syncPending();
    }

    return op;
  }

  /// Sync all pending operations
  Future<SyncResult> syncPending() async {
    if (!_isOnline || _isSyncing) {
      return SyncResult(synced: 0, failed: 0, pending: _queue.pendingCount);
    }

    _isSyncing = true;
    notifyListeners();

    int synced = 0;
    int failed = 0;

    try {
      final List<QueuedOp> pending = _queue.getPending();

      if (pending.isEmpty) {
        return SyncResult(synced: 0, failed: 0, pending: 0);
      }

      // Process each operation using Firestore directly
      for (final QueuedOp op in pending) {
        if (op.retryCount >= 3) {
          failed++;
          continue;
        }

        try {
          // Process operation based on type using Firestore
          await processOperation(op);
          await _queue.updateStatus(op.id, OpStatus.synced);
          synced++;
        } catch (e) {
          if (_onSyncError != null) {
            _onSyncError(e);
          } else {
            debugPrint('Sync operation failed: $e');
          }
          await _queue.updateStatus(op.id, OpStatus.failed,
              error: e.toString());
          failed++;
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      pending: _queue.pendingCount,
    );
  }

  /// Process a single queued operation.
  ///
  /// Uses idempotency keys as Firestore document IDs so that retries
  /// overwrite the same document instead of creating duplicates (W4 fix).
  @visibleForTesting
  Future<void> processOperation(QueuedOp op) async {
    final firestore = _firestoreService.firestore;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(op.payload);
    // Attach the idempotency key to the payload for server-side tracking
    if (op.idempotencyKey != null) {
      payload['idempotencyKey'] = op.idempotencyKey;
    }

    switch (op.type) {
      case OpType.attendanceRecord:
        await firestore
            .collection('attendanceRecords')
            .doc(op.idempotencyKey)
            .set(payload);
        break;
      case OpType.presenceCheckin:
        await firestore
            .collection('checkins')
            .doc(op.idempotencyKey)
            .set(payload);
        break;
      case OpType.presenceCheckout:
        await firestore.collection('checkins').doc(op.idempotencyKey).set(payload);
        break;
      case OpType.incidentSubmit:
        await firestore
            .collection('incidents')
            .doc(op.idempotencyKey)
            .set(payload);
        break;
      case OpType.messageSend:
        final String threadId = payload['threadId'] as String? ?? '';
        final List<String> participantIds =
            List<String>.from(payload['participantIds'] as List? ?? <String>[]);
        final List<String> participantNames = List<String>.from(
            payload['participantNames'] as List? ?? <String>[]);
        final String body = payload['body'] as String? ?? '';
        if (threadId.isNotEmpty) {
          await firestore.collection('messageThreads').doc(threadId).set(
            <String, dynamic>{
              'participantIds': participantIds,
              'participantNames': participantNames,
              if ((payload['siteId'] as String?)?.isNotEmpty == true)
                'siteId': payload['siteId'],
              'title': payload['title'] as String? ?? 'Direct conversation',
              'status': 'open',
              'lastMessagePreview': body,
              'lastMessageSenderId': payload['senderId'],
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        payload.remove('participantIds');
        payload.remove('participantNames');
        payload.remove('queuedAtClient');
        await firestore.collection('messages').doc(op.idempotencyKey).set(
          <String, dynamic>{
            ...payload,
            'status': 'sent',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        break;
      case OpType.attemptSaveDraft:
        final String docPath = payload.remove('docPath') as String? ?? '';
        final DocumentReference<Map<String, dynamic>> targetRef =
            docPath.isNotEmpty
                ? firestore.doc(docPath)
                : firestore
                    .collection('proofOfLearningBundles')
                    .doc('${payload['learnerId']}_${payload['missionId']}');
        payload.remove('createdAtClient');
        await targetRef.set(
          <String, dynamic>{
            ...payload,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        break;
      case OpType.observationCapture:
        await firestore
            .collection('observationRecords')
            .doc(op.idempotencyKey)
            .set(payload);
        break;
      case OpType.rubricApplication:
        await firestore
            .collection('rubricApplications')
            .doc(op.idempotencyKey)
            .set(payload);
        break;
      case OpType.capabilityGrowthEvent:
        await firestore
            .collection('capabilityGrowthEvents')
            .doc(op.idempotencyKey)
            .set(payload);
        break;
      case OpType.checkpointVerification:
        await firestore
            .collection('checkpointVerifications')
            .doc(op.idempotencyKey)
            .set(payload);
        break;

      // Evidence chain operations
      case OpType.checkpointSubmit:
        await firestore
            .collection('checkpointHistory')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.reflectionSubmit:
        await firestore
            .collection('learnerReflections')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.aiCoachLog:
        await firestore
            .collection('aiCoachInteractions')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.peerFeedbackSubmit:
        await firestore
            .collection('peerFeedback')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.portfolioItemCreate:
        await firestore
            .collection('portfolioItems')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.proofBundleCreate:
        await firestore
            .collection('proofOfLearningBundles')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.proofBundleUpdate:
        final String bundleId = payload.remove('bundleId') as String? ?? '';
        if (bundleId.isEmpty) {
          throw StateError(
            'proofBundleUpdate requires a non-empty bundleId in payload',
          );
        }
        await firestore
            .collection('proofOfLearningBundles')
            .doc(bundleId)
            .update(<String, dynamic>{
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.rubricApply:
        await firestore
            .collection('rubricApplications')
            .doc(op.idempotencyKey)
            .set(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;
      case OpType.bosEventIngest:
        // Route through Cloud Function to ensure FDM extraction, rate
        // limiting, payload sanitization, and COPPA consent checks.
        await FirebaseFunctions.instance
            .httpsCallable('bosIngestEvent')
            .call(<String, dynamic>{
          'eventType': payload['eventType'] as String? ?? '',
          'siteId': payload['siteId'] as String? ?? '',
          'actorRole': payload['actorRole'] as String? ?? '',
          'gradeBand': payload['gradeBand'] as String? ?? '',
          if (payload['sessionOccurrenceId'] != null)
            'sessionOccurrenceId': payload['sessionOccurrenceId'],
          if (payload['missionId'] != null)
            'missionId': payload['missionId'],
          if (payload['checkpointId'] != null)
            'checkpointId': payload['checkpointId'],
          'payload': <String, dynamic>{
            ...payload['payload'] as Map<String, dynamic>? ??
                const <String, dynamic>{},
            'eventId': payload['eventId'] as String? ?? op.idempotencyKey,
            if (payload['schemaVersion'] != null)
              'schemaVersion': payload['schemaVersion'],
            if (payload['contextMode'] != null)
              'contextMode': payload['contextMode'],
            if (payload['actorIdPseudo'] != null)
              'actorIdPseudo': payload['actorIdPseudo'],
            if (payload['assignmentId'] != null)
              'assignmentId': payload['assignmentId'],
            if (payload['lessonId'] != null)
              'lessonId': payload['lessonId'],
          },
        });
        break;
    }
  }

  /// Force retry all failed ops
  Future<void> retryFailed() async {
    final Iterable<QueuedOp> failed =
        _queue.getAll().where((QueuedOp op) => op.status == OpStatus.failed);
    for (final QueuedOp op in failed) {
      await _queue.updateStatus(op.id, OpStatus.pending);
    }
    notifyListeners();
    await syncPending();
  }

  /// Get queue for inspection
  List<QueuedOp> getQueueSnapshot() => _queue.getAll();

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Result of a sync operation
class SyncResult {
  SyncResult({
    required this.synced,
    required this.failed,
    required this.pending,
  });
  final int synced;
  final int failed;
  final int pending;
}
