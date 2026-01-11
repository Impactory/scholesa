import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import '../../offline/offline_queue.dart';
import '../../offline/sync_coordinator.dart';
import 'attendance_models.dart';

/// Service for attendance operations
class AttendanceService extends ChangeNotifier {

  AttendanceService({
    required ApiClient apiClient,
    required SyncCoordinator syncCoordinator,
  })  : _apiClient = apiClient,
        _syncCoordinator = syncCoordinator;
  final ApiClient _apiClient;
  final SyncCoordinator _syncCoordinator;

  List<SessionOccurrence> _todayOccurrences = <SessionOccurrence>[];
  SessionOccurrence? _currentOccurrence;
  bool _isLoading = false;
  String? _error;

  List<SessionOccurrence> get todayOccurrences => _todayOccurrences;
  SessionOccurrence? get currentOccurrence => _currentOccurrence;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load today's occurrences for educator
  Future<void> loadTodayOccurrences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.get('/v1/occurrences/today');
      final List<dynamic> items = response['items'] as List? ?? <dynamic>[];
      _todayOccurrences = items
          .map((e) => SessionOccurrence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load occurrences: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load roster for a specific occurrence
  Future<void> loadOccurrenceRoster(String occurrenceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await _apiClient.get('/v1/occurrences/$occurrenceId/roster');
      final SessionOccurrence occurrence = SessionOccurrence.fromJson(response);
      _currentOccurrence = occurrence;
    } catch (e) {
      _error = 'Failed to load roster: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Record attendance (offline-capable)
  Future<void> recordAttendance(AttendanceRecord record) async {
    // Queue for offline sync
    await _syncCoordinator.queueOperation(
      OpType.attendanceRecord,
      record.toJson(),
    );

    // Optimistically update local state
    if (_currentOccurrence != null) {
      final List<RosterLearner> updatedRoster = _currentOccurrence!.roster.map((RosterLearner learner) {
        if (learner.id == record.learnerId) {
          return RosterLearner(
            id: learner.id,
            displayName: learner.displayName,
            photoUrl: learner.photoUrl,
            currentAttendance: record.copyWith(isOffline: !_syncCoordinator.isOnline),
          );
        }
        return learner;
      }).toList();

      _currentOccurrence = SessionOccurrence(
        id: _currentOccurrence!.id,
        sessionId: _currentOccurrence!.sessionId,
        siteId: _currentOccurrence!.siteId,
        title: _currentOccurrence!.title,
        startTime: _currentOccurrence!.startTime,
        endTime: _currentOccurrence!.endTime,
        roomName: _currentOccurrence!.roomName,
        roster: updatedRoster,
      );
      notifyListeners();
    }
  }

  /// Batch record attendance for multiple learners
  Future<void> batchRecordAttendance(List<AttendanceRecord> records) async {
    for (final AttendanceRecord record in records) {
      await recordAttendance(record);
    }
  }

  /// Clear current occurrence
  void clearCurrentOccurrence() {
    _currentOccurrence = null;
    notifyListeners();
  }
}
