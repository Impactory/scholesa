import '../auth/app_state.dart';
import '../domain/models.dart';
import 'workflow_bridge_service.dart';

class FederatedLearningRuntimeDeliveryResolver {
  FederatedLearningRuntimeDeliveryResolver({
    required AppState appState,
    WorkflowBridgeService? workflowBridge,
  })  : _appState = appState,
        _workflowBridge = workflowBridge ?? WorkflowBridgeService.instance;

  final AppState _appState;
  final WorkflowBridgeService _workflowBridge;

  Future<List<FederatedLearningRuntimeDeliveryRecordModel>> listAssignments({
    String? siteId,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    final List<Map<String, dynamic>> rows =
        await _workflowBridge.listSiteFederatedLearningRuntimeDeliveryRecords(
      siteId: resolvedSiteId,
    );
    return rows
        .map((Map<String, dynamic> row) =>
            FederatedLearningRuntimeDeliveryRecordModel.fromMap(
              (row['id'] as String?) ?? 'runtime_delivery_record',
              row,
            ))
        .where((FederatedLearningRuntimeDeliveryRecordModel model) =>
            model.targetSiteIds.contains(resolvedSiteId) &&
            (model.status == 'assigned' || model.status == 'active'))
        .toList(growable: false);
  }

  Future<FederatedLearningRuntimeDeliveryRecordModel?> resolveLatestAssignment({
    String? siteId,
    String? experimentId,
    String? runtimeTarget,
  }) async {
    final List<FederatedLearningRuntimeDeliveryRecordModel> assignments =
        await listAssignments(siteId: siteId);
    final Iterable<FederatedLearningRuntimeDeliveryRecordModel> filtered =
        assignments.where((FederatedLearningRuntimeDeliveryRecordModel model) {
      final bool matchesExperiment = (experimentId ?? '').trim().isEmpty ||
          model.experimentId == experimentId!.trim();
      final bool matchesRuntimeTarget = (runtimeTarget ?? '').trim().isEmpty ||
          model.runtimeTarget == runtimeTarget!.trim();
      return matchesExperiment && matchesRuntimeTarget;
    });
    if (filtered.isEmpty) {
      return null;
    }
    final List<FederatedLearningRuntimeDeliveryRecordModel> sorted =
        filtered.toList(growable: false)
          ..sort((a, b) {
            final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
    return sorted.first;
  }

  String _resolveSiteId(String? explicitSiteId) {
    final String resolved = (explicitSiteId ?? '').trim().isNotEmpty
        ? explicitSiteId!.trim()
        : ((_appState.activeSiteId ?? '').trim().isNotEmpty
            ? _appState.activeSiteId!.trim()
            : (_appState.siteIds.isNotEmpty ? _appState.siteIds.first : ''));
    if (resolved.isEmpty) {
      throw StateError(
          'No active site available for federated-learning runtime delivery.');
    }
    return resolved;
  }
}