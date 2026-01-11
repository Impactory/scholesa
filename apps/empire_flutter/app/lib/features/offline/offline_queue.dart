import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Represents a pending action to be synced when online
class PendingAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  PendingAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

/// Callback signature for action dispatchers
typedef ActionDispatcher = Future<bool> Function(PendingAction action);

/// Offline queue manager using Hive for local persistence
class OfflineQueue extends ChangeNotifier {
  static const String _boxName = 'offline_queue';
  static const int _maxRetries = 3;

  Box<String>? _box;
  bool _initialized = false;
  bool _isFlushing = false;
  DateTime? _lastSyncedAt;

  final List<PendingAction> _pending = [];
  final Map<String, ActionDispatcher> _dispatchers = {};

  /// Whether the queue has been loaded from storage
  bool get initialized => _initialized;

  /// Whether a flush operation is in progress
  bool get isFlushing => _isFlushing;

  /// Whether there are pending actions
  bool get hasPending => _pending.isNotEmpty;

  /// List of pending actions
  List<PendingAction> get pending => List.unmodifiable(_pending);

  /// Last successful sync time
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Load the queue from persistent storage
  Future<void> load() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox<String>(_boxName);
      await _loadFromStorage();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('OfflineQueue: Error loading: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    if (_box == null) return;

    _pending.clear();

    for (final key in _box!.keys) {
      if (key == 'lastSyncedAt') {
        final ts = _box!.get(key);
        if (ts != null) {
          _lastSyncedAt = DateTime.tryParse(ts);
        }
        continue;
      }

      final jsonStr = _box!.get(key);
      if (jsonStr != null) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          _pending.add(PendingAction.fromJson(json));
        } catch (e) {
          debugPrint('OfflineQueue: Error parsing action $key: $e');
        }
      }
    }

    _pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Register a dispatcher for a specific action type
  void registerDispatcher(String type, ActionDispatcher dispatcher) {
    _dispatchers[type] = dispatcher;
  }

  /// Add a new action to the queue
  Future<void> enqueue(PendingAction action) async {
    if (_box == null) {
      await load();
    }

    // Remove existing action with same ID if present (upsert behavior)
    _pending.removeWhere((a) => a.id == action.id);
    await _box?.delete('action_${action.id}');

    _pending.add(action);
    await _box?.put('action_${action.id}', jsonEncode(action.toJson()));
    notifyListeners();
  }

  /// Remove an action from the queue
  Future<void> _dequeue(String actionId) async {
    await _box?.delete('action_$actionId');
    _pending.removeWhere((a) => a.id == actionId);
  }

  /// Flush all pending actions using registered dispatchers
  Future<void> flush({required bool online}) async {
    if (!online || _isFlushing || _pending.isEmpty) return;

    _isFlushing = true;
    notifyListeners();

    final toProcess = List<PendingAction>.from(_pending);

    for (final action in toProcess) {
      final dispatcher = _dispatchers[action.type];
      if (dispatcher == null) {
        debugPrint('OfflineQueue: No dispatcher for type ${action.type}');
        continue;
      }

      try {
        final success = await dispatcher(action);
        if (success) {
          await _dequeue(action.id);
        } else {
          action.retryCount++;
          if (action.retryCount >= _maxRetries) {
            debugPrint('OfflineQueue: Max retries reached for ${action.id}');
            await _dequeue(action.id);
          } else {
            await _box?.put('action_${action.id}', jsonEncode(action.toJson()));
          }
        }
      } catch (e) {
        debugPrint('OfflineQueue: Error dispatching ${action.id}: $e');
        action.retryCount++;
        if (action.retryCount >= _maxRetries) {
          await _dequeue(action.id);
        } else {
          await _box?.put('action_${action.id}', jsonEncode(action.toJson()));
        }
      }
    }

    _lastSyncedAt = DateTime.now();
    await _box?.put('lastSyncedAt', _lastSyncedAt!.toIso8601String());

    _isFlushing = false;
    notifyListeners();
  }

  /// Clear all pending actions
  Future<void> clearAll() async {
    await _box?.clear();
    _pending.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _box?.close();
    super.dispose();
  }
}
