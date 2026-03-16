import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../services/workflow_bridge_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqFeatureFlags(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Feature Flags page for managing feature toggles
/// Based on docs/49_ROUTE_FLIP_TRACKER.md
class HqFeatureFlagsPage extends StatefulWidget {
  const HqFeatureFlagsPage({
    super.key,
    WorkflowBridgeService? workflowBridge,
    FederatedLearningUpdateSummaryRepository? updateSummaryRepository,
  })  : _workflowBridge = workflowBridge,
        _updateSummaryRepository = updateSummaryRepository;

  final WorkflowBridgeService? _workflowBridge;
  final FederatedLearningUpdateSummaryRepository? _updateSummaryRepository;

  @override
  State<HqFeatureFlagsPage> createState() => _HqFeatureFlagsPageState();
}

class _FeatureFlag {
  _FeatureFlag({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.scope,
    this.enabledSites,
  });

  final String id;
  final String name;
  final String description;
  bool isEnabled;
  final String scope; // 'global', 'site', 'user'
  final List<String>? enabledSites;
}

class _HqFeatureFlagsPageState extends State<HqFeatureFlagsPage> {
  List<_FeatureFlag> _flags = <_FeatureFlag>[];
  List<FederatedLearningExperimentModel> _experiments =
      <FederatedLearningExperimentModel>[];
  Map<String, List<FederatedLearningAggregationRunModel>>
      _aggregationRunsByExperiment =
      <String, List<FederatedLearningAggregationRunModel>>{};
  Map<String, List<FederatedLearningMergeArtifactModel>>
      _mergeArtifactsByExperiment =
      <String, List<FederatedLearningMergeArtifactModel>>{};
  Map<String, List<FederatedLearningCandidateModelPackageModel>>
      _candidatePackagesByExperiment =
      <String, List<FederatedLearningCandidateModelPackageModel>>{};
  Map<String, FederatedLearningExperimentReviewRecordModel>
      _experimentReviewRecordsByExperimentId =
      <String, FederatedLearningExperimentReviewRecordModel>{};
  Map<String, FederatedLearningPilotEvidenceRecordModel>
      _pilotEvidenceRecordsByPackageId =
      <String, FederatedLearningPilotEvidenceRecordModel>{};
  Map<String, FederatedLearningPilotApprovalRecordModel>
      _pilotApprovalRecordsByPackageId =
      <String, FederatedLearningPilotApprovalRecordModel>{};
  Map<String, FederatedLearningPilotExecutionRecordModel>
      _pilotExecutionRecordsByPackageId =
      <String, FederatedLearningPilotExecutionRecordModel>{};
  Map<String, FederatedLearningRuntimeDeliveryRecordModel>
      _runtimeDeliveryRecordsByPackageId =
      <String, FederatedLearningRuntimeDeliveryRecordModel>{};
  Map<String, List<FederatedLearningRuntimeActivationRecordModel>>
      _runtimeActivationRecordsByPackageId =
      <String, List<FederatedLearningRuntimeActivationRecordModel>>{};
  Map<String, FederatedLearningRuntimeRolloutAlertRecordModel>
      _runtimeRolloutAlertsByDeliveryId =
      <String, FederatedLearningRuntimeRolloutAlertRecordModel>{};
  Map<String, FederatedLearningRuntimeRolloutEscalationRecordModel>
      _runtimeRolloutEscalationsByDeliveryId =
      <String, FederatedLearningRuntimeRolloutEscalationRecordModel>{};
  Map<String, FederatedLearningRuntimeRolloutControlRecordModel>
      _runtimeRolloutControlsByDeliveryId =
      <String, FederatedLearningRuntimeRolloutControlRecordModel>{};
  Map<String, FederatedLearningCandidatePromotionRecordModel>
      _promotionRecordsByPackageId =
      <String, FederatedLearningCandidatePromotionRecordModel>{};
  Map<String, FederatedLearningCandidatePromotionRevocationRecordModel>
      _promotionRevocationRecordsByPackageId =
      <String, FederatedLearningCandidatePromotionRevocationRecordModel>{};
  Map<String, FederatedLearningUpdateSummaryModel> _updateSummariesById =
      <String, FederatedLearningUpdateSummaryModel>{};
  bool _isLoadingFlags = false;
  bool _isLoadingExperiments = false;

  WorkflowBridgeService get _workflowBridge =>
      widget._workflowBridge ?? WorkflowBridgeService.instance;
  FederatedLearningUpdateSummaryRepository get _updateSummaryRepository =>
      widget._updateSummaryRepository ??
      FederatedLearningUpdateSummaryRepository();

  Future<void> _showAcceptedSummaryDialog({
    required FederatedLearningExperimentModel experiment,
    required List<String> summaryIds,
    String title = 'Accepted summaries',
  }) async {
    final List<String> normalizedSummaryIds = summaryIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalizedSummaryIds.isEmpty) {
      return;
    }

    final List<FederatedLearningUpdateSummaryModel> summaries =
        await _updateSummaryRepository.listByIds(normalizedSummaryIds);
    final Map<String, FederatedLearningUpdateSummaryModel> summariesById =
        <String, FederatedLearningUpdateSummaryModel>{
      for (final FederatedLearningUpdateSummaryModel summary in summaries)
        summary.id: summary,
    };

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _tHqFeatureFlags(context, '$title: ${experiment.name}'),
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqFeatureFlags(
                      context,
                      'Requested summaries: ${normalizedSummaryIds.join(', ')}',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...normalizedSummaryIds.map((String summaryId) {
                    final FederatedLearningUpdateSummaryModel? summary =
                        summariesById[summaryId];
                    if (summary == null) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          _tHqFeatureFlags(
                            context,
                            'Summary $summaryId was referenced by provenance but is not available in the current bounded summary store.',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return _buildAcceptedSummaryEntry(summary);
                  }),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tHqFeatureFlags(context, 'Close')),
            ),
          ],
        );
      },
    );
  }

  String _formatContributionDetailPreview(
    List<FederatedLearningContributionDetailModel> details,
  ) {
    if (details.isEmpty) {
      return '';
    }
    return details
        .map(
          (FederatedLearningContributionDetailModel detail) =>
              '${detail.summaryId}/${detail.siteId} raw ${_formatMergeMetric(detail.rawWeight)} -> scaled ${_formatMergeMetric(detail.effectiveWeight)}',
        )
        .join(' | ');
  }

  String _formatContributionRollup(
    List<FederatedLearningContributionDetailModel> details, {
    required int summaryCount,
    required double? effectiveTotalWeight,
    required int fallbackRawTotalWeight,
  }) {
    final double rawTotalWeight = details.isEmpty
        ? fallbackRawTotalWeight.toDouble()
        : details.fold<double>(
            0,
            (double sum, FederatedLearningContributionDetailModel detail) =>
                sum + detail.rawWeight,
          );
    final double effectiveWeight = details.isEmpty
        ? (effectiveTotalWeight ?? rawTotalWeight)
        : details.fold<double>(
            0,
            (double sum, FederatedLearningContributionDetailModel detail) =>
                sum + detail.effectiveWeight,
          );
    final int dampedSummaryCount = details
        .where(
          (FederatedLearningContributionDetailModel detail) =>
              detail.normScale < 0.999999,
        )
        .length;
    return 'Damping: $dampedSummaryCount of $summaryCount summaries scaled · raw weight ${_formatMergeMetric(rawTotalWeight)} · effective weight ${_formatMergeMetric(effectiveWeight)}';
  }

  String _formatAggregationObservabilityRollup({
    required int summaryCount,
    required int? dampedSummaryCount,
    required double? rawTotalWeight,
    required double? effectiveTotalWeight,
    required double? minUpdateNorm,
    required double? maxUpdateNorm,
  }) {
    final int dampedCount = dampedSummaryCount ?? 0;
    final String normRange =
        minUpdateNorm == null && maxUpdateNorm == null
            ? 'n/a'
            : '${_formatMergeMetric(minUpdateNorm)}-${_formatMergeMetric(maxUpdateNorm)}';
    return 'Observability: $dampedCount of $summaryCount damped · raw weight ${_formatMergeMetric(rawTotalWeight)} · effective weight ${_formatMergeMetric(effectiveTotalWeight)} · norm range $normRange';
  }

  String _formatMergeStrategyLabel(
    String? mergeStrategy, {
    bool compact = false,
  }) {
    switch ((mergeStrategy ?? '').trim()) {
      case 'norm_capped_summary_balanced_runtime_vector_average_v1':
        return compact
            ? 'Summary-balanced merge'
            : 'Summary-balanced norm-capped average';
      case 'norm_capped_weighted_runtime_vector_average_v2':
      default:
        return compact
            ? 'Sample-weighted merge'
            : 'Sample-weighted norm-capped average';
    }
  }

  List<FederatedLearningUpdateSummaryModel> _summaryModelsForIds(
    List<String> summaryIds,
  ) {
    return summaryIds
        .map((String summaryId) => _updateSummariesById[summaryId.trim()])
        .whereType<FederatedLearningUpdateSummaryModel>()
        .toList(growable: false);
  }

  String _formatLocalTrainingRollup(List<String> summaryIds) {
    final List<FederatedLearningUpdateSummaryModel> summaries =
        _summaryModelsForIds(summaryIds).where((summary) {
      return (summary.optimizerStrategy ?? '').trim().isNotEmpty ||
          summary.localEpochCount != null ||
          summary.localStepCount != null ||
          summary.trainingWindowSeconds != null ||
          (summary.warmStartPackageId ?? '').trim().isNotEmpty;
    }).toList(growable: false);
    if (summaries.isEmpty) {
      return '';
    }

    final Set<String> optimizerStrategies = summaries
        .map((FederatedLearningUpdateSummaryModel summary) =>
            (summary.optimizerStrategy ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> warmStartPackageIds = summaries
        .map((FederatedLearningUpdateSummaryModel summary) =>
            (summary.warmStartPackageId ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final int totalEpochs = summaries.fold<int>(
      0,
      (int sum, FederatedLearningUpdateSummaryModel summary) =>
          sum + (summary.localEpochCount ?? 0),
    );
    final int totalSteps = summaries.fold<int>(
      0,
      (int sum, FederatedLearningUpdateSummaryModel summary) =>
          sum + (summary.localStepCount ?? 0),
    );
    final int totalWindowSeconds = summaries.fold<int>(
      0,
      (int sum, FederatedLearningUpdateSummaryModel summary) =>
          sum + (summary.trainingWindowSeconds ?? 0),
    );
    final String optimizerLabel = optimizerStrategies.isEmpty
        ? 'n/a'
        : optimizerStrategies.length == 1
            ? optimizerStrategies.first
            : 'mixed';
    final String warmStartLabel = warmStartPackageIds.isEmpty
        ? 'n/a'
        : warmStartPackageIds.length == 1
            ? warmStartPackageIds.first
            : 'mixed';

    return 'Local training rollup: $optimizerLabel · ${summaries.length} summaries · epochs $totalEpochs · steps $totalSteps · window ${totalWindowSeconds}s · warm start $warmStartLabel';
  }

  String _formatRuntimePayloadSummary(
    FederatedLearningCandidateModelPackageModel? package,
  ) {
    if (package == null) {
      return '';
    }
    return 'Runtime payload: model ${package.modelVersion} · vector ${package.runtimeVectorLength}/${package.maxVectorLength} · payload ${package.totalPayloadBytes} bytes · avg norm ${_formatMergeMetric(package.averageUpdateNorm)} · digest ${package.runtimeVectorDigest}';
  }

  String _formatCompatibilityRollup({
    required List<String> schemaVersions,
    required List<String> runtimeTargets,
    required List<String> optimizerStrategies,
    String? warmStartPackageId,
    String? warmStartModelVersion,
  }) {
    final String schemaLabel = schemaVersions.isEmpty
        ? 'n/a'
        : schemaVersions.length == 1
            ? schemaVersions.first
            : 'mixed';
    final String runtimeTargetLabel = runtimeTargets.isEmpty
        ? 'n/a'
        : runtimeTargets.length == 1
            ? runtimeTargets.first
            : 'mixed';
    final String optimizerLabel = optimizerStrategies.isEmpty
        ? 'n/a'
        : optimizerStrategies.length == 1
            ? optimizerStrategies.first
            : 'mixed';
    final String warmStartPackageLabel =
        (warmStartPackageId ?? '').trim().isEmpty
            ? 'n/a'
            : warmStartPackageId!.trim();
    final String warmStartModelLabel =
        (warmStartModelVersion ?? '').trim().isEmpty
            ? 'n/a'
            : warmStartModelVersion!.trim();
    return 'Compatibility batch: runtime $runtimeTargetLabel · schema $schemaLabel · optimizer $optimizerLabel · warm start $warmStartPackageLabel · model $warmStartModelLabel';
  }

  String _formatRuntimeDeliveryCompatibilityRollup(
    FederatedLearningRuntimeDeliveryRecordModel record,
    FederatedLearningCandidateModelPackageModel? package,
  ) {
    final List<String> schemaVersions = record.schemaVersions.isNotEmpty
        ? record.schemaVersions
        : (package?.schemaVersions ?? const <String>[]);
    final String recordRuntimeTarget = record.runtimeTarget.trim();
    final List<String> runtimeTargets = recordRuntimeTarget.isNotEmpty
        ? <String>[recordRuntimeTarget]
        : (package?.runtimeTargets ?? const <String>[]);
    final List<String> optimizerStrategies =
        record.optimizerStrategies.isNotEmpty
            ? record.optimizerStrategies
            : (package?.optimizerStrategies ?? const <String>[]);
    final String warmStartPackageId =
        (record.warmStartPackageId ?? '').trim().isNotEmpty
            ? record.warmStartPackageId!.trim()
            : (package?.warmStartPackageId ?? '');
    final String warmStartModelVersion =
        (record.warmStartModelVersion ?? '').trim().isNotEmpty
            ? record.warmStartModelVersion!.trim()
            : (package?.warmStartModelVersion ?? '');
    if (schemaVersions.isEmpty &&
        optimizerStrategies.isEmpty &&
        warmStartPackageId.isEmpty &&
        warmStartModelVersion.isEmpty) {
      return '';
    }
    return _formatCompatibilityRollup(
      schemaVersions: schemaVersions,
      runtimeTargets: runtimeTargets,
      optimizerStrategies: optimizerStrategies,
      warmStartPackageId: warmStartPackageId,
      warmStartModelVersion: warmStartModelVersion,
    );
  }

  String _formatRuntimeActivationCompatibilityRollup(
    FederatedLearningRuntimeActivationRecordModel record,
  ) {
    final List<String> runtimeTargets = record.runtimeTarget.trim().isNotEmpty
        ? <String>[record.runtimeTarget.trim()]
        : const <String>[];
    if (record.schemaVersions.isEmpty &&
        record.optimizerStrategies.isEmpty &&
        (record.warmStartPackageId ?? '').trim().isEmpty &&
        (record.warmStartModelVersion ?? '').trim().isEmpty) {
      return '';
    }
    return _formatCompatibilityRollup(
      schemaVersions: record.schemaVersions,
      runtimeTargets: runtimeTargets,
      optimizerStrategies: record.optimizerStrategies,
      warmStartPackageId: record.warmStartPackageId,
      warmStartModelVersion: record.warmStartModelVersion,
    );
  }

  String _formatRuntimeRolloutCompatibilityRollup({
    required String runtimeTarget,
    required List<String> schemaVersions,
    required List<String> optimizerStrategies,
    String? warmStartPackageId,
    String? warmStartModelVersion,
  }) {
    final List<String> runtimeTargets = runtimeTarget.trim().isNotEmpty
        ? <String>[runtimeTarget.trim()]
        : const <String>[];
    if (schemaVersions.isEmpty &&
        optimizerStrategies.isEmpty &&
        (warmStartPackageId ?? '').trim().isEmpty &&
        (warmStartModelVersion ?? '').trim().isEmpty) {
      return '';
    }
    return _formatCompatibilityRollup(
      schemaVersions: schemaVersions,
      runtimeTargets: runtimeTargets,
      optimizerStrategies: optimizerStrategies,
      warmStartPackageId: warmStartPackageId,
      warmStartModelVersion: warmStartModelVersion,
    );
  }

  String _formatRuntimeRolloutDigestRollup({
    required String packageDigest,
    required String boundedDigest,
    required String manifestDigest,
  }) {
    if (packageDigest.trim().isEmpty &&
        boundedDigest.trim().isEmpty &&
        manifestDigest.trim().isEmpty) {
      return '';
    }
    final String packageLabel =
        packageDigest.trim().isEmpty ? 'n/a' : packageDigest.trim();
    final String boundedLabel =
        boundedDigest.trim().isEmpty ? 'n/a' : boundedDigest.trim();
    final String manifestLabel =
        manifestDigest.trim().isEmpty ? 'n/a' : manifestDigest.trim();
    return 'Digests: package $packageLabel · bounded $boundedLabel · manifest $manifestLabel';
  }

  String _buildRuntimeRolloutBoundedDigestSuffix(String boundedDigest) {
    final String normalized = boundedDigest.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return ' · bounded $normalized';
  }

  Future<void> _showContributionDetailsDialog({
    required String experimentLabel,
    required List<FederatedLearningContributionDetailModel> details,
    String title = 'Contribution details',
  }) async {
    if (details.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _tHqFeatureFlags(dialogContext, '$title: $experimentLabel'),
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqFeatureFlags(
                      dialogContext,
                      'Contribution rows: ${details.length}',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...details.map(
                    (FederatedLearningContributionDetailModel detail) =>
                        Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tHqFeatureFlags(
                              dialogContext,
                              'Summary ${detail.summaryId} · site ${detail.siteId} · ${detail.sampleCount} samples',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tHqFeatureFlags(
                              dialogContext,
                              'Raw weight: ${_formatMergeMetric(detail.rawWeight)} · Norm scale: ${_formatMergeMetric(detail.normScale)} · Effective weight: ${_formatMergeMetric(detail.effectiveWeight)}',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: ScholesaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tHqFeatureFlags(
                              dialogContext,
                              'Norm: ${_formatMergeMetric(detail.updateNorm)} · Payload: ${detail.payloadBytes} bytes · Vector length: ${detail.vectorLength}',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: ScholesaColors.textSecondary,
                            ),
                          ),
                          if ((detail.traceId ?? '').trim().isNotEmpty ||
                              (detail.payloadDigest ?? '')
                                  .trim()
                                  .isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              _tHqFeatureFlags(
                                dialogContext,
                                'Trace: ${detail.traceId ?? ''} · Digest: ${detail.payloadDigest ?? ''}',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: ScholesaColors.textSecondary,
                              ),
                            ),
                          ],
                          if ((detail.runtimeTarget ?? '').trim().isNotEmpty ||
                              detail.schemaVersion
                                  .trim()
                                  .isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              _tHqFeatureFlags(
                                dialogContext,
                                'Runtime: ${detail.runtimeTarget ?? ''} · Schema: ${detail.schemaVersion}',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: ScholesaColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tHqFeatureFlags(dialogContext, 'Close')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAcceptedSummaryEntry(
    FederatedLearningUpdateSummaryModel summary,
  ) {
    final String createdLabel = _formatTimestamp(summary.createdAt);
    final String requestedBy = (summary.requestedBy ?? '').trim();
    final String status = (summary.status ?? '').trim();
    final String runtimeTarget = (summary.runtimeTarget ?? '').trim();
    final String optimizerStrategy = (summary.optimizerStrategy ?? '').trim();
    final String warmStartPackageId = (summary.warmStartPackageId ?? '').trim();
    final String warmStartDeliveryRecordId =
        (summary.warmStartDeliveryRecordId ?? '').trim();
    final String warmStartModelVersion =
        (summary.warmStartModelVersion ?? '').trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tHqFeatureFlags(
              context,
              'Summary ${summary.id} · site ${summary.siteId} · ${summary.sampleCount} samples',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _tHqFeatureFlags(context, 'Created: $createdLabel'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Trace: ${summary.traceId} · Digest: ${summary.payloadDigest}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Vector length: ${summary.vectorLength} · Payload bytes: ${summary.payloadBytes} · Update norm: ${_formatMergeMetric(summary.updateNorm)}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Battery: ${summary.batteryState} · Network: ${summary.networkType}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (optimizerStrategy.isNotEmpty ||
              summary.localEpochCount != null ||
              summary.localStepCount != null ||
              summary.trainingWindowSeconds != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Local training: ${optimizerStrategy.isNotEmpty ? optimizerStrategy : 'n/a'} · epochs ${summary.localEpochCount ?? 0} · steps ${summary.localStepCount ?? 0} · window ${summary.trainingWindowSeconds ?? 0}s',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (warmStartPackageId.isNotEmpty ||
              warmStartDeliveryRecordId.isNotEmpty ||
              warmStartModelVersion.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Warm start: package ${warmStartPackageId.isNotEmpty ? warmStartPackageId : 'n/a'} · delivery ${warmStartDeliveryRecordId.isNotEmpty ? warmStartDeliveryRecordId : 'n/a'} · model ${warmStartModelVersion.isNotEmpty ? warmStartModelVersion : 'n/a'}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (runtimeTarget.isNotEmpty ||
              requestedBy.isNotEmpty ||
              status.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Runtime target: ${runtimeTarget.isNotEmpty ? runtimeTarget : 'n/a'} · Requested by: ${requestedBy.isNotEmpty ? requestedBy : 'n/a'} · Status: ${status.isNotEmpty ? status : 'accepted'}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summarySearchTokens(List<String> summaryIds) {
    if (summaryIds.isEmpty) {
      return '';
    }
    return summaryIds
        .map((String summaryId) => _updateSummariesById[summaryId.trim()])
        .whereType<FederatedLearningUpdateSummaryModel>()
        .map((FederatedLearningUpdateSummaryModel summary) => <String>[
              summary.id,
              summary.siteId,
              summary.traceId,
              summary.payloadDigest,
              summary.optimizerStrategy ?? '',
              summary.warmStartPackageId ?? '',
              summary.warmStartDeliveryRecordId ?? '',
              summary.warmStartModelVersion ?? '',
              summary.localEpochCount?.toString() ?? '',
              summary.localStepCount?.toString() ?? '',
              summary.trainingWindowSeconds?.toString() ?? '',
              summary.networkType,
              summary.batteryState,
              summary.runtimeTarget ?? '',
            ].join(' '))
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqFeatureFlags(context, 'Feature Flags')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_feature_flags',
                  'cta_id': 'open_change_history',
                  'surface': 'appbar',
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(_tHqFeatureFlags(
                        context, 'Opening change history...'))),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildExperimentSection(),
          const SizedBox(height: 24),
          if (_isLoadingFlags)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqFeatureFlags(context, 'Loading...'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          if (!_isLoadingFlags && _flags.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqFeatureFlags(context, 'No feature flags found'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          if (_flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _tHqFeatureFlags(context, 'Feature flags'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ..._flags.map((flag) => _buildFlagCard(flag)),
        ],
      ),
    );
  }

  Widget _buildExperimentSection() {
    final List<FederatedLearningExperimentModel> sortedExperiments =
        List<FederatedLearningExperimentModel>.from(_experiments)
          ..sort(_compareExperimentPriority);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqFeatureFlags(context, 'Federated learning experiments'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tHqFeatureFlags(
                      context,
                      'Prototype cohorts stay site-scoped, bounded, and upload-only.',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _showCreateExperimentDialog,
              icon: const Icon(Icons.science_rounded),
              label: Text(_tHqFeatureFlags(context, 'Create experiment')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingExperiments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 3),
          )
        else if (_experiments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ScholesaColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              _tHqFeatureFlags(
                context,
                'No federated-learning experiments are configured yet.',
              ),
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
          )
        else
          ...sortedExperiments.map(_buildExperimentCard),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tHqFeatureFlags(context,
                  'Feature flags control which features are available to users. Changes take effect immediately.'),
              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagCard(_FeatureFlag flag) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            flag.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildScopeChip(flag.scope),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(context, flag.description),
                        style: const TextStyle(
                            fontSize: 13, color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: flag.isEnabled,
                  onChanged: (bool value) async {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'hq_feature_flags',
                        'cta_id': 'toggle_feature_flag',
                        'surface': 'flag_card',
                        'flag_id': flag.id,
                        'flag_name': flag.name,
                        'enabled': value,
                      },
                    );
                    await _toggleFlag(flag, value);
                  },
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
            if (flag.scope == 'site' && flag.enabledSites != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: flag.enabledSites!
                    .map((String site) => Chip(
                          label:
                              Text(site, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExperimentCard(FederatedLearningExperimentModel experiment) {
    final List<FederatedLearningAggregationRunModel> runs =
        _aggregationRunsByExperiment[experiment.id] ??
            const <FederatedLearningAggregationRunModel>[];
    final Map<String, FederatedLearningCandidateModelPackageModel>
        candidatePackagesByRunId = {
      for (final FederatedLearningCandidateModelPackageModel package
          in _candidatePackagesByExperiment[experiment.id] ??
              const <FederatedLearningCandidateModelPackageModel>[])
        package.aggregationRunId: package,
    };
    final FederatedLearningCandidateModelPackageModel? latestPackage =
        runs.isNotEmpty ? candidatePackagesByRunId[runs.first.id] : null;
    final FederatedLearningCandidatePromotionRecordModel? latestPromotion =
        latestPackage == null
            ? null
            : _promotionRecordsByPackageId[latestPackage.id];
    final FederatedLearningPilotEvidenceRecordModel? latestPilotEvidence =
        latestPackage == null
            ? null
            : _pilotEvidenceRecordsByPackageId[latestPackage.id];
    final FederatedLearningPilotApprovalRecordModel? latestPilotApproval =
        latestPackage == null
            ? null
            : _pilotApprovalRecordsByPackageId[latestPackage.id];
    final FederatedLearningPilotExecutionRecordModel? latestPilotExecution =
        latestPackage == null
            ? null
            : _pilotExecutionRecordsByPackageId[latestPackage.id];
    final FederatedLearningRuntimeDeliveryRecordModel? latestRuntimeDelivery =
        latestPackage == null
            ? null
            : _runtimeDeliveryRecordsByPackageId[latestPackage.id];
    final List<FederatedLearningRuntimeActivationRecordModel>
        runtimeActivationRecords = latestPackage == null
            ? const <FederatedLearningRuntimeActivationRecordModel>[]
            : (_runtimeActivationRecordsByPackageId[latestPackage.id] ??
                const <FederatedLearningRuntimeActivationRecordModel>[]);
    final FederatedLearningRuntimeActivationRecordModel?
        latestRuntimeActivation = runtimeActivationRecords.isEmpty
            ? null
            : runtimeActivationRecords.first;
    final FederatedLearningExperimentReviewRecordModel? reviewRecord =
        _experimentReviewRecordsByExperimentId[experiment.id];
    final FederatedLearningCandidatePromotionRevocationRecordModel?
        latestPromotionRevocation = latestPackage == null
            ? null
            : _promotionRevocationRecordsByPackageId[latestPackage.id];
    final FederatedLearningAggregationRunModel? latestRun =
        runs.isNotEmpty ? runs.first : null;
    final String latestAggregationTrainingRollup = latestRun == null
        ? ''
        : _formatLocalTrainingRollup(latestRun.summaryIds);
    final String latestPackageTrainingRollup = latestPackage == null
        ? ''
        : _formatLocalTrainingRollup(latestPackage.summaryIds);
    final String latestPackagePayloadSummary =
        _formatRuntimePayloadSummary(latestPackage);
    final String runtimeDeliveryLifecycle = latestRuntimeDelivery == null
        ? ''
        : _summarizeRuntimeDeliveryLifecycle(latestRuntimeDelivery);
    final _RuntimeRolloutHealthSummary? runtimeRolloutHealth =
        latestRuntimeDelivery == null
            ? null
            : _buildRuntimeRolloutHealthSummary(
                latestRuntimeDelivery,
                runtimeActivationRecords,
              );
    final FederatedLearningRuntimeRolloutAlertRecordModel?
        latestRuntimeRolloutAlert = latestRuntimeDelivery == null
            ? null
            : _runtimeRolloutAlertsByDeliveryId[latestRuntimeDelivery.id];
    final FederatedLearningRuntimeRolloutEscalationRecordModel?
        latestRuntimeRolloutEscalation = latestRuntimeDelivery == null
            ? null
            : _runtimeRolloutEscalationsByDeliveryId[latestRuntimeDelivery.id];
    final FederatedLearningRuntimeRolloutControlRecordModel?
        latestRuntimeRolloutControl = latestRuntimeDelivery == null
            ? null
            : _runtimeRolloutControlsByDeliveryId[latestRuntimeDelivery.id];
    final bool runtimeDeliveryTerminal = latestRuntimeDelivery != null &&
        _isRuntimeDeliveryTerminalLifecycle(latestRuntimeDelivery);
    final String runtimeRolloutAlert =
        runtimeRolloutHealth == null || runtimeDeliveryTerminal
            ? ''
            : _buildRuntimeRolloutAlert(
                runtimeRolloutHealth,
                latestRuntimeRolloutAlert,
              );
    final bool rolloutAlertAcknowledged = !runtimeDeliveryTerminal &&
        runtimeRolloutHealth != null &&
        _isRuntimeRolloutAlertAcknowledged(
          runtimeRolloutHealth,
          latestRuntimeRolloutAlert,
        );
    final Color rolloutAlertColor =
        rolloutAlertAcknowledged ? Colors.blueGrey : Colors.orange;
    final String rolloutAlertNotes =
        (latestRuntimeRolloutAlert?.notes ?? '').trim();
    final String rolloutAlertAcknowledgement = rolloutAlertAcknowledged &&
            latestRuntimeRolloutAlert != null
        ? 'Acknowledged ${_formatTimestamp(latestRuntimeRolloutAlert.acknowledgedAt)} by ${latestRuntimeRolloutAlert.acknowledgedBy ?? "hq"}'
        : '';
    final bool rolloutEscalationCurrent = !runtimeDeliveryTerminal &&
        runtimeRolloutHealth != null &&
        _isRuntimeRolloutEscalationCurrent(
          runtimeRolloutHealth,
          latestRuntimeRolloutEscalation,
        );
    final String rolloutEscalationSummary = rolloutEscalationCurrent
        ? _buildRuntimeRolloutEscalationSummary(latestRuntimeRolloutEscalation!)
        : '';
    final bool rolloutControlActive = latestRuntimeRolloutControl != null &&
        latestRuntimeRolloutControl.mode != 'monitor';
    final String rolloutControlSummary = rolloutControlActive
        ? _buildRuntimeRolloutControlSummary(latestRuntimeRolloutControl)
        : '';
    final String latestPromotionStatus = _effectivePromotionStatus(
      latestPromotion,
      latestPromotionRevocation,
    );
    final String latestPromotionTarget = _effectivePromotionTarget(
      latestPromotion,
      latestPromotionRevocation,
    );
    final Color statusColor = switch (experiment.status) {
      'active' => Colors.green,
      'pilot_ready' => Colors.blue,
      'paused' => Colors.orange,
      'disabled' => Colors.red,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        experiment.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((experiment.description ?? '')
                          .trim()
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          experiment.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showExperimentDialog(existing: experiment),
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(_tHqFeatureFlags(context, 'Edit')),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showAggregationHistoryDialog(experiment),
                        icon: const Icon(Icons.timeline_rounded),
                        label: Text(_tHqFeatureFlags(context, 'View history')),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showCandidatePackageHistoryDialog(experiment),
                        icon: const Icon(Icons.inventory_rounded),
                        label: Text(_tHqFeatureFlags(context, 'View packages')),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showExperimentReviewDialog(experiment),
                        icon: const Icon(Icons.fact_check_rounded),
                        label:
                            Text(_tHqFeatureFlags(context, 'Review checklist')),
                      ),
                      if (latestPackage != null)
                        TextButton.icon(
                          onPressed: () => _showPilotEvidenceDialog(
                            experiment: experiment,
                            candidatePackage: latestPackage,
                          ),
                          icon: const Icon(Icons.science_rounded),
                          label:
                              Text(_tHqFeatureFlags(context, 'Pilot evidence')),
                        ),
                      if (latestPackage != null)
                        TextButton.icon(
                          onPressed: () => _showPilotApprovalDialog(
                            experiment: experiment,
                            candidatePackage: latestPackage,
                          ),
                          icon: const Icon(Icons.verified_rounded),
                          label:
                              Text(_tHqFeatureFlags(context, 'Pilot approval')),
                        ),
                      if (latestPackage != null)
                        TextButton.icon(
                          onPressed: () => _showPilotExecutionDialog(
                            experiment: experiment,
                            candidatePackage: latestPackage,
                          ),
                          icon: const Icon(Icons.rocket_launch_rounded),
                          label: Text(
                              _tHqFeatureFlags(context, 'Pilot execution')),
                        ),
                      if (latestPackage != null)
                        TextButton.icon(
                          onPressed: () => _showRuntimeDeliveryDialog(
                            experiment: experiment,
                            candidatePackage: latestPackage,
                          ),
                          icon: const Icon(Icons.send_to_mobile_rounded),
                          label: Text(
                              _tHqFeatureFlags(context, 'Runtime delivery')),
                        ),
                      TextButton.icon(
                        onPressed: () => _showRuntimeDeliveryHistoryDialog(
                          experiment,
                        ),
                        icon: const Icon(Icons.history_toggle_off_rounded),
                        label:
                            Text(_tHqFeatureFlags(context, 'Delivery history')),
                      ),
                      if (latestRuntimeDelivery != null)
                        TextButton.icon(
                          onPressed: () => _showRuntimeRolloutHealthDialog(
                            experiment,
                            latestRuntimeDelivery,
                            runtimeActivationRecords,
                          ),
                          icon: const Icon(Icons.monitor_heart_rounded),
                          label:
                              Text(_tHqFeatureFlags(context, 'Site rollout')),
                        ),
                      if (latestRuntimeDelivery != null)
                        TextButton.icon(
                          onPressed: () =>
                              _showRuntimeRolloutAlertHistoryDialog(
                            experiment,
                          ),
                          icon: const Icon(Icons.notifications_active_rounded),
                          label:
                              Text(_tHqFeatureFlags(context, 'Alert history')),
                        ),
                      if (latestPackage != null)
                        TextButton.icon(
                          onPressed: () => _showRuntimeActivationHistoryDialog(
                            experiment,
                            latestPackage,
                            runtimeActivationRecords,
                          ),
                          icon: const Icon(Icons.fact_check_rounded),
                          label: Text(
                              _tHqFeatureFlags(context, 'Activation history')),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildExperimentChip(
                    experiment.runtimeTarget, Icons.phone_iphone_rounded),
                _buildExperimentChip(experiment.status, Icons.flag_rounded,
                    color: statusColor),
                _buildExperimentChip(
                  _formatMergeStrategyLabel(
                    experiment.mergeStrategy,
                    compact: true,
                  ),
                  Icons.balance_rounded,
                ),
                _buildExperimentChip(
                  '${experiment.aggregateThreshold} min cohort',
                  Icons.groups_rounded,
                ),
                _buildExperimentChip(
                  '${experiment.rawUpdateMaxBytes} byte cap',
                  Icons.data_object_rounded,
                ),
                _buildExperimentChip(
                  experiment.enablePrototypeUploads
                      ? 'Uploads enabled'
                      : 'Uploads disabled',
                  experiment.enablePrototypeUploads
                      ? Icons.cloud_upload_rounded
                      : Icons.cloud_off_rounded,
                  color: experiment.enablePrototypeUploads
                      ? Colors.green
                      : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _tHqFeatureFlags(
                context,
                'Enabled sites: ${experiment.allowedSiteIds.join(', ')}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if ((experiment.featureFlagId ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Flag: ${experiment.featureFlagId}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Configured merge policy: ${_formatMergeStrategyLabel(experiment.mergeStrategy)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if (latestRun != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Latest aggregation: ${latestRun.totalSampleCount} samples from ${latestRun.summaryCount} summaries across ${latestRun.distinctSiteCount} sites.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              if (latestRun.contributingSiteIds.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest aggregation contributors: ${_formatSiteList(latestRun.contributingSiteIds)}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              if (latestAggregationTrainingRollup.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest aggregation training: $latestAggregationTrainingRollup',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Latest aggregation compatibility: ${_formatCompatibilityRollup(
                    schemaVersions: latestRun.schemaVersions,
                    runtimeTargets: latestRun.runtimeTargets,
                    optimizerStrategies: latestRun.optimizerStrategies,
                    warmStartPackageId: latestRun.warmStartPackageId,
                    warmStartModelVersion: latestRun.warmStartModelVersion,
                  )}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              if (latestRun.contributionDetails.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest aggregation damping: ${_formatContributionRollup(
                      latestRun.contributionDetails,
                      summaryCount: latestRun.summaryCount,
                      effectiveTotalWeight: latestRun.effectiveTotalWeight,
                      fallbackRawTotalWeight: latestRun.totalSampleCount,
                    )}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              if (latestRun.rawTotalWeight != null ||
                  latestRun.minUpdateNorm != null ||
                  latestRun.maxUpdateNorm != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest aggregation observability: ${_formatAggregationObservabilityRollup(
                      summaryCount: latestRun.summaryCount,
                      dampedSummaryCount: latestRun.dampedSummaryCount,
                      rawTotalWeight: latestRun.rawTotalWeight,
                      effectiveTotalWeight: latestRun.effectiveTotalWeight,
                      minUpdateNorm: latestRun.minUpdateNorm,
                      maxUpdateNorm: latestRun.maxUpdateNorm,
                    )}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
            ],
            if (latestPackage != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Latest candidate package: ${latestPackage.id} (${latestPackage.packageFormat})',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Latest package rollout: ${latestPackage.rolloutStatus}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              if ((latestPackage.mergeStrategy ?? '')
                  .trim()
                  .isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest package merge: ${latestPackage.mergeStrategy} · norm cap ${_formatMergeMetric(latestPackage.normCap)} · effective weight ${_formatMergeMetric(latestPackage.effectiveTotalWeight)}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              if (latestPackagePayloadSummary.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest package payload: $latestPackagePayloadSummary',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              if (latestPackageTrainingRollup.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest package training: $latestPackageTrainingRollup',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Latest package compatibility: ${_formatCompatibilityRollup(
                    schemaVersions: latestPackage.schemaVersions,
                    runtimeTargets: latestPackage.runtimeTargets,
                    optimizerStrategies: latestPackage.optimizerStrategies,
                    warmStartPackageId: latestPackage.warmStartPackageId,
                    warmStartModelVersion: latestPackage.warmStartModelVersion,
                  )}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              if (latestPackage.contributionDetails.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest package damping: ${_formatContributionRollup(
                      latestPackage.contributionDetails,
                      summaryCount: latestPackage.summaryCount,
                      effectiveTotalWeight: latestPackage.effectiveTotalWeight,
                      fallbackRawTotalWeight: latestPackage.sampleCount,
                    )}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
              if (latestPackage.rawTotalWeight != null ||
                  latestPackage.minUpdateNorm != null ||
                  latestPackage.maxUpdateNorm != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _tHqFeatureFlags(
                    context,
                    'Latest package observability: ${_formatAggregationObservabilityRollup(
                      summaryCount: latestPackage.summaryCount,
                      dampedSummaryCount: latestPackage.dampedSummaryCount,
                      rawTotalWeight: latestPackage.rawTotalWeight,
                      effectiveTotalWeight: latestPackage.effectiveTotalWeight,
                      minUpdateNorm: latestPackage.minUpdateNorm,
                      maxUpdateNorm: latestPackage.maxUpdateNorm,
                    )}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScholesaColors.textSecondary,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                reviewRecord == null
                    ? 'Review status: pending'
                    : 'Review status: ${reviewRecord.status}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if (reviewRecord != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Checklist: privacy ${reviewRecord.privacyReviewComplete ? 'done' : 'open'} · sign-off ${reviewRecord.signoffChecklistComplete ? 'done' : 'open'} · rollout risk ${reviewRecord.rolloutRiskAcknowledged ? 'acknowledged' : 'open'}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (latestPilotEvidence != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Pilot evidence: ${latestPilotEvidence.status} · sandbox eval ${latestPilotEvidence.sandboxEvalComplete ? 'done' : 'open'} · metrics ${latestPilotEvidence.metricsSnapshotComplete ? 'done' : 'open'} · rollback ${latestPilotEvidence.rollbackPlanVerified ? 'verified' : 'open'}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                latestPilotApproval == null
                    ? 'Pilot approval: pending'
                    : 'Pilot approval: ${latestPilotApproval.status} (${latestPilotApproval.promotionTarget})',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                latestPilotExecution == null
                    ? 'Pilot execution: planned'
                    : 'Pilot execution: ${latestPilotExecution.status} · ${latestPilotExecution.launchedSiteIds.length} sites · ${latestPilotExecution.sessionCount} sessions · ${latestPilotExecution.learnerCount} learners',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                latestRuntimeDelivery == null
                    ? 'Runtime delivery: pending'
                    : 'Runtime delivery: ${latestRuntimeDelivery.status} · ${latestRuntimeDelivery.targetSiteIds.length} sites · ${latestRuntimeDelivery.runtimeTarget}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if (runtimeDeliveryLifecycle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(context, runtimeDeliveryLifecycle),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (runtimeRolloutHealth != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Site rollout: ${runtimeRolloutHealth.resolvedCount} resolved · ${runtimeRolloutHealth.stagedCount} staged · ${runtimeRolloutHealth.fallbackCount} fallback · ${runtimeRolloutHealth.pendingCount} pending',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (runtimeRolloutAlert.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: rolloutAlertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: rolloutAlertColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            rolloutAlertAcknowledged
                                ? Icons.task_alt_rounded
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: rolloutAlertColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tHqFeatureFlags(context, runtimeRolloutAlert),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: rolloutAlertColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (rolloutAlertAcknowledged &&
                        rolloutAlertNotes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'HQ notes: $rolloutAlertNotes',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ],
                    if (rolloutAlertAcknowledgement.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          rolloutAlertAcknowledgement,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: latestRuntimeDelivery == null
                                ? null
                                : () => _showRuntimeRolloutAlertDialog(
                                      experiment,
                                      latestRuntimeDelivery,
                                      runtimeRolloutHealth!,
                                      latestRuntimeRolloutAlert,
                                    ),
                            icon: Icon(
                              rolloutAlertAcknowledged
                                  ? Icons.edit_note_rounded
                                  : Icons.task_alt_rounded,
                            ),
                            label: Text(
                              _tHqFeatureFlags(
                                context,
                                rolloutAlertAcknowledged
                                    ? 'Update triage'
                                    : 'Acknowledge alert',
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: latestRuntimeDelivery == null
                                ? null
                                : () => _showRuntimeRolloutEscalationDialog(
                                      experiment,
                                      latestRuntimeDelivery,
                                      runtimeRolloutHealth!,
                                      latestRuntimeRolloutEscalation,
                                    ),
                            icon: const Icon(Icons.support_agent_rounded),
                            label: Text(
                              _tHqFeatureFlags(
                                context,
                                rolloutEscalationCurrent
                                    ? 'Update escalation'
                                    : 'Escalate alert',
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: latestRuntimeDelivery == null
                                ? null
                                : () => _showRuntimeRolloutControlDialog(
                                      experiment,
                                      latestRuntimeDelivery,
                                      latestRuntimeRolloutControl,
                                    ),
                            icon:
                                const Icon(Icons.pause_circle_outline_rounded),
                            label: Text(
                              _tHqFeatureFlags(
                                context,
                                rolloutControlActive
                                    ? 'Update control'
                                    : 'Rollout control',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rolloutEscalationSummary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _tHqFeatureFlags(context, rolloutEscalationSummary),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ],
                    if (rolloutControlSummary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _tHqFeatureFlags(context, rolloutControlSummary),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                _buildRuntimeActivationSummary(
                  latestRuntimeDelivery,
                  latestRuntimeActivation,
                  runtimeActivationRecords,
                ),
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if (latestPromotionStatus.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Latest package promotion: $latestPromotionStatus ($latestPromotionTarget)',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if ((_promotionRecordsByPackageId.values
                .where((record) => record.experimentId == experiment.id)
                .isNotEmpty)) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showPromotionHistoryDialog(experiment),
                  icon: const Icon(Icons.approval_rounded),
                  label: Text(
                    _tHqFeatureFlags(context, 'View promotions'),
                  ),
                ),
              ),
            ],
            if (runs.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _tHqFeatureFlags(context, 'Recent aggregation runs'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...runs.take(3).map(
                    (FederatedLearningAggregationRunModel run) =>
                        _buildAggregationRunRow(
                      run,
                      candidatePackagesByRunId[run.id],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAggregationRunRow(
    FederatedLearningAggregationRunModel run,
    FederatedLearningCandidateModelPackageModel? candidatePackage,
  ) {
    final String artifactStatus =
        (run.mergeArtifactStatus ?? '').trim().isNotEmpty
            ? run.mergeArtifactStatus!
            : 'missing';
    final String artifactId = (run.mergeArtifactId ?? '').trim();
    final String packageId =
        (candidatePackage?.id ?? run.candidateModelPackageId ?? '').trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tHqFeatureFlags(
              context,
              'Run ${run.id}: ${run.totalSampleCount} samples from ${run.summaryCount} summaries across ${run.distinctSiteCount} sites.',
            ),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              artifactId.isNotEmpty
                  ? 'Artifact $artifactStatus: $artifactId'
                  : 'Artifact $artifactStatus',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (packageId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Package staged: $packageId'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAggregationHistoryDialog(
    FederatedLearningExperimentModel experiment, {
    String initialQuery = '',
  }) async {
    final List<FederatedLearningAggregationRunModel> runs =
        _aggregationRunsByExperiment[experiment.id] ??
            const <FederatedLearningAggregationRunModel>[];
    final Map<String, FederatedLearningMergeArtifactModel> artifactsByRunId = {
      for (final FederatedLearningMergeArtifactModel artifact
          in _mergeArtifactsByExperiment[experiment.id] ??
              const <FederatedLearningMergeArtifactModel>[])
        artifact.aggregationRunId: artifact,
    };
    final Map<String, FederatedLearningCandidateModelPackageModel>
        candidatePackagesByRunId = {
      for (final FederatedLearningCandidateModelPackageModel package
          in _candidatePackagesByExperiment[experiment.id] ??
              const <FederatedLearningCandidateModelPackageModel>[])
        package.aggregationRunId: package,
    };
    const int pageSize = 2;
    String filterQuery = initialQuery;
    int pageIndex = 0;
    String sortMode = 'newest';
    String artifactFilter = 'all';
    bool latestOnly = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String normalizedQuery = filterQuery.trim().toLowerCase();
            final List<FederatedLearningAggregationRunModel> sortedRuns =
                List<FederatedLearningAggregationRunModel>.from(runs);
            if (sortMode == 'oldest') {
              sortedRuns.sort((a, b) {
                final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
                return aMillis.compareTo(bMillis);
              });
            } else if (sortMode == 'largest_batch') {
              sortedRuns.sort((a, b) {
                final int sampleCompare =
                    b.totalSampleCount.compareTo(a.totalSampleCount);
                if (sampleCompare != 0) return sampleCompare;
                final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
                return bMillis.compareTo(aMillis);
              });
            }

            List<FederatedLearningAggregationRunModel> filteredRuns =
                sortedRuns.where((FederatedLearningAggregationRunModel run) {
              final FederatedLearningMergeArtifactModel? artifact =
                  artifactsByRunId[run.id];
              final bool hasArtifact =
                  ((artifact?.id ?? run.mergeArtifactId ?? '')
                      .trim()
                      .isNotEmpty);
              if (artifactFilter == 'generated' && !hasArtifact) {
                return false;
              }
              if (artifactFilter == 'missing' && hasArtifact) {
                return false;
              }
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final String haystack = <String>[
                run.id,
                run.triggerSummaryId,
                run.summaryIds.join(' '),
                _summarySearchTokens(run.summaryIds),
                _summarySearchTokens(<String>[run.triggerSummaryId]),
                run.mergeArtifactId ?? '',
                run.mergeStrategy ?? '',
                run.boundedDigest ?? '',
                run.contributingSiteIds.join(' '),
                run.schemaVersions.join(' '),
                run.runtimeTargets.join(' '),
                run.optimizerStrategies.join(' '),
                run.compatibilityKey ?? '',
                run.warmStartPackageId ?? '',
                run.warmStartModelVersion ?? '',
                _formatCompatibilityRollup(
                  schemaVersions: run.schemaVersions,
                  runtimeTargets: run.runtimeTargets,
                  optimizerStrategies: run.optimizerStrategies,
                  warmStartPackageId: run.warmStartPackageId,
                  warmStartModelVersion: run.warmStartModelVersion,
                ),
                artifact?.id ?? '',
                artifact?.mergeStrategy ?? '',
                artifact?.boundedDigest ?? '',
                artifact?.contributingSiteIds.join(' ') ?? '',
                candidatePackagesByRunId[run.id]
                        ?.contributingSiteIds
                        .join(' ') ??
                    '',
              ].join(' ').toLowerCase();
              return haystack.contains(normalizedQuery);
            }).toList(growable: false);

            if (latestOnly && filteredRuns.isNotEmpty) {
              filteredRuns = <FederatedLearningAggregationRunModel>[
                filteredRuns.first,
              ];
            }
            final int generatedArtifactCount = filteredRuns.where(
              (FederatedLearningAggregationRunModel run) {
                final FederatedLearningMergeArtifactModel? artifact =
                    artifactsByRunId[run.id];
                return ((artifact?.id ?? run.mergeArtifactId ?? '')
                    .trim()
                    .isNotEmpty);
              },
            ).length;
            final int missingArtifactCount =
                filteredRuns.length - generatedArtifactCount;
            final int stagedPackageCount = filteredRuns.where(
              (FederatedLearningAggregationRunModel run) {
                final FederatedLearningCandidateModelPackageModel? package =
                    candidatePackagesByRunId[run.id];
                return ((package?.id ?? run.candidateModelPackageId ?? '')
                    .trim()
                    .isNotEmpty);
              },
            ).length;
            final int sampleTotal = filteredRuns.fold<int>(
              0,
              (int total, FederatedLearningAggregationRunModel run) =>
                  total + run.totalSampleCount,
            );
            final int pageCount = filteredRuns.isEmpty
                ? 1
                : ((filteredRuns.length - 1) ~/ pageSize) + 1;
            if (pageIndex >= pageCount) {
              pageIndex = pageCount - 1;
            }
            final int startIndex =
                filteredRuns.isEmpty ? 0 : pageIndex * pageSize;
            final int endIndex = filteredRuns.isEmpty
                ? 0
                : (startIndex + pageSize > filteredRuns.length
                    ? filteredRuns.length
                    : startIndex + pageSize);
            final List<FederatedLearningAggregationRunModel> visibleRuns =
                filteredRuns.sublist(startIndex, endIndex);

            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  context,
                  'Aggregation history: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (runs.isNotEmpty) ...<Widget>[
                        TextFormField(
                          initialValue: initialQuery,
                          onChanged: (String value) {
                            setDialogState(() {
                              filterQuery = value;
                              pageIndex = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: _tHqFeatureFlags(
                              context,
                              'Filter by run ID, summary ID, artifact ID, digest, site ID, optimizer, or warm start',
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: sortMode,
                          onChanged: (String? value) {
                            setDialogState(() {
                              sortMode = value ?? 'newest';
                              pageIndex = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: _tHqFeatureFlags(context, 'Sort runs'),
                          ),
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text(
                                  _tHqFeatureFlags(context, 'Newest first')),
                            ),
                            DropdownMenuItem(
                              value: 'oldest',
                              child: Text(
                                  _tHqFeatureFlags(context, 'Oldest first')),
                            ),
                            DropdownMenuItem(
                              value: 'largest_batch',
                              child: Text(
                                _tHqFeatureFlags(
                                    context, 'Largest batch first'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilterChip(
                              label: Text(
                                  _tHqFeatureFlags(context, 'Latest only')),
                              selected: latestOnly,
                              onSelected: (bool value) {
                                setDialogState(() {
                                  latestOnly = value;
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Artifact generated'),
                              ),
                              selected: artifactFilter == 'generated',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  artifactFilter = value ? 'generated' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Artifact missing'),
                              ),
                              selected: artifactFilter == 'missing',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  artifactFilter = value ? 'missing' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _buildExperimentChip(
                              'Runs: ${filteredRuns.length}',
                              Icons.timeline_rounded,
                            ),
                            _buildExperimentChip(
                              'Artifacts generated: $generatedArtifactCount',
                              Icons.inventory_2_rounded,
                              color: Colors.green,
                            ),
                            _buildExperimentChip(
                              'Artifacts missing: $missingArtifactCount',
                              Icons.error_outline_rounded,
                              color: Colors.orange,
                            ),
                            _buildExperimentChip(
                              'Packages staged: $stagedPackageCount',
                              Icons.inventory_rounded,
                              color: Colors.blue,
                            ),
                            _buildExperimentChip(
                              'Samples: $sampleTotal',
                              Icons.stacked_bar_chart_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (runs.isEmpty)
                        Text(
                          _tHqFeatureFlags(
                            context,
                            'No aggregation runs have materialized for this experiment yet.',
                          ),
                        )
                      else if (filteredRuns.isEmpty)
                        Text(
                          _tHqFeatureFlags(
                            context,
                            'No aggregation runs match the current filter.',
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: visibleRuns
                              .map(
                                (FederatedLearningAggregationRunModel run) =>
                                    _buildAggregationHistoryEntry(
                                  run,
                                  artifactsByRunId[run.id],
                                  candidatePackagesByRunId[run.id],
                                  experiment,
                                ),
                              )
                              .toList(),
                        ),
                      if (filteredRuns.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _tHqFeatureFlags(
                                  context,
                                  'Showing ${startIndex + 1}-$endIndex of ${filteredRuns.length}',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: pageIndex > 0
                                  ? () {
                                      setDialogState(() {
                                        pageIndex -= 1;
                                      });
                                    }
                                  : null,
                              child:
                                  Text(_tHqFeatureFlags(context, 'Previous')),
                            ),
                            TextButton(
                              onPressed: pageIndex < pageCount - 1
                                  ? () {
                                      setDialogState(() {
                                        pageIndex += 1;
                                      });
                                    }
                                  : null,
                              child: Text(_tHqFeatureFlags(context, 'Next')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_tHqFeatureFlags(context, 'Close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCandidatePackageHistoryDialog(
    FederatedLearningExperimentModel experiment,
  ) {
    final List<FederatedLearningCandidateModelPackageModel> packages =
        _candidatePackagesByExperiment[experiment.id] ??
            const <FederatedLearningCandidateModelPackageModel>[];
    const int pageSize = 2;
    String filterQuery = '';
    int pageIndex = 0;
    String sortMode = 'newest';
    String promotionFilter = 'all';
    bool latestOnly = false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String normalizedQuery = filterQuery.trim().toLowerCase();
            final List<FederatedLearningCandidateModelPackageModel>
                sortedPackages =
                List<FederatedLearningCandidateModelPackageModel>.from(
                    packages);
            if (sortMode == 'oldest') {
              sortedPackages.sort((a, b) {
                final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
                return aMillis.compareTo(bMillis);
              });
            } else if (sortMode == 'largest_batch') {
              sortedPackages.sort((a, b) {
                final int sampleCompare =
                    b.sampleCount.compareTo(a.sampleCount);
                if (sampleCompare != 0) return sampleCompare;
                final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
                return bMillis.compareTo(aMillis);
              });
            }

            List<FederatedLearningCandidateModelPackageModel> filteredPackages =
                sortedPackages.where(
                    (FederatedLearningCandidateModelPackageModel package) {
              final FederatedLearningCandidatePromotionRecordModel? promotion =
                  _promotionRecordsByPackageId[package.id];
              final FederatedLearningCandidatePromotionRevocationRecordModel?
                  revocation =
                  _promotionRevocationRecordsByPackageId[package.id];
              final String effectiveStatus =
                  _effectivePromotionStatus(promotion, revocation);
              if (promotionFilter == 'approved' &&
                  effectiveStatus != 'approved_for_eval') {
                return false;
              }
              if (promotionFilter == 'hold' && effectiveStatus != 'hold') {
                return false;
              }
              if (promotionFilter == 'revoked' &&
                  effectiveStatus != 'revoked') {
                return false;
              }
              if (promotionFilter == 'awaiting' &&
                  (promotion != null || revocation != null)) {
                return false;
              }
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final String haystack = <String>[
                package.id,
                package.mergeArtifactId,
                package.triggerSummaryId,
                package.summaryIds.join(' '),
                _summarySearchTokens(package.summaryIds),
                _summarySearchTokens(<String>[package.triggerSummaryId]),
                package.packageDigest,
                package.boundedDigest,
                package.packageFormat,
                package.rolloutStatus,
                package.contributingSiteIds.join(' '),
                package.schemaVersions.join(' '),
                package.runtimeTargets.join(' '),
                package.optimizerStrategies.join(' '),
                package.compatibilityKey ?? '',
                package.warmStartPackageId ?? '',
                package.warmStartModelVersion ?? '',
                _formatCompatibilityRollup(
                  schemaVersions: package.schemaVersions,
                  runtimeTargets: package.runtimeTargets,
                  optimizerStrategies: package.optimizerStrategies,
                  warmStartPackageId: package.warmStartPackageId,
                  warmStartModelVersion: package.warmStartModelVersion,
                ),
                promotion?.id ?? '',
                promotion?.status ?? '',
                promotion?.target ?? '',
                promotion?.rationale ?? '',
                revocation?.id ?? '',
                revocation?.revokedStatus ?? '',
                revocation?.rationale ?? '',
              ].join(' ').toLowerCase();
              return haystack.contains(normalizedQuery);
            }).toList(growable: false);

            if (latestOnly && filteredPackages.isNotEmpty) {
              filteredPackages = <FederatedLearningCandidateModelPackageModel>[
                filteredPackages.first,
              ];
            }

            final int approvedCount = filteredPackages.where((package) {
              return _effectivePromotionStatus(
                    _promotionRecordsByPackageId[package.id],
                    _promotionRevocationRecordsByPackageId[package.id],
                  ) ==
                  'approved_for_eval';
            }).length;
            final int holdCount = filteredPackages.where((package) {
              return _effectivePromotionStatus(
                    _promotionRecordsByPackageId[package.id],
                    _promotionRevocationRecordsByPackageId[package.id],
                  ) ==
                  'hold';
            }).length;
            final int revokedCount = filteredPackages.where((package) {
              return _effectivePromotionStatus(
                    _promotionRecordsByPackageId[package.id],
                    _promotionRevocationRecordsByPackageId[package.id],
                  ) ==
                  'revoked';
            }).length;
            final int awaitingCount = filteredPackages.length -
                approvedCount -
                holdCount -
                revokedCount;
            final int sampleTotal = filteredPackages.fold<int>(
              0,
              (int total,
                      FederatedLearningCandidateModelPackageModel package) =>
                  total + package.sampleCount,
            );
            final int pageCount = filteredPackages.isEmpty
                ? 1
                : ((filteredPackages.length - 1) ~/ pageSize) + 1;
            if (pageIndex >= pageCount) {
              pageIndex = pageCount - 1;
            }
            final int startIndex =
                filteredPackages.isEmpty ? 0 : pageIndex * pageSize;
            final int endIndex = filteredPackages.isEmpty
                ? 0
                : (startIndex + pageSize > filteredPackages.length
                    ? filteredPackages.length
                    : startIndex + pageSize);
            final List<FederatedLearningCandidateModelPackageModel>
                visiblePackages =
                filteredPackages.sublist(startIndex, endIndex);

            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  context,
                  'Candidate packages: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (packages.isNotEmpty) ...<Widget>[
                        TextField(
                          onChanged: (String value) {
                            setDialogState(() {
                              filterQuery = value;
                              pageIndex = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: _tHqFeatureFlags(
                              context,
                              'Filter by package ID, artifact ID, trigger or summary ID, digest, site ID, optimizer, or warm start',
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: sortMode,
                          onChanged: (String? value) {
                            setDialogState(() {
                              sortMode = value ?? 'newest';
                              pageIndex = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText:
                                _tHqFeatureFlags(context, 'Sort packages'),
                          ),
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text(
                                _tHqFeatureFlags(context, 'Newest first'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'oldest',
                              child: Text(
                                _tHqFeatureFlags(context, 'Oldest first'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'largest_batch',
                              child: Text(
                                _tHqFeatureFlags(
                                    context, 'Largest batch first'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilterChip(
                              label: Text(
                                  _tHqFeatureFlags(context, 'Latest only')),
                              selected: latestOnly,
                              onSelected: (bool value) {
                                setDialogState(() {
                                  latestOnly = value;
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Approved for eval'),
                              ),
                              selected: promotionFilter == 'approved',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  promotionFilter = value ? 'approved' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Awaiting promotion'),
                              ),
                              selected: promotionFilter == 'awaiting',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  promotionFilter = value ? 'awaiting' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'On hold'),
                              ),
                              selected: promotionFilter == 'hold',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  promotionFilter = value ? 'hold' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Revoked'),
                              ),
                              selected: promotionFilter == 'revoked',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  promotionFilter = value ? 'revoked' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _buildExperimentChip(
                              'Packages: ${filteredPackages.length}',
                              Icons.inventory_rounded,
                            ),
                            _buildExperimentChip(
                              'Approved for eval: $approvedCount',
                              Icons.approval_rounded,
                              color: Colors.green,
                            ),
                            _buildExperimentChip(
                              'Awaiting promotion: $awaitingCount',
                              Icons.hourglass_bottom_rounded,
                              color: Colors.orange,
                            ),
                            _buildExperimentChip(
                              'On hold: $holdCount',
                              Icons.pause_circle_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            _buildExperimentChip(
                              'Revoked: $revokedCount',
                              Icons.undo_rounded,
                              color: Colors.deepOrange,
                            ),
                            _buildExperimentChip(
                              'Samples: $sampleTotal',
                              Icons.stacked_bar_chart_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (packages.isEmpty)
                        Text(
                          _tHqFeatureFlags(
                            context,
                            'No candidate packages have been staged for this experiment yet.',
                          ),
                        )
                      else if (filteredPackages.isEmpty)
                        Text(
                          _tHqFeatureFlags(
                            context,
                            'No candidate packages match the current filter.',
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: visiblePackages
                              .map(
                                (FederatedLearningCandidateModelPackageModel
                                        package) =>
                                    _buildCandidatePackageHistoryEntry(
                                  experiment,
                                  package,
                                  _promotionRecordsByPackageId[package.id],
                                  _promotionRevocationRecordsByPackageId[
                                      package.id],
                                  onTraceAggregation: () =>
                                      _showAggregationHistoryDialog(
                                    experiment,
                                    initialQuery: package.aggregationRunId,
                                  ),
                                  onTraceAcceptedSummaries:
                                      package.summaryIds.isEmpty
                                          ? null
                                          : () => _showAcceptedSummaryDialog(
                                                experiment: experiment,
                                                summaryIds: package.summaryIds,
                                              ),
                                  onTraceTriggerSummary:
                                      package.triggerSummaryId.trim().isEmpty
                                          ? null
                                          : () => _showAcceptedSummaryDialog(
                                                experiment: experiment,
                                                summaryIds: <String>[
                                                  package.triggerSummaryId,
                                                ],
                                                title: 'Trigger summary',
                                              ),
                                  onApprove: () =>
                                      _showCandidatePromotionDecisionDialog(
                                    experiment: experiment,
                                    package: package,
                                    existingPromotion:
                                        _promotionRecordsByPackageId[
                                            package.id],
                                    initialStatus: 'approved_for_eval',
                                    refreshDialog: () {
                                      setDialogState(() {});
                                    },
                                  ),
                                  onHold: () =>
                                      _showCandidatePromotionDecisionDialog(
                                    experiment: experiment,
                                    package: package,
                                    existingPromotion:
                                        _promotionRecordsByPackageId[
                                            package.id],
                                    initialStatus: 'hold',
                                    refreshDialog: () {
                                      setDialogState(() {});
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      if (filteredPackages.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _tHqFeatureFlags(
                                  context,
                                  'Showing ${startIndex + 1}-$endIndex of ${filteredPackages.length}',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: pageIndex > 0
                                  ? () {
                                      setDialogState(() {
                                        pageIndex -= 1;
                                      });
                                    }
                                  : null,
                              child:
                                  Text(_tHqFeatureFlags(context, 'Previous')),
                            ),
                            TextButton(
                              onPressed: pageIndex < pageCount - 1
                                  ? () {
                                      setDialogState(() {
                                        pageIndex += 1;
                                      });
                                    }
                                  : null,
                              child: Text(_tHqFeatureFlags(context, 'Next')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_tHqFeatureFlags(context, 'Close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAggregationHistoryEntry(
    FederatedLearningAggregationRunModel run,
    FederatedLearningMergeArtifactModel? artifact,
    FederatedLearningCandidateModelPackageModel? candidatePackage,
    FederatedLearningExperimentModel experiment,
  ) {
    final String createdLabel = _formatTimestamp(run.createdAt);
    final String digest =
        (artifact?.boundedDigest ?? run.boundedDigest ?? '').trim();
    final String strategy =
        (artifact?.mergeStrategy ?? run.mergeStrategy ?? '').trim();
    final double? normCap =
        artifact?.normCap ?? candidatePackage?.normCap ?? run.normCap;
    final double? effectiveTotalWeight = artifact?.effectiveTotalWeight ??
        candidatePackage?.effectiveTotalWeight ??
        run.effectiveTotalWeight;
    final List<String> contributingSiteIds = artifact?.contributingSiteIds ??
        candidatePackage?.contributingSiteIds ??
        run.contributingSiteIds;
    final List<FederatedLearningContributionDetailModel> contributionDetails =
        artifact?.contributionDetails ??
            candidatePackage?.contributionDetails ??
            run.contributionDetails;
    final double? rawTotalWeight = artifact?.rawTotalWeight ??
      candidatePackage?.rawTotalWeight ??
      run.rawTotalWeight;
    final int? dampedSummaryCount = artifact?.dampedSummaryCount ??
      candidatePackage?.dampedSummaryCount ??
      run.dampedSummaryCount;
    final double? minUpdateNorm = artifact?.minUpdateNorm ??
      candidatePackage?.minUpdateNorm ??
      run.minUpdateNorm;
    final double? maxUpdateNorm = artifact?.maxUpdateNorm ??
      candidatePackage?.maxUpdateNorm ??
      run.maxUpdateNorm;
    final String artifactId =
        (artifact?.id ?? run.mergeArtifactId ?? '').trim();
    final String packageId =
        (candidatePackage?.id ?? run.candidateModelPackageId ?? '').trim();
    final String packageFormat = (candidatePackage?.packageFormat ??
            run.candidateModelPackageFormat ??
            '')
        .trim();
    final String triggerSummaryId = run.triggerSummaryId.trim();
    final String acceptedSummaryIds = run.summaryIds.join(', ');
    final String localTrainingRollup =
        _formatLocalTrainingRollup(run.summaryIds);
    final String runtimePayloadSummary =
        _formatRuntimePayloadSummary(candidatePackage);
    final String compatibilityRollup = _formatCompatibilityRollup(
      schemaVersions: run.schemaVersions,
      runtimeTargets: run.runtimeTargets,
      optimizerStrategies: run.optimizerStrategies,
      warmStartPackageId: run.warmStartPackageId,
      warmStartModelVersion: run.warmStartModelVersion,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tHqFeatureFlags(
              context,
              'Run ${run.id} · ${run.totalSampleCount} samples · ${run.summaryCount} summaries · ${run.distinctSiteCount} sites',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _tHqFeatureFlags(
              context,
              'Created: $createdLabel',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (triggerSummaryId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Trigger summary: $triggerSummaryId',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAcceptedSummaryDialog(
                experiment: experiment,
                summaryIds: <String>[triggerSummaryId],
                title: 'Trigger summary',
              ),
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: Text(
                _tHqFeatureFlags(context, 'Open trigger summary'),
              ),
            ),
          ],
          if (acceptedSummaryIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Accepted summaries: $acceptedSummaryIds',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAcceptedSummaryDialog(
                experiment: experiment,
                summaryIds: run.summaryIds,
              ),
              icon: const Icon(Icons.description_rounded),
              label: Text(
                _tHqFeatureFlags(context, 'Open accepted summaries'),
              ),
            ),
          ],
          if (localTrainingRollup.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, localTrainingRollup),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(context, compatibilityRollup),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (artifactId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Artifact: $artifactId'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (strategy.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Strategy: $strategy'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (normCap != null || effectiveTotalWeight != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Norm cap: ${_formatMergeMetric(normCap)} · Effective weight: ${_formatMergeMetric(effectiveTotalWeight)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (contributionDetails.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                _formatContributionRollup(
                  contributionDetails,
                  summaryCount: run.summaryCount,
                  effectiveTotalWeight: effectiveTotalWeight,
                  fallbackRawTotalWeight: run.totalSampleCount,
                ),
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (rawTotalWeight != null ||
              minUpdateNorm != null ||
              maxUpdateNorm != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                _formatAggregationObservabilityRollup(
                  summaryCount: run.summaryCount,
                  dampedSummaryCount: dampedSummaryCount,
                  rawTotalWeight: rawTotalWeight,
                  effectiveTotalWeight: effectiveTotalWeight,
                  minUpdateNorm: minUpdateNorm,
                  maxUpdateNorm: maxUpdateNorm,
                ),
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (packageId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Package: $packageId'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (packageFormat.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Package format: $packageFormat'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (runtimePayloadSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, runtimePayloadSummary),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (contributingSiteIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Contributor sites: ${_formatSiteList(contributingSiteIds)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (contributionDetails.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Contribution detail: ${_formatContributionDetailPreview(contributionDetails)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showContributionDetailsDialog(
                experimentLabel: experiment.name,
                details: contributionDetails,
              ),
              icon: const Icon(Icons.insights_rounded),
              label: Text(
                _tHqFeatureFlags(context, 'Open contribution details'),
              ),
            ),
          ],
          if (digest.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Digest: $digest'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Vector ceiling: ${run.maxVectorLength} · Payload: ${run.totalPayloadBytes} bytes · Avg norm: ${run.averageUpdateNorm}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExperimentReviewDialog(
    FederatedLearningExperimentModel experiment,
  ) async {
    final FederatedLearningExperimentReviewRecordModel? existingReview =
        _experimentReviewRecordsByExperimentId[experiment.id];
    final TextEditingController notesController = TextEditingController(
      text: existingReview?.notes ?? '',
    );
    String status = existingReview?.status ?? 'pending';
    bool privacyReviewComplete = existingReview?.privacyReviewComplete ?? false;
    bool signoffChecklistComplete =
        existingReview?.signoffChecklistComplete ?? false;
    bool rolloutRiskAcknowledged =
        existingReview?.rolloutRiskAcknowledged ?? false;

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(context, 'Experiment review checklist'),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                            context, 'Experiment: ${experiment.name}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Review status'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'pending', child: Text('pending')),
                          DropdownMenuItem(
                              value: 'approved', child: Text('approved')),
                          DropdownMenuItem(
                              value: 'blocked', child: Text('blocked')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'pending';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: privacyReviewComplete,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(context, 'Privacy review complete'),
                        ),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            privacyReviewComplete = value ?? false;
                          });
                        },
                      ),
                      CheckboxListTile(
                        value: signoffChecklistComplete,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(
                              context, 'Sign-off checklist complete'),
                        ),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            signoffChecklistComplete = value ?? false;
                          });
                        },
                      ),
                      CheckboxListTile(
                        value: rolloutRiskAcknowledged,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(
                              context, 'Rollout risk acknowledged'),
                        ),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            rolloutRiskAcknowledged = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Review notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save review')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await _saveExperimentReviewRecord(
      experiment: experiment,
      status: status,
      privacyReviewComplete: privacyReviewComplete,
      signoffChecklistComplete: signoffChecklistComplete,
      rolloutRiskAcknowledged: rolloutRiskAcknowledged,
      notes: notesController.text,
    );
  }

  Widget _buildCandidatePackageHistoryEntry(
    FederatedLearningExperimentModel experiment,
    FederatedLearningCandidateModelPackageModel package,
    FederatedLearningCandidatePromotionRecordModel? promotion,
    FederatedLearningCandidatePromotionRevocationRecordModel? revocation, {
    VoidCallback? onApprove,
    VoidCallback? onHold,
    VoidCallback? onTraceAggregation,
    VoidCallback? onTraceAcceptedSummaries,
    VoidCallback? onTraceTriggerSummary,
  }) {
    final String createdLabel = _formatTimestamp(package.createdAt);
    final String decidedLabel = _formatTimestamp(promotion?.decidedAt);
    final String revokedLabel = _formatTimestamp(revocation?.revokedAt);
    final String effectiveStatus =
        _effectivePromotionStatus(promotion, revocation);
    final String effectiveTarget =
        _effectivePromotionTarget(promotion, revocation);
    final String mergeStrategy = (package.mergeStrategy ?? '').trim();
    final String localTrainingRollup =
        _formatLocalTrainingRollup(package.summaryIds);
    final String runtimePayloadSummary = _formatRuntimePayloadSummary(package);
    final String compatibilityRollup = _formatCompatibilityRollup(
      schemaVersions: package.schemaVersions,
      runtimeTargets: package.runtimeTargets,
      optimizerStrategies: package.optimizerStrategies,
      warmStartPackageId: package.warmStartPackageId,
      warmStartModelVersion: package.warmStartModelVersion,
    );
    final bool isApproved = effectiveStatus == 'approved_for_eval';
    final bool isHold = effectiveStatus == 'hold';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tHqFeatureFlags(
              context,
              'Package ${package.id} · ${package.sampleCount} samples · ${package.summaryCount} summaries · ${package.distinctSiteCount} sites',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _tHqFeatureFlags(context, 'Created: $createdLabel'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Artifact: ${package.mergeArtifactId} · Format: ${package.packageFormat}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (runtimePayloadSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, runtimePayloadSummary),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(context, compatibilityRollup),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (mergeStrategy.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, 'Strategy: $mergeStrategy'),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package.normCap != null ||
              package.effectiveTotalWeight != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Norm cap: ${_formatMergeMetric(package.normCap)} · Effective weight: ${_formatMergeMetric(package.effectiveTotalWeight)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package.contributionDetails.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                _formatContributionRollup(
                  package.contributionDetails,
                  summaryCount: package.summaryCount,
                  effectiveTotalWeight: package.effectiveTotalWeight,
                  fallbackRawTotalWeight: package.sampleCount,
                ),
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package.rawTotalWeight != null ||
              package.minUpdateNorm != null ||
              package.maxUpdateNorm != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                _formatAggregationObservabilityRollup(
                  summaryCount: package.summaryCount,
                  dampedSummaryCount: package.dampedSummaryCount,
                  rawTotalWeight: package.rawTotalWeight,
                  effectiveTotalWeight: package.effectiveTotalWeight,
                  minUpdateNorm: package.minUpdateNorm,
                  maxUpdateNorm: package.maxUpdateNorm,
                ),
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package.contributingSiteIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Contributor sites: ${_formatSiteList(package.contributingSiteIds)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package.contributionDetails.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Contribution detail: ${_formatContributionDetailPreview(package.contributionDetails)}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showContributionDetailsDialog(
                experimentLabel: experiment.name,
                details: package.contributionDetails,
              ),
              icon: const Icon(Icons.insights_rounded),
              label: Text(
                _tHqFeatureFlags(context, 'Open contribution details'),
              ),
            ),
          ],
          if (package.summaryIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Accepted summaries: ${package.summaryIds.join(', ')}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (localTrainingRollup.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(context, localTrainingRollup),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package.triggerSummaryId.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Trigger summary: ${package.triggerSummaryId}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onTraceTriggerSummary,
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: Text(
                _tHqFeatureFlags(context, 'Open trigger summary'),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
                context, 'Rollout status: ${package.rolloutStatus}'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
                context, 'Package digest: ${package.packageDigest}'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
                context, 'Bounded digest: ${package.boundedDigest}'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              promotion == null
                  ? 'Promotion: awaiting decision'
                  : 'Promotion: $effectiveStatus ($effectiveTarget)',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (promotion != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Decision record: ${promotion.id} · $decidedLabel',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if ((promotion.decidedBy ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Decided by: ${promotion.decidedBy}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (promotion.packageDigest.trim().isNotEmpty ||
                promotion.boundedDigest.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Decision digests: package ${promotion.packageDigest} · bounded ${promotion.boundedDigest}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ],
          if (revocation != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Revocation record: ${revocation.id} · revoked ${revocation.revokedStatus} · $revokedLabel',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if ((revocation.revokedBy ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Revoked by: ${revocation.revokedBy}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (revocation.packageDigest.trim().isNotEmpty ||
                revocation.boundedDigest.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Revocation digests: package ${revocation.packageDigest} · bounded ${revocation.boundedDigest}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ],
          if ((promotion?.rationale ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Rationale: ${promotion!.rationale}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if ((revocation?.rationale ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Rollback rationale: ${revocation!.rationale}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: isApproved ? null : onApprove,
                child: Text(
                  _tHqFeatureFlags(
                    context,
                    isApproved ? 'Approved for eval' : 'Approve for eval',
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: isHold ? null : onHold,
                child: Text(
                  _tHqFeatureFlags(
                    context,
                    isHold ? 'On hold' : 'Mark hold',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onTraceAggregation,
                icon: const Icon(Icons.timeline_rounded),
                label: Text(
                  _tHqFeatureFlags(context, 'Open aggregation run'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onTraceAcceptedSummaries,
                icon: const Icon(Icons.description_rounded),
                label: Text(
                  _tHqFeatureFlags(context, 'Open accepted summaries'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCandidatePromotionDecisionDialog({
    required FederatedLearningExperimentModel experiment,
    required FederatedLearningCandidateModelPackageModel package,
    required String initialStatus,
    FederatedLearningCandidatePromotionRecordModel? existingPromotion,
    VoidCallback? refreshDialog,
  }) async {
    final TextEditingController rationaleController = TextEditingController(
      text: existingPromotion?.rationale ?? '',
    );
    String selectedStatus = initialStatus;

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(context, 'Record package decision'),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Experiment: ${experiment.name}',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Package: ${package.id} · ${package.sampleCount} samples',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Promotion decision'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'approved_for_eval',
                            child: Text('approved_for_eval'),
                          ),
                          DropdownMenuItem(
                            value: 'hold',
                            child: Text('hold'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            selectedStatus = value ?? initialStatus;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rationaleController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Rationale'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Saved with the bounded sandbox-eval promotion record.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save decision')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await _saveCandidatePromotionDecision(
      package: package,
      status: selectedStatus,
      rationale: rationaleController.text,
    );
    refreshDialog?.call();
  }

  Future<void> _showPromotionHistoryDialog(
    FederatedLearningExperimentModel experiment,
  ) {
    final List<FederatedLearningCandidatePromotionRecordModel> records =
        _promotionRecordsByPackageId.values
            .where((record) => record.experimentId == experiment.id)
            .toList(growable: false)
          ..sort((a, b) {
            final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
    final Map<String, FederatedLearningCandidateModelPackageModel>
        packagesById = {
      for (final FederatedLearningCandidateModelPackageModel package
          in _candidatePackagesByExperiment[experiment.id] ??
              const <FederatedLearningCandidateModelPackageModel>[])
        package.id: package,
    };
    const int pageSize = 2;
    String filterQuery = '';
    int pageIndex = 0;
    String sortMode = 'newest';
    String statusFilter = 'all';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String normalizedQuery = filterQuery.trim().toLowerCase();
            final List<FederatedLearningCandidatePromotionRecordModel>
                sortedRecords =
                List<FederatedLearningCandidatePromotionRecordModel>.from(
                    records);
            if (sortMode == 'oldest') {
              sortedRecords.sort((a, b) {
                final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
                return aMillis.compareTo(bMillis);
              });
            } else if (sortMode == 'approved_first') {
              sortedRecords.sort((a, b) {
                final int statusCompare =
                    _promotionStatusRank(a.status).compareTo(
                  _promotionStatusRank(b.status),
                );
                if (statusCompare != 0) return statusCompare;
                final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
                return bMillis.compareTo(aMillis);
              });
            }

            final List<FederatedLearningCandidatePromotionRecordModel>
                filteredRecords = sortedRecords.where((record) {
              if (statusFilter == 'approved' &&
                  _effectivePromotionStatus(
                        record,
                        _promotionRevocationRecordsByPackageId[
                            record.candidateModelPackageId],
                      ) !=
                      'approved_for_eval') {
                return false;
              }
              if (statusFilter == 'hold' &&
                  _effectivePromotionStatus(
                        record,
                        _promotionRevocationRecordsByPackageId[
                            record.candidateModelPackageId],
                      ) !=
                      'hold') {
                return false;
              }
              if (statusFilter == 'revoked' &&
                  _effectivePromotionStatus(
                        record,
                        _promotionRevocationRecordsByPackageId[
                            record.candidateModelPackageId],
                      ) !=
                      'revoked') {
                return false;
              }
              if (normalizedQuery.isEmpty) {
                return true;
              }
              final FederatedLearningCandidateModelPackageModel? package =
                  packagesById[record.candidateModelPackageId];
              final FederatedLearningCandidatePromotionRevocationRecordModel?
                  revocation = _promotionRevocationRecordsByPackageId[
                      record.candidateModelPackageId];
              final String haystack = <String>[
                record.id,
                record.candidateModelPackageId,
                record.aggregationRunId,
                record.mergeArtifactId,
                record.packageDigest,
                record.boundedDigest,
                record.status,
                record.target,
                record.rationale ?? '',
                record.decidedBy ?? '',
                package?.triggerSummaryId ?? '',
                package?.summaryIds.join(' ') ?? '',
                _summarySearchTokens(package?.summaryIds ?? <String>[]),
                _summarySearchTokens(<String>[package?.triggerSummaryId ?? '']),
                package?.packageDigest ?? '',
                package?.boundedDigest ?? '',
                package?.contributingSiteIds.join(' ') ?? '',
                package?.schemaVersions.join(' ') ?? '',
                package?.runtimeTargets.join(' ') ?? '',
                package?.optimizerStrategies.join(' ') ?? '',
                package?.compatibilityKey ?? '',
                package?.warmStartPackageId ?? '',
                package?.warmStartModelVersion ?? '',
                package == null
                    ? ''
                    : _formatCompatibilityRollup(
                        schemaVersions: package.schemaVersions,
                        runtimeTargets: package.runtimeTargets,
                        optimizerStrategies: package.optimizerStrategies,
                        warmStartPackageId: package.warmStartPackageId,
                        warmStartModelVersion: package.warmStartModelVersion,
                      ),
                revocation?.id ?? '',
                revocation?.packageDigest ?? '',
                revocation?.boundedDigest ?? '',
                revocation?.revokedStatus ?? '',
                revocation?.rationale ?? '',
              ].join(' ').toLowerCase();
              return haystack.contains(normalizedQuery);
            }).toList(growable: false);

            final int approvedCount = filteredRecords
                .where((record) =>
                    _effectivePromotionStatus(
                      record,
                      _promotionRevocationRecordsByPackageId[
                          record.candidateModelPackageId],
                    ) ==
                    'approved_for_eval')
                .length;
            final int holdCount = filteredRecords
                .where((record) =>
                    _effectivePromotionStatus(
                      record,
                      _promotionRevocationRecordsByPackageId[
                          record.candidateModelPackageId],
                    ) ==
                    'hold')
                .length;
            final int revokedCount = filteredRecords
                .where((record) =>
                    _effectivePromotionStatus(
                      record,
                      _promotionRevocationRecordsByPackageId[
                          record.candidateModelPackageId],
                    ) ==
                    'revoked')
                .length;
            final int sampleTotal = filteredRecords.fold<int>(
              0,
              (int total,
                      FederatedLearningCandidatePromotionRecordModel record) =>
                  total +
                  (packagesById[record.candidateModelPackageId]?.sampleCount ??
                      0),
            );
            final int pageCount = filteredRecords.isEmpty
                ? 1
                : ((filteredRecords.length - 1) ~/ pageSize) + 1;
            if (pageIndex >= pageCount) {
              pageIndex = pageCount - 1;
            }
            final int startIndex =
                filteredRecords.isEmpty ? 0 : pageIndex * pageSize;
            final int endIndex = filteredRecords.isEmpty
                ? 0
                : (startIndex + pageSize > filteredRecords.length
                    ? filteredRecords.length
                    : startIndex + pageSize);
            final List<FederatedLearningCandidatePromotionRecordModel>
                visibleRecords = filteredRecords.sublist(startIndex, endIndex);

            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  context,
                  'Promotion history: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (records.isNotEmpty) ...<Widget>[
                        TextField(
                          onChanged: (String value) {
                            setDialogState(() {
                              filterQuery = value;
                              pageIndex = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: _tHqFeatureFlags(
                              context,
                              'Filter by package ID, artifact ID, decision ID, trigger or summary ID, rationale, site ID, optimizer, or warm start',
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: sortMode,
                          onChanged: (String? value) {
                            setDialogState(() {
                              sortMode = value ?? 'newest';
                              pageIndex = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: _tHqFeatureFlags(
                              context,
                              'Sort promotions',
                            ),
                          ),
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text(
                                _tHqFeatureFlags(context, 'Newest first'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'oldest',
                              child: Text(
                                _tHqFeatureFlags(context, 'Oldest first'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'approved_first',
                              child: Text(
                                _tHqFeatureFlags(context, 'Approved first'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Approved for eval'),
                              ),
                              selected: statusFilter == 'approved',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  statusFilter = value ? 'approved' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'On hold'),
                              ),
                              selected: statusFilter == 'hold',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  statusFilter = value ? 'hold' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                            FilterChip(
                              label: Text(
                                _tHqFeatureFlags(context, 'Revoked'),
                              ),
                              selected: statusFilter == 'revoked',
                              onSelected: (bool value) {
                                setDialogState(() {
                                  statusFilter = value ? 'revoked' : 'all';
                                  pageIndex = 0;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _buildExperimentChip(
                              'Decisions: ${filteredRecords.length}',
                              Icons.approval_rounded,
                            ),
                            _buildExperimentChip(
                              'Approved: $approvedCount',
                              Icons.check_circle_outline_rounded,
                              color: Colors.green,
                            ),
                            _buildExperimentChip(
                              'On hold: $holdCount',
                              Icons.pause_circle_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            _buildExperimentChip(
                              'Revoked: $revokedCount',
                              Icons.undo_rounded,
                              color: Colors.deepOrange,
                            ),
                            _buildExperimentChip(
                              'Samples: $sampleTotal',
                              Icons.stacked_bar_chart_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (records.isEmpty)
                        Text(
                          _tHqFeatureFlags(
                            context,
                            'No promotion decisions have been recorded for this experiment yet.',
                          ),
                        )
                      else if (filteredRecords.isEmpty)
                        Text(
                          _tHqFeatureFlags(
                            context,
                            'No promotion decisions match the current filter.',
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: visibleRecords
                              .map(
                                (FederatedLearningCandidatePromotionRecordModel
                                        record) =>
                                    _buildPromotionHistoryEntry(
                                  experiment,
                                  record,
                                  packagesById[record.candidateModelPackageId],
                                  _promotionRevocationRecordsByPackageId[
                                      record.candidateModelPackageId],
                                  onTraceAggregation: () =>
                                      _showAggregationHistoryDialog(
                                    experiment,
                                    initialQuery: record.aggregationRunId,
                                  ),
                                  onTraceAcceptedSummaries: packagesById[record
                                                  .candidateModelPackageId]
                                              ?.summaryIds
                                              .isEmpty ==
                                          false
                                      ? () => _showAcceptedSummaryDialog(
                                            experiment: experiment,
                                            summaryIds: packagesById[record
                                                    .candidateModelPackageId]!
                                                .summaryIds,
                                          )
                                      : null,
                                  onTraceTriggerSummary: packagesById[record
                                                  .candidateModelPackageId]
                                              ?.triggerSummaryId
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? () => _showAcceptedSummaryDialog(
                                            experiment: experiment,
                                            summaryIds: <String>[
                                              packagesById[record
                                                      .candidateModelPackageId]!
                                                  .triggerSummaryId,
                                            ],
                                            title: 'Trigger summary',
                                          )
                                      : null,
                                  onRevoke: () =>
                                      _showCandidatePromotionRevocationDialog(
                                    record: record,
                                    refreshDialog: () {
                                      setDialogState(() {});
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      if (filteredRecords.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _tHqFeatureFlags(
                                  context,
                                  'Showing ${startIndex + 1}-$endIndex of ${filteredRecords.length}',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ScholesaColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: pageIndex > 0
                                  ? () {
                                      setDialogState(() {
                                        pageIndex -= 1;
                                      });
                                    }
                                  : null,
                              child:
                                  Text(_tHqFeatureFlags(context, 'Previous')),
                            ),
                            TextButton(
                              onPressed: pageIndex < pageCount - 1
                                  ? () {
                                      setDialogState(() {
                                        pageIndex += 1;
                                      });
                                    }
                                  : null,
                              child: Text(_tHqFeatureFlags(context, 'Next')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_tHqFeatureFlags(context, 'Close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _promotionStatusRank(String status) {
    switch (status) {
      case 'approved_for_eval':
        return 0;
      case 'hold':
        return 1;
      case 'revoked':
        return 2;
      default:
        return 3;
    }
  }

  String _effectivePromotionStatus(
    FederatedLearningCandidatePromotionRecordModel? promotion,
    FederatedLearningCandidatePromotionRevocationRecordModel? revocation,
  ) {
    if (revocation != null) {
      return 'revoked';
    }
    return (promotion?.status ?? '').trim();
  }

  String _effectivePromotionTarget(
    FederatedLearningCandidatePromotionRecordModel? promotion,
    FederatedLearningCandidatePromotionRevocationRecordModel? revocation,
  ) {
    return (revocation?.target ?? promotion?.target ?? '').trim();
  }

  Widget _buildPromotionHistoryEntry(
    FederatedLearningExperimentModel experiment,
    FederatedLearningCandidatePromotionRecordModel record,
    FederatedLearningCandidateModelPackageModel? package,
    FederatedLearningCandidatePromotionRevocationRecordModel? revocation, {
    VoidCallback? onRevoke,
    VoidCallback? onTraceAggregation,
    VoidCallback? onTraceAcceptedSummaries,
    VoidCallback? onTraceTriggerSummary,
  }) {
    final String decidedLabel = _formatTimestamp(record.decidedAt);
    final String updatedLabel = _formatTimestamp(record.updatedAt);
    final String revokedLabel = _formatTimestamp(revocation?.revokedAt);
    final String effectiveStatus =
        _effectivePromotionStatus(record, revocation);
    final String effectiveTarget =
        _effectivePromotionTarget(record, revocation);
    final String localTrainingRollup =
        _formatLocalTrainingRollup(package?.summaryIds ?? const <String>[]);
    final String runtimePayloadSummary = _formatRuntimePayloadSummary(package);
    final String compatibilityRollup = package == null
        ? ''
        : _formatCompatibilityRollup(
            schemaVersions: package.schemaVersions,
            runtimeTargets: package.runtimeTargets,
            optimizerStrategies: package.optimizerStrategies,
            warmStartPackageId: package.warmStartPackageId,
            warmStartModelVersion: package.warmStartModelVersion,
          );
    final bool isRevoked = revocation != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _tHqFeatureFlags(
              context,
              'Decision ${record.id} · $effectiveStatus ($effectiveTarget)',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _tHqFeatureFlags(
              context,
              'Package: ${record.candidateModelPackageId} · Artifact: ${record.mergeArtifactId}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Run: ${record.aggregationRunId} · Decided: $decidedLabel',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(
              context,
              'Updated: $updatedLabel${(record.decidedBy ?? '').trim().isEmpty ? '' : ' · By: ${record.decidedBy}'}',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          if (record.packageDigest.trim().isNotEmpty ||
              record.boundedDigest.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Decision digests: package ${record.packageDigest} · bounded ${record.boundedDigest}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (package != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Samples: ${package.sampleCount} · Digest: ${package.boundedDigest}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if ((package.mergeStrategy ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Strategy: ${package.mergeStrategy}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (package.normCap != null ||
                package.effectiveTotalWeight != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Norm cap: ${_formatMergeMetric(package.normCap)} · Effective weight: ${_formatMergeMetric(package.effectiveTotalWeight)}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (package.contributionDetails.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  _formatContributionRollup(
                    package.contributionDetails,
                    summaryCount: package.summaryCount,
                    effectiveTotalWeight: package.effectiveTotalWeight,
                    fallbackRawTotalWeight: package.sampleCount,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (package.rawTotalWeight != null ||
                package.minUpdateNorm != null ||
                package.maxUpdateNorm != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  _formatAggregationObservabilityRollup(
                    summaryCount: package.summaryCount,
                    dampedSummaryCount: package.dampedSummaryCount,
                    rawTotalWeight: package.rawTotalWeight,
                    effectiveTotalWeight: package.effectiveTotalWeight,
                    minUpdateNorm: package.minUpdateNorm,
                    maxUpdateNorm: package.maxUpdateNorm,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (package.contributingSiteIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Contributor sites: ${_formatSiteList(package.contributingSiteIds)}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (package.contributionDetails.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Contribution detail: ${_formatContributionDetailPreview(package.contributionDetails)}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showContributionDetailsDialog(
                  experimentLabel: experiment.name,
                  details: package.contributionDetails,
                ),
                icon: const Icon(Icons.insights_rounded),
                label: Text(
                  _tHqFeatureFlags(context, 'Open contribution details'),
                ),
              ),
            ],
            if (package.summaryIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Accepted summaries: ${package.summaryIds.join(', ')}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (localTrainingRollup.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(context, localTrainingRollup),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (compatibilityRollup.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(context, compatibilityRollup),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (package.triggerSummaryId.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Trigger summary: ${package.triggerSummaryId}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onTraceTriggerSummary,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(
                  _tHqFeatureFlags(context, 'Open trigger summary'),
                ),
              ),
            ],
          ],
          if ((record.rationale ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Rationale: ${record.rationale}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
          if (revocation != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _tHqFeatureFlags(
                context,
                'Revocation: ${revocation.id} · revoked ${revocation.revokedStatus} · $revokedLabel',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: ScholesaColors.textSecondary,
              ),
            ),
            if ((revocation.revokedBy ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Revoked by: ${revocation.revokedBy}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if ((revocation.rationale ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Rollback rationale: ${revocation.rationale}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (revocation.packageDigest.trim().isNotEmpty ||
                revocation.boundedDigest.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(
                  context,
                  'Revocation digests: package ${revocation.packageDigest} · bounded ${revocation.boundedDigest}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
            if (runtimePayloadSummary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _tHqFeatureFlags(context, runtimePayloadSummary),
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: isRevoked ? null : onRevoke,
                icon: const Icon(Icons.undo_rounded),
                label: Text(
                  _tHqFeatureFlags(
                    context,
                    isRevoked ? 'Revoked' : 'Revoke decision',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onTraceAggregation,
                icon: const Icon(Icons.timeline_rounded),
                label: Text(
                  _tHqFeatureFlags(context, 'Open aggregation run'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onTraceAcceptedSummaries,
                icon: const Icon(Icons.description_rounded),
                label: Text(
                  _tHqFeatureFlags(context, 'Open accepted summaries'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveCandidatePromotionDecision({
    required FederatedLearningCandidateModelPackageModel package,
    required String status,
    required String rationale,
  }) async {
    try {
      await _workflowBridge.upsertFederatedLearningCandidatePromotionRecord(
        <String, dynamic>{
          'candidateModelPackageId': package.id,
          'status': status,
          'target': 'sandbox_eval',
          'rationale': rationale.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Candidate package decision saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Candidate package decision failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveExperimentReviewRecord({
    required FederatedLearningExperimentModel experiment,
    required String status,
    required bool privacyReviewComplete,
    required bool signoffChecklistComplete,
    required bool rolloutRiskAcknowledged,
    required String notes,
  }) async {
    try {
      await _workflowBridge.upsertFederatedLearningExperimentReviewRecord(
        <String, dynamic>{
          'experimentId': experiment.id,
          'status': status,
          'privacyReviewComplete': privacyReviewComplete,
          'signoffChecklistComplete': signoffChecklistComplete,
          'rolloutRiskAcknowledged': rolloutRiskAcknowledged,
          'notes': notes.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Experiment review saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Experiment review failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showPilotEvidenceDialog({
    required FederatedLearningExperimentModel experiment,
    required FederatedLearningCandidateModelPackageModel candidatePackage,
  }) async {
    final FederatedLearningPilotEvidenceRecordModel? existingEvidence =
        _pilotEvidenceRecordsByPackageId[candidatePackage.id];
    final TextEditingController notesController = TextEditingController(
      text: existingEvidence?.notes ?? '',
    );
    String status = existingEvidence?.status ?? 'pending';
    bool sandboxEvalComplete = existingEvidence?.sandboxEvalComplete ?? false;
    bool metricsSnapshotComplete =
        existingEvidence?.metricsSnapshotComplete ?? false;
    bool rollbackPlanVerified = existingEvidence?.rollbackPlanVerified ?? false;

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(context, 'Pilot evidence checklist'),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Experiment: ${experiment.name}',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Candidate package: ${candidatePackage.id}',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Evidence status'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'pending', child: Text('pending')),
                          DropdownMenuItem(
                            value: 'ready_for_pilot',
                            child: Text('ready_for_pilot'),
                          ),
                          DropdownMenuItem(
                              value: 'blocked', child: Text('blocked')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'pending';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: sandboxEvalComplete,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(context, 'Sandbox eval complete'),
                        ),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            sandboxEvalComplete = value ?? false;
                          });
                        },
                      ),
                      CheckboxListTile(
                        value: metricsSnapshotComplete,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(
                              context, 'Metrics snapshot reviewed'),
                        ),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            metricsSnapshotComplete = value ?? false;
                          });
                        },
                      ),
                      CheckboxListTile(
                        value: rollbackPlanVerified,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(context, 'Rollback plan verified'),
                        ),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            rollbackPlanVerified = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Pilot evidence notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save evidence')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await _savePilotEvidenceRecord(
      candidateModelPackageId: candidatePackage.id,
      status: status,
      sandboxEvalComplete: sandboxEvalComplete,
      metricsSnapshotComplete: metricsSnapshotComplete,
      rollbackPlanVerified: rollbackPlanVerified,
      notes: notesController.text,
    );
  }

  Future<void> _savePilotEvidenceRecord({
    required String candidateModelPackageId,
    required String status,
    required bool sandboxEvalComplete,
    required bool metricsSnapshotComplete,
    required bool rollbackPlanVerified,
    required String notes,
  }) async {
    try {
      await _workflowBridge.upsertFederatedLearningPilotEvidenceRecord(
        <String, dynamic>{
          'candidateModelPackageId': candidateModelPackageId,
          'status': status,
          'sandboxEvalComplete': sandboxEvalComplete,
          'metricsSnapshotComplete': metricsSnapshotComplete,
          'rollbackPlanVerified': rollbackPlanVerified,
          'notes': notes.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Pilot evidence saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Pilot evidence failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showPilotApprovalDialog({
    required FederatedLearningExperimentModel experiment,
    required FederatedLearningCandidateModelPackageModel candidatePackage,
  }) async {
    final FederatedLearningPilotApprovalRecordModel? existingApproval =
        _pilotApprovalRecordsByPackageId[candidatePackage.id];
    final TextEditingController notesController = TextEditingController(
      text: existingApproval?.notes ?? '',
    );
    String status = existingApproval?.status ?? 'pending';

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(context, 'Pilot approval record'),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                            context, 'Experiment: ${experiment.name}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Candidate package: ${candidatePackage.id}',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Approval status'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Approved requires approved review, ready-for-pilot evidence, and a non-revoked approved-for-eval promotion.',
                          ),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'pending', child: Text('pending')),
                          DropdownMenuItem(
                              value: 'approved', child: Text('approved')),
                          DropdownMenuItem(
                              value: 'blocked', child: Text('blocked')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'pending';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Pilot approval notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save approval')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await _savePilotApprovalRecord(
      candidateModelPackageId: candidatePackage.id,
      status: status,
      notes: notesController.text,
    );
  }

  Future<void> _savePilotApprovalRecord({
    required String candidateModelPackageId,
    required String status,
    required String notes,
  }) async {
    try {
      await _workflowBridge.upsertFederatedLearningPilotApprovalRecord(
        <String, dynamic>{
          'candidateModelPackageId': candidateModelPackageId,
          'status': status,
          'notes': notes.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Pilot approval saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Pilot approval failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showPilotExecutionDialog({
    required FederatedLearningExperimentModel experiment,
    required FederatedLearningCandidateModelPackageModel candidatePackage,
  }) async {
    final FederatedLearningPilotExecutionRecordModel? existingExecution =
        _pilotExecutionRecordsByPackageId[candidatePackage.id];
    final TextEditingController launchedSitesController = TextEditingController(
      text: existingExecution?.launchedSiteIds.join(', ') ?? '',
    );
    final TextEditingController sessionCountController = TextEditingController(
      text: (existingExecution?.sessionCount ?? 0).toString(),
    );
    final TextEditingController learnerCountController = TextEditingController(
      text: (existingExecution?.learnerCount ?? 0).toString(),
    );
    final TextEditingController notesController = TextEditingController(
      text: existingExecution?.notes ?? '',
    );
    String status = existingExecution?.status ?? 'planned';

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(context, 'Pilot execution record'),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                            context, 'Experiment: ${experiment.name}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Candidate package: ${candidatePackage.id}',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Execution status'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Launched, observed, and completed require approved pilot approval. Observed and completed also require launched sites plus positive session and learner counts.',
                          ),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'planned', child: Text('planned')),
                          DropdownMenuItem(
                              value: 'launched', child: Text('launched')),
                          DropdownMenuItem(
                              value: 'observed', child: Text('observed')),
                          DropdownMenuItem(
                              value: 'completed', child: Text('completed')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'planned';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: launchedSitesController,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Launched site IDs'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Comma-separated site IDs. All sites must already be in the experiment cohort.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sessionCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Session count'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: learnerCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Learner count'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(
                              context, 'Pilot execution notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save execution')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final List<String> launchedSiteIds = launchedSitesController.text
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    final int sessionCount =
        int.tryParse(sessionCountController.text.trim()) ?? 0;
    final int learnerCount =
        int.tryParse(learnerCountController.text.trim()) ?? 0;

    await _savePilotExecutionRecord(
      candidateModelPackageId: candidatePackage.id,
      status: status,
      launchedSiteIds: launchedSiteIds,
      sessionCount: sessionCount,
      learnerCount: learnerCount,
      notes: notesController.text,
    );
  }

  Future<void> _savePilotExecutionRecord({
    required String candidateModelPackageId,
    required String status,
    required List<String> launchedSiteIds,
    required int sessionCount,
    required int learnerCount,
    required String notes,
  }) async {
    try {
      await _workflowBridge.upsertFederatedLearningPilotExecutionRecord(
        <String, dynamic>{
          'candidateModelPackageId': candidateModelPackageId,
          'status': status,
          'launchedSiteIds': launchedSiteIds,
          'sessionCount': sessionCount,
          'learnerCount': learnerCount,
          'notes': notes.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Pilot execution saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Pilot execution failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRuntimeDeliveryDialog({
    required FederatedLearningExperimentModel experiment,
    required FederatedLearningCandidateModelPackageModel candidatePackage,
  }) async {
    final FederatedLearningRuntimeDeliveryRecordModel? existingDelivery =
        _runtimeDeliveryRecordsByPackageId[candidatePackage.id];
    final TextEditingController targetSitesController = TextEditingController(
      text: existingDelivery?.targetSiteIds.join(', ') ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existingDelivery?.notes ?? '',
    );
    final TextEditingController expiryHoursController = TextEditingController(
      text: existingDelivery?.expiresAt == null
          ? '168'
          : existingDelivery!.expiresAt!
              .toDate()
              .difference(DateTime.now())
              .inHours
              .clamp(1, 24 * 365)
              .toString(),
    );
    final TextEditingController revocationReasonController =
        TextEditingController(
      text: existingDelivery?.revocationReason ?? '',
    );
    String status = existingDelivery?.status ?? 'prepared';

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(context, 'Runtime delivery record'),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                            context, 'Experiment: ${experiment.name}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tHqFeatureFlags(
                          context,
                          'Candidate package: ${candidatePackage.id}',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Delivery status'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Assigned and active delivery require observed or completed pilot execution and sites within the experiment cohort.',
                          ),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'prepared', child: Text('prepared')),
                          DropdownMenuItem(
                              value: 'assigned', child: Text('assigned')),
                          DropdownMenuItem(
                              value: 'active', child: Text('active')),
                          DropdownMenuItem(
                              value: 'revoked', child: Text('revoked')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'prepared';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: targetSitesController,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Target site IDs'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Comma-separated site IDs. Delivery stays bounded to the approved experiment cohort.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: expiryHoursController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(
                              context, 'Expiry window (hours)'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Assigned and active deliveries expire automatically after this many hours unless HQ refreshes them.',
                          ),
                        ),
                      ),
                      if (status == 'revoked') ...<Widget>[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: revocationReasonController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText:
                                _tHqFeatureFlags(context, 'Revocation reason'),
                            helperText: _tHqFeatureFlags(
                              context,
                              'Required when revoking a delivered runtime package.',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(
                              context, 'Runtime delivery notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save delivery')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final List<String> targetSiteIds = targetSitesController.text
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    final int? expiryHours = int.tryParse(expiryHoursController.text.trim());
    final int? expiresAt = (status == 'assigned' || status == 'active') &&
            expiryHours != null &&
            expiryHours > 0
        ? DateTime.now()
            .toUtc()
            .add(Duration(hours: expiryHours))
            .millisecondsSinceEpoch
        : null;

    await _saveRuntimeDeliveryRecord(
      candidateModelPackageId: candidatePackage.id,
      status: status,
      targetSiteIds: targetSiteIds,
      expiresAt: expiresAt,
      revocationReason: revocationReasonController.text,
      notes: notesController.text,
    );
  }

  Future<void> _saveRuntimeDeliveryRecord({
    required String candidateModelPackageId,
    required String status,
    required List<String> targetSiteIds,
    required int? expiresAt,
    required String revocationReason,
    required String notes,
  }) async {
    try {
      await _workflowBridge.upsertFederatedLearningRuntimeDeliveryRecord(
        <String, dynamic>{
          'candidateModelPackageId': candidateModelPackageId,
          'status': status,
          'targetSiteIds': targetSiteIds,
          if (expiresAt != null) 'expiresAt': expiresAt,
          if (status == 'revoked' && revocationReason.trim().isNotEmpty)
            'revocationReason': revocationReason.trim(),
          'notes': notes.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Runtime delivery saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Runtime delivery failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRuntimeDeliveryHistoryDialog(
    FederatedLearningExperimentModel experiment,
  ) async {
    final Map<String, FederatedLearningCandidateModelPackageModel>
        packagesById = {
      for (final FederatedLearningCandidateModelPackageModel package
          in _candidatePackagesByExperiment[experiment.id] ??
              const <FederatedLearningCandidateModelPackageModel>[])
        package.id: package,
    };
    final List<FederatedLearningRuntimeDeliveryRecordModel> records =
        (await _workflowBridge.listFederatedLearningRuntimeDeliveryRecords(
      experimentId: experiment.id,
      limit: 120,
    ))
            .map((Map<String, dynamic> row) =>
                FederatedLearningRuntimeDeliveryRecordModel.fromMap(
                  (row['id'] as String?) ?? 'runtime_delivery_record',
                  row,
                ))
            .toList()
          ..sort((a, b) {
            final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
    String filterQuery = '';
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final String normalizedQuery = filterQuery.trim().toLowerCase();
            final List<FederatedLearningRuntimeDeliveryRecordModel>
                filteredRecords = records.where(
              (FederatedLearningRuntimeDeliveryRecordModel record) {
                if (normalizedQuery.isEmpty) {
                  return true;
                }
                final FederatedLearningCandidateModelPackageModel? package =
                    packagesById[record.candidateModelPackageId];
                final String aggregationRunId =
                    record.aggregationRunId.trim().isNotEmpty
                        ? record.aggregationRunId
                        : package?.aggregationRunId ?? '';
                final String mergeArtifactId =
                    record.mergeArtifactId.trim().isNotEmpty
                        ? record.mergeArtifactId
                        : package?.mergeArtifactId ?? '';
                final String packageDigest =
                    record.packageDigest.trim().isNotEmpty
                        ? record.packageDigest
                        : package?.packageDigest ?? '';
                final String boundedDigest =
                    record.boundedDigest.trim().isNotEmpty
                        ? record.boundedDigest
                        : package?.boundedDigest ?? '';
                final String triggerSummaryId =
                    record.triggerSummaryId.trim().isNotEmpty
                        ? record.triggerSummaryId
                        : package?.triggerSummaryId ?? '';
                final List<String> summaryIds = record.summaryIds.isNotEmpty
                    ? record.summaryIds
                    : package?.summaryIds ?? const <String>[];
                final String haystack = <String>[
                  record.id,
                  record.status,
                  record.runtimeTarget,
                  record.candidateModelPackageId,
                  aggregationRunId,
                  mergeArtifactId,
                  packageDigest,
                  boundedDigest,
                  triggerSummaryId,
                  summaryIds.join(' '),
                  _summarySearchTokens(summaryIds),
                  _summarySearchTokens(<String>[triggerSummaryId]),
                  record.targetSiteIds.join(' '),
                  record.notes ?? '',
                  record.revocationReason ?? '',
                  package?.rolloutStatus ?? '',
                  package?.packageFormat ?? '',
                  package?.contributingSiteIds.join(' ') ?? '',
                  record.schemaVersions.join(' '),
                  record.optimizerStrategies.join(' '),
                  record.compatibilityKey ?? '',
                  record.warmStartPackageId ?? '',
                  record.warmStartModelVersion ?? '',
                  package?.schemaVersions.join(' ') ?? '',
                  package?.runtimeTargets.join(' ') ?? '',
                  package?.optimizerStrategies.join(' ') ?? '',
                  package?.compatibilityKey ?? '',
                  package?.warmStartPackageId ?? '',
                  package?.warmStartModelVersion ?? '',
                  _formatRuntimeDeliveryCompatibilityRollup(record, package),
                ].join(' ').toLowerCase();
                return haystack.contains(normalizedQuery);
              },
            ).toList(growable: false);

            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  dialogContext,
                  'Runtime delivery history: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 640,
                child: records.isEmpty
                    ? Text(
                        _tHqFeatureFlags(
                          dialogContext,
                          'No runtime deliveries recorded for this experiment yet.',
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            TextFormField(
                              initialValue: filterQuery,
                              onChanged: (String value) {
                                setDialogState(() {
                                  filterQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: _tHqFeatureFlags(
                                  dialogContext,
                                  'Filter by delivery ID, package ID, summary ID, digest, site ID, optimizer, or warm start',
                                ),
                                prefixIcon: const Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tHqFeatureFlags(
                                dialogContext,
                                'Showing ${filteredRecords.length} of ${records.length}',
                              ),
                              style: const TextStyle(
                                color: ScholesaColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (filteredRecords.isEmpty)
                              Text(
                                _tHqFeatureFlags(
                                  dialogContext,
                                  'No runtime deliveries match current filter.',
                                ),
                              )
                            else
                              ...filteredRecords.map(
                                (FederatedLearningRuntimeDeliveryRecordModel
                                    record) {
                                  final FederatedLearningCandidateModelPackageModel?
                                      package = packagesById[
                                          record.candidateModelPackageId];
                                  final String aggregationRunId =
                                      record.aggregationRunId.trim().isNotEmpty
                                          ? record.aggregationRunId
                                          : package?.aggregationRunId ?? '';
                                  final String mergeArtifactId =
                                      record.mergeArtifactId.trim().isNotEmpty
                                          ? record.mergeArtifactId
                                          : package?.mergeArtifactId ?? '';
                                  final String packageDigest =
                                      record.packageDigest.trim().isNotEmpty
                                          ? record.packageDigest
                                          : package?.packageDigest ?? '';
                                  final String boundedDigest =
                                      record.boundedDigest.trim().isNotEmpty
                                          ? record.boundedDigest
                                          : package?.boundedDigest ?? '';
                                  final String triggerSummaryId =
                                      record.triggerSummaryId.trim().isNotEmpty
                                          ? record.triggerSummaryId
                                          : package?.triggerSummaryId ?? '';
                                  final List<String> summaryIds = record
                                          .summaryIds.isNotEmpty
                                      ? record.summaryIds
                                      : package?.summaryIds ?? const <String>[];
                                  final String localTrainingRollup =
                                      _formatLocalTrainingRollup(summaryIds);
                                  final String runtimePayloadSummary =
                                      _formatRuntimePayloadSummary(package);
                                  final String compatibilityRollup =
                                      _formatRuntimeDeliveryCompatibilityRollup(
                                    record,
                                    package,
                                  );
                                  final List<
                                          FederatedLearningContributionDetailModel>
                                      contributionDetails =
                                      package?.contributionDetails ??
                                          const <FederatedLearningContributionDetailModel>[];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _tHqFeatureFlags(
                                            dialogContext,
                                            '${record.id} · ${record.status} · ${record.targetSiteIds.length} sites · ${record.runtimeTarget}',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _tHqFeatureFlags(
                                            dialogContext,
                                            'Lifecycle: ${_runtimeDeliveryLifecycleDetail(record)}',
                                          ),
                                          style: const TextStyle(
                                            color: ScholesaColors.textSecondary,
                                          ),
                                        ),
                                        if (aggregationRunId
                                                .trim()
                                                .isNotEmpty ||
                                            mergeArtifactId
                                                .trim()
                                                .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              'Aggregation run: $aggregationRunId · Artifact: $mergeArtifactId',
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (packageDigest.trim().isNotEmpty ||
                                            boundedDigest
                                                .trim()
                                                .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              'Delivery digests: package $packageDigest · bounded $boundedDigest',
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (runtimePayloadSummary
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              runtimePayloadSummary,
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (compatibilityRollup
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              compatibilityRollup,
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (contributionDetails
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              _formatContributionRollup(
                                                contributionDetails,
                                                summaryCount: summaryIds.length,
                                                effectiveTotalWeight: package
                                                    ?.effectiveTotalWeight,
                                                fallbackRawTotalWeight:
                                                    package?.sampleCount ?? 0,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (triggerSummaryId
                                            .trim()
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              'Trigger summary: $triggerSummaryId',
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (summaryIds.isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              'Accepted summaries: ${summaryIds.join(', ')}',
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (localTrainingRollup
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              localTrainingRollup,
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (contributionDetails
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              'Contribution detail: ${_formatContributionDetailPreview(contributionDetails)}',
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if ((record.revocationReason ?? '')
                                            .trim()
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            _tHqFeatureFlags(
                                              dialogContext,
                                              'Revocation reason: ${record.revocationReason}',
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  ScholesaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (aggregationRunId.trim().isNotEmpty ||
                                            summaryIds.isNotEmpty ||
                                            triggerSummaryId
                                                .trim()
                                                .isNotEmpty ||
                                            contributionDetails
                                                .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: <Widget>[
                                              if (aggregationRunId
                                                  .trim()
                                                  .isNotEmpty)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showAggregationHistoryDialog(
                                                    experiment,
                                                    initialQuery:
                                                        aggregationRunId,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.timeline_rounded,
                                                  ),
                                                  label: Text(
                                                    _tHqFeatureFlags(
                                                      dialogContext,
                                                      'Open aggregation run',
                                                    ),
                                                  ),
                                                ),
                                              if (summaryIds.isNotEmpty)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showAcceptedSummaryDialog(
                                                    experiment: experiment,
                                                    summaryIds: summaryIds,
                                                    title: 'Accepted summaries',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.description_rounded,
                                                  ),
                                                  label: Text(
                                                    _tHqFeatureFlags(
                                                      dialogContext,
                                                      'Open accepted summaries',
                                                    ),
                                                  ),
                                                ),
                                              if (triggerSummaryId
                                                  .trim()
                                                  .isNotEmpty)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showAcceptedSummaryDialog(
                                                    experiment: experiment,
                                                    summaryIds: <String>[
                                                      triggerSummaryId,
                                                    ],
                                                    title: 'Trigger summary',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.bolt_rounded,
                                                  ),
                                                  label: Text(
                                                    _tHqFeatureFlags(
                                                      dialogContext,
                                                      'Open trigger summary',
                                                    ),
                                                  ),
                                                ),
                                              if (contributionDetails
                                                  .isNotEmpty)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showContributionDetailsDialog(
                                                    experimentLabel:
                                                        experiment.name,
                                                    details:
                                                        contributionDetails,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.insights_rounded,
                                                  ),
                                                  label: Text(
                                                    _tHqFeatureFlags(
                                                      dialogContext,
                                                      'Open contribution details',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRuntimeRolloutHealthDialog(
    FederatedLearningExperimentModel experiment,
    FederatedLearningRuntimeDeliveryRecordModel delivery,
    List<FederatedLearningRuntimeActivationRecordModel> activationRecords,
  ) async {
    final _RuntimeRolloutHealthSummary summary =
        _buildRuntimeRolloutHealthSummary(delivery, activationRecords);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _tHqFeatureFlags(
              dialogContext,
              'Runtime rollout health: ${experiment.name}',
            ),
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqFeatureFlags(
                      dialogContext,
                      'Summary: ${summary.resolvedCount} resolved · ${summary.stagedCount} staged · ${summary.fallbackCount} fallback · ${summary.pendingCount} pending',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...summary.siteRows.map(
                    (_RuntimeRolloutHealthRow row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _tHqFeatureFlags(
                              dialogContext,
                              '${row.siteId} · ${row.statusLabel}',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tHqFeatureFlags(dialogContext, row.detailLabel),
                            style: const TextStyle(
                              color: ScholesaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tHqFeatureFlags(dialogContext, 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRuntimeRolloutAlertDialog(
    FederatedLearningExperimentModel experiment,
    FederatedLearningRuntimeDeliveryRecordModel delivery,
    _RuntimeRolloutHealthSummary summary,
    FederatedLearningRuntimeRolloutAlertRecordModel? existingAlert,
  ) async {
    String status = existingAlert?.status ?? 'acknowledged';
    final TextEditingController notesController = TextEditingController(
      text: existingAlert?.notes ?? '',
    );

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  dialogContext,
                  'Rollout alert triage: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                          dialogContext,
                          'Current alert: ${summary.fallbackCount} fallback · ${summary.pendingCount} pending',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(dialogContext, 'Status'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('active'),
                          ),
                          DropdownMenuItem(
                            value: 'acknowledged',
                            child: Text('acknowledged'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'acknowledged';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(dialogContext, 'HQ notes'),
                          helperText: _tHqFeatureFlags(
                            dialogContext,
                            'Capture triage context for fallback or pending rollout states.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    try {
      await _workflowBridge.upsertFederatedLearningRuntimeRolloutAlertRecord(
        <String, dynamic>{
          'deliveryRecordId': delivery.id,
          'status': status,
          'notes': notesController.text.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Rollout alert triage saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Rollout alert triage failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRuntimeRolloutAlertHistoryDialog(
    FederatedLearningExperimentModel experiment,
  ) async {
    final List<dynamic> payloads = await Future.wait<dynamic>(<Future<dynamic>>[
      _workflowBridge.listFederatedLearningRuntimeRolloutAlertRecords(
        experimentId: experiment.id,
        limit: 120,
      ),
      _workflowBridge.listFederatedLearningRuntimeDeliveryRecords(
        experimentId: experiment.id,
        limit: 120,
      ),
      _workflowBridge.listFederatedLearningRuntimeRolloutAuditEvents(
        experimentId: experiment.id,
        limit: 160,
      ),
      _workflowBridge.listFederatedLearningRuntimeRolloutEscalationRecords(
        experimentId: experiment.id,
        limit: 120,
      ),
      _workflowBridge
          .listFederatedLearningRuntimeRolloutEscalationHistoryRecords(
        experimentId: experiment.id,
        limit: 160,
      ),
      _workflowBridge.listFederatedLearningRuntimeRolloutControlRecords(
        experimentId: experiment.id,
        limit: 120,
      ),
    ]);

    final List<FederatedLearningRuntimeRolloutAlertRecordModel> records =
        (payloads[0] as List<Map<String, dynamic>>)
            .map((Map<String, dynamic> row) =>
                FederatedLearningRuntimeRolloutAlertRecordModel.fromMap(
                  (row['id'] as String?) ?? 'runtime_rollout_alert_record',
                  row,
                ))
            .toList()
          ..sort((a, b) {
            final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
    final Map<String, FederatedLearningRuntimeDeliveryRecordModel>
        deliveriesById = {
      for (final FederatedLearningRuntimeDeliveryRecordModel delivery
          in (payloads[1] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeDeliveryRecordModel.fromMap(
                    (row['id'] as String?) ?? 'runtime_delivery_record',
                    row,
                  )))
        delivery.id: delivery,
    };
    final Map<String, List<FederatedLearningRuntimeRolloutAuditEventModel>>
        triageEventsByDeliveryId =
        <String, List<FederatedLearningRuntimeRolloutAuditEventModel>>{};
    for (final FederatedLearningRuntimeRolloutAuditEventModel event
        in (payloads[2] as List<Map<String, dynamic>>).map(
            (Map<String, dynamic> row) =>
                FederatedLearningRuntimeRolloutAuditEventModel.fromMap(
                  (row['id'] as String?) ?? 'runtime_rollout_audit_event',
                  row,
                ))) {
      if (!event.action.endsWith('runtime_rollout_alert_record.upsert')) {
        continue;
      }
      triageEventsByDeliveryId
          .putIfAbsent(event.deliveryRecordId,
              () => <FederatedLearningRuntimeRolloutAuditEventModel>[])
          .add(event);
    }
    for (final List<FederatedLearningRuntimeRolloutAuditEventModel> events
        in triageEventsByDeliveryId.values) {
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    final Map<String, FederatedLearningRuntimeRolloutEscalationRecordModel>
        escalationByDeliveryId = {
      for (final FederatedLearningRuntimeRolloutEscalationRecordModel record
          in (payloads[3] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeRolloutEscalationRecordModel.fromMap(
                    (row['id'] as String?) ??
                        'runtime_rollout_escalation_record',
                    row,
                  )))
        record.deliveryRecordId: record,
    };
    final Map<String,
            List<FederatedLearningRuntimeRolloutEscalationHistoryRecordModel>>
        escalationHistoryByDeliveryId = <String,
            List<
                FederatedLearningRuntimeRolloutEscalationHistoryRecordModel>>{};
    for (final FederatedLearningRuntimeRolloutEscalationHistoryRecordModel record
        in (payloads[4] as List<Map<String, dynamic>>).map((Map<String, dynamic>
                row) =>
            FederatedLearningRuntimeRolloutEscalationHistoryRecordModel.fromMap(
              (row['id'] as String?) ??
                  'runtime_rollout_escalation_history_record',
              row,
            ))) {
      escalationHistoryByDeliveryId
          .putIfAbsent(
            record.deliveryRecordId,
            () =>
                <FederatedLearningRuntimeRolloutEscalationHistoryRecordModel>[],
          )
          .add(record);
    }
    for (final List<
            FederatedLearningRuntimeRolloutEscalationHistoryRecordModel> records
        in escalationHistoryByDeliveryId.values) {
      records.sort((a, b) {
        final int aMillis = a.recordedAt?.millisecondsSinceEpoch ?? 0;
        final int bMillis = b.recordedAt?.millisecondsSinceEpoch ?? 0;
        return bMillis.compareTo(aMillis);
      });
    }
    final Map<String, FederatedLearningRuntimeRolloutControlRecordModel>
        rolloutControlsByDeliveryId = {
      for (final FederatedLearningRuntimeRolloutControlRecordModel record
          in (payloads[5] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeRolloutControlRecordModel.fromMap(
                    (row['id'] as String?) ?? 'runtime_rollout_control_record',
                    row,
                  )))
        record.deliveryRecordId: record,
    };
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _tHqFeatureFlags(
              dialogContext,
              'Runtime rollout alert history: ${experiment.name}',
            ),
          ),
          content: SizedBox(
            width: 700,
            child: records.isEmpty
                ? Text(
                    _tHqFeatureFlags(
                      dialogContext,
                      'No rollout alert triage records recorded for this experiment yet.',
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: records.map(
                          (FederatedLearningRuntimeRolloutAlertRecordModel
                              record) {
                        final FederatedLearningRuntimeDeliveryRecordModel?
                            delivery = deliveriesById[record.deliveryRecordId];
                        final FederatedLearningRuntimeRolloutEscalationRecordModel?
                            escalation =
                            escalationByDeliveryId[record.deliveryRecordId];
                        final FederatedLearningRuntimeRolloutControlRecordModel?
                            rolloutControl = rolloutControlsByDeliveryId[
                                record.deliveryRecordId];
                        final List<
                                FederatedLearningRuntimeRolloutEscalationHistoryRecordModel>
                            escalationHistory = escalationHistoryByDeliveryId[
                                    record.deliveryRecordId] ??
                                const <FederatedLearningRuntimeRolloutEscalationHistoryRecordModel>[];
                        final List<
                                FederatedLearningRuntimeRolloutAuditEventModel>
                            triageEvents =
                            triageEventsByDeliveryId[record.deliveryRecordId] ??
                                const <FederatedLearningRuntimeRolloutAuditEventModel>[];
                        final String digestRollup =
                            _formatRuntimeRolloutDigestRollup(
                          packageDigest: record.packageDigest,
                          boundedDigest: record.boundedDigest,
                          manifestDigest: record.manifestDigest,
                        );
                        final String compatibilityRollup =
                            _formatRuntimeRolloutCompatibilityRollup(
                          runtimeTarget: record.runtimeTarget,
                          schemaVersions: record.schemaVersions,
                          optimizerStrategies: record.optimizerStrategies,
                          warmStartPackageId: record.warmStartPackageId,
                          warmStartModelVersion: record.warmStartModelVersion,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _tHqFeatureFlags(
                                  dialogContext,
                                  '${record.deliveryRecordId} · ${record.status} · ${record.fallbackCount} fallback · ${record.pendingCount} pending',
                                ),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              if (delivery != null) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    'Delivery: ${delivery.status} · ${delivery.targetSiteIds.length} sites · ${delivery.runtimeTarget}',
                                  ),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (digestRollup.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(dialogContext, digestRollup),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (compatibilityRollup.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(
                                      dialogContext, compatibilityRollup),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if ((record.notes ?? '')
                                  .trim()
                                  .isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    'HQ notes: ${record.notes!.trim()}',
                                  ),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (record.status == 'acknowledged') ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    'Acknowledged ${_formatTimestamp(record.acknowledgedAt)} by ${record.acknowledgedBy ?? 'hq'}',
                                  ),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (escalation != null) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    _buildRuntimeRolloutEscalationSummary(
                                        escalation),
                                  ),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (rolloutControl != null &&
                                  rolloutControl.mode != 'monitor') ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    _buildRuntimeRolloutControlSummary(
                                        rolloutControl),
                                  ),
                                  style: const TextStyle(
                                    color: ScholesaColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (escalationHistory.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    'Escalation history',
                                  ),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                ...escalationHistory.take(4).map(
                                      (FederatedLearningRuntimeRolloutEscalationHistoryRecordModel
                                              historyRecord) =>
                                          Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          _tHqFeatureFlags(
                                            dialogContext,
                                            _buildRuntimeRolloutEscalationHistoryLine(
                                                historyRecord),
                                          ),
                                          style: const TextStyle(
                                            color: ScholesaColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                              if (triageEvents.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    'Triage history',
                                  ),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                ...triageEvents.take(4).map(
                                      (FederatedLearningRuntimeRolloutAuditEventModel
                                              event) =>
                                          Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          _tHqFeatureFlags(
                                            dialogContext,
                                            _runtimeRolloutTriageHistoryLine(
                                                event),
                                          ),
                                          style: const TextStyle(
                                            color: ScholesaColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () => _showRuntimeRolloutAuditDialog(
                                  experiment,
                                  deliveryRecordId: record.deliveryRecordId,
                                ),
                                icon: const Icon(Icons.receipt_long_rounded),
                                label: Text(
                                  _tHqFeatureFlags(
                                    dialogContext,
                                    'View audit feed',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
          ),
          actions: <Widget>[
            TextButton.icon(
              onPressed: () => _showRuntimeRolloutAuditDialog(experiment),
              icon: const Icon(Icons.receipt_long_rounded),
              label:
                  Text(_tHqFeatureFlags(dialogContext, 'View rollout audit')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tHqFeatureFlags(dialogContext, 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRuntimeRolloutAuditDialog(
    FederatedLearningExperimentModel experiment, {
    String? deliveryRecordId,
  }) async {
    final List<FederatedLearningRuntimeRolloutAuditEventModel> events =
        (await _workflowBridge.listFederatedLearningRuntimeRolloutAuditEvents(
      experimentId: experiment.id,
      deliveryRecordId: deliveryRecordId,
      limit: 160,
    ))
            .map((Map<String, dynamic> row) =>
                FederatedLearningRuntimeRolloutAuditEventModel.fromMap(
                  (row['id'] as String?) ?? 'runtime_rollout_audit_event',
                  row,
                ))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        String selectedPackageId = '';
        String selectedSiteId = '';
        final List<String> packageOptions = events
            .map((event) => event.candidateModelPackageId)
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final List<String> siteOptions = <String>{
          for (final FederatedLearningRuntimeRolloutAuditEventModel event
              in events)
            if (event.siteId.trim().isNotEmpty) event.siteId,
          for (final FederatedLearningRuntimeRolloutAuditEventModel event
              in events)
            ...event.targetSiteIds.where((value) => value.trim().isNotEmpty),
        }.toList()
          ..sort();

        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final List<FederatedLearningRuntimeRolloutAuditEventModel>
                filteredEvents = events
                    .where((event) =>
                        (selectedPackageId.isEmpty ||
                            event.candidateModelPackageId ==
                                selectedPackageId) &&
                        (selectedSiteId.isEmpty ||
                            event.siteId == selectedSiteId ||
                            event.targetSiteIds.contains(selectedSiteId)))
                    .toList(growable: false);

            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  dialogContext,
                  deliveryRecordId == null
                      ? 'Runtime rollout audit: ${experiment.name}'
                      : 'Runtime rollout audit: ${experiment.name} · $deliveryRecordId',
                ),
              ),
              content: SizedBox(
                width: 760,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (packageOptions.isNotEmpty ||
                        siteOptions.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          if (packageOptions.isNotEmpty)
                            SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedPackageId,
                                decoration: InputDecoration(
                                  labelText: _tHqFeatureFlags(
                                      dialogContext, 'Package filter'),
                                ),
                                items: <DropdownMenuItem<String>>[
                                  DropdownMenuItem(
                                    value: '',
                                    child: Text(_tHqFeatureFlags(
                                        dialogContext, 'All packages')),
                                  ),
                                  ...packageOptions.map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  ),
                                ],
                                onChanged: (String? value) {
                                  setDialogState(() {
                                    selectedPackageId = value ?? '';
                                  });
                                },
                              ),
                            ),
                          if (siteOptions.isNotEmpty)
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedSiteId,
                                decoration: InputDecoration(
                                  labelText: _tHqFeatureFlags(
                                      dialogContext, 'Site filter'),
                                ),
                                items: <DropdownMenuItem<String>>[
                                  DropdownMenuItem(
                                    value: '',
                                    child: Text(_tHqFeatureFlags(
                                        dialogContext, 'All sites')),
                                  ),
                                  ...siteOptions.map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  ),
                                ],
                                onChanged: (String? value) {
                                  setDialogState(() {
                                    selectedSiteId = value ?? '';
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _tHqFeatureFlags(
                        dialogContext,
                        'Showing ${filteredEvents.length} audit events',
                      ),
                      style: const TextStyle(
                        color: ScholesaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredEvents.isEmpty
                          ? SingleChildScrollView(
                              child: Text(
                                _tHqFeatureFlags(
                                  dialogContext,
                                  'No rollout audit events recorded for this scope yet.',
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: filteredEvents.map(
                                    (FederatedLearningRuntimeRolloutAuditEventModel
                                        event) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _tHqFeatureFlags(
                                            dialogContext,
                                            _runtimeRolloutAuditTitle(event),
                                          ),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _tHqFeatureFlags(
                                            dialogContext,
                                            _runtimeRolloutAuditDetail(event),
                                          ),
                                          style: const TextStyle(
                                            color: ScholesaColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRuntimeRolloutEscalationDialog(
    FederatedLearningExperimentModel experiment,
    FederatedLearningRuntimeDeliveryRecordModel delivery,
    _RuntimeRolloutHealthSummary summary,
    FederatedLearningRuntimeRolloutEscalationRecordModel? existingEscalation,
  ) async {
    String status = existingEscalation?.status ?? 'open';
    final TextEditingController ownerController = TextEditingController(
      text: existingEscalation?.ownerUserId ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existingEscalation?.notes ?? '',
    );

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  dialogContext,
                  'Rollout escalation: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                          dialogContext,
                          'Current issue: ${summary.fallbackCount} fallback · ${summary.pendingCount} pending',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(
                              dialogContext, 'Escalation status'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'open', child: Text('open')),
                          DropdownMenuItem(
                            value: 'investigating',
                            child: Text('investigating'),
                          ),
                          DropdownMenuItem(
                              value: 'resolved', child: Text('resolved')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'open';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerController,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(dialogContext, 'Owner user ID'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(
                              dialogContext, 'Escalation notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    try {
      await _workflowBridge
          .upsertFederatedLearningRuntimeRolloutEscalationRecord(
        <String, dynamic>{
          'deliveryRecordId': delivery.id,
          'status': status,
          'ownerUserId': ownerController.text.trim(),
          'notes': notesController.text.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Rollout escalation saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Rollout escalation failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRuntimeRolloutControlDialog(
    FederatedLearningExperimentModel experiment,
    FederatedLearningRuntimeDeliveryRecordModel delivery,
    FederatedLearningRuntimeRolloutControlRecordModel? existingControl,
  ) async {
    String mode = existingControl?.mode ?? 'monitor';
    final TextEditingController ownerController = TextEditingController(
      text: existingControl?.ownerUserId ?? '',
    );
    final TextEditingController reasonController = TextEditingController(
      text: existingControl?.reason ?? '',
    );

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  dialogContext,
                  'Rollout control: ${experiment.name}',
                ),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tHqFeatureFlags(
                          dialogContext,
                          'Delivery ${delivery.id} stays immutable; this control is an HQ operator override for rollout handling only.',
                        ),
                        style: const TextStyle(
                          color: ScholesaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(dialogContext, 'Control mode'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'monitor', child: Text('monitor')),
                          DropdownMenuItem(
                              value: 'restricted', child: Text('restricted')),
                          DropdownMenuItem(
                              value: 'paused', child: Text('paused')),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            mode = value ?? 'monitor';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerController,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(dialogContext, 'Owner user ID'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reasonController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(dialogContext, 'Control reason'),
                          helperText: _tHqFeatureFlags(
                            dialogContext,
                            'Restricted or paused control should state the bounded operator reason.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_tHqFeatureFlags(dialogContext, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    try {
      await _workflowBridge.upsertFederatedLearningRuntimeRolloutControlRecord(
        <String, dynamic>{
          'deliveryRecordId': delivery.id,
          'mode': mode,
          'ownerUserId': ownerController.text.trim(),
          'reason': reasonController.text.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Rollout control saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Rollout control failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRuntimeActivationHistoryDialog(
    FederatedLearningExperimentModel experiment,
    FederatedLearningCandidateModelPackageModel candidatePackage,
    List<FederatedLearningRuntimeActivationRecordModel> activationRecords,
  ) async {
    final List<FederatedLearningRuntimeActivationRecordModel> records =
        List<FederatedLearningRuntimeActivationRecordModel>.from(
      activationRecords,
    )..sort((a, b) {
            final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
    final int resolvedCount =
        records.where((record) => record.status == 'resolved').length;
    final int stagedCount =
        records.where((record) => record.status == 'staged').length;
    final int fallbackCount =
        records.where((record) => record.status == 'fallback').length;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _tHqFeatureFlags(
              dialogContext,
              'Runtime activation history: ${experiment.name}',
            ),
          ),
          content: SizedBox(
            width: 640,
            child: records.isEmpty
                ? Text(
                    _tHqFeatureFlags(
                      dialogContext,
                      'No runtime activation reports recorded for ${candidatePackage.id} yet.',
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _tHqFeatureFlags(
                            dialogContext,
                            'Summary: $resolvedCount resolved · $stagedCount staged · $fallbackCount fallback',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        ...records.map(
                          (FederatedLearningRuntimeActivationRecordModel
                              record) {
                            final String compatibilityRollup =
                                _formatRuntimeActivationCompatibilityRollup(
                              record,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _tHqFeatureFlags(
                                      dialogContext,
                                      '${record.siteId} · ${record.status} · ${record.runtimeTarget}',
                                    ),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _tHqFeatureFlags(
                                      dialogContext,
                                      'Reported ${_formatTimestamp(record.updatedAt)} · manifest ${record.manifestDigest}',
                                    ),
                                    style: const TextStyle(
                                      color: ScholesaColors.textSecondary,
                                    ),
                                  ),
                                  if (record.packageDigest.trim().isNotEmpty ||
                                      record.boundedDigest
                                          .trim()
                                          .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 2),
                                    Text(
                                      _tHqFeatureFlags(
                                        dialogContext,
                                        'Digests: package ${record.packageDigest} · bounded ${record.boundedDigest}',
                                      ),
                                      style: const TextStyle(
                                        color: ScholesaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (compatibilityRollup
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 2),
                                    Text(
                                      _tHqFeatureFlags(
                                        dialogContext,
                                        compatibilityRollup,
                                      ),
                                      style: const TextStyle(
                                        color: ScholesaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if ((record.notes ?? '')
                                      .trim()
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 2),
                                    Text(
                                      _tHqFeatureFlags(
                                          dialogContext, record.notes!),
                                      style: const TextStyle(
                                        color: ScholesaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tHqFeatureFlags(dialogContext, 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCandidatePromotionRevocationDialog({
    required FederatedLearningCandidatePromotionRecordModel record,
    VoidCallback? refreshDialog,
  }) async {
    final TextEditingController rationaleController = TextEditingController();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _tHqFeatureFlags(context, 'Revoke package decision'),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tHqFeatureFlags(
                      context,
                      'Decision: ${record.id} · ${record.status} (${record.target})',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rationaleController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText:
                          _tHqFeatureFlags(context, 'Rollback rationale'),
                      helperText: _tHqFeatureFlags(
                        context,
                        'Saved as bounded rollback proof for the sandbox-eval record.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_tHqFeatureFlags(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_tHqFeatureFlags(context, 'Save rollback')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await _revokeCandidatePromotionDecision(
      candidateModelPackageId: record.candidateModelPackageId,
      rationale: rationaleController.text,
    );
    refreshDialog?.call();
  }

  Future<void> _revokeCandidatePromotionDecision({
    required String candidateModelPackageId,
    required String rationale,
  }) async {
    try {
      await _workflowBridge.revokeFederatedLearningCandidatePromotionRecord(
        <String, dynamic>{
          'candidateModelPackageId': candidateModelPackageId,
          'rationale': rationale.trim(),
        },
      );
      if (!mounted) return;
      await _loadExperiments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Candidate package rollback saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Candidate package rollback failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp? value) {
    if (value == null) return _tHqFeatureFlags(context, 'unknown');
    return value.toDate().toIso8601String();
  }

  String _formatMergeMetric(double? value) {
    if (value == null) return _tHqFeatureFlags(context, 'unknown');
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(3);
  }

  String _formatSiteList(List<String> siteIds) {
    if (siteIds.isEmpty) return _tHqFeatureFlags(context, 'none');
    return siteIds.join(', ');
  }

  String _summarizeRuntimeDeliveryLifecycle(
    FederatedLearningRuntimeDeliveryRecordModel record,
  ) {
    return 'Runtime lifecycle: ${_runtimeDeliveryLifecycleDetail(record)}';
  }

  String _runtimeDeliveryLifecycleDetail(
    FederatedLearningRuntimeDeliveryRecordModel record,
  ) {
    if (record.status == 'superseded' || record.supersededAt != null) {
      final String byDelivery =
          (record.supersededByDeliveryRecordId ?? '').trim().isEmpty
              ? ''
              : ' by ${record.supersededByDeliveryRecordId!.trim()}';
      final String reason = (record.supersessionReason ?? '').trim().isEmpty
          ? ''
          : ' · ${record.supersessionReason!.trim()}';
      return 'superseded ${_formatTimestamp(record.supersededAt)}$byDelivery$reason';
    }
    if (record.status == 'revoked' || record.revokedAt != null) {
      final String revokedBy = (record.revokedBy ?? '').trim().isEmpty
          ? ''
          : ' by ${record.revokedBy!.trim()}';
      final String reason = (record.revocationReason ?? '').trim().isEmpty
          ? ''
          : ' · ${record.revocationReason!.trim()}';
      return 'revoked ${_formatTimestamp(record.revokedAt)}$revokedBy$reason';
    }
    final DateTime? expiresAt = record.expiresAt?.toDate().toUtc();
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      return 'expired ${_formatTimestamp(record.expiresAt)}';
    }
    if (record.expiresAt != null) {
      return 'live until ${_formatTimestamp(record.expiresAt)}';
    }
    return 'no expiry recorded';
  }

  String _buildRuntimeActivationSummary(
    FederatedLearningRuntimeDeliveryRecordModel? latestRuntimeDelivery,
    FederatedLearningRuntimeActivationRecordModel? latestRuntimeActivation,
    List<FederatedLearningRuntimeActivationRecordModel>
        runtimeActivationRecords,
  ) {
    if (latestRuntimeActivation != null) {
      return 'Runtime activation: ${latestRuntimeActivation.status} · ${runtimeActivationRecords.length} site reports · ${latestRuntimeActivation.runtimeTarget}';
    }
    if (latestRuntimeDelivery != null &&
        _isRuntimeDeliveryTerminalLifecycle(latestRuntimeDelivery)) {
      return 'Runtime activation: none recorded · ${_runtimeDeliveryLifecycleDetail(latestRuntimeDelivery)}';
    }
    return 'Runtime activation: pending';
  }

  bool _isRuntimeRolloutAlertAcknowledged(
    _RuntimeRolloutHealthSummary summary,
    FederatedLearningRuntimeRolloutAlertRecordModel? alertRecord,
  ) {
    if (alertRecord?.status != 'acknowledged') {
      return false;
    }
    return alertRecord!.fallbackCount == summary.fallbackCount &&
        alertRecord.pendingCount == summary.pendingCount &&
        (summary.fallbackCount > 0 || summary.pendingCount > 0);
  }

  bool _isRuntimeRolloutEscalationCurrent(
    _RuntimeRolloutHealthSummary summary,
    FederatedLearningRuntimeRolloutEscalationRecordModel? escalationRecord,
  ) {
    if (escalationRecord == null) {
      return false;
    }
    if (escalationRecord.status == 'resolved') {
      return false;
    }
    return escalationRecord.fallbackCount == summary.fallbackCount &&
        escalationRecord.pendingCount == summary.pendingCount &&
        (summary.fallbackCount > 0 || summary.pendingCount > 0);
  }

  String _buildRuntimeRolloutAlert(
    _RuntimeRolloutHealthSummary summary,
    FederatedLearningRuntimeRolloutAlertRecordModel? alertRecord,
  ) {
    final List<String> parts = <String>[];
    if (summary.fallbackCount > 0) {
      parts.add('${summary.fallbackCount} fallback');
    }
    if (summary.pendingCount > 0) {
      parts.add('${summary.pendingCount} pending');
    }
    if (parts.isEmpty) {
      return '';
    }
    if (_isRuntimeRolloutAlertAcknowledged(summary, alertRecord)) {
      return 'Rollout alert acknowledged: ${parts.join(' · ')} site statuses reviewed. Use Site rollout for detail.';
    }
    return 'Rollout alert: ${parts.join(' · ')} site statuses need review. Use Site rollout for detail.';
  }

  String _runtimeRolloutAuditTitle(
    FederatedLearningRuntimeRolloutAuditEventModel event,
  ) {
    final String timestamp = DateTime.fromMillisecondsSinceEpoch(
      event.timestamp,
      isUtc: true,
    ).toIso8601String();
    if (event.action.endsWith('runtime_delivery_record.upsert')) {
      return '$timestamp · Delivery ${event.deliveryRecordId} · ${event.status}';
    }
    if (event.action.endsWith('runtime_activation_record.upsert')) {
      return '$timestamp · Activation ${event.siteId} · ${event.status}';
    }
    if (event.action.endsWith('runtime_rollout_escalation_record.upsert')) {
      return '$timestamp · Escalation ${event.deliveryRecordId} · ${event.status}';
    }
    if (event.action.endsWith('runtime_rollout_control_record.upsert')) {
      return '$timestamp · Control ${event.deliveryRecordId} · ${event.mode}';
    }
    return '$timestamp · Alert triage ${event.deliveryRecordId} · ${event.status}';
  }

  String _runtimeRolloutAuditDetail(
    FederatedLearningRuntimeRolloutAuditEventModel event,
  ) {
    final String digestRollup = _formatRuntimeRolloutDigestRollup(
      packageDigest: event.packageDigest,
      boundedDigest: event.boundedDigest,
      manifestDigest: event.manifestDigest,
    );
    final String compatibilityRollup = _formatRuntimeRolloutCompatibilityRollup(
      runtimeTarget: event.runtimeTarget,
      schemaVersions: event.schemaVersions,
      optimizerStrategies: event.optimizerStrategies,
      warmStartPackageId: event.warmStartPackageId,
      warmStartModelVersion: event.warmStartModelVersion,
    );
    final String digestSuffix = digestRollup.isEmpty ? '' : ' · $digestRollup';
    final String compatibilitySuffix =
        compatibilityRollup.isEmpty ? '' : ' · $compatibilityRollup';
    if (event.action.endsWith('runtime_delivery_record.upsert')) {
      final String sites = event.targetSiteIds.isEmpty
          ? 'no target sites'
          : event.targetSiteIds.join(', ');
      return 'Sites: $sites · runtime ${event.runtimeTarget} · manifest ${event.manifestDigest}$digestSuffix$compatibilitySuffix';
    }
    if (event.action.endsWith('runtime_activation_record.upsert')) {
      return 'Delivery ${event.deliveryRecordId} · site ${event.siteId} · runtime ${event.runtimeTarget} · manifest ${event.manifestDigest}$digestSuffix$compatibilitySuffix';
    }
    if (event.action.endsWith('runtime_rollout_escalation_record.upsert')) {
      final String owner =
          event.ownerUserId.trim().isEmpty ? 'unassigned' : event.ownerUserId;
      return 'Delivery ${event.deliveryRecordId} · owner $owner · ${event.fallbackCount} fallback · ${event.pendingCount} pending$digestSuffix$compatibilitySuffix';
    }
    if (event.action.endsWith('runtime_rollout_control_record.upsert')) {
      final String owner =
          event.ownerUserId.trim().isEmpty ? 'unassigned' : event.ownerUserId;
      final String reason =
          event.reason.trim().isEmpty ? '' : ' · ${event.reason.trim()}';
      return 'Delivery ${event.deliveryRecordId} · mode ${event.mode} · owner $owner$reason$digestSuffix$compatibilitySuffix';
    }
    return 'Delivery ${event.deliveryRecordId} · ${event.fallbackCount} fallback · ${event.pendingCount} pending$digestSuffix$compatibilitySuffix';
  }

  String _runtimeRolloutTriageHistoryLine(
    FederatedLearningRuntimeRolloutAuditEventModel event,
  ) {
    final String notes =
        event.notes.trim().isEmpty ? '' : ' · ${event.notes.trim()}';
    final String actor =
        event.userId?.trim().isNotEmpty == true ? event.userId!.trim() : 'hq';
    return '${DateTime.fromMillisecondsSinceEpoch(event.timestamp, isUtc: true).toIso8601String()} · ${event.status} by $actor$notes';
  }

  String _buildRuntimeRolloutEscalationSummary(
    FederatedLearningRuntimeRolloutEscalationRecordModel record,
  ) {
    final String owner = (record.ownerUserId ?? '').trim().isEmpty
        ? 'unassigned'
        : record.ownerUserId!.trim();
    final String due = _buildRuntimeRolloutEscalationDueSegment(record);
    final String notes = (record.notes ?? '').trim().isEmpty
        ? ''
        : ' · ${(record.notes ?? '').trim()}';
    final String resolved = record.status == 'resolved'
        ? ' · resolved ${_formatTimestamp(record.resolvedAt)}'
        : '';
    final String digest =
        _buildRuntimeRolloutBoundedDigestSuffix(record.boundedDigest);
    return 'Escalation: ${record.status} · owner $owner$due$resolved$digest$notes';
  }

  String _buildRuntimeRolloutEscalationHistoryLine(
    FederatedLearningRuntimeRolloutEscalationHistoryRecordModel record,
  ) {
    final String owner = (record.ownerUserId ?? '').trim().isEmpty
        ? 'unassigned'
        : record.ownerUserId!.trim();
    final String due = _buildRuntimeRolloutEscalationHistoryDueSegment(record);
    final String notes = (record.notes ?? '').trim().isEmpty
        ? ''
        : ' · ${(record.notes ?? '').trim()}';
    final String actor = (record.recordedBy ?? '').trim().isEmpty
        ? 'hq'
        : record.recordedBy!.trim();
    final String digest =
        _buildRuntimeRolloutBoundedDigestSuffix(record.boundedDigest);
    return '${_formatTimestamp(record.recordedAt)} · ${record.status} by $actor · owner $owner$due$digest$notes';
  }

  String _buildRuntimeRolloutControlSummary(
    FederatedLearningRuntimeRolloutControlRecordModel record,
  ) {
    final String owner = (record.ownerUserId ?? '').trim().isEmpty
        ? 'unassigned'
        : record.ownerUserId!.trim();
    final String reason = (record.reason ?? '').trim().isEmpty
        ? ''
        : ' · ${(record.reason ?? '').trim()}';
    final String reviewBy = record.reviewByAt == null
        ? ''
        : ' · review by ${_formatTimestamp(record.reviewByAt)}';
    final String released =
        record.mode == 'monitor' && record.releasedAt != null
            ? ' · released ${_formatTimestamp(record.releasedAt)}'
            : '';
    final String digest =
        _buildRuntimeRolloutBoundedDigestSuffix(record.boundedDigest);
    return 'Control: ${record.mode} · owner $owner$reviewBy$released$digest$reason';
  }

  String _buildRuntimeRolloutEscalationDueSegment(
    FederatedLearningRuntimeRolloutEscalationRecordModel record,
  ) {
    if (record.status == 'resolved' || record.dueAt == null) {
      return '';
    }
    final DateTime dueAt = record.dueAt!.toDate().toUtc();
    final DateTime now = DateTime.now().toUtc();
    if (!dueAt.isAfter(now)) {
      return ' · overdue ${_formatTimestamp(record.dueAt)}';
    }
    if (dueAt.difference(now).inHours <= 6) {
      return ' · due ${_formatTimestamp(record.dueAt)}';
    }
    return '';
  }

  String _buildRuntimeRolloutEscalationHistoryDueSegment(
    FederatedLearningRuntimeRolloutEscalationHistoryRecordModel record,
  ) {
    if (record.status == 'resolved' || record.dueAt == null) {
      return '';
    }
    final DateTime dueAt = record.dueAt!.toDate().toUtc();
    final DateTime now = DateTime.now().toUtc();
    if (!dueAt.isAfter(now)) {
      return ' · overdue ${_formatTimestamp(record.dueAt)}';
    }
    if (dueAt.difference(now).inHours <= 6) {
      return ' · due ${_formatTimestamp(record.dueAt)}';
    }
    return '';
  }

  int _compareExperimentPriority(
    FederatedLearningExperimentModel a,
    FederatedLearningExperimentModel b,
  ) {
    final int severityDelta = _rolloutAlertSeverityForExperiment(b) -
        _rolloutAlertSeverityForExperiment(a);
    if (severityDelta != 0) {
      return severityDelta;
    }
    final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
    final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
    return bMillis.compareTo(aMillis);
  }

  int _rolloutAlertSeverityForExperiment(
    FederatedLearningExperimentModel experiment,
  ) {
    final List<FederatedLearningAggregationRunModel> runs =
        _aggregationRunsByExperiment[experiment.id] ??
            const <FederatedLearningAggregationRunModel>[];
    if (runs.isEmpty) {
      return 0;
    }
    final Map<String, FederatedLearningCandidateModelPackageModel>
        candidatePackagesByRunId = {
      for (final FederatedLearningCandidateModelPackageModel package
          in _candidatePackagesByExperiment[experiment.id] ??
              const <FederatedLearningCandidateModelPackageModel>[])
        package.aggregationRunId: package,
    };
    final FederatedLearningCandidateModelPackageModel? latestPackage =
        candidatePackagesByRunId[runs.first.id];
    if (latestPackage == null) {
      return 0;
    }
    final FederatedLearningRuntimeDeliveryRecordModel? latestRuntimeDelivery =
        _runtimeDeliveryRecordsByPackageId[latestPackage.id];
    if (latestRuntimeDelivery == null) {
      return 0;
    }
    if (_isRuntimeDeliveryTerminalLifecycle(latestRuntimeDelivery)) {
      return 0;
    }
    final List<FederatedLearningRuntimeActivationRecordModel>
        runtimeActivationRecords =
        _runtimeActivationRecordsByPackageId[latestPackage.id] ??
            const <FederatedLearningRuntimeActivationRecordModel>[];
    final _RuntimeRolloutHealthSummary summary =
        _buildRuntimeRolloutHealthSummary(
      latestRuntimeDelivery,
      runtimeActivationRecords,
    );
    final FederatedLearningRuntimeRolloutAlertRecordModel? alertRecord =
        _runtimeRolloutAlertsByDeliveryId[latestRuntimeDelivery.id];
    if (_isRuntimeRolloutAlertAcknowledged(summary, alertRecord)) {
      return 0;
    }
    if (summary.fallbackCount > 0) {
      return 2;
    }
    if (summary.pendingCount > 0) {
      return 1;
    }
    return 0;
  }

  _RuntimeRolloutHealthSummary _buildRuntimeRolloutHealthSummary(
    FederatedLearningRuntimeDeliveryRecordModel delivery,
    List<FederatedLearningRuntimeActivationRecordModel> activationRecords,
  ) {
    final Map<String, FederatedLearningRuntimeActivationRecordModel>
        latestActivationBySite =
        <String, FederatedLearningRuntimeActivationRecordModel>{};
    for (final FederatedLearningRuntimeActivationRecordModel record
        in activationRecords) {
      if (record.deliveryRecordId != delivery.id) {
        continue;
      }
      final FederatedLearningRuntimeActivationRecordModel? existing =
          latestActivationBySite[record.siteId];
      final int recordMillis = record.updatedAt?.millisecondsSinceEpoch ?? 0;
      final int existingMillis =
          existing?.updatedAt?.millisecondsSinceEpoch ?? 0;
      if (existing == null || recordMillis > existingMillis) {
        latestActivationBySite[record.siteId] = record;
      }
    }

    final List<_RuntimeRolloutHealthRow> rows = delivery.targetSiteIds
        .map((siteId) => _buildRuntimeRolloutHealthRow(
              siteId,
              delivery,
              latestActivationBySite[siteId],
            ))
        .toList(growable: false);

    return _RuntimeRolloutHealthSummary(
      siteRows: rows,
      resolvedCount: rows.where((row) => row.status == 'resolved').length,
      stagedCount: rows.where((row) => row.status == 'staged').length,
      fallbackCount: rows.where((row) => row.status == 'fallback').length,
      pendingCount: rows.where((row) => row.status == 'pending').length,
    );
  }

  bool _isRuntimeDeliveryTerminalLifecycle(
    FederatedLearningRuntimeDeliveryRecordModel delivery,
  ) {
    if (delivery.status == 'superseded' || delivery.supersededAt != null) {
      return true;
    }
    if (delivery.status == 'revoked' || delivery.revokedAt != null) {
      return true;
    }
    final DateTime? expiresAt = delivery.expiresAt?.toDate().toUtc();
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      return true;
    }
    return false;
  }

  _RuntimeRolloutHealthRow _buildRuntimeRolloutHealthRow(
    String siteId,
    FederatedLearningRuntimeDeliveryRecordModel delivery,
    FederatedLearningRuntimeActivationRecordModel? activation,
  ) {
    if (delivery.status == 'superseded' || delivery.supersededAt != null) {
      final String byDelivery =
          (delivery.supersededByDeliveryRecordId ?? '').trim().isEmpty
              ? 'newer delivery'
              : delivery.supersededByDeliveryRecordId!.trim();
      final String reason =
          (delivery.supersessionReason ?? '').trim().isNotEmpty
              ? ' ${(delivery.supersessionReason ?? '').trim()}'
              : '';
      return _RuntimeRolloutHealthRow(
        siteId: siteId,
        status: 'fallback',
        statusLabel: 'fallback',
        detailLabel: 'Delivery superseded by $byDelivery.$reason',
      );
    }
    if (delivery.status == 'revoked' || delivery.revokedAt != null) {
      final String reason = (delivery.revocationReason ?? '').trim().isNotEmpty
          ? delivery.revocationReason!.trim()
          : 'HQ revoked this delivery';
      return _RuntimeRolloutHealthRow(
        siteId: siteId,
        status: 'fallback',
        statusLabel: 'fallback',
        detailLabel: 'Delivery revoked. $reason',
      );
    }

    final DateTime? expiresAt = delivery.expiresAt?.toDate().toUtc();
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      return _RuntimeRolloutHealthRow(
        siteId: siteId,
        status: 'fallback',
        statusLabel: 'fallback',
        detailLabel:
            'Delivery expired at ${_formatTimestamp(delivery.expiresAt)}.',
      );
    }

    if (activation == null) {
      return _RuntimeRolloutHealthRow(
        siteId: siteId,
        status: 'pending',
        statusLabel: 'pending',
        detailLabel: 'No site activation report recorded yet.',
      );
    }

    final String label = activation.status;
    final String detail = activation.status == 'fallback'
        ? 'Latest site report requested fallback.'
        : 'Latest site report ${activation.status} at ${_formatTimestamp(activation.updatedAt)}.';
    return _RuntimeRolloutHealthRow(
      siteId: siteId,
      status: activation.status,
      statusLabel: label,
      detailLabel: detail,
    );
  }

  Widget _buildExperimentChip(
    String label,
    IconData icon, {
    Color? color,
  }) {
    final Color resolvedColor = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            _tHqFeatureFlags(context, label),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: resolvedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String scope) {
    late final Color color;
    late final IconData icon;
    if (scope == 'global') {
      color = Colors.green;
      icon = Icons.public_rounded;
    } else if (scope == 'site') {
      color = Colors.blue;
      icon = Icons.location_on_rounded;
    } else if (scope == 'user') {
      color = Colors.purple;
      icon = Icons.person_rounded;
    } else {
      color = Colors.grey;
      icon = Icons.flag_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(_tHqFeatureFlags(context, scope),
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    await Future.wait(<Future<void>>[
      _loadFlags(),
      _loadExperiments(),
    ]);
  }

  Future<void> _loadFlags() async {
    if (!mounted) return;
    setState(() => _isLoadingFlags = true);
    try {
      final List<_FeatureFlag> loaded =
          (await _workflowBridge.listFeatureFlags())
              .map(_mapToFeatureFlag)
              .toList();

      if (!mounted) return;
      setState(() {
        _flags = loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _flags = <_FeatureFlag>[]);
    } finally {
      if (mounted) {
        setState(() => _isLoadingFlags = false);
      }
    }
  }

  Future<void> _loadExperiments() async {
    if (!mounted) return;
    setState(() => _isLoadingExperiments = true);
    try {
      final List<dynamic> payloads =
          await Future.wait<dynamic>(<Future<dynamic>>[
        _workflowBridge.listFederatedLearningExperiments(),
        _workflowBridge.listFederatedLearningExperimentReviewRecords(
            limit: 120),
        _workflowBridge.listFederatedLearningAggregationRuns(limit: 120),
        _workflowBridge.listFederatedLearningMergeArtifacts(limit: 120),
        _workflowBridge.listFederatedLearningCandidateModelPackages(limit: 120),
        _workflowBridge.listFederatedLearningPilotEvidenceRecords(limit: 120),
        _workflowBridge.listFederatedLearningPilotApprovalRecords(limit: 120),
        _workflowBridge.listFederatedLearningPilotExecutionRecords(limit: 120),
        _workflowBridge.listFederatedLearningRuntimeDeliveryRecords(limit: 120),
        _workflowBridge.listFederatedLearningRuntimeActivationRecords(
            limit: 120),
        _workflowBridge.listFederatedLearningRuntimeRolloutAlertRecords(
            limit: 120),
        _workflowBridge.listFederatedLearningRuntimeRolloutEscalationRecords(
            limit: 120),
        _workflowBridge.listFederatedLearningRuntimeRolloutControlRecords(
            limit: 120),
        _workflowBridge.listFederatedLearningCandidatePromotionRecords(
            limit: 120),
        _workflowBridge
            .listFederatedLearningCandidatePromotionRevocationRecords(
                limit: 120),
      ]);
      final List<FederatedLearningExperimentModel> loaded = (payloads[0]
              as List<Map<String, dynamic>>)
          .map((Map<String, dynamic> row) =>
              FederatedLearningExperimentModel.fromMap(
                (row['id'] as String?) ?? 'experiment',
                row,
              ))
          .toList()
        ..sort((a, b) {
          final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
          final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      final List<FederatedLearningAggregationRunModel> runs = (payloads[2]
              as List<Map<String, dynamic>>)
          .map((Map<String, dynamic> row) =>
              FederatedLearningAggregationRunModel.fromMap(
                (row['id'] as String?) ?? 'aggregation_run',
                row,
              ))
          .toList()
        ..sort((a, b) {
          final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      final Map<String, List<FederatedLearningAggregationRunModel>> runsByExp =
          <String, List<FederatedLearningAggregationRunModel>>{};
      for (final FederatedLearningAggregationRunModel run in runs) {
        runsByExp
            .putIfAbsent(
              run.experimentId,
              () => <FederatedLearningAggregationRunModel>[],
            )
            .add(run);
      }
      final List<FederatedLearningMergeArtifactModel> artifacts = (payloads[3]
              as List<Map<String, dynamic>>)
          .map((Map<String, dynamic> row) =>
              FederatedLearningMergeArtifactModel.fromMap(
                (row['id'] as String?) ?? 'merge_artifact',
                row,
              ))
          .toList()
        ..sort((a, b) {
          final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      final Map<String, List<FederatedLearningMergeArtifactModel>>
          artifactsByExp =
          <String, List<FederatedLearningMergeArtifactModel>>{};
      for (final FederatedLearningMergeArtifactModel artifact in artifacts) {
        artifactsByExp
            .putIfAbsent(
              artifact.experimentId,
              () => <FederatedLearningMergeArtifactModel>[],
            )
            .add(artifact);
      }
      final List<FederatedLearningCandidateModelPackageModel> packages =
          (payloads[4] as List<Map<String, dynamic>>)
              .map((Map<String, dynamic> row) =>
                  FederatedLearningCandidateModelPackageModel.fromMap(
                    (row['id'] as String?) ?? 'candidate_package',
                    row,
                  ))
              .toList()
            ..sort((a, b) {
              final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
              final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
              return bMillis.compareTo(aMillis);
            });
      final Map<String, List<FederatedLearningCandidateModelPackageModel>>
          packagesByExp =
          <String, List<FederatedLearningCandidateModelPackageModel>>{};
      for (final FederatedLearningCandidateModelPackageModel package
          in packages) {
        packagesByExp
            .putIfAbsent(
              package.experimentId,
              () => <FederatedLearningCandidateModelPackageModel>[],
            )
            .add(package);
      }
      final Map<String, FederatedLearningPilotEvidenceRecordModel>
          pilotEvidenceByPackageId =
          <String, FederatedLearningPilotEvidenceRecordModel>{};
      for (final FederatedLearningPilotEvidenceRecordModel record
          in (payloads[5] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningPilotEvidenceRecordModel.fromMap(
                    (row['id'] as String?) ?? 'pilot_evidence_record',
                    row,
                  ))) {
        pilotEvidenceByPackageId[record.candidateModelPackageId] = record;
      }
      final Map<String, FederatedLearningPilotApprovalRecordModel>
          pilotApprovalByPackageId =
          <String, FederatedLearningPilotApprovalRecordModel>{};
      for (final FederatedLearningPilotApprovalRecordModel record
          in (payloads[6] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningPilotApprovalRecordModel.fromMap(
                    (row['id'] as String?) ?? 'pilot_approval_record',
                    row,
                  ))) {
        pilotApprovalByPackageId[record.candidateModelPackageId] = record;
      }
      final Map<String, FederatedLearningPilotExecutionRecordModel>
          pilotExecutionByPackageId =
          <String, FederatedLearningPilotExecutionRecordModel>{};
      for (final FederatedLearningPilotExecutionRecordModel record
          in (payloads[7] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningPilotExecutionRecordModel.fromMap(
                    (row['id'] as String?) ?? 'pilot_execution_record',
                    row,
                  ))) {
        pilotExecutionByPackageId[record.candidateModelPackageId] = record;
      }
      final Map<String, FederatedLearningRuntimeDeliveryRecordModel>
          runtimeDeliveryByPackageId =
          <String, FederatedLearningRuntimeDeliveryRecordModel>{};
      for (final FederatedLearningRuntimeDeliveryRecordModel record
          in (payloads[8] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeDeliveryRecordModel.fromMap(
                    (row['id'] as String?) ?? 'runtime_delivery_record',
                    row,
                  ))) {
        runtimeDeliveryByPackageId[record.candidateModelPackageId] = record;
      }
      final Map<String, List<FederatedLearningRuntimeActivationRecordModel>>
          runtimeActivationByPackageId =
          <String, List<FederatedLearningRuntimeActivationRecordModel>>{};
      for (final FederatedLearningRuntimeActivationRecordModel record
          in (payloads[9] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeActivationRecordModel.fromMap(
                    (row['id'] as String?) ?? 'runtime_activation_record',
                    row,
                  ))) {
        runtimeActivationByPackageId
            .putIfAbsent(
              record.candidateModelPackageId,
              () => <FederatedLearningRuntimeActivationRecordModel>[],
            )
            .add(record);
      }
      for (final List<FederatedLearningRuntimeActivationRecordModel> records
          in runtimeActivationByPackageId.values) {
        records.sort((a, b) {
          final int aMillis = a.updatedAt?.millisecondsSinceEpoch ?? 0;
          final int bMillis = b.updatedAt?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      }
      final Map<String, FederatedLearningRuntimeRolloutAlertRecordModel>
          runtimeRolloutAlertsByDeliveryId =
          <String, FederatedLearningRuntimeRolloutAlertRecordModel>{};
      for (final FederatedLearningRuntimeRolloutAlertRecordModel record
          in (payloads[10] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeRolloutAlertRecordModel.fromMap(
                    (row['id'] as String?) ?? 'runtime_rollout_alert_record',
                    row,
                  ))) {
        runtimeRolloutAlertsByDeliveryId[record.deliveryRecordId] = record;
      }
      final Map<String, FederatedLearningRuntimeRolloutEscalationRecordModel>
          runtimeRolloutEscalationsByDeliveryId =
          <String, FederatedLearningRuntimeRolloutEscalationRecordModel>{};
      for (final FederatedLearningRuntimeRolloutEscalationRecordModel record
          in (payloads[11] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeRolloutEscalationRecordModel.fromMap(
                    (row['id'] as String?) ??
                        'runtime_rollout_escalation_record',
                    row,
                  ))) {
        runtimeRolloutEscalationsByDeliveryId[record.deliveryRecordId] = record;
      }
      final Map<String, FederatedLearningRuntimeRolloutControlRecordModel>
          runtimeRolloutControlsByDeliveryId =
          <String, FederatedLearningRuntimeRolloutControlRecordModel>{};
      for (final FederatedLearningRuntimeRolloutControlRecordModel record
          in (payloads[12] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningRuntimeRolloutControlRecordModel.fromMap(
                    (row['id'] as String?) ?? 'runtime_rollout_control_record',
                    row,
                  ))) {
        runtimeRolloutControlsByDeliveryId[record.deliveryRecordId] = record;
      }
      final Map<String, FederatedLearningExperimentReviewRecordModel>
          reviewRecordsByExperimentId =
          <String, FederatedLearningExperimentReviewRecordModel>{};
      for (final FederatedLearningExperimentReviewRecordModel record
          in (payloads[1] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningExperimentReviewRecordModel.fromMap(
                    (row['id'] as String?) ?? 'experiment_review_record',
                    row,
                  ))) {
        reviewRecordsByExperimentId[record.experimentId] = record;
      }
      final Map<String, FederatedLearningCandidatePromotionRecordModel>
          promotionsByPackageId =
          <String, FederatedLearningCandidatePromotionRecordModel>{};
      for (final FederatedLearningCandidatePromotionRecordModel record
          in (payloads[13] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningCandidatePromotionRecordModel.fromMap(
                    (row['id'] as String?) ?? 'promotion_record',
                    row,
                  ))) {
        promotionsByPackageId[record.candidateModelPackageId] = record;
      }
      final Map<String,
              FederatedLearningCandidatePromotionRevocationRecordModel>
          revocationsByPackageId =
          <String, FederatedLearningCandidatePromotionRevocationRecordModel>{};
      for (final FederatedLearningCandidatePromotionRevocationRecordModel record
          in (payloads[14] as List<Map<String, dynamic>>).map(
              (Map<String, dynamic> row) =>
                  FederatedLearningCandidatePromotionRevocationRecordModel
                      .fromMap(
                    (row['id'] as String?) ?? 'promotion_revocation_record',
                    row,
                  ))) {
        revocationsByPackageId[record.candidateModelPackageId] = record;
      }
      final Set<String> summaryIds = <String>{
        for (final FederatedLearningAggregationRunModel run in runs)
          ...run.summaryIds.where((String id) => id.trim().isNotEmpty),
        for (final FederatedLearningAggregationRunModel run in runs)
          if (run.triggerSummaryId.trim().isNotEmpty) run.triggerSummaryId,
        for (final FederatedLearningCandidateModelPackageModel package
            in packages)
          ...package.summaryIds.where((String id) => id.trim().isNotEmpty),
        for (final FederatedLearningCandidateModelPackageModel package
            in packages)
          if (package.triggerSummaryId.trim().isNotEmpty)
            package.triggerSummaryId,
      };
      Map<String, FederatedLearningUpdateSummaryModel> summariesById =
          <String, FederatedLearningUpdateSummaryModel>{};
      if (summaryIds.isNotEmpty) {
        try {
          summariesById = <String, FederatedLearningUpdateSummaryModel>{
            for (final FederatedLearningUpdateSummaryModel summary
                in await _updateSummaryRepository.listByIds(
              summaryIds.toList()..sort(),
            ))
              summary.id: summary,
          };
        } catch (_) {
          summariesById = <String, FederatedLearningUpdateSummaryModel>{};
        }
      }
      if (!mounted) return;
      setState(() {
        _experiments = loaded;
        _aggregationRunsByExperiment = runsByExp;
        _mergeArtifactsByExperiment = artifactsByExp;
        _candidatePackagesByExperiment = packagesByExp;
        _pilotEvidenceRecordsByPackageId = pilotEvidenceByPackageId;
        _pilotApprovalRecordsByPackageId = pilotApprovalByPackageId;
        _pilotExecutionRecordsByPackageId = pilotExecutionByPackageId;
        _runtimeDeliveryRecordsByPackageId = runtimeDeliveryByPackageId;
        _runtimeActivationRecordsByPackageId = runtimeActivationByPackageId;
        _runtimeRolloutAlertsByDeliveryId = runtimeRolloutAlertsByDeliveryId;
        _runtimeRolloutEscalationsByDeliveryId =
            runtimeRolloutEscalationsByDeliveryId;
        _runtimeRolloutControlsByDeliveryId =
            runtimeRolloutControlsByDeliveryId;
        _experimentReviewRecordsByExperimentId = reviewRecordsByExperimentId;
        _promotionRecordsByPackageId = promotionsByPackageId;
        _promotionRevocationRecordsByPackageId = revocationsByPackageId;
        _updateSummariesById = summariesById;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _experiments = <FederatedLearningExperimentModel>[];
        _aggregationRunsByExperiment =
            <String, List<FederatedLearningAggregationRunModel>>{};
        _mergeArtifactsByExperiment =
            <String, List<FederatedLearningMergeArtifactModel>>{};
        _candidatePackagesByExperiment =
            <String, List<FederatedLearningCandidateModelPackageModel>>{};
        _pilotEvidenceRecordsByPackageId =
            <String, FederatedLearningPilotEvidenceRecordModel>{};
        _pilotApprovalRecordsByPackageId =
            <String, FederatedLearningPilotApprovalRecordModel>{};
        _pilotExecutionRecordsByPackageId =
            <String, FederatedLearningPilotExecutionRecordModel>{};
        _runtimeDeliveryRecordsByPackageId =
            <String, FederatedLearningRuntimeDeliveryRecordModel>{};
        _runtimeActivationRecordsByPackageId =
            <String, List<FederatedLearningRuntimeActivationRecordModel>>{};
        _runtimeRolloutAlertsByDeliveryId =
            <String, FederatedLearningRuntimeRolloutAlertRecordModel>{};
        _runtimeRolloutEscalationsByDeliveryId =
            <String, FederatedLearningRuntimeRolloutEscalationRecordModel>{};
        _runtimeRolloutControlsByDeliveryId =
            <String, FederatedLearningRuntimeRolloutControlRecordModel>{};
        _experimentReviewRecordsByExperimentId =
            <String, FederatedLearningExperimentReviewRecordModel>{};
        _promotionRecordsByPackageId =
            <String, FederatedLearningCandidatePromotionRecordModel>{};
        _promotionRevocationRecordsByPackageId = <String,
            FederatedLearningCandidatePromotionRevocationRecordModel>{};
        _updateSummariesById = <String, FederatedLearningUpdateSummaryModel>{};
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingExperiments = false);
      }
    }
  }

  Future<void> _toggleFlag(_FeatureFlag flag, bool enabled) async {
    try {
      await _workflowBridge.upsertFeatureFlag(<String, dynamic>{
        'id': flag.id,
        'name': flag.name,
        'description': flag.description,
        'enabled': enabled,
        'scope': flag.scope,
        'enabledSites': flag.enabledSites ?? const <String>[],
      });

      if (!mounted) return;
      setState(() => flag.isEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${flag.name} ${enabled ? _tHqFeatureFlags(context, 'enabled') : _tHqFeatureFlags(context, 'disabled')}'),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_tHqFeatureFlags(context, 'Feature flag update failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCreateExperimentDialog() {
    return _showExperimentDialog();
  }

  Future<void> _showExperimentDialog({
    FederatedLearningExperimentModel? existing,
  }) async {
    final TextEditingController nameController =
        TextEditingController(text: existing?.name ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final TextEditingController sitesController = TextEditingController(
      text: existing?.allowedSiteIds.join(', ') ?? '',
    );
    final TextEditingController thresholdController = TextEditingController(
      text: '${existing?.aggregateThreshold ?? 25}',
    );
    final TextEditingController rawBytesController = TextEditingController(
      text: '${existing?.rawUpdateMaxBytes ?? 16384}',
    );
    String runtimeTarget = existing?.runtimeTarget ?? 'flutter_mobile';
    String status = existing?.status ?? 'draft';
    String mergeStrategy = existing?.mergeStrategy ??
      'norm_capped_weighted_runtime_vector_average_v2';
    bool enablePrototypeUploads = existing?.enablePrototypeUploads ?? false;

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _tHqFeatureFlags(
                  context,
                  existing == null ? 'Create experiment' : 'Edit experiment',
                ),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Experiment name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Description'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: runtimeTarget,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Runtime target'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'flutter_mobile',
                            child: Text('flutter_mobile'),
                          ),
                          DropdownMenuItem(
                            value: 'web_pwa',
                            child: Text('web_pwa'),
                          ),
                          DropdownMenuItem(
                            value: 'hybrid',
                            child: Text('hybrid'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            runtimeTarget = value ?? 'flutter_mobile';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Status'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                              value: 'draft', child: Text('draft')),
                          DropdownMenuItem(
                            value: 'pilot_ready',
                            child: Text('pilot_ready'),
                          ),
                          DropdownMenuItem(
                              value: 'active', child: Text('active')),
                          DropdownMenuItem(
                              value: 'paused', child: Text('paused')),
                          DropdownMenuItem(
                            value: 'disabled',
                            child: Text('disabled'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            status = value ?? 'draft';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: mergeStrategy,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Merge policy'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value:
                                'norm_capped_weighted_runtime_vector_average_v2',
                            child: Text('Sample-weighted merge'),
                          ),
                          DropdownMenuItem(
                            value:
                                'norm_capped_summary_balanced_runtime_vector_average_v1',
                            child: Text('Summary-balanced merge'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setDialogState(() {
                            mergeStrategy = value ??
                                'norm_capped_weighted_runtime_vector_average_v2';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sitesController,
                        decoration: InputDecoration(
                          labelText:
                              _tHqFeatureFlags(context, 'Enabled site IDs'),
                          helperText: _tHqFeatureFlags(
                            context,
                            'Comma-separated site IDs for the prototype cohort.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: thresholdController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _tHqFeatureFlags(
                                    context, 'Aggregate threshold'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: rawBytesController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _tHqFeatureFlags(
                                    context, 'Raw update max bytes'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: enablePrototypeUploads,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _tHqFeatureFlags(context, 'Enable prototype uploads'),
                        ),
                        subtitle: Text(
                          _tHqFeatureFlags(
                            context,
                            'Only metadata summaries are accepted; raw updates remain blocked.',
                          ),
                        ),
                        onChanged: (bool value) {
                          setDialogState(() {
                            enablePrototypeUploads = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tHqFeatureFlags(context, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tHqFeatureFlags(context, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      await _saveExperiment(
        existingId: existing?.id,
        name: nameController.text,
        description: descriptionController.text,
        runtimeTarget: runtimeTarget,
        status: status,
        mergeStrategy: mergeStrategy,
        enabledSiteIds: sitesController.text,
        aggregateThresholdText: thresholdController.text,
        rawUpdateMaxBytesText: rawBytesController.text,
        enablePrototypeUploads: enablePrototypeUploads,
      );
    }
  }

  Future<void> _saveExperiment({
    String? existingId,
    required String name,
    required String description,
    required String runtimeTarget,
    required String status,
    required String mergeStrategy,
    required String enabledSiteIds,
    required String aggregateThresholdText,
    required String rawUpdateMaxBytesText,
    required bool enablePrototypeUploads,
  }) async {
    final int aggregateThreshold =
        int.tryParse(aggregateThresholdText.trim()) ?? 25;
    final int rawUpdateMaxBytes =
        int.tryParse(rawUpdateMaxBytesText.trim()) ?? 16384;
    final List<String> allowedSiteIds = enabledSiteIds
        .split(',')
        .map((String entry) => entry.trim())
        .where((String entry) => entry.isNotEmpty)
        .toList(growable: false);

    try {
      await _workflowBridge.upsertFederatedLearningExperiment(<String, dynamic>{
        if ((existingId ?? '').trim().isNotEmpty) 'id': existingId,
        'name': name.trim(),
        'description': description.trim(),
        'runtimeTarget': runtimeTarget,
        'status': status,
        'mergeStrategy': mergeStrategy,
        'allowedSiteIds': allowedSiteIds,
        'aggregateThreshold': aggregateThreshold,
        'rawUpdateMaxBytes': rawUpdateMaxBytes,
        'enablePrototypeUploads': enablePrototypeUploads,
      });
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Federated experiment saved'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqFeatureFlags(context, 'Federated experiment save failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  _FeatureFlag _mapToFeatureFlag(Map<String, dynamic> data) {
    final List<String>? enabledSites = (data['enabledSites'] as List?)
        ?.map((dynamic e) => e.toString())
        .toList();
    return _FeatureFlag(
      id: (data['id'] as String?) ?? (data['name'] as String?) ?? 'flag',
      name: (data['name'] as String?) ?? (data['id'] as String?) ?? 'flag',
      description: (data['description'] as String?) ?? '',
      isEnabled:
          (data['enabled'] as bool?) ?? (data['isEnabled'] as bool?) ?? false,
      scope: (data['scope'] as String?) ?? 'global',
      enabledSites: enabledSites,
    );
  }
}

class _RuntimeRolloutHealthSummary {
  const _RuntimeRolloutHealthSummary({
    required this.siteRows,
    required this.resolvedCount,
    required this.stagedCount,
    required this.fallbackCount,
    required this.pendingCount,
  });

  final List<_RuntimeRolloutHealthRow> siteRows;
  final int resolvedCount;
  final int stagedCount;
  final int fallbackCount;
  final int pendingCount;
}

class _RuntimeRolloutHealthRow {
  const _RuntimeRolloutHealthRow({
    required this.siteId,
    required this.status,
    required this.statusLabel,
    required this.detailLabel,
  });

  final String siteId;
  final String status;
  final String statusLabel;
  final String detailLabel;
}
