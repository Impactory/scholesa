import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models.dart';
import '../domain/repositories.dart';
import 'telemetry_service.dart';

/// The capability growth engine connects rubric applications to capability
/// mastery updates, portfolio item enrichment, and next-step generation.
///
/// This is the "interpret" step of the evidence chain:
///   rubric applied → growth event created → mastery updated →
///   portfolio enriched → next steps generated
class CapabilityGrowthEngine {
  CapabilityGrowthEngine({
    CapabilityGrowthEventRepository? growthEventRepo,
    CapabilityMasteryRepository? masteryRepo,
    PortfolioItemRepository? portfolioItemRepo,
    EvidenceRecordRepository? evidenceRepo,
    LearnerNextStepRepository? nextStepRepo,
    CheckpointRepository? checkpointRepo,
    FirebaseFirestore? firestore,
  })  : _growthEventRepo =
            growthEventRepo ?? CapabilityGrowthEventRepository(),
        _masteryRepo = masteryRepo ?? CapabilityMasteryRepository(),
        _portfolioItemRepo = portfolioItemRepo ?? PortfolioItemRepository(),
        _evidenceRepo = evidenceRepo ?? EvidenceRecordRepository(),
        _nextStepRepo = nextStepRepo ?? LearnerNextStepRepository(),
        _checkpointRepo = checkpointRepo ?? CheckpointRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final CapabilityGrowthEventRepository _growthEventRepo;
  final CapabilityMasteryRepository _masteryRepo;
  final PortfolioItemRepository _portfolioItemRepo;
  final EvidenceRecordRepository _evidenceRepo;
  final LearnerNextStepRepository _nextStepRepo;
  final CheckpointRepository _checkpointRepo;
  final FirebaseFirestore _firestore;

