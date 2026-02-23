import 'package:equatable/equatable.dart';

/// Habit frequency
enum HabitFrequency {
  daily,
  weekdays,
  weekends,
  weekly,
  custom;

  String get label {
    switch (this) {
      case HabitFrequency.daily:
        return 'Every day';
      case HabitFrequency.weekdays:
        return 'Weekdays';
      case HabitFrequency.weekends:
        return 'Weekends';
      case HabitFrequency.weekly:
        return 'Weekly';
      case HabitFrequency.custom:
        return 'Custom';
    }
  }
}

/// Habit category for grouping
enum HabitCategory {
  learning,
  health,
  mindfulness,
  social,
  creativity,
  productivity;

  String get label {
    switch (this) {
      case HabitCategory.learning:
        return 'Learning';
      case HabitCategory.health:
        return 'Health';
      case HabitCategory.mindfulness:
        return 'Mindfulness';
      case HabitCategory.social:
        return 'Social';
      case HabitCategory.creativity:
        return 'Creativity';
      case HabitCategory.productivity:
        return 'Productivity';
    }
  }

  String get emoji {
    switch (this) {
      case HabitCategory.learning:
        return '📚';
      case HabitCategory.health:
        return '💪';
      case HabitCategory.mindfulness:
        return '🧘';
      case HabitCategory.social:
        return '👥';
      case HabitCategory.creativity:
        return '🎨';
      case HabitCategory.productivity:
        return '⚡';
    }
  }
}

/// Time of day preference (renamed to avoid Flutter's TimeOfDay conflict)
enum HabitTimePreference {
  morning,
  afternoon,
  evening,
  anytime;

  String get label {
    switch (this) {
      case HabitTimePreference.morning:
        return 'Morning';
      case HabitTimePreference.afternoon:
        return 'Afternoon';
      case HabitTimePreference.evening:
        return 'Evening';
      case HabitTimePreference.anytime:
        return 'Anytime';
    }
  }

  String get emoji {
    switch (this) {
      case HabitTimePreference.morning:
        return '🌅';
      case HabitTimePreference.afternoon:
        return '☀️';
      case HabitTimePreference.evening:
        return '🌙';
      case HabitTimePreference.anytime:
        return '⏰';
    }
  }
}

/// Model for a habit
class Habit extends Equatable { // 1-7 for Mon-Sun

  const Habit({
    required this.id,
    required this.title,
    this.description,
    required this.emoji,
    required this.category,
    this.frequency = HabitFrequency.daily,
    this.preferredTime = HabitTimePreference.anytime,
    this.targetMinutes = 10,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalCompletions = 0,
    required this.createdAt,
    this.lastCompletedAt,
    this.isActive = true,
    this.customDays,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      emoji: json['emoji'] as String,
      category: HabitCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => HabitCategory.learning,
      ),
      frequency: HabitFrequency.values.firstWhere(
        (f) => f.name == json['frequency'],
        orElse: () => HabitFrequency.daily,
      ),
      preferredTime: HabitTimePreference.values.firstWhere(
        (HabitTimePreference t) => t.name == json['preferredTime'],
        orElse: () => HabitTimePreference.anytime,
      ),
      targetMinutes: json['targetMinutes'] as int? ?? 10,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      totalCompletions: json['totalCompletions'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      customDays: (json['customDays'] as List<dynamic>?)?.cast<int>(),
    );
  }
  final String id;
  final String title;
  final String? description;
  final String emoji;
  final HabitCategory category;
  final HabitFrequency frequency;
  final HabitTimePreference preferredTime;
  final int targetMinutes;
  final int currentStreak;
  final int longestStreak;
  final int totalCompletions;
  final DateTime createdAt;
  final DateTime? lastCompletedAt;
  final bool isActive;
  final List<int>? customDays;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'emoji': emoji,
      'category': category.name,
      'frequency': frequency.name,
      'preferredTime': preferredTime.name,
      'targetMinutes': targetMinutes,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalCompletions': totalCompletions,
      'createdAt': createdAt.toIso8601String(),
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'isActive': isActive,
      'customDays': customDays,
    };
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    HabitCategory? category,
    HabitFrequency? frequency,
    HabitTimePreference? preferredTime,
    int? targetMinutes,
    int? currentStreak,
    int? longestStreak,
    int? totalCompletions,
    DateTime? createdAt,
    DateTime? lastCompletedAt,
    bool? isActive,
    List<int>? customDays,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      preferredTime: preferredTime ?? this.preferredTime,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      createdAt: createdAt ?? this.createdAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      isActive: isActive ?? this.isActive,
      customDays: customDays ?? this.customDays,
    );
  }

  bool get isCompletedToday {
    if (lastCompletedAt == null) return false;
    final DateTime now = DateTime.now();
    return lastCompletedAt!.year == now.year &&
        lastCompletedAt!.month == now.month &&
        lastCompletedAt!.day == now.day;
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        description,
        emoji,
        category,
        frequency,
        preferredTime,
        targetMinutes,
        currentStreak,
        longestStreak,
        totalCompletions,
        createdAt,
        lastCompletedAt,
        isActive,
        customDays,
      ];
}

/// Habit completion log entry
class HabitLog extends Equatable {

  const HabitLog({
    required this.id,
    required this.habitId,
    required this.completedAt,
    required this.durationMinutes,
    this.note,
    this.moodEmoji,
  });

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      durationMinutes: json['durationMinutes'] as int,
      note: json['note'] as String?,
      moodEmoji: json['moodEmoji'] as String?,
    );
  }
  final String id;
  final String habitId;
  final DateTime completedAt;
  final int durationMinutes;
  final String? note;
  final String? moodEmoji;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'habitId': habitId,
      'completedAt': completedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'note': note,
      'moodEmoji': moodEmoji,
    };
  }

  @override
  List<Object?> get props => <Object?>[id, habitId, completedAt, durationMinutes, note, moodEmoji];
}

/// Weekly summary for habit tracking
class WeeklyHabitSummary extends Equatable { // 7 bools for Mon-Sun

  const WeeklyHabitSummary({
    required this.weekStart,
    required this.totalCompletions,
    required this.totalMinutes,
    required this.completionsByHabit,
    required this.dailyCompletions,
  });
  final DateTime weekStart;
  final int totalCompletions;
  final int totalMinutes;
  final Map<String, int> completionsByHabit;
  final List<bool> dailyCompletions;

  double get completionRate {
    final int total = dailyCompletions.length;
    final int completed = dailyCompletions.where((bool d) => d).length;
    return completed / total;
  }

  @override
  List<Object?> get props => <Object?>[
        weekStart,
        totalCompletions,
        totalMinutes,
        completionsByHabit,
        dailyCompletions,
      ];
}
