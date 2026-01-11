import 'package:flutter/foundation.dart';
import '../../services/api_client.dart';
import 'habit_models.dart';

/// Service for habit tracking and coaching
class HabitService extends ChangeNotifier {

  HabitService({
    required ApiClient apiClient,
    required this.learnerId,
  }) : _apiClient = apiClient;
  final ApiClient _apiClient;
  final String learnerId;

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

  /// Load all habits
  Future<void> loadHabits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(milliseconds: 500));
      _habits = _generateMockHabits();
      _recentLogs = _generateMockLogs();
      _weeklySummary = _generateMockWeeklySummary();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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

  /// Delete/archive a habit
  Future<bool> deleteHabit(String habitId) async {
    try {
      final int index = _habits.indexWhere((Habit h) => h.id == habitId);
      if (index != -1) {
        _habits[index] = _habits[index].copyWith(isActive: false);
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

  // Mock data generators
  List<Habit> _generateMockHabits() {
    final DateTime now = DateTime.now();
    return <Habit>[
      Habit(
        id: 'habit_001',
        title: 'Morning Reading',
        description: 'Read for at least 15 minutes every morning',
        emoji: '📖',
        category: HabitCategory.learning,
        preferredTime: HabitTimePreference.morning,
        targetMinutes: 15,
        currentStreak: 12,
        longestStreak: 21,
        totalCompletions: 45,
        createdAt: now.subtract(const Duration(days: 60)),
        lastCompletedAt: now.subtract(const Duration(hours: 16)),
      ),
      Habit(
        id: 'habit_002',
        title: 'Practice Coding',
        description: 'Solve one coding challenge or work on a project',
        emoji: '💻',
        category: HabitCategory.learning,
        frequency: HabitFrequency.weekdays,
        preferredTime: HabitTimePreference.afternoon,
        targetMinutes: 30,
        currentStreak: 5,
        longestStreak: 14,
        totalCompletions: 28,
        createdAt: now.subtract(const Duration(days: 45)),
        lastCompletedAt: now.subtract(const Duration(days: 1)),
      ),
      Habit(
        id: 'habit_003',
        title: 'Mindful Breathing',
        description: '5 minutes of deep breathing exercises',
        emoji: '🧘',
        category: HabitCategory.mindfulness,
        preferredTime: HabitTimePreference.morning,
        targetMinutes: 5,
        currentStreak: 8,
        longestStreak: 15,
        totalCompletions: 52,
        createdAt: now.subtract(const Duration(days: 90)),
        lastCompletedAt: now, // Completed today
      ),
      Habit(
        id: 'habit_004',
        title: 'Journal Writing',
        description: 'Write about your day, learnings, and gratitude',
        emoji: '✍️',
        category: HabitCategory.creativity,
        preferredTime: HabitTimePreference.evening,
        currentStreak: 3,
        longestStreak: 7,
        totalCompletions: 18,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      Habit(
        id: 'habit_005',
        title: 'Physical Activity',
        description: 'Any form of exercise or movement',
        emoji: '🏃',
        category: HabitCategory.health,
        targetMinutes: 20,
        longestStreak: 10,
        totalCompletions: 35,
        createdAt: now.subtract(const Duration(days: 75)),
        lastCompletedAt: now.subtract(const Duration(days: 2)),
      ),
      Habit(
        id: 'habit_006',
        title: 'Help Someone',
        description: 'Do one kind deed or help a friend',
        emoji: '🤝',
        category: HabitCategory.social,
        targetMinutes: 5,
        currentStreak: 4,
        longestStreak: 12,
        totalCompletions: 40,
        createdAt: now.subtract(const Duration(days: 50)),
        lastCompletedAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  List<HabitLog> _generateMockLogs() {
    final DateTime now = DateTime.now();
    return <HabitLog>[
      HabitLog(
        id: 'log_001',
        habitId: 'habit_003',
        completedAt: now,
        durationMinutes: 5,
        moodEmoji: '😌',
      ),
      HabitLog(
        id: 'log_002',
        habitId: 'habit_006',
        completedAt: now.subtract(const Duration(hours: 3)),
        durationMinutes: 10,
        note: 'Helped classmate with math homework',
        moodEmoji: '😊',
      ),
      HabitLog(
        id: 'log_003',
        habitId: 'habit_001',
        completedAt: now.subtract(const Duration(hours: 16)),
        durationMinutes: 20,
        note: 'Finished chapter 5 of science book',
        moodEmoji: '🤓',
      ),
      HabitLog(
        id: 'log_004',
        habitId: 'habit_002',
        completedAt: now.subtract(const Duration(days: 1)),
        durationMinutes: 45,
        note: 'Built a simple calculator app',
        moodEmoji: '🚀',
      ),
    ];
  }

  WeeklyHabitSummary _generateMockWeeklySummary() {
    return WeeklyHabitSummary(
      weekStart: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
      totalCompletions: 28,
      totalMinutes: 340,
      completionsByHabit: const <String, int>{
        'habit_001': 6,
        'habit_002': 4,
        'habit_003': 7,
        'habit_004': 4,
        'habit_005': 3,
        'habit_006': 4,
      },
      dailyCompletions: const <bool>[true, true, true, false, true, true, true],
    );
  }
}
