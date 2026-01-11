import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import 'offline_queue.dart';

/// Coordinates sync between offline queue and server
class SyncCoordinator extends ChangeNotifier {

  SyncCoordinator({
    required OfflineQueue queue,
    required ApiClient apiClient,
    Connectivity? connectivity,
  })  : _queue = queue,
        _apiClient = apiClient,
        _connectivity = connectivity ?? Connectivity();
  final OfflineQueue _queue;
  final ApiClient _apiClient;
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

      // Batch sync via /v1/sync/batch
      final List<Map<String, Object?>> batch = pending
          .where((QueuedOp op) => op.retryCount < 3) // Max 3 retries
          .map((QueuedOp op) => <String, Object?>{
                'opId': op.id,
                'type': op.type.name,
                'payload': op.payload,
                'idempotencyKey': op.idempotencyKey,
              })
          .toList();

      if (batch.isEmpty) {
        return SyncResult(synced: 0, failed: pending.length, pending: 0);
      }

      try {
        final Map<String, dynamic> response = await _apiClient.post('/v1/sync/batch', body: <String, dynamic>{'ops': batch});
        final List<dynamic> results = response['results'] as List? ?? <dynamic>[];

        for (final result in results) {
          final String opId = result['opId'] as String;
          final bool success = result['success'] as bool? ?? false;
          final String? error = result['error'] as String?;

          if (success) {
            await _queue.updateStatus(opId, OpStatus.synced);
            synced++;
          } else {
            await _queue.updateStatus(opId, OpStatus.failed, error: error);
            failed++;
          }
        }
      } catch (e) {
        debugPrint('Batch sync failed: $e');
        // Mark all as failed for retry
        for (final QueuedOp op in pending) {
          await _queue.updateStatus(op.id, OpStatus.failed, error: e.toString());
        }
        failed = pending.length;
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
