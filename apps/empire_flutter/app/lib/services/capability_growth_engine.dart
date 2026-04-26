import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/models.dart';
import '../domain/repositories.dart';
import 'telemetry_service.dart';

/// The capability growth engine connects rubric applications to capability
/// mastery updates through the server-owned growth callable.
///
/// This is the "interpret" step of the evidence chain:
///   rubric applied → server validation → growth event/mastery/portfolio update
class CapabilityGrowthEngine {
  CapabilityGrowthEngine({
    EvidenceRecordRepository? evidenceRepo,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _evidenceRepo = evidenceRepo ?? EvidenceRecordRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functionsOverride = functions;

  final EvidenceRecordRepository _evidenceRepo;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  /// Process a rubric application and propagate through the evidence chain.
  ///
  /// This is the critical path: rubric → Cloud Function validation →
  /// growth event → mastery → portfolio.
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
    final List<String> evidenceRecordIds = <String>[
      if (evidenceRecordId != null && evidenceRecordId.trim().isNotEmpty)
        evidenceRecordId.trim(),
    ];
    final String resolvedMissionAttemptId = _firstNonEmpty(
        <String?>[missionAttemptId, rubricApplication.missionAttemptId]);
    final String resolvedPortfolioItemId =
        _firstNonEmpty(<String?>[portfolioItemId]);
    if (evidenceRecordIds.isEmpty &&
        resolvedMissionAttemptId.isEmpty &&
        resolvedPortfolioItemId.isEmpty) {
      throw StateError(
        'Capability growth requires evidence, mission attempt, or portfolio item context.',
      );
    }

    final HttpsCallableResult<dynamic> callableResult = await _functions
        .httpsCallable('applyRubricToEvidence')
        .call(<String, dynamic>{
      'learnerId': learnerId,
      'siteId': siteId,
      'rubricId': rubricApplication.rubricId,
      'evidenceRecordIds': evidenceRecordIds,
      'scores': _rubricScoresForCallable(
        rubricApplication: rubricApplication,
        capabilityId: capabilityId,
        pillarCode: pillarCode,
        fallbackLevel: level,
      ),
      if (resolvedMissionAttemptId.isNotEmpty)
        'missionAttemptId': resolvedMissionAttemptId,
      if (resolvedPortfolioItemId.isNotEmpty)
        'portfolioItemId': resolvedPortfolioItemId,
    });

    final Map<dynamic, dynamic>? data =
        callableResult.data is Map<dynamic, dynamic>
            ? callableResult.data as Map<dynamic, dynamic>
            : null;
    final List<String> growthEventIds = _stringListFromDynamic(
      data?['growthEventIds'],
    );
    final String serverRubricApplicationId =
        data?['rubricApplicationId'] as String? ?? rubricApplication.id;

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
          'rubricApplicationId': serverRubricApplicationId,
          'hasPortfolioItem': portfolioItemId != null,
          'hasEvidence': evidenceRecordId != null,
          'serverRouted': true,
        },
      );
    } catch (_) {}

    return CapabilityGrowthResult(
      growthEventId: growthEventIds.isNotEmpty ? growthEventIds.first : '',
      masteryId: '${learnerId}_$capabilityId',
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

  List<Map<String, dynamic>> _rubricScoresForCallable({
    required RubricApplicationModel rubricApplication,
    required String capabilityId,
    required String pillarCode,
    required int fallbackLevel,
  }) {
    final List<Map<String, dynamic>> normalizedScores = rubricApplication.scores
        .where(
          (Map<String, dynamic> score) => _firstNonEmpty(
                  <String?>[score['capabilityId'] as String?, capabilityId])
              .isNotEmpty,
        )
        .map((Map<String, dynamic> score) => <String, dynamic>{
              'criterionId': _firstNonEmpty(<String?>[
                score['criterionId'] as String?,
                rubricApplication.id,
              ]),
              'capabilityId': _firstNonEmpty(<String?>[
                score['capabilityId'] as String?,
                capabilityId,
              ]),
              'pillarCode': _firstNonEmpty(<String?>[
                score['pillarCode'] as String?,
                pillarCode,
                'FUTURE_SKILLS',
              ]),
              'score': (score['score'] as num?)?.toInt() ?? fallbackLevel,
              'maxScore': (score['maxScore'] as num?)?.toInt() ?? 4,
              if (_firstNonEmpty(<String?>[score['processDomainId'] as String?])
                  .isNotEmpty)
                'processDomainId': score['processDomainId'],
            })
        .where((Map<String, dynamic> score) =>
            (score['score'] as int) >= 0 &&
            (score['maxScore'] as int) > 0 &&
            (score['score'] as int) <= (score['maxScore'] as int))
        .toList(growable: false);
    if (normalizedScores.isNotEmpty) {
      return normalizedScores;
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'criterionId': rubricApplication.id,
        'capabilityId': capabilityId,
        'pillarCode': pillarCode.isNotEmpty ? pillarCode : 'FUTURE_SKILLS',
        'score': fallbackLevel.clamp(1, 4),
        'maxScore': 4,
      },
    ];
  }

  List<String> _stringListFromDynamic(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
  }

  String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
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
