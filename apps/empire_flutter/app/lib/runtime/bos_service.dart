import 'package:cloud_functions/cloud_functions.dart';
import 'bos_models.dart';

Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  return value.map(
    (dynamic key, dynamic val) => MapEntry(key.toString(), val),
  );
}

// ──────────────────────────────────────────────────────
// BOS Service — Client-side callable wrapper
// Spec: BOS_MIA_HOW_TO_IMPLEMENT.md §1–§8
// ──────────────────────────────────────────────────────

/// Calls BOS Cloud Functions from the Flutter client.
class BosService {
  BosService._();
  static final BosService instance = BosService._();

  FirebaseFunctions? _functions;

  FirebaseFunctions get _fn {
    _functions ??= FirebaseFunctions.instance;
    return _functions!;
  }

  // ── Endpoint 1: Ingest BOS event ────────────────

  Future<void> ingestEvent(BosEvent event) async {
    await _fn.httpsCallable('bosIngestEvent').call(<String, dynamic>{
      'eventType': event.eventType,
      'siteId': event.siteId,
      'actorRole': event.actorRole,
      'gradeBand': event.gradeBand.code,
      if (event.sessionOccurrenceId != null)
        'sessionOccurrenceId': event.sessionOccurrenceId,
      if (event.missionId != null) 'missionId': event.missionId,
      if (event.checkpointId != null) 'checkpointId': event.checkpointId,
      'payload': <String, dynamic>{
        ...event.payload,
        'eventId': event.eventId,
        'schemaVersion': BosEvent.schemaVersion,
        'contextMode': event.contextMode.code,
        if (event.actorIdPseudo != null) 'actorIdPseudo': event.actorIdPseudo,
        if (event.assignmentId != null) 'assignmentId': event.assignmentId,
        if (event.lessonId != null) 'lessonId': event.lessonId,
      },
    });
  }

  // ── Endpoint 2: Get orchestration state ────────────

  Future<OrchestrationState?> getOrchestrationState({
    required String learnerId,
    required String sessionOccurrenceId,
  }) async {
    final HttpsCallableResult<dynamic> result = await _fn
        .httpsCallable('bosGetOrchestrationState')
        .call(<String, dynamic>{
      'learnerId': learnerId,
      'sessionOccurrenceId': sessionOccurrenceId,
    });

    final Map<String, dynamic>? response = _asStringDynamicMap(result.data);
    final Map<String, dynamic>? stateData =
      _asStringDynamicMap(response?['state']);
    if (stateData == null) return null;
    return OrchestrationState.tryFromMap(stateData);
  }

  // ── Endpoint 3: Get intervention (runs FDM + Estimator + Policy) ──

  Future<BosIntervention?> getIntervention({
    required String siteId,
    required String learnerId,
    required String sessionOccurrenceId,
    required GradeBand gradeBand,
  }) async {
    final HttpsCallableResult<dynamic> result =
        await _fn.httpsCallable('bosGetIntervention').call(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'sessionOccurrenceId': sessionOccurrenceId,
      'gradeBand': gradeBand.code,
    });

    final Map<String, dynamic>? response = _asStringDynamicMap(result.data);
    final Map<String, dynamic>? interventionData =
      _asStringDynamicMap(response?['intervention']);
    if (interventionData == null) return null;
    return BosIntervention.fromMap(interventionData);
  }

  // ── Endpoint 4: Score MVL episode ─────────────────

  Future<String> scoreMvl({required String episodeId}) async {
    final HttpsCallableResult<dynamic> result =
        await _fn.httpsCallable('bosScoreMvl').call(<String, dynamic>{
      'episodeId': episodeId,
    });
    final Map<String, dynamic>? response = _asStringDynamicMap(result.data);
    final String? resolution = response?['resolution'] as String?;
    if (resolution == null || resolution.trim().isEmpty) {
      throw const FormatException('Malformed MVL resolution payload.');
    }
    return resolution;
  }

  // ── Endpoint 5: Submit MVL evidence ───────────────

  Future<void> submitMvlEvidence({
    required String episodeId,
    required List<String> eventIds,
  }) async {
    await _fn.httpsCallable('bosSubmitMvlEvidence').call(<String, dynamic>{
      'episodeId': episodeId,
      'eventIds': eventIds,
    });
  }

  // ── Endpoint 6: Teacher override MVL ──────────────

  Future<void> teacherOverrideMvl({
    required String episodeId,
    required String resolution,
    String? reason,
  }) async {
    await _fn.httpsCallable('bosTeacherOverrideMvl').call(<String, dynamic>{
      'episodeId': episodeId,
      'resolution': resolution,
      if (reason != null) 'reason': reason,
    });
  }

  // ── Endpoint 7: Get class insights ────────────────

  Future<Map<String, dynamic>> getClassInsights({
    required String sessionOccurrenceId,
    required String siteId,
  }) async {
    final HttpsCallableResult<dynamic> result =
        await _fn.httpsCallable('bosGetClassInsights').call(<String, dynamic>{
      'sessionOccurrenceId': sessionOccurrenceId,
      'siteId': siteId,
    });
    return _asStringDynamicMap(result.data) ?? <String, dynamic>{};
  }

  // ── Endpoint 9: Get learner loop insights ───────

  Future<Map<String, dynamic>> getLearnerLoopInsights({
    required String siteId,
    required String learnerId,
    int lookbackDays = 30,
  }) async {
    final HttpsCallableResult<dynamic> result = await _fn
        .httpsCallable('bosGetLearnerLoopInsights')
        .call(<String, dynamic>{
      'siteId': siteId,
      'learnerId': learnerId,
      'lookbackDays': lookbackDays,
    });
    return _asStringDynamicMap(result.data) ?? <String, dynamic>{};
  }

  // ── Endpoint 8: Contestability ────────────────────

  Future<void> requestContestability({
    required String episodeId,
    String? reason,
  }) async {
    await _fn.httpsCallable('bosContestability').call(<String, dynamic>{
      'action': 'request',
      'episodeId': episodeId,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> resolveContestability({
    required String episodeId,
    required String resolution,
  }) async {
    await _fn.httpsCallable('bosContestability').call(<String, dynamic>{
      'action': 'resolve',
      'episodeId': episodeId,
      'resolution': resolution,
    });
  }

  // ── AI Coach (genAiCoach with BOS context) ────────

  Future<AiCoachResponse> callAiCoach(AiCoachRequest request) async {
    final HttpsCallableResult<dynamic> result =
        await _fn.httpsCallable('genAiCoach').call(request.toMap());
    final Map<String, dynamic>? response = _asStringDynamicMap(result.data);
    if (response == null) {
      throw const FormatException('Malformed AI coach payload.');
    }
    return AiCoachResponse.fromMap(response);
  }
}
