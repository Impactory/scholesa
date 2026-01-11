import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import 'educator_models.dart';

/// Service for educator-specific features
class EducatorService extends ChangeNotifier {

  EducatorService({
    required ApiClient apiClient,
    required this.educatorId,
  }) : _apiClient = apiClient;
  final ApiClient _apiClient;
  final String educatorId;

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

  /// Load today's schedule
  Future<void> loadTodaySchedule() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _todayClasses = _generateMockClasses();
      _dayStats = _generateMockStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Quick attendance mark
  Future<bool> markAttendance(String classId, String learnerId, String status) async {
    try {
      // In real implementation, would update server and local state
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Mock data generators
  List<TodayClass> _generateMockClasses() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return <TodayClass>[
      TodayClass(
        id: 'class_001',
        sessionId: 'session_001',
        title: 'Future Skills: Python Programming',
        description: 'Introduction to functions and loops',
        startTime: today.add(const Duration(hours: 9)),
        endTime: today.add(const Duration(hours: 10)),
        location: 'Lab A',
        enrolledCount: 12,
        presentCount: 12,
        status: 'completed',
        learners: _generateMockLearners(12, allPresent: true),
      ),
      TodayClass(
        id: 'class_002',
        sessionId: 'session_002',
        title: 'Leadership Workshop',
        description: 'Team collaboration and communication',
        startTime: today.add(const Duration(hours: 10, minutes: 30)),
        endTime: today.add(const Duration(hours: 11, minutes: 30)),
        location: 'Room 201',
        enrolledCount: 8,
        presentCount: 7,
        status: now.hour >= 10 && now.hour < 12 ? 'in_progress' : 'completed',
        learners: _generateMockLearners(8),
      ),
      TodayClass(
        id: 'class_003',
        sessionId: 'session_003',
        title: 'Impact Project Review',
        description: 'Mid-project presentations',
        startTime: today.add(const Duration(hours: 13)),
        endTime: today.add(const Duration(hours: 14, minutes: 30)),
        location: 'Main Hall',
        enrolledCount: 15,
        status: now.hour >= 13 ? 'in_progress' : 'upcoming',
        learners: _generateMockLearners(15, recorded: false),
      ),
      TodayClass(
        id: 'class_004',
        sessionId: 'session_004',
        title: 'Creative Coding',
        description: 'Building interactive art with p5.js',
        startTime: today.add(const Duration(hours: 15)),
        endTime: today.add(const Duration(hours: 16)),
        location: 'Lab B',
        enrolledCount: 10,
        status: 'upcoming',
        learners: _generateMockLearners(10, recorded: false),
      ),
    ];
  }

  List<EnrolledLearner> _generateMockLearners(int count, {bool allPresent = false, bool recorded = true}) {
    final List<String> names = <String>[
      'Alex Chen', 'Emma Wilson', 'Liam Johnson', 'Sophia Brown',
      'Noah Davis', 'Olivia Miller', 'Ethan Garcia', 'Ava Martinez',
      'Mason Rodriguez', 'Isabella Anderson', 'Lucas Thomas', 'Mia Taylor',
      'Oliver Jackson', 'Charlotte White', 'Aiden Harris',
    ];

    return List.generate(count, (int i) {
      String? status;
      if (recorded) {
        if (allPresent) {
          status = 'present';
        } else {
          status = i % 8 == 0 ? 'absent' : (i % 5 == 0 ? 'late' : 'present');
        }
      }
      return EnrolledLearner(
        id: 'learner_${i + 1}',
        name: names[i % names.length],
        attendanceStatus: status,
      );
    });
  }

  EducatorDayStats _generateMockStats() {
    return const EducatorDayStats(
      totalClasses: 4,
      completedClasses: 2,
      totalLearners: 45,
      presentLearners: 38,
      missionsToReview: 7,
      unreadMessages: 3,
    );
  }

  // ========== Sessions Management ==========
  List<EducatorSession> _sessions = <EducatorSession>[];
  List<EducatorSession> get sessions => _sessions;

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _sessions = _generateMockSessions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<EducatorSession> _generateMockSessions() {
    final DateTime now = DateTime.now();
    return <EducatorSession>[
      EducatorSession(
        id: 'ses_001',
        title: 'Python Fundamentals',
        description: 'Introduction to programming with Python',
        pillar: 'future_skills',
        startTime: now.add(const Duration(days: 1, hours: 9)),
        endTime: now.add(const Duration(days: 1, hours: 10)),
        location: 'Lab A',
        enrolledCount: 12,
        maxCapacity: 15,
        status: 'upcoming',
      ),
      EducatorSession(
        id: 'ses_002',
        title: 'Leadership Circle',
        description: 'Developing leadership skills through collaboration',
        pillar: 'leadership',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        location: 'Room 201',
        enrolledCount: 8,
        maxCapacity: 10,
        status: 'completed',
      ),
      EducatorSession(
        id: 'ses_003',
        title: 'Community Impact Project',
        description: 'Working on local sustainability initiatives',
        pillar: 'impact',
        startTime: now.add(const Duration(days: 2, hours: 14)),
        endTime: now.add(const Duration(days: 2, hours: 16)),
        location: 'Main Hall',
        enrolledCount: 18,
        maxCapacity: 20,
        status: 'upcoming',
      ),
    ];
  }

  // ========== Learners Management ==========
  List<EducatorLearner> _learners = <EducatorLearner>[];
  List<EducatorLearner> get learners => _learners;

  Future<void> loadLearners() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _learners = _generateMockEducatorLearners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<EducatorLearner> _generateMockEducatorLearners() {
    return <EducatorLearner>[
      const EducatorLearner(
        id: 'l_001',
        name: 'Emma Wilson',
        email: 'emma@example.com',
        attendanceRate: 95,
        missionsCompleted: 28,
        pillarProgress: <String, double>{
          'future_skills': 0.72,
          'leadership': 0.65,
          'impact': 0.58,
        },
        enrolledSessionIds: <String>['ses_001', 'ses_003'],
      ),
      const EducatorLearner(
        id: 'l_002',
        name: 'Liam Chen',
        email: 'liam@example.com',
        attendanceRate: 88,
        missionsCompleted: 22,
        pillarProgress: <String, double>{
          'future_skills': 0.85,
          'leadership': 0.45,
          'impact': 0.52,
        },
        enrolledSessionIds: <String>['ses_001', 'ses_002'],
      ),
      const EducatorLearner(
        id: 'l_003',
        name: 'Sofia Martinez',
        email: 'sofia@example.com',
        attendanceRate: 92,
        missionsCompleted: 25,
        pillarProgress: <String, double>{
          'future_skills': 0.60,
          'leadership': 0.78,
          'impact': 0.70,
        },
        enrolledSessionIds: <String>['ses_002', 'ses_003'],
      ),
    ];
  }
}
