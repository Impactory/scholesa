import '../auth/app_state.dart';
import '../domain/models.dart';
import 'federated_learning_runtime_delivery_resolver.dart';
import 'workflow_bridge_service.dart';

class FederatedLearningRuntimeActivationReporter {
  FederatedLearningRuntimeActivationReporter({
    required AppState appState,
    FederatedLearningRuntimeDeliveryResolver? deliveryResolver,
    WorkflowBridgeService? workflowBridge,
  })  : _appState = appState,
        _deliveryResolver = deliveryResolver ??
            FederatedLearningRuntimeDeliveryResolver(
              appState: appState,
              workflowBridge: workflowBridge,
            ),
        _workflowBridge = workflowBridge ?? WorkflowBridgeService.instance;

  final AppState _appState;
  final FederatedLearningRuntimeDeliveryResolver _deliveryResolver;
  final WorkflowBridgeService _workflowBridge;

  Future<List<FederatedLearningRuntimeActivationRecordModel>> listReports({
    String? siteId,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    final List<Map<String, dynamic>> rows =
        await _workflowBridge.listSiteFederatedLearningRuntimeActivationRecords(
      siteId: resolvedSiteId,
    );
    final List<FederatedLearningRuntimeActivationRecordModel> records = rows
        .map((Map<String, dynamic> row) =>
            FederatedLearningRuntimeActivationRecordModel.fromMap(
              (row['id'] as String?) ?? 'runtime_activation_record',
              row,
            ))
        .where((FederatedLearningRuntimeActivationRecordModel model) =>
            model.siteId == resolvedSiteId)
        .toList(growable: false);
    records.sort((a, b) {
      final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });
    return records;
  }

  Future<String?> reportLatestAssignmentActivation({
    String? siteId,
    String? experimentId,
    String? runtimeTarget,
    required String status,
    String? traceId,
    String? notes,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    final FederatedLearningRuntimeDeliveryRecordModel? assignment =
        await _deliveryResolver.resolveLatestAssignment(
      siteId: resolvedSiteId,
      experimentId: experimentId,
      runtimeTarget: runtimeTarget,
    );
    if (assignment == null) {
      return null;
    }
    return reportDeliveryActivation(
      deliveryRecordId: assignment.id,
      siteId: resolvedSiteId,
      status: status,
      traceId: traceId,
      notes: notes,
    );
  }

  Future<String?> reportDeliveryActivation({
    required String deliveryRecordId,
    String? siteId,
    required String status,
    String? traceId,
    String? notes,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    return _workflowBridge.upsertFederatedLearningRuntimeActivationRecord(
      <String, dynamic>{
        'deliveryRecordId': deliveryRecordId.trim(),
        'siteId': resolvedSiteId,
        'status': status.trim(),
        if ((traceId ?? '').trim().isNotEmpty) 'traceId': traceId!.trim(),
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
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
          'No active site available for federated-learning runtime activation.');
    }
    return resolved;
  }
}