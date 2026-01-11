import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'educator_models.dart';

/// Service for educator-specific features - wired to Firebase
class EducatorService extends ChangeNotifier {

  EducatorService({
    required FirestoreService firestoreService,
    required this.educatorId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String educatorId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<TodayClass> _todayClasses = <TodayClass>[];
  EducatorDayStats? _dayStats;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TodayClass> get todayClasses => _todayClasses;
  TodayClass? get currentClass => _todayClasses.where((TodayClass c) => c.isNow).firstOrNull;
  List<TodayClass> get upcomingClasses =>
      _todayClasses.where((TodayClass c) => c.status == 'upcoming').toList();
  EducatorDayStats? get dayStats => _dayStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load today's schedule from Firebase
  Future<void> loadTodaySchedule() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Query session occurrences for this educator today
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('sessionOccurrences')
          .where('educatorId', isEqualTo: educatorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .orderBy('startTime')
          .get();

      _todayClasses = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return TodayClass(
          id: doc.id,
          sessionId: data['sessionId'] as String? ?? '',
          title: data['title'] as String? ?? 'Session',
          description: data['description'] as String? ?? '',
          startTime: _parseTimestamp(data['startTime']) ?? DateTime.now(),
          endTime: _parseTimestamp(data['endTime']) ?? DateTime.now().add(const Duration(hours: 1)),
          location: data['location'] as String? ?? '',
          enrolledCount: data['enrolledCount'] as int? ?? 0,
          presentCount: data['presentCount'] as int? ?? 0,
          status: data['status'] as String? ?? 'upcoming',
          learners: <EnrolledLearner>[],
        );
      }).toList();

      _dayStats = _calculateStats();
      debugPrint('Loaded ${_todayClasses.length} classes for educator $educatorId');
    } catch (e) {
      debugPrint('Error loading educator schedule: $e');
      _error = 'Failed to load schedule: $e';
      _todayClasses = <TodayClass>[];
      _dayStats = const EducatorDayStats(
        totalClasses: 0,
        completedClasses: 0,
        totalLearners: 0,
        presentLearners: 0,
        missionsToReview: 0,
        unreadMessages: 0,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  EducatorDayStats _calculateStats() {
    final int completed = _todayClasses.where((TodayClass c) => c.status == 'completed').length;
    final int totalLearners = _todayClasses.fold(0, (int sum, TodayClass c) => sum + c.enrolledCount);
    final int presentLearners = _todayClasses.fold(0, (int sum, TodayClass c) => sum + c.presentCount);
    return EducatorDayStats(
      totalClasses: _todayClasses.length,
      completedClasses: completed,
      totalLearners: totalLearners,
      presentLearners: presentLearners,
      missionsToReview: 0,
      unreadMessages: 0,
    );
  }

  /// Start a class (transition to in_progress)
  Future<bool> startClass(String classId) async {
    try {
      final int index = _todayClasses.indexWhere((TodayClass c) => c.id == classId);
      if (index == -1) return false;
      
      // In real implementation, would update server
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Quick attendance mark - saves to Firebase
  Future<bool> markAttendance(String classId, String learnerId, String status) async {
    try {
      await _firestore.collection('attendanceRecords').add(<String, dynamic>{
        'sessionOccurrenceId': classId,
        'learnerId': learnerId,
        'status': status,
        'recordedBy': educatorId,
        'recordedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ========== Sessions Management ==========
  List<EducatorSession> _sessions = <EducatorSession>[];
  List<EducatorSession> get sessions => _sessions;

  /// Load sessions from Firebase
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('sessions')
          .where('educatorId', isEqualTo: educatorId)
          .orderBy('startTime', descending: true)
          .get();

      _sessions = snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return EducatorSession(
          id: doc.id,
          title: data['title'] as String? ?? 'Session',
          description: data['description'] as String? ?? '',
          pillar: data['pillar'] as String? ?? 'future_skills',
          startTime: _parseTimestamp(data['startTime']) ?? DateTime.now(),
          endTime: _parseTimestamp(data['endTime']) ?? DateTime.now().add(const Duration(hours: 1)),
          location: data['location'] as String? ?? '',
          enrolledCount: data['enrolledCount'] as int? ?? 0,
          maxCapacity: data['maxCapacity'] as int? ?? 20,
          status: data['status'] as String? ?? 'upcoming',
        );
      }).toList();

      debugPrint('Loaded ${_sessions.length} sessions for educator');
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      _error = 'Failed to load sessions: $e';
      _sessions = <EducatorSession>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== Learners Management ==========
  List<EducatorLearner> _learners = <EducatorLearner>[];
  List<EducatorLearner> get learners => _learners;

  /// Load learners from Firebase
  Future<void> loadLearners() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Get enrollments for this educator's sessions
      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot = await _firestore
          .collection('enrollments')
          .where('educatorId', isEqualTo: educatorId)
          .get();

      final Set<String> learnerIds = enrollmentSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data()['learnerId'] as String?)
          .whereType<String>()
          .toSet();

      if (learnerIds.isEmpty) {
        _learners = <EducatorLearner>[];
        return;
      }

      // Fetch learner profiles
      final List<EducatorLearner> loadedLearners = <EducatorLearner>[];
      for (final String learnerId in learnerIds) {
        final DocumentSnapshot<Map<String, dynamic>> doc = 
            await _firestore.collection('users').doc(learnerId).get();
        if (doc.exists) {
          final Map<String, dynamic> data = doc.data()!;
          loadedLearners.add(EducatorLearner(
            id: doc.id,
            name: data['displayName'] as String? ?? 'Unknown',
            email: data['email'] as String? ?? '',
            attendanceRate: (data['attendanceRate'] as num?)?.toInt() ?? 0,
            missionsCompleted: data['missionsCompleted'] as int? ?? 0,
            pillarProgress: <String, double>{
              'future_skills': (data['futureSkillsProgress'] as num?)?.toDouble() ?? 0,
              'leadership': (data['leadershipProgress'] as num?)?.toDouble() ?? 0,
              'impact': (data['impactProgress'] as num?)?.toDouble() ?? 0,
            },
            enrolledSessionIds: List<String>.from(data['enrolledSessionIds'] as List<dynamic>? ?? <dynamic>[]),
          ));
        }
      }
      _learners = loadedLearners;
      debugPrint('Loaded ${_learners.length} learners for educator');
    } catch (e) {
      debugPrint('Error loading learners: $e');
      _error = 'Failed to load learners: $e';
      _learners = <EducatorLearner>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
