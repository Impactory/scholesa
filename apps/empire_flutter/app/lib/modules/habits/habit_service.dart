import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'habit_models.dart';

/// Service for habit tracking and coaching
class HabitService extends ChangeNotifier {

  HabitService({
    required FirestoreService firestoreService,
    required this.learnerId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String learnerId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Habit> _habits = <Habit>[];
  List<HabitLog> _recentLogs = <HabitLog>[];
  WeeklyHabitSummary? _weeklySummary;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Habit> get habits => _habits;
  List<Habit> get activeHabits => _habits.where((Habit h) => h.isActive).toList();
  List<Habit> get todayHabits => activeHabits; // Could filter by frequency/day
  List<HabitLog> get recentLogs => _recentLogs;
  WeeklyHabitSummary? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get completedTodayCount => _habits.where((Habit h) => h.isCompletedToday).length;
  int get totalTodayCount => todayHabits.length;
  double get todayProgress => totalTodayCount > 0 ? completedTodayCount / totalTodayCount : 0;

  int get totalStreak {
    if (_habits.isEmpty) return 0;
    return _habits.fold(0, (int sum, Habit h) => sum + h.currentStreak);
  }

  /// Load all habits from Firebase
  Future<void> loadHabits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load habits for this learner
      final QuerySnapshot<Map<String, dynamic>> habitsSnapshot = await _firestore
          .collection('habits')
          .where('learnerId', isEqualTo: learnerId)
          .where('isActive', isEqualTo: true)
          .get();

      _habits = habitsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return Habit(
          id: doc.id,
          title: data['title'] as String? ?? 'Habit',
          description: data['description'] as String?,
          emoji: data['emoji'] as String? ?? '⭐',
          category: _parseCategory(data['category'] as String?),
          frequency: _parseFrequency(data['frequency'] as String?),
          preferredTime: _parseTimePreference(data['preferredTime'] as String?),
          targetMinutes: data['targetMinutes'] as int? ?? 10,
          createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
          currentStreak: data['currentStreak'] as int? ?? 0,
          longestStreak: data['longestStreak'] as int? ?? 0,
          totalCompletions: data['totalCompletions'] as int? ?? 0,
          lastCompletedAt: _parseTimestamp(data['lastCompletedAt']),
          isActive: data['isActive'] as bool? ?? true,
        );
      }).toList();

