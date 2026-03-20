import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../../offline/offline_queue.dart';
import '../../offline/sync_coordinator.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import 'mission_models.dart';

const String _fallbackLearnerName = 'Learner unavailable';

@immutable
class MissionProofCheckpoint {
  const MissionProofCheckpoint({
    required this.id,
    required this.summary,
    this.artifactNote,
    this.createdAt,
  });

  final String id;
  final String summary;
  final String? artifactNote;
  final DateTime? createdAt;

  factory MissionProofCheckpoint.fromMap(Map<String, dynamic> data) {
    return MissionProofCheckpoint(
      id: data['id'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      artifactNote: data['artifactNote'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'summary': summary,
        if (artifactNote != null && artifactNote!.isNotEmpty)
          'artifactNote': artifactNote,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}

@immutable
class MissionProofBundle {
  const MissionProofBundle({
    required this.id,
    required this.missionId,
    required this.learnerId,
    this.siteId,
    this.explainItBack,
    this.oralCheckResponse,
    this.miniRebuildPlan,
    this.aiAssistanceUsed,
    this.aiAssistanceDetails,
    this.versionHistory = const <MissionProofCheckpoint>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String missionId;
  final String learnerId;
  final String? siteId;
  final String? explainItBack;
  final String? oralCheckResponse;
  final String? miniRebuildPlan;
  final bool? aiAssistanceUsed;
  final String? aiAssistanceDetails;
  final List<MissionProofCheckpoint> versionHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReady {
    return (explainItBack?.trim().isNotEmpty ?? false) &&
        (oralCheckResponse?.trim().isNotEmpty ?? false) &&
        (miniRebuildPlan?.trim().isNotEmpty ?? false) &&
        versionHistory.isNotEmpty;
  }

  factory MissionProofBundle.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final List<dynamic> rawHistory =
        data['versionHistory'] as List<dynamic>? ?? <dynamic>[];
    return MissionProofBundle(
      id: doc.id,
      missionId: data['missionId'] as String? ?? '',
      learnerId: data['learnerId'] as String? ?? '',
      siteId: data['siteId'] as String?,
      explainItBack: data['explainItBack'] as String?,
      oralCheckResponse: data['oralCheckResponse'] as String?,
      miniRebuildPlan: data['miniRebuildPlan'] as String?,
        aiAssistanceUsed: data['aiAssistanceUsed'] as bool?,
        aiAssistanceDetails: data['aiAssistanceDetails'] as String?,
      versionHistory: rawHistory
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> entry) =>
              MissionProofCheckpoint.fromMap(Map<String, dynamic>.from(entry)))
          .toList(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Service for learner missions
class MissionService extends ChangeNotifier {
  MissionService({
    required FirestoreService firestoreService,
    required this.learnerId,
    SyncCoordinator? syncCoordinator,
  })  : _firestoreService = firestoreService,
        _syncCoordinator = syncCoordinator;
  final FirestoreService _firestoreService;
  final SyncCoordinator? _syncCoordinator;
  final String learnerId;
  FirebaseFirestore get _firestore => _firestoreService.firestore;
  bool get isOnline => _syncCoordinator?.isOnline ?? true;

  List<Mission> _missions = <Mission>[];
  final Map<String, _MissionConfusabilityProfile> _missionProfiles =
      <String, _MissionConfusabilityProfile>{};
  LearnerProgress? _progress;
  bool _isLoading = false;
  String? _error;

  // Filters
  Pillar? _pillarFilter;
  MissionStatus? _statusFilter;

  // Getters
  List<Mission> get missions => _filteredMissions;
  List<Mission> get activeMissions => _missions
      .where((Mission m) => m.status == MissionStatus.inProgress)
      .toList();
  List<Mission> get completedMissions => _missions
      .where((Mission m) => m.status == MissionStatus.completed)
      .toList();
  LearnerProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Pillar? get pillarFilter => _pillarFilter;
  MissionStatus? get statusFilter => _statusFilter;

  Mission? getMissionById(String missionId) {
    for (final Mission mission in _missions) {
      if (mission.id == missionId) {
        return mission;
      }
    }
    return null;
  }

  List<Mission> get _filteredMissions {
    return _missions.where((Mission mission) {
      if (_pillarFilter != null && mission.pillar != _pillarFilter) {
        return false;
      }
      if (_statusFilter != null && mission.status != _statusFilter) {
        return false;
      }
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
      _missionProfiles.clear();

      // Load missions assigned to this learner
      final QuerySnapshot<Map<String, dynamic>> assignmentsSnapshot =
          await _firestore
              .collection('missionAssignments')
              .where('learnerId', isEqualTo: learnerId)
              .get();

      final List<Mission> loadedMissions = <Mission>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> assignDoc
          in assignmentsSnapshot.docs) {
        final Map<String, dynamic> assignData = assignDoc.data();
        final String missionId = assignData['missionId'] as String? ?? '';

        // Get mission details
        final DocumentSnapshot<Map<String, dynamic>> missionDoc =
            await _firestore.collection('missions').doc(missionId).get();

        if (missionDoc.exists) {
          final Map<String, dynamic> missionData = missionDoc.data()!;
          final List<Skill> skills = await _loadMissionSkills(missionData);
          _missionProfiles[missionId] = await _loadMissionConfusabilityProfile(
            missionId,
            missionData,
            skills,
          );

          // Get steps for this mission
          final QuerySnapshot<Map<String, dynamic>> stepsSnapshot =
              await _firestore
                  .collection('missions')
                  .doc(missionId)
                  .collection('steps')
                  .orderBy('order')
                  .get();

          final List<MissionStep> steps = stepsSnapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
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
            skills: skills,
            dueDate: _parseTimestamp(assignData['dueDate']),
            startedAt: _parseTimestamp(assignData['startedAt']),
            completedAt: _parseTimestamp(assignData['completedAt']),
            educatorFeedback: assignData['feedback'] as String?,
            reflectionPrompt: missionData['reflectionPrompt'] as String?,
            fsrsLastRating:
                _parseFsrsRating(assignData['fsrsLastRating'] as String?),
            nextReviewAt: _parseTimestamp(assignData['nextReviewAt']),
            fsrsQueueState: _parseFsrsQueueState(
              assignData['fsrsQueueState'] as String?,
            ),
            interleavingMode: _parseInterleavingMode(
              assignData['interleavingMode'] as String?,
            ),
            recommendedInterleavingMissionIds: List<String>.from(
              assignData['recommendedInterleavingMissionIds'] as List? ??
                  const <String>[],
            ),
            confusabilityBand:
                assignData['confusabilityBand'] as String? ?? 'low',
            workedExampleShown:
                assignData['workedExampleShown'] as bool? ?? false,
            workedExampleFadeStage:
                assignData['workedExampleFadeStage'] as int? ?? 0,
            workedExamplePromptLevel: _parseWorkedExamplePromptLevel(
              assignData['workedExamplePromptLevel'] as String?,
            ),
            workedExampleSuccessStreak:
                assignData['workedExampleSuccessStreak'] as int? ?? 0,
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

  DocumentReference<Map<String, dynamic>> _proofBundleRef(String missionId) {
    return _firestore
        .collection('proofOfLearningBundles')
        .doc('${learnerId}_$missionId');
  }

  String _newProofCheckpointId(String missionId) {
    return _proofBundleRef(missionId).collection('versionHistory').doc().id;
  }

  Future<MissionProofBundle?> loadProofBundle(String missionId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _proofBundleRef(missionId).get();
    if (!snapshot.exists) {
      return null;
    }
    return MissionProofBundle.fromDoc(snapshot);
  }

  Future<MissionProofBundle?> saveProofBundleDraft({
    required String missionId,
    String? explainItBack,
    String? oralCheckResponse,
    String? miniRebuildPlan,
    bool? aiAssistanceUsed,
    String? aiAssistanceDetails,
  }) async {
    final MissionProofBundle? existing = await loadProofBundle(missionId);
    final String? siteId =
        existing?.siteId ?? await _resolveSiteIdForMission(missionId);
    final DocumentReference<Map<String, dynamic>> ref =
        _proofBundleRef(missionId);
    final String explain =
        explainItBack?.trim() ?? existing?.explainItBack ?? '';
    final String oral =
        oralCheckResponse?.trim() ?? existing?.oralCheckResponse ?? '';
    final String rebuild =
        miniRebuildPlan?.trim() ?? existing?.miniRebuildPlan ?? '';
    final bool? resolvedAiAssistanceUsed =
      aiAssistanceUsed ?? existing?.aiAssistanceUsed;
    final String? resolvedAiAssistanceDetails =
      aiAssistanceDetails != null
        ? (aiAssistanceDetails.trim().isEmpty
          ? null
          : aiAssistanceDetails.trim())
        : existing?.aiAssistanceDetails;
    final List<Map<String, dynamic>> versionHistory = existing == null
        ? <Map<String, dynamic>>[]
        : existing.versionHistory
            .map((MissionProofCheckpoint entry) => entry.toMap())
            .toList();

    if (_syncCoordinator?.isOnline ?? true) {
      await ref.set(<String, dynamic>{
        'missionId': missionId,
        'learnerId': learnerId,
        if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
        'explainItBack': explain,
        'oralCheckResponse': oral,
        'miniRebuildPlan': rebuild,
        if (resolvedAiAssistanceUsed != null)
          'aiAssistanceUsed': resolvedAiAssistanceUsed,
        if (resolvedAiAssistanceDetails != null)
          'aiAssistanceDetails': resolvedAiAssistanceDetails,
        if (existing != null) 'versionHistory': versionHistory,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': existing == null
            ? FieldValue.serverTimestamp()
            : (existing.createdAt == null
                ? FieldValue.serverTimestamp()
                : Timestamp.fromDate(existing.createdAt!)),
      }, SetOptions(merge: true));
      return loadProofBundle(missionId);
    }

    await _syncCoordinator!.queueOperation(
      OpType.attemptSaveDraft,
      <String, dynamic>{
        'docPath': ref.path,
        'missionId': missionId,
        'learnerId': learnerId,
        if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
        'explainItBack': explain,
        'oralCheckResponse': oral,
        'miniRebuildPlan': rebuild,
        if (resolvedAiAssistanceUsed != null)
          'aiAssistanceUsed': resolvedAiAssistanceUsed,
        if (resolvedAiAssistanceDetails != null)
          'aiAssistanceDetails': resolvedAiAssistanceDetails,
        'versionHistory': versionHistory,
        'createdAtClient': DateTime.now().millisecondsSinceEpoch,
      },
    );

    return MissionProofBundle(
      id: ref.id,
      missionId: missionId,
      learnerId: learnerId,
      siteId: siteId,
      explainItBack: explain,
      oralCheckResponse: oral,
      miniRebuildPlan: rebuild,
        aiAssistanceUsed: resolvedAiAssistanceUsed,
        aiAssistanceDetails: resolvedAiAssistanceDetails,
      versionHistory:
          existing?.versionHistory ?? const <MissionProofCheckpoint>[],
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<MissionProofBundle?> addVersionCheckpoint({
    required String missionId,
    required String summary,
    String? artifactNote,
  }) async {
    final String trimmedSummary = summary.trim();
    if (trimmedSummary.isEmpty) {
      return loadProofBundle(missionId);
    }

    final MissionProofBundle? existing = await loadProofBundle(missionId);
    final String? siteId =
        existing?.siteId ?? await _resolveSiteIdForMission(missionId);
    final MissionProofCheckpoint checkpoint = MissionProofCheckpoint(
      id: _newProofCheckpointId(missionId),
      summary: trimmedSummary,
      artifactNote:
          artifactNote?.trim().isNotEmpty == true ? artifactNote!.trim() : null,
      createdAt: DateTime.now(),
    );
    final List<MissionProofCheckpoint> versionHistory =
        <MissionProofCheckpoint>[
      ...?existing?.versionHistory,
      checkpoint,
    ];

    await _proofBundleRef(missionId).set(<String, dynamic>{
      'missionId': missionId,
      'learnerId': learnerId,
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      'explainItBack': existing?.explainItBack ?? '',
      'oralCheckResponse': existing?.oralCheckResponse ?? '',
      'miniRebuildPlan': existing?.miniRebuildPlan ?? '',
      if (existing?.aiAssistanceUsed != null)
        'aiAssistanceUsed': existing!.aiAssistanceUsed,
      if (existing?.aiAssistanceDetails?.trim().isNotEmpty == true)
        'aiAssistanceDetails': existing!.aiAssistanceDetails!.trim(),
      'versionHistory': versionHistory
          .map((MissionProofCheckpoint entry) => entry.toMap())
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': existing == null
          ? FieldValue.serverTimestamp()
          : (existing.createdAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(existing.createdAt!)),
    }, SetOptions(merge: true));

    await TelemetryService.instance.logEvent(
      event: 'version_history_checkpointed',
      siteId: siteId,
      metadata: <String, dynamic>{
        'mission_id': missionId,
        'checkpoint_count': versionHistory.length,
        'has_artifact_note': checkpoint.artifactNote != null,
      },
    );

    return loadProofBundle(missionId);
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

  FsrsRating? _parseFsrsRating(String? rating) {
    if (rating == null || rating.isEmpty) {
      return null;
    }
    return FsrsRating.values.firstWhere(
      (FsrsRating value) => value.name == rating,
      orElse: () => FsrsRating.good,
    );
  }

  FsrsQueueState _parseFsrsQueueState(String? state) {
    return FsrsQueueState.values.firstWhere(
      (FsrsQueueState value) => value.name == state,
      orElse: () => FsrsQueueState.idle,
    );
  }

  InterleavingMode _parseInterleavingMode(String? mode) {
    return InterleavingMode.values.firstWhere(
      (InterleavingMode value) => value.name == mode,
      orElse: () => InterleavingMode.focusOnly,
    );
  }

  WorkedExamplePromptLevel _parseWorkedExamplePromptLevel(String? value) {
    return WorkedExamplePromptLevel.values.firstWhere(
      (WorkedExamplePromptLevel promptLevel) => promptLevel.name == value,
      orElse: () => WorkedExamplePromptLevel.fullModel,
    );
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _getAssignmentDocForMission(
    String missionId,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> assignmentsSnapshot =
        await _firestore
            .collection('missionAssignments')
            .where('learnerId', isEqualTo: learnerId)
            .where('missionId', isEqualTo: missionId)
            .limit(1)
            .get();

    if (assignmentsSnapshot.docs.isEmpty) {
      return null;
    }

    return assignmentsSnapshot.docs.first;
  }

  String? _siteIdFromAssignment(
    QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc,
  ) {
    final String? siteId = assignmentDoc?.data()['siteId'] as String?;
    if (siteId == null || siteId.isEmpty) {
      return null;
    }
    return siteId;
  }

  DateTime _nextReviewTimeForRating(FsrsRating rating) {
    final DateTime now = DateTime.now();
    switch (rating) {
      case FsrsRating.again:
        return now.add(const Duration(minutes: 10));
      case FsrsRating.hard:
        return now.add(const Duration(days: 1));
      case FsrsRating.good:
        return now.add(const Duration(days: 3));
      case FsrsRating.easy:
        return now.add(const Duration(days: 7));
    }
  }

  _WorkedExamplePolicyOutcome _workedExamplePolicyForReview(
    Mission current,
    FsrsRating rating,
  ) {
    int nextFadeStage = current.workedExampleFadeStage;
    int nextSuccessStreak = current.workedExampleSuccessStreak;
    String action = 'hold';

    final bool strongRating =
        rating == FsrsRating.good || rating == FsrsRating.easy;
    if (strongRating) {
      nextSuccessStreak += 1;
      if (nextSuccessStreak >= 2 && nextFadeStage < 4) {
        nextFadeStage += 1;
        nextSuccessStreak = 0;
        action = 'decay';
      }
    } else if (rating == FsrsRating.again) {
      nextSuccessStreak = 0;
      if (nextFadeStage > 0) {
        nextFadeStage -= 1;
        action = 'rebuild_support';
      }
    } else {
      nextSuccessStreak = 0;
    }

    return _WorkedExamplePolicyOutcome(
      fadeStage: nextFadeStage,
      promptLevel: _promptLevelForFadeStage(nextFadeStage),
      successStreak: nextSuccessStreak,
      action: action,
    );
  }

  Future<List<Skill>> _loadMissionSkills(
    Map<String, dynamic> missionData,
  ) async {
    final List<Skill> embeddedSkills =
        (missionData['skills'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Skill.fromJson)
            .toList();
    if (embeddedSkills.isNotEmpty) {
      return embeddedSkills;
    }

    final List<String> skillIds = List<String>.from(
      missionData['skillIds'] as List? ?? const <String>[],
    );
    if (skillIds.isEmpty) {
      return const <Skill>[];
    }

    final List<Skill> resolvedSkills = <Skill>[];
    for (final String skillId in skillIds) {
      final DocumentSnapshot<Map<String, dynamic>> skillDoc =
          await _firestore.collection('skills').doc(skillId).get();
      if (!skillDoc.exists) {
        resolvedSkills.add(Skill(
          id: skillId,
          name: skillId,
          pillar: _parsePillar(missionData['pillarCode'] as String?),
        ));
        continue;
      }
      final Map<String, dynamic> skillData = skillDoc.data()!;
      resolvedSkills.add(Skill(
        id: skillDoc.id,
        name: skillData['name'] as String? ?? skillDoc.id,
        description: skillData['description'] as String?,
        pillar: _parsePillar(skillData['pillarCode'] as String?),
      ));
    }
    return resolvedSkills;
  }

  Future<_MissionConfusabilityProfile> _loadMissionConfusabilityProfile(
    String missionId,
    Map<String, dynamic> missionData,
    List<Skill> skills,
  ) async {
    final Set<String> skillIds = <String>{
      ...skills.map((Skill skill) => skill.id),
      ...List<String>.from(
        missionData['skillIds'] as List? ?? const <String>[],
      ),
    }..removeWhere((String value) => value.isEmpty);
    final Set<String> pillarCodes = <String>{
      if (missionData['pillarCode'] is String)
        (missionData['pillarCode'] as String).trim(),
      ...List<String>.from(
        missionData['pillarCodes'] as List? ?? const <String>[],
      ),
    }..removeWhere((String value) => value.isEmpty);
    final Set<String> misconceptionTags = <String>{};

    final QuerySnapshot<Map<String, dynamic>> snapshotDocs = await _firestore
        .collection('missionSnapshots')
        .where('missionId', isEqualTo: missionId)
        .limit(3)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> snapshotDoc
        in snapshotDocs.docs) {
      final Map<String, dynamic> snapshotData = snapshotDoc.data();
      skillIds.addAll(
        List<String>.from(
            snapshotData['skillIds'] as List? ?? const <String>[]),
      );
      pillarCodes.addAll(
        List<String>.from(
          snapshotData['pillarCodes'] as List? ?? const <String>[],
        ),
      );
      _collectConfusabilityTags(snapshotData['bodyJson'], misconceptionTags);
    }

    return _MissionConfusabilityProfile(
      skillIds: skillIds,
      pillarCodes: pillarCodes,
      misconceptionTags: misconceptionTags,
    );
  }

  void _collectConfusabilityTags(dynamic node, Set<String> output) {
    if (node == null) {
      return;
    }
    if (node is Map) {
      node.forEach((dynamic key, dynamic value) {
        final String normalizedKey = key.toString().trim().toLowerCase();
        if (normalizedKey == 'misconceptiontags' ||
            normalizedKey == 'misconceptions' ||
            normalizedKey == 'confusabilitytags') {
          if (value is List) {
            output.addAll(
              value
                  .map((dynamic item) => item.toString().trim())
                  .where((String item) => item.isNotEmpty),
            );
          }
        }
        _collectConfusabilityTags(value, output);
      });
      return;
    }
    if (node is List) {
      for (final dynamic value in node) {
        _collectConfusabilityTags(value, output);
      }
    }
  }

  _InterleavingRecommendation _buildInterleavingRecommendation(
    Mission source,
    InterleavingMode mode,
  ) {
    final List<Mission> candidates = _missions
        .where((Mission mission) =>
            mission.id != source.id &&
            mission.status != MissionStatus.completed)
        .toList();

    candidates.sort(
      (Mission left, Mission right) => _interleavingPriority(
        source,
        left,
        mode,
      ).compareTo(
        _interleavingPriority(
          source,
          right,
          mode,
        ),
      ),
    );

    final int confusableCount = candidates
        .where(
          (Mission mission) => _confusabilityOverlapScore(source, mission) > 0,
        )
        .length;

    return _InterleavingRecommendation(
      missionIds:
          candidates.take(3).map((Mission mission) => mission.id).toList(),
      confusabilityBand: confusableCount >= 2
          ? 'high'
          : confusableCount == 1
              ? 'medium'
              : 'low',
    );
  }

  int _interleavingPriority(
    Mission source,
    Mission candidate,
    InterleavingMode mode,
  ) {
    final int overlap = _confusabilityOverlapScore(source, candidate);
    final bool samePillar = candidate.pillar == source.pillar;
    final int difficultyDistance =
        (candidate.difficulty.index - source.difficulty.index).abs();
    final int progressDistance =
        ((candidate.progress - source.progress).abs() * 10).round();
    switch (mode) {
      case InterleavingMode.focusOnly:
        return samePillar
            ? difficultyDistance + progressDistance
            : 20 + overlap;
      case InterleavingMode.mixed:
        return (samePillar ? 4 : 0) +
            (overlap == 0 ? 0 : 8) +
            difficultyDistance +
            progressDistance;
      case InterleavingMode.scaffoldedMixed:
        return (overlap > 0 ? 0 : 6) +
            (samePillar ? 0 : 4) +
            difficultyDistance +
            progressDistance;
    }
  }

  int _confusabilityOverlapScore(Mission source, Mission candidate) {
    final _MissionConfusabilityProfile sourceProfile =
        _missionProfiles[source.id] ??
            _MissionConfusabilityProfile.empty(
              source.skills.map((Skill skill) => skill.id).toSet(),
            );
    final _MissionConfusabilityProfile candidateProfile =
        _missionProfiles[candidate.id] ??
            _MissionConfusabilityProfile.empty(
              candidate.skills.map((Skill skill) => skill.id).toSet(),
            );

    final int skillOverlap =
        sourceProfile.skillIds.intersection(candidateProfile.skillIds).length;
    final int misconceptionOverlap = sourceProfile.misconceptionTags
        .intersection(candidateProfile.misconceptionTags)
        .length;
    final int pillarOverlap = sourceProfile.pillarCodes
        .intersection(candidateProfile.pillarCodes)
        .length;
    return (misconceptionOverlap * 3) + (skillOverlap * 2) + pillarOverlap;
  }

  WorkedExamplePromptLevel _promptLevelForFadeStage(int fadeStage) {
    if (fadeStage >= 4) {
      return WorkedExamplePromptLevel.independentCheck;
    }
    if (fadeStage == 3) {
      return WorkedExamplePromptLevel.hintOnly;
    }
    if (fadeStage == 2) {
      return WorkedExamplePromptLevel.partialSteps;
    }
    return WorkedExamplePromptLevel.fullModel;
  }

  LearnerProgress _calculateProgress() {
    final int totalXp = _missions
        .where((Mission m) => m.status == MissionStatus.completed)
        .fold(0, (int sum, Mission m) => sum + m.xpReward);
    final int completed = _missions
        .where((Mission m) => m.status == MissionStatus.completed)
        .length;
    final int level = (totalXp / 1000).floor() + 1;
    return LearnerProgress(
      totalXp: totalXp,
      currentLevel: level,
      xpToNextLevel: (level * 1000) - totalXp,
      missionsCompleted: completed,
      currentStreak: 5,
      pillarProgress: const <Pillar, int>{
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
        final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
            await _getAssignmentDocForMission(missionId);

        if (assignmentDoc != null) {
          await assignmentDoc.reference.update(<String, dynamic>{
            'status': 'in_progress',
            'startedAt': FieldValue.serverTimestamp(),
          });
        }

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
      final int missionIndex =
          _missions.indexWhere((Mission m) => m.id == missionId);
      if (missionIndex == -1) return false;

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);

      final Mission mission = _missions[missionIndex];
      final List<MissionStep> updatedSteps =
          mission.steps.map((MissionStep step) {
        if (step.id == stepId) {
          return step.copyWith(
            isCompleted: true,
            completedAt: DateTime.now().toIso8601String(),
          );
        }
        return step;
      }).toList();

      final int completedCount =
          updatedSteps.where((MissionStep s) => s.isCompleted).length;
      final double progress = completedCount / updatedSteps.length;

      _missions[missionIndex] = mission.copyWith(
        steps: updatedSteps,
        progress: progress,
      );

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'progress': progress,
          'status': progress >= 1.0 ? 'completed' : 'in_progress',
          if (progress >= 1.0) 'completedAt': FieldValue.serverTimestamp(),
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Submit a mission for review using the canonical missionAttempts record.
  Future<String?> submitMission(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index != -1) {
        final Mission mission = _missions[index];
        final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
            await _getAssignmentDocForMission(missionId);
        final String? siteId = _siteIdFromAssignment(assignmentDoc) ??
            await _resolveSiteIdForMission(missionId);
        final MissionProofBundle? proofBundle =
            await loadProofBundle(missionId);
        final String? sessionOccurrenceId =
            assignmentDoc?.data()['sessionOccurrenceId'] as String?;
        final DocumentReference<Map<String, dynamic>> attemptRef =
            _firestore.collection('missionAttempts').doc();
        final DocumentReference<Map<String, dynamic>> submissionRef =
            _firestore.collection('missionSubmissions').doc(attemptRef.id);
        final String submissionText =
            'Mission "${mission.title}" submitted for educator review.';
        final Map<String, dynamic> canonicalAttempt = <String, dynamic>{
          'missionId': missionId,
          'missionTitle': mission.title,
          'learnerId': learnerId,
          if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
          if (sessionOccurrenceId != null && sessionOccurrenceId.isNotEmpty)
            'sessionOccurrenceId': sessionOccurrenceId,
          'status': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // Keep submission payload privacy-minimized.
          'content': submissionText,
          'submissionText': submissionText,
          'attachmentUrls': const <String>[],
          if (proofBundle != null) 'proofBundleId': proofBundle.id,
          if (proofBundle != null)
            'proofBundleSummary': <String, dynamic>{
              'isReady': proofBundle.isReady,
              'checkpointCount': proofBundle.versionHistory.length,
              'hasExplainItBack':
                  proofBundle.explainItBack?.trim().isNotEmpty ?? false,
              'hasOralCheck':
                  proofBundle.oralCheckResponse?.trim().isNotEmpty ?? false,
              'hasMiniRebuild':
                  proofBundle.miniRebuildPlan?.trim().isNotEmpty ?? false,
              'hasLearnerAiDisclosure': proofBundle.aiAssistanceUsed != null,
              'aiAssistanceUsed': proofBundle.aiAssistanceUsed == true,
              'hasAiAssistanceDetails':
                proofBundle.aiAssistanceDetails?.trim().isNotEmpty ?? false,
            },
        };

        final WriteBatch batch = _firestore.batch();
        batch.set(attemptRef, canonicalAttempt);
        batch.set(
          submissionRef,
          canonicalAttempt,
          SetOptions(merge: true),
        );
        if (assignmentDoc != null) {
          batch.update(assignmentDoc.reference, <String, dynamic>{
            'status': 'submitted',
            'submittedAt': FieldValue.serverTimestamp(),
            'lastSubmissionId': attemptRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
            'reviewStatus': FieldValue.delete(),
            'gradedBy': FieldValue.delete(),
            'gradedAt': FieldValue.delete(),
            'rating': FieldValue.delete(),
            'feedback': FieldValue.delete(),
            'aiFeedbackDraft': FieldValue.delete(),
            'aiFeedbackEdited': FieldValue.delete(),
            'rubricId': FieldValue.delete(),
            'rubricTitle': FieldValue.delete(),
            'rubricScores': FieldValue.delete(),
            'rubricTotalScore': FieldValue.delete(),
            'rubricMaxScore': FieldValue.delete(),
          });
        }

        await batch.commit();

        _missions[index] = _missions[index].copyWith(
          status: MissionStatus.submitted,
        );
        notifyListeners();
        return attemptRef.id;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> _resolveSiteIdForMission(String missionId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> assignments = await _firestore
          .collection('missionAssignments')
          .where('learnerId', isEqualTo: learnerId)
          .limit(100)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in assignments.docs) {
        final Map<String, dynamic> data = doc.data();
        if (data['missionId'] == missionId) {
          final String? siteId = data['siteId'] as String?;
          if (siteId != null && siteId.isNotEmpty) {
            return siteId;
          }
        }
      }
    } catch (_) {
      // Best effort only; callers handle null site IDs.
    }
    return null;
  }

  /// Mark a mission as complete (after educator approval)
  Future<bool> completeMission(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index != -1) {
        final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
            await _getAssignmentDocForMission(missionId);

        final Mission mission = _missions[index];
        _missions[index] = mission.copyWith(
          status: MissionStatus.completed,
          completedAt: DateTime.now(),
          progress: 1.0,
        );

        if (assignmentDoc != null) {
          await assignmentDoc.reference.update(<String, dynamic>{
            'status': 'completed',
            'progress': 1.0,
            'completedAt': FieldValue.serverTimestamp(),
          });
        }

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

  Future<bool> rateFsrsReview(
    String missionId, {
    required FsrsRating rating,
  }) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index == -1) {
        return false;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);
      final DateTime nextReviewAt = _nextReviewTimeForRating(rating);
      final Mission current = _missions[index];
      final _WorkedExamplePolicyOutcome workedExampleOutcome =
          _workedExamplePolicyForReview(current, rating);

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'fsrsLastRating': rating.name,
          'fsrsRatedAt': FieldValue.serverTimestamp(),
          'nextReviewAt': Timestamp.fromDate(nextReviewAt),
          'fsrsQueueState': 'scheduled',
          'workedExampleFadeStage': workedExampleOutcome.fadeStage,
          'workedExamplePromptLevel': workedExampleOutcome.promptLevel.name,
          'workedExampleSuccessStreak': workedExampleOutcome.successStreak,
        });
      }

      _missions[index] = _missions[index].copyWith(
        fsrsLastRating: rating,
        nextReviewAt: nextReviewAt,
        fsrsQueueState: FsrsQueueState.scheduled,
        workedExampleFadeStage: workedExampleOutcome.fadeStage,
        workedExamplePromptLevel: workedExampleOutcome.promptLevel,
        workedExampleSuccessStreak: workedExampleOutcome.successStreak,
      );

      await TelemetryService.instance.logEvent(
        event: 'fsrs.review.rated',
        role: 'learner',
        siteId: _siteIdFromAssignment(assignmentDoc),
        metadata: <String, dynamic>{
          'mission_id': missionId,
          'itemType': 'mission',
          'rating': rating.name,
          'next_review_at': nextReviewAt.toIso8601String(),
          'worked_example_fade_stage': workedExampleOutcome.fadeStage,
          'worked_example_prompt_level': workedExampleOutcome.promptLevel.name,
          'worked_example_policy_action': workedExampleOutcome.action,
          'worked_example_success_streak': workedExampleOutcome.successStreak,
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> snoozeFsrsQueue(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index == -1) {
        return false;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);
      final DateTime nextReviewAt = DateTime.now().add(const Duration(days: 1));

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'nextReviewAt': Timestamp.fromDate(nextReviewAt),
          'fsrsQueueState': 'snoozed',
          'fsrsSnoozedAt': FieldValue.serverTimestamp(),
        });
      }

      _missions[index] = _missions[index].copyWith(
        nextReviewAt: nextReviewAt,
        fsrsQueueState: FsrsQueueState.snoozed,
      );

      await TelemetryService.instance.logEvent(
        event: 'fsrs.queue.snoozed',
        role: 'learner',
        siteId: _siteIdFromAssignment(assignmentDoc),
        metadata: <String, dynamic>{
          'mission_id': missionId,
          'itemCount': 1,
          'itemType': 'mission',
          'next_review_at': nextReviewAt.toIso8601String(),
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rescheduleFsrsQueue(
    String missionId, {
    int days = 3,
  }) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index == -1) {
        return false;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);
      final DateTime nextReviewAt = DateTime.now().add(Duration(days: days));

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'nextReviewAt': Timestamp.fromDate(nextReviewAt),
          'fsrsQueueState': 'rescheduled',
          'fsrsRescheduledAt': FieldValue.serverTimestamp(),
        });
      }

      _missions[index] = _missions[index].copyWith(
        nextReviewAt: nextReviewAt,
        fsrsQueueState: FsrsQueueState.rescheduled,
      );

      await TelemetryService.instance.logEvent(
        event: 'fsrs.queue.rescheduled',
        role: 'learner',
        siteId: _siteIdFromAssignment(assignmentDoc),
        metadata: <String, dynamic>{
          'mission_id': missionId,
          'itemCount': 1,
          'itemType': 'mission',
          'days': days,
          'next_review_at': nextReviewAt.toIso8601String(),
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> suspendFsrsQueue(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index == -1) {
        return false;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'nextReviewAt': FieldValue.delete(),
          'fsrsQueueState': 'suspended',
          'fsrsSuspendedAt': FieldValue.serverTimestamp(),
        });
      }

      final Mission current = _missions[index];
      _missions[index] = Mission(
        id: current.id,
        title: current.title,
        description: current.description,
        imageUrl: current.imageUrl,
        pillar: current.pillar,
        difficulty: current.difficulty,
        skills: current.skills,
        steps: current.steps,
        status: current.status,
        xpReward: current.xpReward,
        dueDate: current.dueDate,
        startedAt: current.startedAt,
        completedAt: current.completedAt,
        progress: current.progress,
        educatorFeedback: current.educatorFeedback,
        reflectionPrompt: current.reflectionPrompt,
        fsrsLastRating: current.fsrsLastRating,
        nextReviewAt: null,
        fsrsQueueState: FsrsQueueState.suspended,
        interleavingMode: current.interleavingMode,
        recommendedInterleavingMissionIds:
            current.recommendedInterleavingMissionIds,
        confusabilityBand: current.confusabilityBand,
        workedExampleShown: current.workedExampleShown,
        workedExampleFadeStage: current.workedExampleFadeStage,
        workedExamplePromptLevel: current.workedExamplePromptLevel,
        workedExampleSuccessStreak: current.workedExampleSuccessStreak,
      );

      await TelemetryService.instance.logEvent(
        event: 'fsrs.queue.rescheduled',
        role: 'learner',
        siteId: _siteIdFromAssignment(assignmentDoc),
        metadata: <String, dynamic>{
          'mission_id': missionId,
          'itemCount': 1,
          'itemType': 'mission',
          'action': 'suspend',
          'queue_state': 'suspended',
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setInterleavingMode(
    String missionId, {
    required InterleavingMode mode,
  }) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index == -1) {
        return false;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);
      final _InterleavingRecommendation recommendation =
          _buildInterleavingRecommendation(_missions[index], mode);

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'interleavingMode': mode.name,
          'recommendedInterleavingMissionIds': recommendation.missionIds,
          'confusabilityBand': recommendation.confusabilityBand,
          'interleavingUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      _missions[index] = _missions[index].copyWith(
        interleavingMode: mode,
        recommendedInterleavingMissionIds: recommendation.missionIds,
        confusabilityBand: recommendation.confusabilityBand,
      );

      await TelemetryService.instance.logEvent(
        event: 'interleaving.mode.changed',
        role: 'learner',
        siteId: _siteIdFromAssignment(assignmentDoc),
        metadata: <String, dynamic>{
          'mission_id': missionId,
          'mode': mode.name,
          'recommended_count': recommendation.missionIds.length,
          'confusabilityBand': recommendation.confusabilityBand,
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> showWorkedExample(String missionId) async {
    try {
      final int index = _missions.indexWhere((Mission m) => m.id == missionId);
      if (index == -1) {
        return false;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>? assignmentDoc =
          await _getAssignmentDocForMission(missionId);
      final int nextFadeStage = _missions[index].workedExampleFadeStage >= 4
          ? 4
          : _missions[index].workedExampleFadeStage + 1;
      final WorkedExamplePromptLevel promptLevel =
          _promptLevelForFadeStage(nextFadeStage);

      if (assignmentDoc != null) {
        await assignmentDoc.reference.update(<String, dynamic>{
          'workedExampleShown': true,
          'workedExampleFadeStage': nextFadeStage,
          'workedExamplePromptLevel': promptLevel.name,
          'workedExampleShownAt': FieldValue.serverTimestamp(),
        });
      }

      _missions[index] = _missions[index].copyWith(
        workedExampleShown: true,
        workedExampleFadeStage: nextFadeStage,
        workedExamplePromptLevel: promptLevel,
        workedExampleSuccessStreak: 0,
      );

      await TelemetryService.instance.logEvent(
        event: 'worked_example.shown',
        role: 'learner',
        siteId: _siteIdFromAssignment(assignmentDoc),
        metadata: <String, dynamic>{
          'mission_id': missionId,
          'triggerTag': 'mission_detail_sheet',
          'fadeStage': nextFadeStage,
          'promptLevel': promptLevel.name,
        },
      );

      notifyListeners();
      return true;
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
    _error = null;
    notifyListeners();
    try {
      final QuerySnapshot<Map<String, dynamic>> canonicalSnapshot =
          await _pendingReviewAttemptsQuery(siteId: siteId).limit(50).get();
      final Set<String> canonicalIds =
          canonicalSnapshot.docs.map((doc) => doc.id).toSet();
      final QuerySnapshot<Map<String, dynamic>> legacySnapshot =
          await _legacyPendingReviewSubmissionsQuery(siteId: siteId)
              .limit(50)
              .get();

      final List<MissionSubmission> canonicalReviews = await Future.wait(
        canonicalSnapshot.docs.map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              _hydrateMissionSubmission(docId: doc.id, data: doc.data()),
        ),
      );
      final List<MissionSubmission> legacyReviews = await Future.wait(
        legacySnapshot.docs
            .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                !canonicalIds.contains(doc.id))
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  _hydrateMissionSubmission(docId: doc.id, data: doc.data()),
            ),
      );

      _pendingReviews = <MissionSubmission>[
        ...canonicalReviews,
        ...legacyReviews,
      ]..sort((MissionSubmission a, MissionSubmission b) =>
          b.submittedAt.compareTo(a.submittedAt));

      final QuerySnapshot<Map<String, dynamic>> reviewedSnapshot =
          await _reviewedMissionAttemptsQuery(siteId: siteId).get();
      _reviewedToday = reviewedSnapshot.docs.where((doc) {
        final Map<String, dynamic> data = doc.data();
        final String reviewedStatus = _normalizedReviewQueueStatus(
          status: data['status'] as String?,
          reviewStatus: data['reviewStatus'] as String?,
        );
        return reviewedStatus == 'reviewed' ||
            reviewedStatus == 'approved' ||
            reviewedStatus == 'revision';
      }).length;

      if (_reviewedToday == 0) {
        final QuerySnapshot<Map<String, dynamic>> legacyReviewedSnapshot =
            await _legacyReviewedSubmissionsQuery(siteId: siteId).get();
        _reviewedToday = legacyReviewedSnapshot.docs.where((doc) {
          final Map<String, dynamic> data = doc.data();
          final String reviewedStatus = _normalizedReviewQueueStatus(
            status: data['status'] as String?,
            reviewStatus: data['reviewStatus'] as String?,
          );
          return reviewedStatus == 'reviewed' ||
              reviewedStatus == 'approved' ||
              reviewedStatus == 'revision';
        }).length;
      }

      debugPrint('Loaded ${_pendingReviews.length} pending reviews');
    } catch (e) {
      debugPrint('Error loading pending reviews: $e');
      _error = 'Unable to load mission review queue right now.';
      _pendingReviews = <MissionSubmission>[];
      _reviewedToday = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Query<Map<String, dynamic>> _pendingReviewAttemptsQuery({String? siteId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('missionAttempts')
        .where('status', whereIn: const <String>[
      'submitted',
      'pending_review'
    ]).orderBy('submittedAt', descending: true);

    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    return query;
  }

  Query<Map<String, dynamic>> _legacyPendingReviewSubmissionsQuery({
    String? siteId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('missionSubmissions')
        .where('status', whereIn: const <String>[
      'pending',
      'submitted'
    ]).orderBy('submittedAt', descending: true);

    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    return query;
  }

  Query<Map<String, dynamic>> _reviewedMissionAttemptsQuery({String? siteId}) {
    final DateTime today = DateTime.now();
    final DateTime startOfDay = DateTime(today.year, today.month, today.day);
    Query<Map<String, dynamic>> query =
        _firestore.collection('missionAttempts').where(
              'reviewedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            );
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    return query;
  }

  Query<Map<String, dynamic>> _legacyReviewedSubmissionsQuery({
    String? siteId,
  }) {
    final DateTime today = DateTime.now();
    final DateTime startOfDay = DateTime(today.year, today.month, today.day);
    Query<Map<String, dynamic>> query =
        _firestore.collection('missionSubmissions').where(
              'reviewedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            );
    if (siteId != null && siteId.isNotEmpty) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    return query;
  }

  Future<MissionSubmission> _hydrateMissionSubmission({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final String learnerId = data['learnerId'] as String? ?? '';
    final DocumentSnapshot<Map<String, dynamic>> learnerDoc =
        await _firestore.collection('users').doc(learnerId).get();
    final Map<String, dynamic>? learnerData = learnerDoc.data();

    final String missionId = data['missionId'] as String? ?? '';
    final DocumentSnapshot<Map<String, dynamic>> missionDoc =
        await _firestore.collection('missions').doc(missionId).get();
    final Map<String, dynamic>? missionData = missionDoc.data();
    final String rubricId =
        (data['rubricId'] as String?)?.trim().isNotEmpty == true
            ? (data['rubricId'] as String).trim()
            : missionData?['rubricId'] as String? ?? '';
    List<Map<String, dynamic>> rubricCriteria = const <Map<String, dynamic>>[];

    if (rubricId.isNotEmpty) {
      final DocumentSnapshot<Map<String, dynamic>> rubricDoc =
          await _firestore.collection('rubrics').doc(rubricId).get();
      rubricCriteria = (rubricDoc.data()?['criteria'] as List?)
              ?.map(
                (dynamic entry) => Map<String, dynamic>.from(entry as Map),
              )
              .toList() ??
          const <Map<String, dynamic>>[];
    }

    final String missionTitle =
        (data['missionTitle'] as String?)?.trim().isNotEmpty == true
            ? (data['missionTitle'] as String).trim()
            : (missionData?['title'] as String?)?.trim().isNotEmpty == true
                ? (missionData?['title'] as String).trim()
                : 'Mission unavailable';
    final List<String> attachmentUrls = List<String>.from(
      data['attachmentUrls'] as List? ??
          data['artifactUrls'] as List? ??
          const <String>[],
    );

    return MissionSubmission(
      id: docId,
      missionId: missionId,
      missionTitle: missionTitle,
      learnerId: learnerId,
      learnerName:
          (learnerData?['displayName'] as String?)?.trim().isNotEmpty == true
              ? (learnerData?['displayName'] as String).trim()
              : _fallbackLearnerName,
      learnerPhotoUrl: learnerData?['photoUrl'] as String?,
      siteId: data['siteId'] as String?,
      pillar: data['pillarCode'] as String? ??
          missionData?['pillarCode'] as String? ??
          'future_skills',
      submittedAt: _parseTimestamp(data['submittedAt']) ??
          _parseTimestamp(data['updatedAt']) ??
          DateTime.now(),
      status: _normalizedReviewQueueStatus(
        status: data['status'] as String?,
        reviewStatus: data['reviewStatus'] as String?,
      ),
      submissionText:
          data['submissionText'] as String? ?? data['content'] as String?,
      attachmentUrls: attachmentUrls,
      rating: data['rating'] as int?,
      feedback: data['feedback'] as String?,
      aiFeedbackDraft: data['aiFeedbackDraft'] as String?,
      rubricId: rubricId,
      rubricTitle: data['rubricTitle'] as String? ??
          missionData?['rubricTitle'] as String?,
      rubricCriteria: rubricCriteria,
      rubricScores: (data['rubricScores'] as List?)
              ?.map(
                (dynamic entry) => Map<String, dynamic>.from(entry as Map),
              )
              .toList() ??
          const <Map<String, dynamic>>[],
    );
  }

  String _normalizedReviewQueueStatus({
    required String? status,
    required String? reviewStatus,
  }) {
    if (reviewStatus != null && reviewStatus.trim().isNotEmpty) {
      return reviewStatus.trim();
    }
    switch (status) {
      case 'submitted':
      case 'pending':
      case 'pending_review':
        return 'pending';
      default:
        return status?.trim().isNotEmpty == true ? status!.trim() : 'pending';
    }
  }

  /// Submit review for a mission
  Future<bool> submitReview({
    required String submissionId,
    required int rating,
    required String feedback,
    required String reviewerId,
    String status = 'reviewed',
    String? aiFeedbackDraft,
    String? rubricId,
    String? rubricTitle,
    List<Map<String, dynamic>> rubricScores = const <Map<String, dynamic>>[],
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> canonicalAttemptRef =
          await _resolveReviewAttemptRef(submissionId);
      final DocumentSnapshot<Map<String, dynamic>> canonicalAttemptSnapshot =
          await canonicalAttemptRef.get();
      final DocumentReference<Map<String, dynamic>> submissionRef =
          _firestore.collection('missionSubmissions').doc(submissionId);
      final DocumentSnapshot<Map<String, dynamic>> submissionSnapshot =
          await submissionRef.get();
      final Map<String, dynamic> submissionData =
          canonicalAttemptSnapshot.data() ??
              submissionSnapshot.data() ??
              <String, dynamic>{};
      if (submissionData.isEmpty) {
        _error = 'Unable to load mission review record right now.';
        notifyListeners();
        return false;
      }
      final String missionId = submissionData['missionId'] as String? ?? '';
      final String reviewLearnerId =
          submissionData['learnerId'] as String? ?? learnerId;
      final String? reviewSiteId = submissionData['siteId'] as String?;
      final String trimmedFeedback = feedback.trim();
      final String? trimmedAiDraft = aiFeedbackDraft?.trim().isNotEmpty == true
          ? aiFeedbackDraft!.trim()
          : null;
      final String resolvedRubricId = rubricId?.trim().isNotEmpty == true
          ? rubricId!.trim()
          : submissionData['rubricId'] as String? ?? '';
      final String? resolvedRubricTitle = rubricTitle?.trim().isNotEmpty == true
          ? rubricTitle!.trim()
          : submissionData['rubricTitle'] as String?;
        final String missionTitle =
          (submissionData['missionTitle'] as String? ?? '').trim();
        final String submissionText =
          (submissionData['submissionText'] as String? ?? '').trim();
        final List<String> submissionAttachmentUrls = List<String>.from(
        submissionData['attachmentUrls'] as List? ?? const <String>[],
        );
        final String? proofBundleId =
          (submissionData['proofBundleId'] as String?)?.trim().isNotEmpty ==
              true
            ? (submissionData['proofBundleId'] as String).trim()
            : null;
        final Map<String, dynamic>? proofBundleSummary =
            submissionData['proofBundleSummary'] is Map
                ? Map<String, dynamic>.from(
                    submissionData['proofBundleSummary'] as Map,
                  )
                : null;
        final String proofBundleAiAssistanceDetails = proofBundleId == null
          ? ''
          : (((await _firestore
                  .collection('proofOfLearningBundles')
                  .doc(proofBundleId)
                  .get())
                .data()?['aiAssistanceDetails'] as String?) ?? '')
            .trim();
      final List<Map<String, dynamic>> normalizedRubricScores = rubricScores
          .map((Map<String, dynamic> score) => <String, dynamic>{
                ...score,
                'score': (score['score'] as num?)?.toInt() ?? 0,
                'maxScore': (score['maxScore'] as num?)?.toInt() ?? 4,
              })
          .toList();
      final int rubricTotalScore = normalizedRubricScores.fold<int>(
        0,
        (int total, Map<String, dynamic> score) =>
            total + ((score['score'] as num?)?.toInt() ?? 0),
      );
      final int rubricMaxScore = normalizedRubricScores.fold<int>(
        0,
        (int total, Map<String, dynamic> score) =>
            total + ((score['maxScore'] as num?)?.toInt() ?? 0),
      );
      final WriteBatch batch = _firestore.batch();

      batch.set(
          canonicalAttemptRef,
          <String, dynamic>{
            'missionId': missionId,
            if ((submissionData['missionTitle'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true)
              'missionTitle': (submissionData['missionTitle'] as String).trim(),
            'learnerId': reviewLearnerId,
            if (reviewSiteId != null && reviewSiteId.isNotEmpty)
              'siteId': reviewSiteId,
            if ((submissionData['sessionOccurrenceId'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true)
              'sessionOccurrenceId':
                  (submissionData['sessionOccurrenceId'] as String).trim(),
            'status': 'reviewed',
            'reviewStatus': status,
            'rating': rating,
            'feedback': trimmedFeedback,
            'reviewNotes': trimmedFeedback,
            'reviewedBy': reviewerId,
            'reviewedAt': FieldValue.serverTimestamp(),
            'gradedBy': reviewerId,
            'gradedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if ((submissionData['submittedAt']) != null)
              'submittedAt': submissionData['submittedAt'],
            if ((submissionData['createdAt']) != null)
              'createdAt': submissionData['createdAt'],
            if ((submissionData['content'] as String?)?.trim().isNotEmpty ==
                true)
              'content': (submissionData['content'] as String).trim(),
            if ((submissionData['submissionText'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true)
              'submissionText':
                  (submissionData['submissionText'] as String).trim(),
            if (submissionData['attachmentUrls'] is List)
              'attachmentUrls': List<String>.from(
                submissionData['attachmentUrls'] as List,
              ),
            if (trimmedAiDraft != null) 'aiFeedbackDraft': trimmedAiDraft,
            if (trimmedAiDraft != null)
              'aiFeedbackEdited': trimmedAiDraft != trimmedFeedback,
            if (resolvedRubricId.isNotEmpty) 'rubricId': resolvedRubricId,
            if (resolvedRubricTitle != null && resolvedRubricTitle.isNotEmpty)
              'rubricTitle': resolvedRubricTitle,
            if (normalizedRubricScores.isNotEmpty)
              'rubricScores': normalizedRubricScores,
            if (normalizedRubricScores.isNotEmpty)
              'rubricTotalScore': rubricTotalScore,
            if (normalizedRubricScores.isNotEmpty)
              'rubricMaxScore': rubricMaxScore,
          },
          SetOptions(merge: true));

      if (submissionSnapshot.exists || submissionId == canonicalAttemptRef.id) {
        batch.set(
            submissionRef,
            <String, dynamic>{
              'missionId': missionId,
              'learnerId': reviewLearnerId,
              if (reviewSiteId != null && reviewSiteId.isNotEmpty)
                'siteId': reviewSiteId,
              'status': status,
              'rating': rating,
              'feedback': trimmedFeedback,
              'reviewedBy': reviewerId,
              'reviewedAt': FieldValue.serverTimestamp(),
              if (trimmedAiDraft != null) 'aiFeedbackDraft': trimmedAiDraft,
              if (trimmedAiDraft != null)
                'aiFeedbackEdited': trimmedAiDraft != trimmedFeedback,
              if (resolvedRubricId.isNotEmpty) 'rubricId': resolvedRubricId,
              if (resolvedRubricTitle != null && resolvedRubricTitle.isNotEmpty)
                'rubricTitle': resolvedRubricTitle,
              if (normalizedRubricScores.isNotEmpty)
                'rubricScores': normalizedRubricScores,
              if (normalizedRubricScores.isNotEmpty)
                'rubricTotalScore': rubricTotalScore,
              if (normalizedRubricScores.isNotEmpty)
                'rubricMaxScore': rubricMaxScore,
            },
            SetOptions(merge: true));
      }

      if (missionId.isNotEmpty && reviewLearnerId.isNotEmpty) {
        final QuerySnapshot<Map<String, dynamic>> assignmentSnapshot =
            await _firestore
                .collection('missionAssignments')
                .where('learnerId', isEqualTo: reviewLearnerId)
                .where('missionId', isEqualTo: missionId)
                .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> assignmentDoc
            in assignmentSnapshot.docs) {
          final String? assignmentSiteId =
              assignmentDoc.data()['siteId'] as String?;
          if (reviewSiteId != null &&
              reviewSiteId.isNotEmpty &&
              assignmentSiteId != reviewSiteId) {
            continue;
          }
          batch.update(assignmentDoc.reference, <String, dynamic>{
            'reviewStatus': status,
            'lastSubmissionId': canonicalAttemptRef.id,
            'gradedBy': reviewerId,
            'gradedAt': FieldValue.serverTimestamp(),
            'rating': rating,
            'feedback': trimmedFeedback,
            if (trimmedAiDraft != null) 'aiFeedbackDraft': trimmedAiDraft,
            if (trimmedAiDraft != null)
              'aiFeedbackEdited': trimmedAiDraft != trimmedFeedback,
            if (resolvedRubricId.isNotEmpty) 'rubricId': resolvedRubricId,
            if (resolvedRubricTitle != null && resolvedRubricTitle.isNotEmpty)
              'rubricTitle': resolvedRubricTitle,
            if (normalizedRubricScores.isNotEmpty)
              'rubricScores': normalizedRubricScores,
            if (normalizedRubricScores.isNotEmpty)
              'rubricTotalScore': rubricTotalScore,
            if (normalizedRubricScores.isNotEmpty)
              'rubricMaxScore': rubricMaxScore,
          });
        }
      }

      if (resolvedRubricId.isNotEmpty && normalizedRubricScores.isNotEmpty) {
        final DocumentReference<Map<String, dynamic>> rubricApplicationRef =
            _firestore
                .collection('rubricApplications')
                .doc(canonicalAttemptRef.id);
        batch.set(
            rubricApplicationRef,
            <String, dynamic>{
              'siteId': reviewSiteId,
              'missionAttemptId': canonicalAttemptRef.id,
              'submissionId': submissionId,
              'educatorId': reviewerId,
              'rubricId': resolvedRubricId,
              'scores': normalizedRubricScores,
              'overallNote': trimmedFeedback,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        final Map<String, List<Map<String, dynamic>>> rubricScoresByCapability =
            <String, List<Map<String, dynamic>>>{};
        for (final Map<String, dynamic> score in normalizedRubricScores) {
          final String capabilityId =
              (score['capabilityId'] as String? ?? '').trim();
          if (capabilityId.isEmpty) {
            continue;
          }
          rubricScoresByCapability.putIfAbsent(
            capabilityId,
            () => <Map<String, dynamic>>[],
          );
          rubricScoresByCapability[capabilityId]!.add(score);
        }

        QuerySnapshot<Map<String, dynamic>>? learnerEvidenceSnapshot;
        if (reviewLearnerId.isNotEmpty) {
          Query<Map<String, dynamic>> evidenceQuery = _firestore
              .collection('evidenceRecords')
              .where('learnerId', isEqualTo: reviewLearnerId)
              .limit(80);
          if (reviewSiteId != null && reviewSiteId.isNotEmpty) {
            evidenceQuery =
                evidenceQuery.where('siteId', isEqualTo: reviewSiteId);
          }
          learnerEvidenceSnapshot = await evidenceQuery.get();
        }

        for (final MapEntry<String, List<Map<String, dynamic>>> entry
            in rubricScoresByCapability.entries) {
          final String capabilityId = entry.key;
          final List<Map<String, dynamic>> capabilityScores = entry.value;
          final int capabilityRawScore = capabilityScores.fold<int>(
            0,
            (int total, Map<String, dynamic> score) =>
                total + ((score['score'] as num?)?.toInt() ?? 0),
          );
          final int capabilityMaxScore = capabilityScores.fold<int>(
            0,
            (int total, Map<String, dynamic> score) =>
                total + ((score['maxScore'] as num?)?.toInt() ?? 0),
          );
          final String pillarCode = capabilityScores
              .map((Map<String, dynamic> score) =>
                  (score['pillarCode'] as String? ?? '').trim())
              .firstWhere(
                (String value) => value.isNotEmpty,
                orElse: () => '',
              );
          final int nextLevel = capabilityMaxScore <= 0
              ? 0
              : math.max(
                  1,
                  math.min(
                    4,
                    ((capabilityRawScore / capabilityMaxScore) * 4).ceil(),
                  ),
                );
          final String masteryId = '${reviewLearnerId}_$capabilityId';
          final DocumentReference<Map<String, dynamic>> masteryRef =
              _firestore.collection('capabilityMastery').doc(masteryId);
          final DocumentSnapshot<Map<String, dynamic>> masterySnapshot =
              await masteryRef.get();
          final Map<String, dynamic> masteryData =
              masterySnapshot.data() ?? <String, dynamic>{};
          final int highestLevel = math.max(
            nextLevel,
            (masteryData['highestLevel'] as num?)?.toInt() ?? 0,
          );
          final List<String> priorEvidenceIds = List<String>.from(
            masteryData['evidenceIds'] as List? ?? const <String>[],
          );
          final List<String> mergedEvidenceIds = <String>{
            canonicalAttemptRef.id,
            ...priorEvidenceIds,
          }.toList(growable: false);

          batch.set(
            masteryRef,
            <String, dynamic>{
              'learnerId': reviewLearnerId,
              'capabilityId': capabilityId,
              if (reviewSiteId != null && reviewSiteId.isNotEmpty)
                'siteId': reviewSiteId,
              'pillarCode': pillarCode,
              'latestLevel': nextLevel,
              'highestLevel': highestLevel,
              'latestEvidenceId': canonicalAttemptRef.id,
              'latestMissionAttemptId': canonicalAttemptRef.id,
              'evidenceIds': mergedEvidenceIds,
              'createdAt':
                  masteryData['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          final DocumentReference<Map<String, dynamic>> growthEventRef =
              _firestore.collection('capabilityGrowthEvents').doc();
          batch.set(
            growthEventRef,
            <String, dynamic>{
              'learnerId': reviewLearnerId,
              'capabilityId': capabilityId,
              if (reviewSiteId != null && reviewSiteId.isNotEmpty)
                'siteId': reviewSiteId,
              'pillarCode': pillarCode,
              'level': nextLevel,
              'rawScore': capabilityRawScore,
              'maxScore': capabilityMaxScore,
              'evidenceId': canonicalAttemptRef.id,
              'missionAttemptId': canonicalAttemptRef.id,
              'rubricApplicationId': canonicalAttemptRef.id,
              'educatorId': reviewerId,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );

          final Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>
              matchingEvidenceDocs = (learnerEvidenceSnapshot?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            final String evidenceCapabilityId =
                (data['capabilityId'] as String? ?? '').trim();
            final String growthStatus =
                (data['growthStatus'] as String? ?? '').trim().toLowerCase();
            return evidenceCapabilityId == capabilityId &&
                (growthStatus.isEmpty ||
                    growthStatus == 'pending' ||
                    growthStatus == 'captured');
          });

          for (final QueryDocumentSnapshot<Map<String, dynamic>> evidenceDoc
              in matchingEvidenceDocs) {
            final Map<String, dynamic> evidenceData = evidenceDoc.data();
            batch.set(
              evidenceDoc.reference,
              <String, dynamic>{
                'rubricStatus': 'linked',
                'growthStatus': 'updated',
                'linkedMissionAttemptId': canonicalAttemptRef.id,
                'linkedRubricApplicationId': rubricApplicationRef.id,
                'latestGrowthEventId': growthEventRef.id,
                'latestCapabilityLevel': nextLevel,
                'growthUpdatedBy': reviewerId,
                'growthUpdatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );

            final bool portfolioCandidate =
                evidenceData['portfolioCandidate'] == true;
            if (!portfolioCandidate) {
              continue;
            }

            final String capabilityTitle = <String>[
              (evidenceData['capabilityLabel'] as String? ?? '').trim(),
              ...capabilityScores
                  .map((Map<String, dynamic> score) =>
                      (score['capabilityTitle'] as String? ?? '').trim())
                  .where((String value) => value.isNotEmpty),
            ].firstWhere(
              (String value) => value.isNotEmpty,
              orElse: () => capabilityId,
            );
            final String portfolioTitle = <String>[
              missionTitle,
              capabilityTitle,
            ].where((String value) => value.isNotEmpty).join(' • ');
            final String observationNote =
                (evidenceData['observationNote'] as String? ?? '').trim();
            final String portfolioDescription = <String>[
              observationNote,
              trimmedFeedback,
              submissionText,
            ].firstWhere(
              (String value) => value.isNotEmpty,
              orElse: () => 'Reviewed evidence linked to learner growth.',
            );
            final List<String> mergedArtifactUrls = <String>{
              ...submissionAttachmentUrls,
              ...List<String>.from(
                evidenceData['artifactUrls'] as List? ?? const <String>[],
              ),
            }.toList(growable: false);
            final List<String> mergedPillarCodes = <String>{
              pillarCode,
              (evidenceData['capabilityPillarCode'] as String? ?? '').trim(),
              (submissionData['pillarCode'] as String? ?? '').trim(),
            }.where((String value) => value.isNotEmpty).toList(growable: false);
            final String verificationPrompt =
                (evidenceData['nextVerificationPrompt'] as String? ?? '')
                    .trim();
            final bool hasExplainItBack =
              proofBundleSummary?['hasExplainItBack'] == true;
            final bool hasOralCheck =
              proofBundleSummary?['hasOralCheck'] == true;
            final bool hasMiniRebuild =
              proofBundleSummary?['hasMiniRebuild'] == true;
            final bool hasLearnerAiDisclosure =
              proofBundleSummary?['hasLearnerAiDisclosure'] == true;
            final bool aiAssistanceUsed =
              proofBundleSummary?['aiAssistanceUsed'] == true;
            final String proofOfLearningStatus =
              proofBundleSummary == null
                ? 'not-available'
                : hasExplainItBack && hasOralCheck && hasMiniRebuild
                  ? 'verified'
                  : hasExplainItBack || hasOralCheck || hasMiniRebuild
                    ? 'partial'
                    : 'missing';
            final String aiDisclosureStatus = hasLearnerAiDisclosure
              ? aiAssistanceUsed
                ? hasExplainItBack
                  ? 'learner-ai-verified'
                  : 'learner-ai-verification-gap'
                : 'learner-ai-not-used'
              : trimmedAiDraft != null
                ? 'educator-feedback-ai'
                : 'no-learner-ai-signal';
            final DocumentReference<Map<String, dynamic>> portfolioItemRef =
                _firestore.collection('portfolioItems').doc(evidenceDoc.id);
            batch.set(
              portfolioItemRef,
              <String, dynamic>{
                if (reviewSiteId != null && reviewSiteId.isNotEmpty)
                  'siteId': reviewSiteId,
                'learnerId': reviewLearnerId,
                'title': portfolioTitle.isNotEmpty
                    ? portfolioTitle
                    : 'Reviewed evidence artifact',
                'description': portfolioDescription,
                'artifactUrls': mergedArtifactUrls,
                'pillarCodes': mergedPillarCodes,
                'skillIds': const <String>[],
                'evidenceRecordIds': FieldValue.arrayUnion(<String>[
                  evidenceDoc.id,
                ]),
                'capabilityIds': FieldValue.arrayUnion(<String>[capabilityId]),
                'capabilityTitles': FieldValue.arrayUnion(<String>[
                  capabilityTitle,
                ]),
                'growthEventIds': FieldValue.arrayUnion(<String>[
                  growthEventRef.id,
                ]),
                'missionAttemptId': canonicalAttemptRef.id,
                'rubricApplicationId': rubricApplicationRef.id,
                if (proofBundleId != null) 'proofBundleId': proofBundleId,
                'proofOfLearningStatus': proofOfLearningStatus,
                if (hasLearnerAiDisclosure) 'aiAssistanceUsed': aiAssistanceUsed,
                if (proofBundleAiAssistanceDetails.isNotEmpty)
                  'aiAssistanceDetails': proofBundleAiAssistanceDetails,
                'aiDisclosureStatus': aiDisclosureStatus,
                'educatorId': reviewerId,
                if (verificationPrompt.isNotEmpty)
                  'verificationPrompt': verificationPrompt,
                'verificationStatus': 'reviewed',
                'source': 'educator_review_linkage',
                if (evidenceData['observedAt'] != null)
                  'createdAt': evidenceData['observedAt'],
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );

            batch.set(
              evidenceDoc.reference,
              <String, dynamic>{
                'portfolioStatus': 'linked',
                'linkedPortfolioItemId': portfolioItemRef.id,
              },
              SetOptions(merge: true),
            );
          }
        }
      }

      await batch.commit();

      // Update local state
      _pendingReviews = _pendingReviews
          .where((MissionSubmission s) => s.id != submissionId)
          .toList();
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

  Future<DocumentReference<Map<String, dynamic>>> _resolveReviewAttemptRef(
    String reviewRecordId,
  ) async {
    final DocumentReference<Map<String, dynamic>> sameIdAttemptRef =
        _firestore.collection('missionAttempts').doc(reviewRecordId);
    final DocumentSnapshot<Map<String, dynamic>> sameIdAttemptSnapshot =
        await sameIdAttemptRef.get();
    if (sameIdAttemptSnapshot.exists) {
      return sameIdAttemptRef;
    }

    final DocumentSnapshot<Map<String, dynamic>> submissionSnapshot =
        await _firestore
            .collection('missionSubmissions')
            .doc(reviewRecordId)
            .get();
    final Map<String, dynamic> submissionData =
        submissionSnapshot.data() ?? <String, dynamic>{};
    final String missionId = submissionData['missionId'] as String? ?? '';
    final String reviewLearnerId = submissionData['learnerId'] as String? ?? '';
    final String? reviewSiteId = submissionData['siteId'] as String?;

    if (missionId.isNotEmpty && reviewLearnerId.isNotEmpty) {
      final QuerySnapshot<Map<String, dynamic>> missionAttemptSnapshot =
          await _firestore
              .collection('missionAttempts')
              .where('learnerId', isEqualTo: reviewLearnerId)
              .where('missionId', isEqualTo: missionId)
              .get();
      final Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> candidates =
          missionAttemptSnapshot.docs.where((attemptDoc) {
        final Map<String, dynamic> data = attemptDoc.data();
        final String? attemptSiteId = data['siteId'] as String?;
        final String normalizedStatus = _normalizedReviewQueueStatus(
          status: data['status'] as String?,
          reviewStatus: data['reviewStatus'] as String?,
        );
        final bool siteMatches = reviewSiteId == null ||
            reviewSiteId.isEmpty ||
            attemptSiteId == reviewSiteId;
        return siteMatches && normalizedStatus == 'pending';
      });
      if (candidates.isNotEmpty) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            sortedCandidates = candidates.toList()
              ..sort((a, b) {
                final DateTime aSubmitted =
                    _parseTimestamp(a.data()['submittedAt']) ?? DateTime(1970);
                final DateTime bSubmitted =
                    _parseTimestamp(b.data()['submittedAt']) ?? DateTime(1970);
                return bSubmitted.compareTo(aSubmitted);
              });
        return sortedCandidates.first.reference;
      }
    }

    return sameIdAttemptRef;
  }
}

class _WorkedExamplePolicyOutcome {
  const _WorkedExamplePolicyOutcome({
    required this.fadeStage,
    required this.promptLevel,
    required this.successStreak,
    required this.action,
  });

  final int fadeStage;
  final WorkedExamplePromptLevel promptLevel;
  final int successStreak;
  final String action;
}

class _InterleavingRecommendation {
  const _InterleavingRecommendation({
    required this.missionIds,
    required this.confusabilityBand,
  });

  final List<String> missionIds;
  final String confusabilityBand;
}

class _MissionConfusabilityProfile {
  const _MissionConfusabilityProfile({
    required this.skillIds,
    required this.pillarCodes,
    required this.misconceptionTags,
  });

  factory _MissionConfusabilityProfile.empty(Set<String> skillIds) {
    return _MissionConfusabilityProfile(
      skillIds: skillIds,
      pillarCodes: <String>{},
      misconceptionTags: <String>{},
    );
  }

  final Set<String> skillIds;
  final Set<String> pillarCodes;
  final Set<String> misconceptionTags;
}

/// Mission submission model for educator review
class MissionSubmission {
  final String id;
  final String missionId;
  final String missionTitle;
  final String learnerId;
  final String learnerName;
  final String? learnerPhotoUrl;
  final String? siteId;
  final String pillar;
  final DateTime submittedAt;
  final String status;
  final String? submissionText;
  final List<String> attachmentUrls;
  final int? rating;
  final String? feedback;
  final String? aiFeedbackDraft;
  final String? rubricId;
  final String? rubricTitle;
  final List<Map<String, dynamic>> rubricCriteria;
  final List<Map<String, dynamic>> rubricScores;

  const MissionSubmission({
    required this.id,
    required this.missionId,
    required this.missionTitle,
    required this.learnerId,
    required this.learnerName,
    this.learnerPhotoUrl,
    this.siteId,
    required this.pillar,
    required this.submittedAt,
    required this.status,
    this.submissionText,
    this.attachmentUrls = const <String>[],
    this.rating,
    this.feedback,
    this.aiFeedbackDraft,
    this.rubricId,
    this.rubricTitle,
    this.rubricCriteria = const <Map<String, dynamic>>[],
    this.rubricScores = const <Map<String, dynamic>>[],
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

  bool get hasRubric =>
      rubricId?.isNotEmpty == true || rubricCriteria.isNotEmpty;
}
