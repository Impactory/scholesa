import '../auth/app_state.dart';
import '../domain/models.dart';
import 'federated_learning_runtime_activation_reporter.dart';
import 'workflow_bridge_service.dart';

class FederatedLearningRuntimePackageResolver {
  FederatedLearningRuntimePackageResolver({
    required AppState appState,
    WorkflowBridgeService? workflowBridge,
    FederatedLearningRuntimeActivationReporter? activationReporter,
  })  : _appState = appState,
        _workflowBridge = workflowBridge ?? WorkflowBridgeService.instance,
        _activationReporter = activationReporter;

  static const Duration _cacheTtl = Duration(minutes: 5);

  final AppState _appState;
  final WorkflowBridgeService _workflowBridge;
  final FederatedLearningRuntimeActivationReporter? _activationReporter;
  final Map<String, _CachedRuntimePackage> _cache =
      <String, _CachedRuntimePackage>{};
  final Set<String> _reportedActivationKeys = <String>{};

  Future<FederatedLearningResolvedRuntimePackageModel?> resolveActivePackage({
    String? siteId,
    String? experimentId,
    String? runtimeTarget,
  }) async {
    final String resolvedSiteId = _resolveSiteId(siteId);
    final String cacheKey =
        '$resolvedSiteId::${(experimentId ?? '').trim()}::${(runtimeTarget ?? '').trim()}';
    final _CachedRuntimePackage? cached = _cache[cacheKey];
    final DateTime now = DateTime.now().toUtc();
    if (cached != null && now.difference(cached.loadedAt) < _cacheTtl) {
      return cached.package;
    }

    final Map<String, dynamic>? row =
        await _workflowBridge.resolveSiteFederatedLearningRuntimePackage(
      siteId: resolvedSiteId,
      experimentId: experimentId,
      runtimeTarget: runtimeTarget,
    );
    final FederatedLearningResolvedRuntimePackageModel? package = row == null
        ? null
        : FederatedLearningResolvedRuntimePackageModel.fromMap(row);
    _cache[cacheKey] = _CachedRuntimePackage(package: package, loadedAt: now);
    await _reportActivationIfNeeded(package);
    return package;
  }

  void resetForTesting() {
    _cache.clear();
    _reportedActivationKeys.clear();
  }

  Future<void> _reportActivationIfNeeded(
    FederatedLearningResolvedRuntimePackageModel? package,
  ) async {
    if (package == null || _activationReporter == null) {
      return;
    }
    final String activationKey =
        '${package.deliveryRecordId}::${package.siteId}::${package.runtimeVectorDigest}';
    if (_reportedActivationKeys.contains(activationKey)) {
      return;
    }
    await _activationReporter.reportLatestAssignmentActivation(
      siteId: package.siteId,
      experimentId: package.experimentId,
      runtimeTarget: package.runtimeTarget,
      status: 'resolved',
      traceId: package.runtimeVectorDigest,
      notes:
          'Resolved runtime package ${package.packageId} (${package.modelVersion}) for bounded device inference.',
    );
    _reportedActivationKeys.add(activationKey);
  }

  String _resolveSiteId(String? explicitSiteId) {
    final String resolved = (explicitSiteId ?? '').trim().isNotEmpty
        ? explicitSiteId!.trim()
        : ((_appState.activeSiteId ?? '').trim().isNotEmpty
            ? _appState.activeSiteId!.trim()
            : (_appState.siteIds.isNotEmpty ? _appState.siteIds.first : ''));
    if (resolved.isEmpty) {
      throw StateError(
          'No active site available for federated-learning runtime packages.');
    }
    return resolved;
  }
}

class _CachedRuntimePackage {
  const _CachedRuntimePackage({required this.package, required this.loadedAt});

  final FederatedLearningResolvedRuntimePackageModel? package;
  final DateTime loadedAt;
}