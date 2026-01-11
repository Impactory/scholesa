import 'package:flutter/foundation.dart';
import '../../services/firestore_service.dart';
import 'mission_models.dart';

/// Service for learner missions
class MissionService extends ChangeNotifier {

  MissionService({
    required FirestoreService firestoreService,
    required this.learnerId,
  }) : _firestoreService = firestoreService;
  final FirestoreService _firestoreService;
  final String learnerId;

  List<Mission> _missions = <Mission>[];
  LearnerProgress? _progress;
  bool _isLoading = false;
  String? _error;
  
  // Filters
  Pillar? _pillarFilter;
  MissionStatus? _statusFilter;

  // Getters
  List<Mission> get missions => _filteredMissions;
  List<Mission> get activeMissions => _missions.where((Mission m) => m.status == MissionStatus.inProgress).toList();
  List<Mission> get completedMissions => _missions.where((Mission m) => m.status == MissionStatus.completed).toList();
  LearnerProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Pillar? get pillarFilter => _pillarFilter;
  MissionStatus? get statusFilter => _statusFilter;

  List<Mission> get _filteredMissions {
    return _missions.where((Mission mission) {
      if (_pillarFilter != null && mission.pillar != _pillarFilter) return false;
      if (_statusFilter != null && mission.status != _statusFilter) return false;
      return true;
    }).toList();
  }

  // Filters
  void setPillarFilter(Pillar? pillar) {
    _pillarFilter = pillar;
    notifyListeners();
  }

  void setStatusFilter(MissionStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    _pillarFilter = null;
    _statusFilter = null;
    notifyListeners();
  }