  /// Process a rubric application and propagate through the evidence chain.
  ///
  /// This is the critical path: rubric → growth event → mastery → portfolio.
  Future<CapabilityGrowthResult> processRubricApplication({
    required RubricApplicationModel rubricApplication,
    required String learnerId,
    required String siteId,
    required String capabilityId,
    required String pillarCode,
    String? capabilityTitle,
    List<String> progressionDescriptors = const <String>[],
    List<Map<String, dynamic>> checkpointMappings = const [],
    String? educatorId,
    String? missionAttemptId,
    String? evidenceRecordId,
    String? portfolioItemId,
  }) async {
    final int rawScore = _computeRawScore(rubricApplication.scores);
    final int maxScore = _computeMaxScore(rubricApplication.scores);
    final int level = _deriveLevel(rawScore, maxScore);

    // 1. Create growth event
    final String growthEventId =
        '${capabilityId}_${learnerId}_${Timestamp.now().millisecondsSinceEpoch}';
    final growthEvent = CapabilityGrowthEventModel(
      id: growthEventId,
      learnerId: learnerId,
      capabilityId: capabilityId,
      pillarCode: pillarCode,
      level: level,
      rawScore: rawScore,
      maxScore: maxScore,
      capabilityTitle: capabilityTitle,
      siteId: siteId,
      evidenceId: evidenceRecordId,
      missionAttemptId: missionAttemptId,
      rubricApplicationId: rubricApplication.id,
      educatorId: educatorId,
      progressionDescriptors: progressionDescriptors,
      checkpointMappings: checkpointMappings,
      createdAt: Timestamp.now(),
    );
    await _growthEventRepo.upsert(growthEvent);

    // 2. Update capability mastery
    final existingMasteries = await _masteryRepo.listByLearner(learnerId);
    final existing = existingMasteries
        .where((m) => m.capabilityId == capabilityId)
        .toList();

    final List<String> evidenceIds;
    final int highestLevel;
    if (existing.isNotEmpty) {
      final current = existing.first;
      evidenceIds = <String>[
        ...current.evidenceIds,
        if (evidenceRecordId != null) evidenceRecordId,
      ];
      highestLevel =
          level > current.highestLevel ? level : current.highestLevel;
    } else {
      evidenceIds = <String>[
        if (evidenceRecordId != null) evidenceRecordId,
      ];
      highestLevel = level;
    }

    final masteryId = existing.isNotEmpty
        ? existing.first.id
        : '${capabilityId}_$learnerId';
    final mastery = CapabilityMasteryModel(
      id: masteryId,
      learnerId: learnerId,
      capabilityId: capabilityId,
      pillarCode: pillarCode,
      latestLevel: level,
      highestLevel: highestLevel,
      capabilityTitle: capabilityTitle,
      siteId: siteId,
      latestEvidenceId: evidenceRecordId,
      latestMissionAttemptId: missionAttemptId,
      evidenceIds: evidenceIds,
      createdAt: existing.isNotEmpty ? existing.first.createdAt : null,
      updatedAt: Timestamp.now(),
    );
    await _masteryRepo.upsert(mastery);

    // 3. Enrich portfolio item if provided
    if (portfolioItemId != null && portfolioItemId.isNotEmpty) {
      await _enrichPortfolioItem(
        portfolioItemId: portfolioItemId,
        growthEventId: growthEventId,
        capabilityId: capabilityId,
        capabilityTitle: capabilityTitle,
        rubricApplicationId: rubricApplication.id,
        level: level,
        progressionDescriptors: progressionDescriptors,
        checkpointMappings: checkpointMappings,
      );
    }

    // 4. Generate next steps
    await _generateNextSteps(
      learnerId: learnerId,
      siteId: siteId,
      capabilityId: capabilityId,
      pillarCode: pillarCode,
      currentLevel: level,
      capabilityTitle: capabilityTitle,
    );

    // 5. Telemetry
    try {
      await TelemetryService.instance.logEvent(
        event: 'capability.growth.processed',
        role: 'educator',
        siteId: siteId,
        metadata: <String, dynamic>{
          'capabilityId': capabilityId,
          'learnerId': learnerId,
          'level': level,
          'rawScore': rawScore,
          'maxScore': maxScore,
          'rubricApplicationId': rubricApplication.id,
          'hasPortfolioItem': portfolioItemId != null,
          'hasEvidence': evidenceRecordId != null,
        },
      );
    } catch (_) {}

    return CapabilityGrowthResult(
      growthEventId: growthEventId,
      masteryId: masteryId,
      level: level,
      rawScore: rawScore,
      maxScore: maxScore,
    );
  }

