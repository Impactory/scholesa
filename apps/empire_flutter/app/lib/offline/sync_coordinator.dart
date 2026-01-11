import 'dart:async';
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
  })  : _queue = queue,
        _firestoreService = firestoreService,
        _connectivity = connectivity ?? Connectivity();
  final OfflineQueue _queue;
  final FirestoreService _firestoreService;
  final Connectivity _connectivity;

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
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);
    
    // Listen for changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final bool wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.contains(ConnectivityResult.none);
    
    if (_isOnline && !wasOnline) {
      // Just came online, trigger sync
      syncPending();
    }
    
    notifyListeners();
  }

  /// Queue an operation (called from modules)
  Future<QueuedOp> queueOperation(OpType type, Map<String, dynamic> payload) async {
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
          await _processOperation(op);
          await _queue.updateStatus(op.id, OpStatus.synced);
          synced++;
        } catch (e) {
          debugPrint('Sync operation failed: $e');
          await _queue.updateStatus(op.id, OpStatus.failed, error: e.toString());
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

  /// Process a single queued operation
  Future<void> _processOperation(QueuedOp op) async {
    final firestore = _firestoreService.firestore;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(op.payload);

    switch (op.type) {
      case OpType.attendanceRecord:
        await firestore.collection('attendanceRecords').add(payload);
        break;
      case OpType.presenceCheckin:
        await firestore.collection('checkins').add(payload);
        break;
      case OpType.presenceCheckout:
        final String docId = payload['checkinId'] as String? ?? '';
        if (docId.isNotEmpty) {
          payload.remove('checkinId');
          await firestore.collection('checkins').doc(docId).update(payload);
        }
        break;
      case OpType.incidentSubmit:
        await firestore.collection('incidents').add(payload);
        break;
      case OpType.messageSend:
        await firestore.collection('messages').add(payload);
        break;
      case OpType.attemptSaveDraft:
        await firestore.collection('drafts').add(payload);
        break;
    }
  }

  /// Force retry all failed ops
  Future<void> retryFailed() async {
    final Iterable<QueuedOp> failed = _queue.getAll().where((QueuedOp op) => op.status == OpStatus.failed);
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
