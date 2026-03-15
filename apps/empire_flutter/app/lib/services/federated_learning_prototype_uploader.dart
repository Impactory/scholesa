import '../auth/app_state.dart';
import '../domain/models.dart';
import 'workflow_bridge_service.dart';

class FederatedLearningPrototypeUploader {
  FederatedLearningPrototypeUploader({
    required AppState appState,
    WorkflowBridgeService? workflowBridge,
  })  : _appState = appState,
        _workflowBridge = workflowBridge ?? WorkflowBridgeService.instance;

  final AppState _appState;
  final WorkflowBridgeService _workflowBridge;

  Future<List<FederatedLearningExperimentModel>> listAssignments({
    String? siteId,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    final List<Map<String, dynamic>> rows =
        await _workflowBridge.listSiteFederatedLearningExperiments(
      siteId: resolvedSiteId,
    );
    return rows
        .map((Map<String, dynamic> row) =>
            FederatedLearningExperimentModel.fromMap(
              (row['id'] as String?) ?? 'experiment',
              row,
            ))
        .where((FederatedLearningExperimentModel model) =>
            model.acceptsPrototypeUploads &&
            model.allowedSiteIds.contains(resolvedSiteId))
        .toList(growable: false);
  }

  Future<String?> uploadSummary({
    required FederatedLearningExperimentModel experiment,
    required String traceId,
    required String schemaVersion,
    required int sampleCount,
    required int vectorLength,
    required List<double> vectorSketch,
    required int payloadBytes,
    required double updateNorm,
    required String payloadDigest,
    String? optimizerStrategy,
    int? localEpochCount,
    int? localStepCount,
    int? trainingWindowSeconds,
    String? warmStartPackageId,
    String? warmStartDeliveryRecordId,
    String? warmStartModelVersion,
    String batteryState = 'unknown',
    String networkType = 'unknown',
    String? siteId,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    if (!experiment.allowedSiteIds.contains(resolvedSiteId)) {
      throw StateError(
        'Experiment ${experiment.id} is not enabled for site $resolvedSiteId.',
      );
    }
    if (!experiment.acceptsPrototypeUploads) {
      throw StateError(
        'Experiment ${experiment.id} is not accepting prototype uploads.',
      );
    }

    return _workflowBridge.recordFederatedLearningPrototypeUpdate(
      <String, dynamic>{
        'experimentId': experiment.id,
        'siteId': resolvedSiteId,
        'traceId': traceId.trim(),
        'schemaVersion': schemaVersion.trim(),
        'sampleCount': sampleCount,
        'vectorLength': vectorLength,
        'vectorSketch': vectorSketch,
        'payloadBytes': payloadBytes,
        'updateNorm': updateNorm,
        'payloadDigest': payloadDigest.trim(),
        'optimizerStrategy': (optimizerStrategy ?? '').trim(),
        'localEpochCount': localEpochCount,
        'localStepCount': localStepCount,
        'trainingWindowSeconds': trainingWindowSeconds,
        'warmStartPackageId': (warmStartPackageId ?? '').trim(),
        'warmStartDeliveryRecordId': (warmStartDeliveryRecordId ?? '').trim(),
        'warmStartModelVersion': (warmStartModelVersion ?? '').trim(),
        'batteryState': batteryState.trim(),
        'networkType': networkType.trim(),
      },
    );
  }

  String _resolveSiteId(String? explicitSiteId) {
    final String resolved = (explicitSiteId ?? '').trim().isNotEmpty
        ? explicitSiteId!.trim()
        : ((_appState.activeSiteId ?? '').trim().isNotEmpty
            ? _appState.activeSiteId!.trim()
            : (_appState.siteIds.isNotEmpty ? _appState.siteIds.first : ''));
    if (resolved.isEmpty) {
      throw StateError(
          'No active site available for federated-learning uploads.');
    }
    return resolved;
  }
}