  /// Load all missions for the learner
  Future<void> loadMissions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from Firestore first
      if (learnerId.isNotEmpty) {
        final List<Map<String, dynamic>> firestoreData = 
            await _firestoreService.getLearnerMissions(learnerId);
        
        if (firestoreData.isNotEmpty) {
          _missions = firestoreData.map((Map<String, dynamic> data) {
            return Mission(
              id: data['id'] as String,
              title: data['title'] as String? ?? 'Mission',
              description: data['description'] as String? ?? '',
              pillar: _parsePillar(data['pillarCode'] as String?),
              difficulty: _parseDifficulty(data['difficulty'] as String?),
              xpReward: data['xpReward'] as int? ?? 100,
              status: _parseStatus(data['status'] as String?),
              progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
              steps: <MissionStep>[],
              skills: <Skill>[],
            );
          }).toList();
          _progress = _calculateProgress();
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
      
      // Fall back to mock data for demo purposes
      await Future.delayed(const Duration(milliseconds: 300));
      _missions = _generateMockMissions();
      _progress = _generateMockProgress();
    } catch (e) {
      debugPrint('Error loading missions: $e');
      // Fall back to mock data on error
      _missions = _generateMockMissions();
      _progress = _generateMockProgress();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Pillar _parsePillar(String? code) {
    switch (code) {
      case 'future_skills':
        return Pillar.futureSkills;
      case 'leadership':
        return Pillar.leadership;
      case 'impact':
        return Pillar.impact;
      default:
        return Pillar.futureSkills;
    }
  }

  DifficultyLevel _parseDifficulty(String? level) {
    switch (level) {
      case 'beginner':
        return DifficultyLevel.beginner;
      case 'intermediate':
        return DifficultyLevel.intermediate;
      case 'advanced':
        return DifficultyLevel.advanced;
      default:
        return DifficultyLevel.beginner;
    }
  }

  MissionStatus _parseStatus(String? status) {
    switch (status) {
      case 'not_started':
        return MissionStatus.notStarted;
      case 'in_progress':
        return MissionStatus.inProgress;
      case 'submitted':
        return MissionStatus.submitted;
      case 'completed':
        return MissionStatus.completed;
      default:
        return MissionStatus.notStarted;
    }
  }

  LearnerProgress _calculateProgress() {
    final int totalXp = _missions.where((Mission m) => m.status == MissionStatus.completed)
        .fold(0, (int sum, Mission m) => sum + m.xpReward);
    final int completed = _missions.where((Mission m) => m.status == MissionStatus.completed).length;
    final int level = (totalXp / 1000).floor() + 1;
    return LearnerProgress(
      totalXp: totalXp,
      currentLevel: level,
      xpToNextLevel: (level * 1000) - totalXp,
      missionsCompleted: completed,
      currentStreak: 5,
      pillarProgress: <Pillar, int>{
        Pillar.futureSkills: 60,
        Pillar.leadership: 40,
        Pillar.impact: 50,
      },
    );
  }

  /// Start a mission
  Future<bool> startMission(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index != -1) {
        _missions[index] = _missions[index].copyWith(
          status: MissionStatus.inProgress,
          startedAt: DateTime.now(),
        );
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

  /// Complete a mission step
  Future<bool> completeStep(String missionId, String stepId) async {
    try {
      final int missionIndex = _missions.indexWhere((Mission m) => m.id == missionId);
      if (missionIndex == -1) return false;

      final Mission mission = _missions[missionIndex];
      final List<MissionStep> updatedSteps = mission.steps.map((MissionStep step) {
        if (step.id == stepId) {
          return step.copyWith(
            isCompleted: true,
            completedAt: DateTime.now().toIso8601String(),
          );
        }
        return step;
      }).toList();

      final int completedCount = updatedSteps.where((MissionStep s) => s.isCompleted).length;
      final double progress = completedCount / updatedSteps.length;

      _missions[missionIndex] = mission.copyWith(
        steps: updatedSteps,
        progress: progress,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Submit a mission for review
  Future<bool> submitMission(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index != -1) {
        _missions[index] = _missions[index].copyWith(
          status: MissionStatus.submitted,
        );
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

  /// Mark a mission as complete (after educator approval)
  Future<bool> completeMission(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index != -1) {
        final Mission mission = _missions[index];
        _missions[index] = mission.copyWith(
          status: MissionStatus.completed,
          completedAt: DateTime.now(),
          progress: 1.0,
        );
        
        // Update progress
        if (_progress != null) {
          _progress = LearnerProgress(
            totalXp: _progress!.totalXp + mission.xpReward,
            currentLevel: _progress!.currentLevel,
            xpToNextLevel: _progress!.xpToNextLevel - mission.xpReward,
            missionsCompleted: _progress!.missionsCompleted + 1,
            currentStreak: _progress!.currentStreak,
            pillarProgress: _progress!.pillarProgress,
          );
        }
        
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
  List<Mission> _generateMockMissions() {
    return <Mission>[
      Mission(
        id: 'mission_001',
        title: 'Code Your First Website',
        description: 'Learn the basics of HTML and CSS by building a personal portfolio page.',
        pillar: Pillar.futureSkills,
        difficulty: DifficultyLevel.beginner,
        skills: const <Skill>[
          Skill(id: 'skill_html', name: 'HTML', pillar: Pillar.futureSkills),
          Skill(id: 'skill_css', name: 'CSS', pillar: Pillar.futureSkills),
        ],
        steps: const <MissionStep>[
          MissionStep(id: 'step_1', title: 'Set up your project folder', order: 1, isCompleted: true),
          MissionStep(id: 'step_2', title: 'Create the HTML structure', order: 2, isCompleted: true),
          MissionStep(id: 'step_3', title: 'Add your content', order: 3),
          MissionStep(id: 'step_4', title: 'Style with CSS', order: 4),
          MissionStep(id: 'step_5', title: 'Deploy your site', order: 5),
        ],
        status: MissionStatus.inProgress,
        xpReward: 150,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        startedAt: DateTime.now().subtract(const Duration(days: 2)),
        progress: 0.4,
        reflectionPrompt: 'What did you learn about web development?',
      ),
      Mission(
        id: 'mission_002',
        title: 'Lead a Team Discussion',
        description: 'Facilitate a group brainstorming session on a community problem.',
        pillar: Pillar.leadership,
        difficulty: DifficultyLevel.intermediate,
        skills: const <Skill>[
          Skill(id: 'skill_comm', name: 'Communication', pillar: Pillar.leadership),
          Skill(id: 'skill_facilitation', name: 'Facilitation', pillar: Pillar.leadership),
        ],
        steps: const <MissionStep>[
          MissionStep(id: 'step_1', title: 'Choose a community problem', order: 1),
          MissionStep(id: 'step_2', title: 'Prepare discussion questions', order: 2),
          MissionStep(id: 'step_3', title: 'Invite participants', order: 3),
          MissionStep(id: 'step_4', title: 'Lead the discussion', order: 4),
          MissionStep(id: 'step_5', title: 'Document outcomes', order: 5),
        ],
        xpReward: 200,
        dueDate: DateTime.now().add(const Duration(days: 14)),
      ),
      const Mission(
        id: 'mission_003',
        title: 'Design a Sustainability Solution',
        description: 'Create an innovative solution for a local environmental challenge.',
        pillar: Pillar.impact,
        difficulty: DifficultyLevel.advanced,
        skills: <Skill>[
          Skill(id: 'skill_design', name: 'Design Thinking', pillar: Pillar.impact),
          Skill(id: 'skill_sustainability', name: 'Sustainability', pillar: Pillar.impact),
        ],
        steps: <MissionStep>[
          MissionStep(id: 'step_1', title: 'Research local environmental issues', order: 1),
          MissionStep(id: 'step_2', title: 'Brainstorm solutions', order: 2),
          MissionStep(id: 'step_3', title: 'Create a prototype', order: 3),
          MissionStep(id: 'step_4', title: 'Test with stakeholders', order: 4),
          MissionStep(id: 'step_5', title: 'Present your solution', order: 5),
        ],
        xpReward: 300,
      ),
      Mission(
        id: 'mission_004',
        title: 'Build a Calculator App',
        description: 'Learn programming basics by creating a functional calculator.',
        pillar: Pillar.futureSkills,
        difficulty: DifficultyLevel.beginner,
        skills: const <Skill>[
          Skill(id: 'skill_python', name: 'Python', pillar: Pillar.futureSkills),
          Skill(id: 'skill_logic', name: 'Logic', pillar: Pillar.futureSkills),
        ],
        steps: const <MissionStep>[
          MissionStep(id: 'step_1', title: 'Set up Python environment', order: 1, isCompleted: true),
          MissionStep(id: 'step_2', title: 'Create basic operations', order: 2, isCompleted: true),
          MissionStep(id: 'step_3', title: 'Add user interface', order: 3, isCompleted: true),
          MissionStep(id: 'step_4', title: 'Handle edge cases', order: 4, isCompleted: true),
          MissionStep(id: 'step_5', title: 'Write documentation', order: 5, isCompleted: true),
        ],
        status: MissionStatus.completed,
        startedAt: DateTime.now().subtract(const Duration(days: 14)),
        completedAt: DateTime.now().subtract(const Duration(days: 7)),
        progress: 1.0,
        educatorFeedback: 'Great work on error handling! Your code is clean and well-documented.',
      ),
      Mission(
        id: 'mission_005',
        title: 'Public Speaking Challenge',
        description: 'Prepare and deliver a 5-minute presentation on a topic you care about.',
        pillar: Pillar.leadership,
        difficulty: DifficultyLevel.beginner,
        skills: const <Skill>[
          Skill(id: 'skill_speaking', name: 'Public Speaking', pillar: Pillar.leadership),
          Skill(id: 'skill_confidence', name: 'Confidence', pillar: Pillar.leadership),
        ],
        steps: const <MissionStep>[
          MissionStep(id: 'step_1', title: 'Choose your topic', order: 1, isCompleted: true),
          MissionStep(id: 'step_2', title: 'Research and outline', order: 2, isCompleted: true),
          MissionStep(id: 'step_3', title: 'Create visual aids', order: 3),
          MissionStep(id: 'step_4', title: 'Practice delivery', order: 4),
          MissionStep(id: 'step_5', title: 'Present to an audience', order: 5),
        ],
        status: MissionStatus.inProgress,
        xpReward: 150,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
        progress: 0.4,
      ),
    ];
  }

  LearnerProgress _generateMockProgress() {
    return const LearnerProgress(
      totalXp: 1250,
      currentLevel: 5,
      xpToNextLevel: 250,
      missionsCompleted: 8,
      currentStreak: 12,
      pillarProgress: <Pillar, int>{
        Pillar.futureSkills: 450,
        Pillar.leadership: 400,
        Pillar.impact: 400,
      },
    );
  }

  // ========== Educator: Pending Reviews ==========
  List<MissionSubmission> _pendingReviews = <MissionSubmission>[];
  List<MissionSubmission> get pendingReviews => _pendingReviews;
  int get reviewedToday => 5; // Mock value

  Future<void> loadPendingReviews() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _pendingReviews = _generateMockSubmissions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<MissionSubmission> _generateMockSubmissions() {
    final DateTime now = DateTime.now();
    return <MissionSubmission>[
      MissionSubmission(
        id: 'sub_001',
        missionId: 'mission_001',
        missionTitle: 'Build a Calculator App',
        learnerId: 'l_001',
        learnerName: 'Emma Wilson',
        pillar: 'future_skills',
        submittedAt: now.subtract(const Duration(hours: 2)),
        status: 'pending',
        submissionText: 'Here is my completed calculator with error handling.',
      ),
      MissionSubmission(
        id: 'sub_002',
        missionId: 'mission_002',
        missionTitle: 'Team Leadership Project',
        learnerId: 'l_002',
        learnerName: 'Liam Chen',
        pillar: 'leadership',
        submittedAt: now.subtract(const Duration(hours: 5)),
        status: 'pending',
        submissionText: 'Our team presentation on collaboration.',
      ),
      MissionSubmission(
        id: 'sub_003',
        missionId: 'mission_003',
        missionTitle: 'Community Garden Initiative',
        learnerId: 'l_003',
        learnerName: 'Sofia Martinez',
        pillar: 'impact',
        submittedAt: now.subtract(const Duration(days: 1)),
        status: 'reviewed',
        rating: 4,
        feedback: 'Excellent work on community engagement!',
      ),
    ];
  }
}

/// Mission submission model for educator review
class MissionSubmission {
  final String id;
  final String missionId;
  final String missionTitle;
  final String learnerId;
  final String learnerName;
  final String? learnerPhotoUrl;
  final String pillar;
  final DateTime submittedAt;
  final String status;
  final String? submissionText;
  final List<String> attachmentUrls;
  final int? rating;
  final String? feedback;

  const MissionSubmission({
    required this.id,
    required this.missionId,
    required this.missionTitle,
    required this.learnerId,
    required this.learnerName,
    this.learnerPhotoUrl,
    required this.pillar,
    required this.submittedAt,
    required this.status,
    this.submissionText,
    this.attachmentUrls = const <String>[],
    this.rating,
    this.feedback,
  });

  /// Convenience getters for UI
  String get learnerInitials {
    final List<String> parts = learnerName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return learnerName.isNotEmpty ? learnerName[0].toUpperCase() : '?';
  }
  
  String get submissionPreview {
    if (submissionText == null || submissionText!.isEmpty) {
      return attachmentUrls.isNotEmpty 
          ? '${attachmentUrls.length} attachment(s)'
          : 'No content';
    }
    return submissionText!.length > 100 
        ? '${submissionText!.substring(0, 100)}...'
        : submissionText!;
  }
  
  String get submittedAgo {
    final Duration diff = DateTime.now().difference(submittedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