      // Load recent logs
      final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final QuerySnapshot<Map<String, dynamic>> logsSnapshot = await _firestore
          .collection('habitLogs')
          .where('learnerId', isEqualTo: learnerId)
          .where('completedAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('completedAt', descending: true)
          .limit(50)
          .get();

      _recentLogs = logsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        return HabitLog(
          id: doc.id,
          habitId: data['habitId'] as String? ?? '',
          completedAt: _parseTimestamp(data['completedAt']) ?? DateTime.now(),
          durationMinutes: data['durationMinutes'] as int? ?? 0,
          note: data['note'] as String?,
          moodEmoji: data['moodEmoji'] as String?,
        );
      }).toList();

      // Calculate weekly summary
      _weeklySummary = _calculateWeeklySummary();

      debugPrint('Loaded ${_habits.length} habits and ${_recentLogs.length} logs');
    } catch (e) {
      debugPrint('Error loading habits: $e');
      _error = 'Failed to load habits: $e';
      _habits = <Habit>[];
      _recentLogs = <HabitLog>[];
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

  HabitFrequency _parseFrequency(String? freq) {
    switch (freq) {
      case 'daily':
        return HabitFrequency.daily;
      case 'weekdays':
        return HabitFrequency.weekdays;
      case 'weekends':
        return HabitFrequency.weekends;
      case 'custom':
        return HabitFrequency.custom;
      default:
        return HabitFrequency.daily;
    }
  }

  HabitTimePreference _parseTimePreference(String? pref) {
    switch (pref) {
      case 'morning':
        return HabitTimePreference.morning;
      case 'afternoon':
        return HabitTimePreference.afternoon;
      case 'evening':
        return HabitTimePreference.evening;
      default:
        return HabitTimePreference.anytime;
    }
  }

  WeeklyHabitSummary _calculateWeeklySummary() {
    final DateTime now = DateTime.now();
    final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    // Count completions by habit
    final Map<String, int> completionsByHabit = <String, int>{};
    int totalMinutes = 0;
    final List<bool> dailyCompletions = List<bool>.filled(7, false);

    for (final HabitLog log in _recentLogs) {
      completionsByHabit[log.habitId] = (completionsByHabit[log.habitId] ?? 0) + 1;
      totalMinutes += log.durationMinutes ?? 0;
      
      final int dayIndex = log.completedAt.weekday - 1;
      if (dayIndex >= 0 && dayIndex < 7) {
        dailyCompletions[dayIndex] = true;
      }
    }

    return WeeklyHabitSummary(
      weekStart: weekStart,
      totalCompletions: _recentLogs.length,
      totalMinutes: totalMinutes,
      completionsByHabit: completionsByHabit,
      dailyCompletions: dailyCompletions,
    );
  }

  HabitCategory _parseCategory(String? category) {
    switch (category) {
      case 'learning':
        return HabitCategory.learning;
      case 'health':
        return HabitCategory.health;
      case 'creativity':
        return HabitCategory.creativity;
      case 'social':
        return HabitCategory.social;
      case 'mindfulness':
        return HabitCategory.mindfulness;
      default:
        return HabitCategory.learning;
    }
  }

  /// Create a new habit
  Future<Habit?> createHabit({
    required String title,
    String? description,
    required String emoji,
    required HabitCategory category,
    HabitFrequency frequency = HabitFrequency.daily,
    HabitTimePreference preferredTime = HabitTimePreference.anytime,
    int targetMinutes = 10,
  }) async {
    try {
      final Habit habit = Habit(
        id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        emoji: emoji,
        category: category,
        frequency: frequency,
        preferredTime: preferredTime,
        targetMinutes: targetMinutes,
        createdAt: DateTime.now(),
      );

      _habits = <Habit>[..._habits, habit];
      notifyListeners();
      return habit;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Complete a habit for today
  Future<bool> completeHabit(String habitId, {int? durationMinutes, String? note, String? moodEmoji}) async {
    try {
      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index == -1) return false;

      final Habit habit = _habits[index];
      final DateTime now = DateTime.now();
      
      // Create log entry
      final HabitLog log = HabitLog(
        id: 'log_${now.millisecondsSinceEpoch}',
        habitId: habitId,
        completedAt: now,
        durationMinutes: durationMinutes ?? habit.targetMinutes,
        note: note,
        moodEmoji: moodEmoji,
      );
      _recentLogs = <HabitLog>[log, ..._recentLogs];

      // Update habit
      final int newStreak = _calculateNewStreak(habit);
      _habits[index] = habit.copyWith(
        currentStreak: newStreak,
        longestStreak: newStreak > habit.longestStreak ? newStreak : habit.longestStreak,
        totalCompletions: habit.totalCompletions + 1,
        lastCompletedAt: now,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  int _calculateNewStreak(Habit habit) {
    if (habit.lastCompletedAt == null) return 1;
    
    final DateTime now = DateTime.now();
    final DateTime lastDate = habit.lastCompletedAt!;
    final int dayDiff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;

    if (dayDiff == 0) return habit.currentStreak; // Already completed today
    if (dayDiff == 1) return habit.currentStreak + 1; // Consecutive day
    return 1; // Streak broken
  }

  /// Update habit settings
  Future<bool> updateHabit(String habitId, Habit updatedHabit) async {
    try {
      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index != -1) {
        _habits[index] = updatedHabit;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete/archive a habit in Firebase
  Future<bool> deleteHabit(String habitId) async {
    try {
      await _firestore.collection('habits').doc(habitId).update(<String, dynamic>{
        'isActive': false,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index != -1) {
        _habits[index] = _habits[index].copyWith(isActive: false);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting habit: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Create a new habit in Firebase
  Future<Habit?> createHabitInFirestore({
    required String title,
    String? description,
    required String emoji,
    required HabitCategory category,
    HabitFrequency frequency = HabitFrequency.daily,
    HabitTimePreference preferredTime = HabitTimePreference.anytime,
    int targetMinutes = 10,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> docRef = await _firestore.collection('habits').add(<String, dynamic>{
        'learnerId': learnerId,
        'title': title,
        'description': description,
        'emoji': emoji,
        'category': category.name,
        'frequency': frequency.name,
        'preferredTime': preferredTime.name,
        'targetMinutes': targetMinutes,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalCompletions': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final Habit habit = Habit(
        id: docRef.id,
        title: title,
        description: description,
        emoji: emoji,
        category: category,
        frequency: frequency,
        preferredTime: preferredTime,
        targetMinutes: targetMinutes,
        createdAt: DateTime.now(),
      );

      _habits = <Habit>[..._habits, habit];
      notifyListeners();
      return habit;
    } catch (e) {
      debugPrint('Error creating habit: $e');
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Complete a habit and save to Firebase
  Future<bool> completeHabitInFirestore(String habitId, {int? durationMinutes, String? note, String? moodEmoji}) async {
    try {
      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index == -1) return false;

      final Habit habit = _habits[index];
      final DateTime now = DateTime.now();
      
      // Create log entry in Firebase
      final DocumentReference<Map<String, dynamic>> logRef = await _firestore.collection('habitLogs').add(<String, dynamic>{
        'habitId': habitId,
        'learnerId': learnerId,
        'completedAt': FieldValue.serverTimestamp(),
        'durationMinutes': durationMinutes ?? habit.targetMinutes,
        'note': note,
        'moodEmoji': moodEmoji,
      });

      final HabitLog log = HabitLog(
        id: logRef.id,
        habitId: habitId,
        completedAt: now,
        durationMinutes: durationMinutes ?? habit.targetMinutes,
        note: note,
        moodEmoji: moodEmoji,
      );
      _recentLogs = <HabitLog>[log, ..._recentLogs];

      // Update habit streak in Firebase
      final int newStreak = _calculateNewStreak(habit);
      await _firestore.collection('habits').doc(habitId).update(<String, dynamic>{
        'currentStreak': newStreak,
        'longestStreak': newStreak > habit.longestStreak ? newStreak : habit.longestStreak,
        'totalCompletions': FieldValue.increment(1),
        'lastCompletedAt': FieldValue.serverTimestamp(),
      });

      _habits[index] = habit.copyWith(
        currentStreak: newStreak,
        longestStreak: newStreak > habit.longestStreak ? newStreak : habit.longestStreak,
        totalCompletions: habit.totalCompletions + 1,
        lastCompletedAt: now,
      );

      _weeklySummary = _calculateWeeklySummary();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error completing habit: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
