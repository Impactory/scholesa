import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Load all missions for the learner from Firebase
  Future<void> loadMissions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load missions assigned to this learner
      final QuerySnapshot<Map<String, dynamic>> assignmentsSnapshot = await _firestore
          .collection('missionAssignments')
          .where('learnerId', isEqualTo: learnerId)
          .get();

      final List<Mission> loadedMissions = <Mission>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> assignDoc in assignmentsSnapshot.docs) {
        final Map<String, dynamic> assignData = assignDoc.data();
        final String missionId = assignData['missionId'] as String? ?? '';

        // Get mission details
        final DocumentSnapshot<Map<String, dynamic>> missionDoc = await _firestore
            .collection('missions')
            .doc(missionId)
            .get();

        if (missionDoc.exists) {
          final Map<String, dynamic> missionData = missionDoc.data()!;
          
          // Get steps for this mission
          final QuerySnapshot<Map<String, dynamic>> stepsSnapshot = await _firestore
              .collection('missions')
              .doc(missionId)
              .collection('steps')
              .orderBy('order')
              .get();

          final List<MissionStep> steps = stepsSnapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> stepData = doc.data();
            return MissionStep(
              id: doc.id,
              title: stepData['title'] as String? ?? '',
              order: stepData['order'] as int? ?? 0,
              isCompleted: stepData['isCompleted'] as bool? ?? false,
              completedAt: stepData['completedAt'] as String?,
            );
          }).toList();

          loadedMissions.add(Mission(
            id: missionDoc.id,
            title: missionData['title'] as String? ?? 'Mission',
            description: missionData['description'] as String? ?? '',
            pillar: _parsePillar(missionData['pillarCode'] as String?),
            difficulty: _parseDifficulty(missionData['difficulty'] as String?),
            xpReward: missionData['xpReward'] as int? ?? 100,
            status: _parseStatus(assignData['status'] as String?),
            progress: (assignData['progress'] as num?)?.toDouble() ?? 0.0,
            steps: steps,
            skills: <Skill>[],
            dueDate: _parseTimestamp(assignData['dueDate']),
            startedAt: _parseTimestamp(assignData['startedAt']),
            completedAt: _parseTimestamp(assignData['completedAt']),
            educatorFeedback: assignData['feedback'] as String?,
            reflectionPrompt: missionData['reflectionPrompt'] as String?,
          ));
        }
      }

      _missions = loadedMissions;
      _progress = _calculateProgress();

      debugPrint('Loaded ${_missions.length} missions for learner');
    } catch (e) {
      debugPrint('Error loading missions: $e');
      _error = 'Failed to load missions: $e';
      _missions = <Mission>[];
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

  // ========== Educator: Pending Reviews ==========
  List<MissionSubmission> _pendingReviews = <MissionSubmission>[];
  List<MissionSubmission> get pendingReviews => _pendingReviews;
  int _reviewedToday = 0;
  int get reviewedToday => _reviewedToday;

  Future<void> loadPendingReviews({String? educatorId, String? siteId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Build query for pending submissions
      Query<Map<String, dynamic>> query = _firestore
          .collection('missionSubmissions')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true);

      if (siteId != null && siteId.isNotEmpty) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.limit(50).get();

      _pendingReviews = await Future.wait(
        snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
          final Map<String, dynamic> data = doc.data();
          final String learnerId = data['learnerId'] as String? ?? '';

          // Get learner info
          final DocumentSnapshot<Map<String, dynamic>> learnerDoc = await _firestore
              .collection('users')
              .doc(learnerId)
              .get();
          final Map<String, dynamic>? learnerData = learnerDoc.data();

          // Get mission info
          final String missionId = data['missionId'] as String? ?? '';
          final DocumentSnapshot<Map<String, dynamic>> missionDoc = await _firestore
              .collection('missions')
              .doc(missionId)
              .get();
          final Map<String, dynamic>? missionData = missionDoc.data();

          return MissionSubmission(
            id: doc.id,
            missionId: missionId,
            missionTitle: missionData?['title'] as String? ?? 'Unknown Mission',
            learnerId: learnerId,
            learnerName: learnerData?['displayName'] as String? ?? 'Unknown',
            learnerPhotoUrl: learnerData?['photoUrl'] as String?,
            pillar: missionData?['pillarCode'] as String? ?? 'future_skills',
            submittedAt: _parseTimestamp(data['submittedAt']) ?? DateTime.now(),
            status: data['status'] as String? ?? 'pending',
            submissionText: data['submissionText'] as String?,
            attachmentUrls: List<String>.from(data['attachmentUrls'] as List? ?? <String>[]),
            rating: data['rating'] as int?,
            feedback: data['feedback'] as String?,
          );
        }),
      );

      // Count reviewed today
      final DateTime today = DateTime.now();
      final DateTime startOfDay = DateTime(today.year, today.month, today.day);
      final QuerySnapshot<Map<String, dynamic>> reviewedSnapshot = await _firestore
          .collection('missionSubmissions')
          .where('status', isEqualTo: 'reviewed')
          .where('reviewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      _reviewedToday = reviewedSnapshot.docs.length;

      debugPrint('Loaded ${_pendingReviews.length} pending reviews');
    } catch (e) {
      debugPrint('Error loading pending reviews: $e');
      _pendingReviews = <MissionSubmission>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit review for a mission
  Future<bool> submitReview({
    required String submissionId,
    required int rating,
    required String feedback,
    required String reviewerId,
  }) async {
    try {
      await _firestore.collection('missionSubmissions').doc(submissionId).update(<String, dynamic>{
        'status': 'reviewed',
        'rating': rating,
        'feedback': feedback,
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      _pendingReviews = _pendingReviews.where((MissionSubmission s) => s.id != submissionId).toList();
      _reviewedToday++;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error submitting review: $e');
      _error = 'Failed to submit review: $e';
      notifyListeners();
      return false;
    }
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
