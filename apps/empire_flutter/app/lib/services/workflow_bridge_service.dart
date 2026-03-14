import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper around workflow-related callable functions.
class WorkflowBridgeService {
  WorkflowBridgeService({FirebaseFunctions? functions})
      : _functions = functions;

  static WorkflowBridgeService? _instance;
  static WorkflowBridgeService get instance =>
      _instance ??= WorkflowBridgeService();

  FirebaseFunctions? _functions;

  Future<List<Map<String, dynamic>>> listCohortLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    final Map<String, dynamic> payload =
        await _call('listCohortLaunches', <String, dynamic>{
      if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
      'limit': limit,
    });
    return _asMapList(payload['launches']);
  }

  Future<String?> upsertCohortLaunch(Map<String, dynamic> data) async {
    final Map<String, dynamic> payload =
        await _call('upsertCohortLaunch', data);
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listPartnerLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    final Map<String, dynamic> payload =
        await _call('listPartnerLaunches', <String, dynamic>{
      if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
      'limit': limit,
    });
    return _asMapList(payload['launches']);
  }

  Future<String?> upsertPartnerLaunch(Map<String, dynamic> data) async {
    final Map<String, dynamic> payload =
        await _call('upsertPartnerLaunch', data);
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listKpiPacks({
    String? siteId,
    int limit = 40,
  }) async {
    final Map<String, dynamic> payload =
        await _call('listKpiPacks', <String, dynamic>{
      if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
      'limit': limit,
    });
    return _asMapList(payload['packs']);
  }

  Future<String?> generateKpiPack({
    required String period,
    String? siteId,
  }) async {
    final Map<String, dynamic> payload =
        await _call('generateKpiPack', <String, dynamic>{
      if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
      'period': period.trim().isEmpty ? 'month' : period.trim(),
    });
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listRedTeamReviews({
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload =
        await _call('listRedTeamReviews', <String, dynamic>{'limit': limit});
    return _asMapList(payload['reviews']);
  }

  Future<String?> upsertRedTeamReview(Map<String, dynamic> data) async {
    final Map<String, dynamic> payload =
        await _call('upsertRedTeamReview', data);
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listTrainingCycles({
    String? siteId,
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload =
        await _call('listTrainingCycles', <String, dynamic>{
      if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
      'limit': limit,
    });
    return _asMapList(payload['cycles']);
  }

  Future<String?> upsertTrainingCycle(Map<String, dynamic> data) async {
    final Map<String, dynamic> payload =
        await _call('upsertTrainingCycle', data);
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listFeatureFlags({
    int limit = 300,
  }) async {
    final Map<String, dynamic> payload =
        await _call('listFeatureFlags', <String, dynamic>{'limit': limit});
    return _asMapList(payload['flags']);
  }

  Future<String?> upsertFeatureFlag(Map<String, dynamic> data) async {
    final Map<String, dynamic> payload = await _call('upsertFeatureFlag', data);
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningExperiments({
    int limit = 120,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningExperiments',
      <String, dynamic>{'limit': limit},
    );
    return _asMapList(payload['experiments']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningExperimentReviewRecords({
    String? experimentId,
    int limit = 120,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningExperimentReviewRecords',
      <String, dynamic>{
        if ((experimentId ?? '').trim().isNotEmpty)
          'experimentId': experimentId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['records']);
  }

  Future<List<Map<String, dynamic>>> listSiteFederatedLearningExperiments({
    String? siteId,
    int limit = 40,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listSiteFederatedLearningExperiments',
      <String, dynamic>{
        if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['experiments']);
  }

  Future<String?> upsertFederatedLearningExperiment(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> payload =
        await _call('upsertFederatedLearningExperiment', data);
    return _asTrimmedString(payload['id']);
  }

  Future<String?> upsertFederatedLearningExperimentReviewRecord(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> payload = await _call(
      'upsertFederatedLearningExperimentReviewRecord',
      data,
    );
    return _asTrimmedString(payload['id']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningAggregationRuns({
    String? experimentId,
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningAggregationRuns',
      <String, dynamic>{
        if ((experimentId ?? '').trim().isNotEmpty)
          'experimentId': experimentId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['runs']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningMergeArtifacts({
    String? experimentId,
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningMergeArtifacts',
      <String, dynamic>{
        if ((experimentId ?? '').trim().isNotEmpty)
          'experimentId': experimentId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['artifacts']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningCandidateModelPackages({
    String? experimentId,
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningCandidateModelPackages',
      <String, dynamic>{
        if ((experimentId ?? '').trim().isNotEmpty)
          'experimentId': experimentId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['packages']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningCandidatePromotionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningCandidatePromotionRecords',
      <String, dynamic>{
        if ((experimentId ?? '').trim().isNotEmpty)
          'experimentId': experimentId!.trim(),
        if ((candidateModelPackageId ?? '').trim().isNotEmpty)
          'candidateModelPackageId': candidateModelPackageId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['records']);
  }

  Future<List<Map<String, dynamic>>> listFederatedLearningCandidatePromotionRevocationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    final Map<String, dynamic> payload = await _call(
      'listFederatedLearningCandidatePromotionRevocationRecords',
      <String, dynamic>{
        if ((experimentId ?? '').trim().isNotEmpty)
          'experimentId': experimentId!.trim(),
        if ((candidateModelPackageId ?? '').trim().isNotEmpty)
          'candidateModelPackageId': candidateModelPackageId!.trim(),
        'limit': limit,
      },
    );
    return _asMapList(payload['records']);
  }

  Future<String?> upsertFederatedLearningCandidatePromotionRecord(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> payload = await _call(
      'upsertFederatedLearningCandidatePromotionRecord',
      data,
    );
    return _asTrimmedString(payload['id']);
  }

  Future<String?> revokeFederatedLearningCandidatePromotionRecord(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> payload = await _call(
      'revokeFederatedLearningCandidatePromotionRecord',
      data,
    );
    return _asTrimmedString(payload['id']);
  }

  Future<String?> recordFederatedLearningPrototypeUpdate(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> payload =
        await _call('recordFederatedLearningPrototypeUpdate', data);
    return _asTrimmedString(payload['id']);
  }

  Future<Map<String, dynamic>> _call(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final HttpsCallable callable =
        _requiredFunctions.httpsCallable(callableName);
    final HttpsCallableResult<dynamic> result = await callable.call(payload);
    return asMap(result.data);
  }

  FirebaseFunctions get _requiredFunctions =>
      _functions ??= FirebaseFunctions.instance;

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic entryValue) =>
            MapEntry(key.toString(), entryValue),
      );
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }
    return value.map<Map<String, dynamic>>(asMap).toList(growable: false);
  }

  static String _asTrimmedString(dynamic value) {
    return value is String ? value.trim() : value?.toString().trim() ?? '';
  }

  static DateTime? toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is Map) {
      final Map<String, dynamic> data = asMap(value);
      final dynamic secondsRaw = data['seconds'] ?? data['_seconds'];
      final dynamic nanosRaw = data['nanoseconds'] ?? data['_nanoseconds'];
      final int? seconds =
          secondsRaw is int ? secondsRaw : int.tryParse('$secondsRaw');
      final int nanos =
          nanosRaw is int ? nanosRaw : int.tryParse('$nanosRaw') ?? 0;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanos ~/ 1000000),
        );
      }
    }
    if (value != null &&
        value is Object &&
        value.runtimeType.toString().contains('Timestamp') &&
        (value as dynamic).toDate is Function) {
      return (value as dynamic).toDate() as DateTime?;
    }
    return null;
  }
}
