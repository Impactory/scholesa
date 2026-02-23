import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Offline operation statuses
enum OpStatus {
  pending,
  syncing,
  synced,
  failed,
}

/// Operation types from docs/68_OFFLINE_OPS_CATALOG.md
enum OpType {
  attendanceRecord,
  presenceCheckin,
  presenceCheckout,
  incidentSubmit,
  messageSend,
  attemptSaveDraft,
}

/// Single queued operation
class QueuedOp {

  QueuedOp({
    String? id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    String? idempotencyKey,
    this.status = OpStatus.pending,
    this.retryCount = 0,
    this.lastError,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        idempotencyKey = idempotencyKey ?? const Uuid().v4();

  factory QueuedOp.fromJson(Map<String, dynamic> json) => QueuedOp(
        id: json['id'] as String,
        type: OpType.values.firstWhere((t) => t.name == json['type']),
        payload: json['payload'] as Map<String, dynamic>,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        idempotencyKey: json['idempotencyKey'] as String?,
        status: OpStatus.values.firstWhere((s) => s.name == json['status']),
        retryCount: json['retryCount'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
  final String id;
  final OpType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? idempotencyKey;
  OpStatus status;
  int retryCount;
  String? lastError;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'idempotencyKey': idempotencyKey,
        'status': status.name,
        'retryCount': retryCount,
        'lastError': lastError,
      };
}

/// Offline queue using Hive for persistence
class OfflineQueue {
  static const String _boxName = 'offline_queue';
  late Box<Map> _box;
  bool _isInitialized = false;

  /// Initialize the queue
  Future<void> init() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<Map>(_boxName);
    _isInitialized = true;
  }

  /// Add operation to queue
  Future<QueuedOp> enqueue(OpType type, Map<String, dynamic> payload) async {
    final QueuedOp op = QueuedOp(type: type, payload: payload);
    await _box.put(op.id, op.toJson());
    return op;
  }

  /// Get all pending operations
  List<QueuedOp> getPending() {
    return _box.values
        .map((Map<dynamic, dynamic> v) => QueuedOp.fromJson(Map<String, dynamic>.from(v)))
        .where((QueuedOp op) => op.status == OpStatus.pending || op.status == OpStatus.failed)
        .toList()
      ..sort((QueuedOp a, QueuedOp b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get all operations
  List<QueuedOp> getAll() {
    return _box.values
        .map((Map<dynamic, dynamic> v) => QueuedOp.fromJson(Map<String, dynamic>.from(v)))
        .toList()
      ..sort((QueuedOp a, QueuedOp b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Update operation status
  Future<void> updateStatus(String id, OpStatus status, {String? error}) async {
    final Map<dynamic, dynamic>? data = _box.get(id);
    if (data == null) return;
    
    final QueuedOp op = QueuedOp.fromJson(Map<String, dynamic>.from(data));
    op.status = status;
    if (error != null) {
      op.lastError = error;
      op.retryCount++;
    }
    await _box.put(id, op.toJson());
  }

  /// Remove synced operations older than duration
  Future<int> purge({Duration olderThan = const Duration(days: 7)}) async {
    final DateTime cutoff = DateTime.now().subtract(olderThan);
    final List<String> toRemove = <String>[];
    
    for (final MapEntry<dynamic, dynamic> entry in _box.toMap().entries) {
      final QueuedOp op = QueuedOp.fromJson(Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>));
      if (op.status == OpStatus.synced && op.createdAt.isBefore(cutoff)) {
        toRemove.add(entry.key as String);
      }
    }
    
    for (final String key in toRemove) {
      await _box.delete(key);
    }
    
    return toRemove.length;
  }

  /// Get pending count
  int get pendingCount => getPending().length;

  /// Clear all (for testing)
  Future<void> clear() async {
    await _box.clear();
  }
}