  /// Create an evidence record and optionally trigger growth processing.
  Future<String> captureEvidence({
    required String siteId,
    required String learnerId,
    required String evidenceType,
    String? title,
    String? description,
    List<String> artifactUrls = const [],
    String? sessionOccurrenceId,
    String? missionAttemptId,
    String? capabilityId,
    String? pillarCode,
    String? observationId,
    String? reflectionId,
    String? proofBundleId,
    String? educatorId,
    bool aiAssistanceUsed = false,
    String? aiDisclosureNote,
  }) async {
    final docRef = _firestore.collection('evidenceRecords').doc();
    final record = EvidenceRecordModel(
      id: docRef.id,
      siteId: siteId,
      learnerId: learnerId,
      evidenceType: evidenceType,
      title: title,
      description: description,
      artifactUrls: artifactUrls,
      sessionOccurrenceId: sessionOccurrenceId,
      missionAttemptId: missionAttemptId,
      capabilityId: capabilityId,
      pillarCode: pillarCode,
      observationId: observationId,
      reflectionId: reflectionId,
      proofBundleId: proofBundleId,
      educatorId: educatorId,
      status: 'submitted',
      aiAssistanceUsed: aiAssistanceUsed,
      aiDisclosureNote: aiDisclosureNote,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await _evidenceRepo.upsert(record);

    try {
      await TelemetryService.instance.logEvent(
        event: 'evidence.captured',
        role: educatorId != null ? 'educator' : 'learner',
        siteId: siteId,
        metadata: <String, dynamic>{
          'evidenceType': evidenceType,
          'hasArtifacts': artifactUrls.isNotEmpty,
          'aiAssistanceUsed': aiAssistanceUsed,
          'hasCapability': capabilityId != null,
        },
      );
    } catch (_) {}

    return docRef.id;
  }

  Future<void> _enrichPortfolioItem({
    required String portfolioItemId,
    required String growthEventId,
    required String capabilityId,
    String? capabilityTitle,
    required String rubricApplicationId,
    required int level,
    List<String> progressionDescriptors = const [],
    List<Map<String, dynamic>> checkpointMappings = const [],
  }) async {
    final existing = await _portfolioItemRepo.getById(portfolioItemId);
    if (existing == null) return;

    final updatedGrowthIds = <String>[
      ...existing.growthEventIds,
      growthEventId,
    ];
    final updatedCapIds = <String>{
      ...existing.capabilityIds,
      capabilityId,
    }.toList();
    final updatedCapTitles = <String>{
      ...existing.capabilityTitles,
      if (capabilityTitle != null) capabilityTitle,
    }.toList();

    await _portfolioItemRepo.patch(portfolioItemId, <String, dynamic>{
      'growthEventIds': updatedGrowthIds,
      'capabilityIds': updatedCapIds,
      'capabilityTitles': updatedCapTitles,
      'rubricApplicationId': rubricApplicationId,
      'progressionDescriptors': progressionDescriptors,
      'checkpointMappings': checkpointMappings,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> _generateNextSteps({
    required String learnerId,
    required String siteId,
    required String capabilityId,
    required String pillarCode,
    required int currentLevel,
    String? capabilityTitle,
  }) async {
    final targetLevel = currentLevel + 1;

    // Check for checkpoints at the next level
    final checkpoints =
        await _checkpointRepo.listByCapability(capabilityId);
    final nextCheckpoint = checkpoints
        .where((c) => c.order >= targetLevel)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final stepId = '${capabilityId}_${learnerId}_next_$targetLevel';
    final step = LearnerNextStepModel(
      id: stepId,
      siteId: siteId,
      learnerId: learnerId,
      capabilityId: capabilityId,
      pillarCode: pillarCode,
      stepType: 'capability_next_level',
      title:
          'Reach level $targetLevel in ${capabilityTitle ?? capabilityId}',
      description: nextCheckpoint.isNotEmpty
          ? nextCheckpoint.first.guidance
          : null,
      currentLevel: currentLevel,
      targetLevel: targetLevel,
      requiredEvidenceTypes: nextCheckpoint.isNotEmpty
          ? nextCheckpoint.first.requiredEvidenceTypes
          : const <String>[],
      checkpointId:
          nextCheckpoint.isNotEmpty ? nextCheckpoint.first.id : null,
      generatedBy: 'system',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await _nextStepRepo.upsert(step);
  }

  int _computeRawScore(List<Map<String, dynamic>> scores) {
    int total = 0;
    for (final score in scores) {
      final value = score['score'] ?? score['value'] ?? score['points'];
      if (value is num) {
        total += value.toInt();
      }
    }
    return total;
  }

  int _computeMaxScore(List<Map<String, dynamic>> scores) {
    int total = 0;
    for (final score in scores) {
      final value =
          score['maxScore'] ?? score['maxValue'] ?? score['maxPoints'];
      if (value is num) {
        total += value.toInt();
      } else {
        // Default assumption: 4-point scale per criterion
        total += 4;
      }
    }
    return total;
  }

  /// Derive a 1-5 capability level from raw/max score ratio.
  int _deriveLevel(int rawScore, int maxScore) {
    if (maxScore <= 0) return 1;
    final ratio = rawScore / maxScore;
    if (ratio >= 0.90) return 5;
    if (ratio >= 0.75) return 4;
    if (ratio >= 0.55) return 3;
    if (ratio >= 0.35) return 2;
    return 1;
  }
}

class CapabilityGrowthResult {
  const CapabilityGrowthResult({
    required this.growthEventId,
    required this.masteryId,
    required this.level,
    required this.rawScore,
    required this.maxScore,
  });

  final String growthEventId;
  final String masteryId;
  final int level;
  final int rawScore;
  final int maxScore;
}
