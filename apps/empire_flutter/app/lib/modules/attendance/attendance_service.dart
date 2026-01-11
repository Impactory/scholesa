import 'package:cloud_firestore/cloud_firestore.dart';
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
    this.educatorId,
    this.siteId,
  })  : _apiClient = apiClient,
        _syncCoordinator = syncCoordinator;
  final ApiClient _apiClient;
  final SyncCoordinator _syncCoordinator;
  final String? educatorId;
  final String? siteId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SessionOccurrence> _todayOccurrences = <SessionOccurrence>[];
  SessionOccurrence? _currentOccurrence;
  bool _isLoading = false;
  String? _error;

  List<SessionOccurrence> get todayOccurrences => _todayOccurrences;
  SessionOccurrence? get currentOccurrence => _currentOccurrence;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load today's occurrences for educator from Firebase
  Future<void> loadTodayOccurrences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Build query based on available identifiers
      Query<Map<String, dynamic>> query = _firestore
          .collection('sessionOccurrences')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('startTime');

      if (educatorId != null && educatorId!.isNotEmpty) {
        query = query.where('educatorId', isEqualTo: educatorId);
      } else if (siteId != null && siteId!.isNotEmpty) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      _todayOccurrences = await Future.wait(
        snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
          final Map<String, dynamic> data = doc.data();
          
          // Count enrolled learners
          final QuerySnapshot<Map<String, dynamic>> enrollmentsSnapshot = await _firestore
              .collection('enrollments')
              .where('sessionId', isEqualTo: data['sessionId'])
              .where('status', isEqualTo: 'active')
              .get();

          return SessionOccurrence(
            id: doc.id,
            sessionId: data['sessionId'] as String? ?? '',
            siteId: data['siteId'] as String? ?? '',
            title: data['title'] as String? ?? 'Untitled Session',
            startTime: _parseTimestamp(data['startTime']) ?? DateTime.now(),
            endTime: _parseTimestamp(data['endTime']),
            roomName: data['roomName'] as String?,
            roster: <RosterLearner>[], // Roster loaded separately
            learnerCount: enrollmentsSnapshot.docs.length,
          );
        }),
      );

      debugPrint('Loaded ${_todayOccurrences.length} occurrences for today');
    } catch (e) {
      _error = 'Failed to load occurrences: $e';
      debugPrint(_error);
      _todayOccurrences = <SessionOccurrence>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load roster for a specific occurrence from Firebase
  Future<void> loadOccurrenceRoster(String occurrenceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get occurrence details
      final DocumentSnapshot<Map<String, dynamic>> occDoc = await _firestore
          .collection('sessionOccurrences')
          .doc(occurrenceId)
          .get();

      if (!occDoc.exists) {
        _error = 'Occurrence not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final Map<String, dynamic> occData = occDoc.data()!;
      final String sessionId = occData['sessionId'] as String? ?? '';

      // Get enrollments for this session
      final QuerySnapshot<Map<String, dynamic>> enrollmentsSnapshot = await _firestore
          .collection('enrollments')
          .where('sessionId', isEqualTo: sessionId)
          .where('status', isEqualTo: 'active')
          .get();

      // Get existing attendance records for this occurrence
      final QuerySnapshot<Map<String, dynamic>> attendanceSnapshot = await _firestore
          .collection('attendanceRecords')
          .where('occurrenceId', isEqualTo: occurrenceId)
          .get();

      final Map<String, Map<String, dynamic>> attendanceByLearner = <String, Map<String, dynamic>>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in attendanceSnapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        attendanceByLearner[data['learnerId'] as String] = <String, dynamic>{
          ...data,
          'id': doc.id,
        };
      }

      // Build roster with learner details
      final List<RosterLearner> roster = await Future.wait(
        enrollmentsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> enrollDoc) async {
          final String learnerId = enrollDoc.data()['learnerId'] as String? ?? '';
          
          // Get learner details
          final DocumentSnapshot<Map<String, dynamic>> learnerDoc = await _firestore
              .collection('users')
              .doc(learnerId)
              .get();
          
          final Map<String, dynamic>? learnerData = learnerDoc.data();
          final Map<String, dynamic>? existingAttendance = attendanceByLearner[learnerId];

          AttendanceRecord? currentAttendance;
          if (existingAttendance != null) {
            currentAttendance = AttendanceRecord(
              id: existingAttendance['id'] as String,
              occurrenceId: occurrenceId,
              learnerId: learnerId,
              status: _parseAttendanceStatus(existingAttendance['status'] as String?),
              recordedAt: _parseTimestamp(existingAttendance['recordedAt']) ?? DateTime.now(),
              recordedBy: existingAttendance['recordedBy'] as String?,
              notes: existingAttendance['notes'] as String?,
            );
          }

          return RosterLearner(
            id: learnerId,
            displayName: learnerData?['displayName'] as String? ?? 'Unknown',
            photoUrl: learnerData?['photoUrl'] as String?,
            currentAttendance: currentAttendance,
          );
        }),
      );

      _currentOccurrence = SessionOccurrence(
        id: occurrenceId,
        sessionId: sessionId,
        siteId: occData['siteId'] as String? ?? '',
        title: occData['title'] as String? ?? 'Untitled',
        startTime: _parseTimestamp(occData['startTime']) ?? DateTime.now(),
        endTime: _parseTimestamp(occData['endTime']),
        roomName: occData['roomName'] as String?,
        roster: roster,
      );

      debugPrint('Loaded roster with ${roster.length} learners');
    } catch (e) {
      _error = 'Failed to load roster: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Record attendance (offline-capable) to Firebase
  Future<void> recordAttendance(AttendanceRecord record) async {
    try {
      // Queue for offline sync
      await _syncCoordinator.queueOperation(
        OpType.attendanceRecord,
        record.toJson(),
      );

      // Write to Firebase
      if (_syncCoordinator.isOnline) {
        await _firestore.collection('attendanceRecords').add(<String, dynamic>{
          'occurrenceId': record.occurrenceId,
          'learnerId': record.learnerId,
          'status': record.status.name,
          'recordedAt': FieldValue.serverTimestamp(),
          'recordedBy': record.recordedBy,
          'notes': record.notes,
        });
      }

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
    } catch (e) {
      debugPrint('Error recording attendance: $e');
      _error = 'Failed to record attendance: $e';
      notifyListeners();
    }
  }

  /// Batch record attendance for multiple learners
  Future<void> batchRecordAttendance(List<AttendanceRecord> records) async {
    try {
      final WriteBatch batch = _firestore.batch();
      
      for (final AttendanceRecord record in records) {
        final DocumentReference<Map<String, dynamic>> docRef = _firestore.collection('attendanceRecords').doc();
        batch.set(docRef, <String, dynamic>{
          'occurrenceId': record.occurrenceId,
          'learnerId': record.learnerId,
          'status': record.status.name,
          'recordedAt': FieldValue.serverTimestamp(),
          'recordedBy': record.recordedBy,
          'notes': record.notes,
        });
      }

      await batch.commit();

      // Update local state
      if (_currentOccurrence != null) {
        final Map<String, AttendanceRecord> recordsByLearner = <String, AttendanceRecord>{
          for (final AttendanceRecord r in records) r.learnerId: r,
        };

        final List<RosterLearner> updatedRoster = _currentOccurrence!.roster.map((RosterLearner learner) {
          final AttendanceRecord? record = recordsByLearner[learner.id];
          if (record != null) {
            return RosterLearner(
              id: learner.id,
              displayName: learner.displayName,
              photoUrl: learner.photoUrl,
              currentAttendance: record,
            );
          }
          return learner;
        }).toList();

        _currentOccurrence = _currentOccurrence!.copyWith(roster: updatedRoster);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error batch recording attendance: $e');
      _error = 'Failed to save attendance: $e';
      notifyListeners();
    }
  }

  /// Clear current occurrence
  void clearCurrentOccurrence() {
    _currentOccurrence = null;
    notifyListeners();
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  AttendanceStatus _parseAttendanceStatus(String? status) {
    switch (status) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      default:
        return AttendanceStatus.absent;
    }
  }
}

