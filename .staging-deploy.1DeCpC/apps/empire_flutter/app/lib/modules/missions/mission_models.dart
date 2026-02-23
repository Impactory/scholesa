import 'package:equatable/equatable.dart';

/// Mission status
enum MissionStatus {
  notStarted,
  inProgress,
  submitted,
  completed,
  needsRevision;

  String get label {
    switch (this) {
      case MissionStatus.notStarted:
        return 'Not Started';
      case MissionStatus.inProgress:
        return 'In Progress';
      case MissionStatus.submitted:
        return 'Submitted';
      case MissionStatus.completed:
        return 'Completed';
      case MissionStatus.needsRevision:
        return 'Needs Revision';
    }
  }
}

/// Pillar type for mission categorization
enum Pillar {
  futureSkills,
  leadership,
  impact;

  String get label {
    switch (this) {
      case Pillar.futureSkills:
        return 'Future Skills';
      case Pillar.leadership:
        return 'Leadership & Agency';
      case Pillar.impact:
        return 'Impact & Innovation';
    }
  }

  String get emoji {
    switch (this) {
      case Pillar.futureSkills:
        return '🚀';
      case Pillar.leadership:
        return '👑';
      case Pillar.impact:
        return '💡';
    }
  }
}

/// Mission difficulty level
enum DifficultyLevel {
  beginner,
  intermediate,
  advanced;

  String get label {
    switch (this) {
      case DifficultyLevel.beginner:
        return 'Beginner';
      case DifficultyLevel.intermediate:
        return 'Intermediate';
      case DifficultyLevel.advanced:
        return 'Advanced';
    }
  }
}

/// Model for a skill that can be learned
class Skill extends Equatable {

  const Skill({
    required this.id,
    required this.name,
    this.description,
    required this.pillar,
    this.level = 1,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      pillar: Pillar.values.firstWhere(
        (p) => p.name == json['pillar'],
        orElse: () => Pillar.futureSkills,
      ),
      level: json['level'] as int? ?? 1,
    );
  }
  final String id;
  final String name;
  final String? description;
  final Pillar pillar;
  final int level;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'pillar': pillar.name,
      'level': level,
    };
  }

  @override
  List<Object?> get props => <Object?>[id, name, description, pillar, level];
}

/// Model for a mission step/task
class MissionStep extends Equatable {

  const MissionStep({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    this.isCompleted = false,
    this.completedAt,
  });

  factory MissionStep.fromJson(Map<String, dynamic> json) {
    return MissionStep(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      order: json['order'] as int,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] as String?,
    );
  }
  final String id;
  final String title;
  final String? description;
  final int order;
  final bool isCompleted;
  final String? completedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'order': order,
      'isCompleted': isCompleted,
      'completedAt': completedAt,
    };
  }

  MissionStep copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    bool? isCompleted,
    String? completedAt,
  }) {
    return MissionStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, title, description, order, isCompleted, completedAt];
}

/// Model for a mission
class Mission extends Equatable {

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.pillar,
    required this.difficulty,
    this.skills = const [],
    this.steps = const [],
    this.status = MissionStatus.notStarted,
    this.xpReward = 100,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    this.progress = 0.0,
    this.educatorFeedback,
    this.reflectionPrompt,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      pillar: Pillar.values.firstWhere(
        (p) => p.name == json['pillar'],
        orElse: () => Pillar.futureSkills,
      ),
      difficulty: DifficultyLevel.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => DifficultyLevel.beginner,
      ),
      skills: (json['skills'] as List<dynamic>?)
              ?.map((s) => Skill.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => MissionStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      status: MissionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MissionStatus.notStarted,
      ),
      xpReward: json['xpReward'] as int? ?? 100,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      educatorFeedback: json['educatorFeedback'] as String?,
      reflectionPrompt: json['reflectionPrompt'] as String?,
    );
  }
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final Pillar pillar;
  final DifficultyLevel difficulty;
  final List<Skill> skills;
  final List<MissionStep> steps;
  final MissionStatus status;
  final int xpReward;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double progress;
  final String? educatorFeedback;
  final String? reflectionPrompt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'pillar': pillar.name,
      'difficulty': difficulty.name,
      'skills': skills.map((Skill s) => s.toJson()).toList(),
      'steps': steps.map((MissionStep s) => s.toJson()).toList(),
      'status': status.name,
      'xpReward': xpReward,
      'dueDate': dueDate?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'progress': progress,
      'educatorFeedback': educatorFeedback,
      'reflectionPrompt': reflectionPrompt,
    };
  }

  Mission copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    Pillar? pillar,
    DifficultyLevel? difficulty,
    List<Skill>? skills,
    List<MissionStep>? steps,
    MissionStatus? status,
    int? xpReward,
    DateTime? dueDate,
    DateTime? startedAt,
    DateTime? completedAt,
    double? progress,
    String? educatorFeedback,
    String? reflectionPrompt,
  }) {
    return Mission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      pillar: pillar ?? this.pillar,
      difficulty: difficulty ?? this.difficulty,
      skills: skills ?? this.skills,
      steps: steps ?? this.steps,
      status: status ?? this.status,
      xpReward: xpReward ?? this.xpReward,
      dueDate: dueDate ?? this.dueDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      progress: progress ?? this.progress,
      educatorFeedback: educatorFeedback ?? this.educatorFeedback,
      reflectionPrompt: reflectionPrompt ?? this.reflectionPrompt,
    );
  }

  int get completedStepsCount => steps.where((MissionStep s) => s.isCompleted).length;
  int get totalStepsCount => steps.length;

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        description,
        imageUrl,
        pillar,
        difficulty,
        skills,
        steps,
        status,
        xpReward,
        dueDate,
        startedAt,
        completedAt,
        progress,
        educatorFeedback,
        reflectionPrompt,
      ];
}

/// Learner's progress summary
class LearnerProgress extends Equatable {

  const LearnerProgress({
    required this.totalXp,
    required this.currentLevel,
    required this.xpToNextLevel,
    required this.missionsCompleted,
    required this.currentStreak,
    required this.pillarProgress,
  });

  factory LearnerProgress.fromJson(Map<String, dynamic> json) {
    return LearnerProgress(
      totalXp: json['totalXp'] as int,
      currentLevel: json['currentLevel'] as int,
      xpToNextLevel: json['xpToNextLevel'] as int,
      missionsCompleted: json['missionsCompleted'] as int,
      currentStreak: json['currentStreak'] as int,
      pillarProgress: (json['pillarProgress'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          Pillar.values.firstWhere((p) => p.name == key),
          value as int,
        ),
      ),
    );
  }
  final int totalXp;
  final int currentLevel;
  final int xpToNextLevel;
  final int missionsCompleted;
  final int currentStreak;
  final Map<Pillar, int> pillarProgress;

  double get levelProgress => 1 - (xpToNextLevel / (totalXp + xpToNextLevel));

  @override
  List<Object?> get props => <Object?>[
        totalXp,
        currentLevel,
        xpToNextLevel,
        missionsCompleted,
        currentStreak,
        pillarProgress,
      ];
}
