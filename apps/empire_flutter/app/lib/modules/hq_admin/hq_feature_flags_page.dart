import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models.dart';
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
  const HqFeatureFlagsPage({super.key, WorkflowBridgeService? workflowBridge})
      : _workflowBridge = workflowBridge;

  final WorkflowBridgeService? _workflowBridge;

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
  Map<String, FederatedLearningCandidatePromotionRecordModel>
    _promotionRecordsByPackageId =
    <String, FederatedLearningCandidatePromotionRecordModel>{};
  Map<String, FederatedLearningCandidatePromotionRevocationRecordModel>
    _promotionRevocationRecordsByPackageId =
    <String, FederatedLearningCandidatePromotionRevocationRecordModel>{};
  bool _isLoadingFlags = false;
  bool _isLoadingExperiments = false;

  WorkflowBridgeService get _workflowBridge =>
      widget._workflowBridge ?? WorkflowBridgeService.instance;

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
          ..._experiments.map(_buildExperimentCard),
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
    final FederatedLearningExperimentReviewRecordModel? reviewRecord =
      _experimentReviewRecordsByExperimentId[experiment.id];
    final FederatedLearningCandidatePromotionRevocationRecordModel?
        latestPromotionRevocation = latestPackage == null
            ? null
            : _promotionRevocationRecordsByPackageId[latestPackage.id];
    final FederatedLearningAggregationRunModel? latestRun =
      runs.isNotEmpty ? runs.first : null;
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
                        onPressed: () => _showExperimentDialog(existing: experiment),
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(_tHqFeatureFlags(context, 'Edit')),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAggregationHistoryDialog(experiment),
                        icon: const Icon(Icons.timeline_rounded),
                        label: Text(_tHqFeatureFlags(context, 'View history')),
                      ),
                      TextButton.icon(
                        onPressed: () => _showCandidatePackageHistoryDialog(experiment),
                        icon: const Icon(Icons.inventory_rounded),
                        label: Text(_tHqFeatureFlags(context, 'View packages')),
                      ),
                      TextButton.icon(
                        onPressed: () => _showExperimentReviewDialog(experiment),
                        icon: const Icon(Icons.fact_check_rounded),
                        label: Text(_tHqFeatureFlags(context, 'Review checklist')),
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
    FederatedLearningExperimentModel experiment,
  ) {
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
    String filterQuery = '';
    int pageIndex = 0;
    String sortMode = 'newest';
    String artifactFilter = 'all';
    bool latestOnly = false;

    return showDialog<void>(
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

            List<FederatedLearningAggregationRunModel> filteredRuns = sortedRuns
                .where((FederatedLearningAggregationRunModel run) {
              final FederatedLearningMergeArtifactModel? artifact =
                  artifactsByRunId[run.id];
              final bool hasArtifact =
                  ((artifact?.id ?? run.mergeArtifactId ?? '').trim().isNotEmpty);
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
                run.mergeArtifactId ?? '',
                run.mergeStrategy ?? '',
                run.boundedDigest ?? '',
                artifact?.id ?? '',
                artifact?.mergeStrategy ?? '',
                artifact?.boundedDigest ?? '',
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
                return ((artifact?.id ?? run.mergeArtifactId ?? '').trim()
                    .isNotEmpty);
              },
            ).length;
            final int missingArtifactCount =
                filteredRuns.length - generatedArtifactCount;
            final int stagedPackageCount = filteredRuns.where(
              (FederatedLearningAggregationRunModel run) {
                final FederatedLearningCandidateModelPackageModel? package =
                    candidatePackagesByRunId[run.id];
                return ((package?.id ?? run.candidateModelPackageId ?? '').trim()
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
            final int startIndex = filteredRuns.isEmpty ? 0 : pageIndex * pageSize;
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
                            'Filter by run ID, artifact ID, or digest',
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
                              _tHqFeatureFlags(context, 'Sort runs'),
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'newest',
                            child:
                                Text(_tHqFeatureFlags(context, 'Newest first')),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child:
                                Text(_tHqFeatureFlags(context, 'Oldest first')),
                          ),
                          DropdownMenuItem(
                            value: 'largest_batch',
                            child: Text(
                              _tHqFeatureFlags(context, 'Largest batch first'),
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
                            label:
                                Text(_tHqFeatureFlags(context, 'Latest only')),
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
                            child: Text(_tHqFeatureFlags(context, 'Previous')),
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
            final List<FederatedLearningCandidateModelPackageModel> sortedPackages =
                List<FederatedLearningCandidateModelPackageModel>.from(packages);
            if (sortMode == 'oldest') {
              sortedPackages.sort((a, b) {
                final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
                return aMillis.compareTo(bMillis);
              });
            } else if (sortMode == 'largest_batch') {
              sortedPackages.sort((a, b) {
                final int sampleCompare = b.sampleCount.compareTo(a.sampleCount);
                if (sampleCompare != 0) return sampleCompare;
                final int aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
                final int bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
                return bMillis.compareTo(aMillis);
              });
            }

            List<FederatedLearningCandidateModelPackageModel> filteredPackages =
                sortedPackages.where((FederatedLearningCandidateModelPackageModel package) {
              final FederatedLearningCandidatePromotionRecordModel? promotion =
                  _promotionRecordsByPackageId[package.id];
              final FederatedLearningCandidatePromotionRevocationRecordModel?
                  revocation = _promotionRevocationRecordsByPackageId[package.id];
              final String effectiveStatus =
                  _effectivePromotionStatus(promotion, revocation);
              if (promotionFilter == 'approved' &&
                  effectiveStatus != 'approved_for_eval') {
                return false;
              }
              if (promotionFilter == 'hold' && effectiveStatus != 'hold') {
                return false;
              }
              if (promotionFilter == 'revoked' && effectiveStatus != 'revoked') {
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
                package.packageDigest,
                package.boundedDigest,
                package.packageFormat,
                package.rolloutStatus,
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
            final int awaitingCount =
                filteredPackages.length - approvedCount - holdCount - revokedCount;
            final int sampleTotal = filteredPackages.fold<int>(
              0,
              (int total, FederatedLearningCandidateModelPackageModel package) =>
                  total + package.sampleCount,
            );
            final int pageCount = filteredPackages.isEmpty
                ? 1
                : ((filteredPackages.length - 1) ~/ pageSize) + 1;
            if (pageIndex >= pageCount) {
              pageIndex = pageCount - 1;
            }
            final int startIndex = filteredPackages.isEmpty ? 0 : pageIndex * pageSize;
            final int endIndex = filteredPackages.isEmpty
                ? 0
                : (startIndex + pageSize > filteredPackages.length
                    ? filteredPackages.length
                    : startIndex + pageSize);
            final List<FederatedLearningCandidateModelPackageModel> visiblePackages =
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
                              'Filter by package ID, artifact ID, or digest',
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
                                _tHqFeatureFlags(context, 'Largest batch first'),
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
                              label: Text(_tHqFeatureFlags(context, 'Latest only')),
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
                                (FederatedLearningCandidateModelPackageModel package) =>
                                    _buildCandidatePackageHistoryEntry(
                                  package,
                                  _promotionRecordsByPackageId[package.id],
                                  _promotionRevocationRecordsByPackageId[package.id],
                                  onApprove: () =>
                                      _showCandidatePromotionDecisionDialog(
                                    experiment: experiment,
                                    package: package,
                                    existingPromotion:
                                        _promotionRecordsByPackageId[package.id],
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
                                        _promotionRecordsByPackageId[package.id],
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
                              child: Text(_tHqFeatureFlags(context, 'Previous')),
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
  ) {
    final String createdLabel = _formatTimestamp(run.createdAt);
    final String digest =
        (artifact?.boundedDigest ?? run.boundedDigest ?? '').trim();
    final String strategy =
        (artifact?.mergeStrategy ?? run.mergeStrategy ?? '').trim();
    final String artifactId =
        (artifact?.id ?? run.mergeArtifactId ?? '').trim();
    final String packageId =
      (candidatePackage?.id ?? run.candidateModelPackageId ?? '').trim();
    final String packageFormat =
      (candidatePackage?.packageFormat ??
          run.candidateModelPackageFormat ??
          '')
        .trim();

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
                        _tHqFeatureFlags(context, 'Experiment: ${experiment.name}'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: _tHqFeatureFlags(context, 'Review status'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'pending', child: Text('pending')),
                          DropdownMenuItem(value: 'approved', child: Text('approved')),
                          DropdownMenuItem(value: 'blocked', child: Text('blocked')),
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
                          _tHqFeatureFlags(context, 'Sign-off checklist complete'),
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
                          _tHqFeatureFlags(context, 'Rollout risk acknowledged'),
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
    FederatedLearningCandidateModelPackageModel package,
    FederatedLearningCandidatePromotionRecordModel? promotion,
    FederatedLearningCandidatePromotionRevocationRecordModel? revocation,
    {
    VoidCallback? onApprove,
    VoidCallback? onHold,
  }
  ) {
    final String createdLabel = _formatTimestamp(package.createdAt);
    final String decidedLabel = _formatTimestamp(promotion?.decidedAt);
    final String revokedLabel = _formatTimestamp(revocation?.revokedAt);
    final String effectiveStatus = _effectivePromotionStatus(promotion, revocation);
    final String effectiveTarget = _effectivePromotionTarget(promotion, revocation);
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
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(context, 'Rollout status: ${package.rolloutStatus}'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(context, 'Package digest: ${package.packageDigest}'),
            style: const TextStyle(
              fontSize: 12,
              color: ScholesaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tHqFeatureFlags(context, 'Bounded digest: ${package.boundedDigest}'),
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
    final Map<String, FederatedLearningCandidateModelPackageModel> packagesById = {
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
                List<FederatedLearningCandidatePromotionRecordModel>.from(records);
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
                          record.candidateModelPackageId
                        ],
                      ) !=
                      'approved_for_eval') {
                return false;
              }
              if (statusFilter == 'hold' &&
                  _effectivePromotionStatus(
                        record,
                        _promotionRevocationRecordsByPackageId[
                          record.candidateModelPackageId
                        ],
                      ) !=
                      'hold') {
                return false;
              }
              if (statusFilter == 'revoked' &&
                  _effectivePromotionStatus(
                        record,
                        _promotionRevocationRecordsByPackageId[
                          record.candidateModelPackageId
                        ],
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
                record.status,
                record.target,
                record.rationale ?? '',
                record.decidedBy ?? '',
                package?.packageDigest ?? '',
                package?.boundedDigest ?? '',
                revocation?.id ?? '',
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
                        record.candidateModelPackageId
                      ],
                    ) ==
                    'approved_for_eval')
                .length;
            final int holdCount =
                filteredRecords.where((record) =>
                    _effectivePromotionStatus(
                      record,
                      _promotionRevocationRecordsByPackageId[
                        record.candidateModelPackageId
                      ],
                    ) ==
                    'hold').length;
            final int revokedCount = filteredRecords
                .where((record) =>
                    _effectivePromotionStatus(
                      record,
                      _promotionRevocationRecordsByPackageId[
                        record.candidateModelPackageId
                      ],
                    ) ==
                    'revoked')
                .length;
            final int sampleTotal = filteredRecords.fold<int>(
              0,
              (int total, FederatedLearningCandidatePromotionRecordModel record) =>
                  total + (packagesById[record.candidateModelPackageId]?.sampleCount ?? 0),
            );
            final int pageCount = filteredRecords.isEmpty
                ? 1
                : ((filteredRecords.length - 1) ~/ pageSize) + 1;
            if (pageIndex >= pageCount) {
              pageIndex = pageCount - 1;
            }
            final int startIndex = filteredRecords.isEmpty ? 0 : pageIndex * pageSize;
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
                              'Filter by package ID, artifact ID, decision ID, or rationale',
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
                                (FederatedLearningCandidatePromotionRecordModel record) =>
                                    _buildPromotionHistoryEntry(
                                  record,
                                  packagesById[record.candidateModelPackageId],
                                  _promotionRevocationRecordsByPackageId[
                                    record.candidateModelPackageId
                                  ],
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
                              child: Text(_tHqFeatureFlags(context, 'Previous')),
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
    FederatedLearningCandidatePromotionRecordModel record,
    FederatedLearningCandidateModelPackageModel? package,
    FederatedLearningCandidatePromotionRevocationRecordModel? revocation,
    {
    VoidCallback? onRevoke,
  }
  ) {
    final String decidedLabel = _formatTimestamp(record.decidedAt);
    final String updatedLabel = _formatTimestamp(record.updatedAt);
    final String revokedLabel = _formatTimestamp(revocation?.revokedAt);
    final String effectiveStatus = _effectivePromotionStatus(record, revocation);
    final String effectiveTarget = _effectivePromotionTarget(record, revocation);
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
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: isRevoked ? null : onRevoke,
              icon: const Icon(Icons.undo_rounded),
              label: Text(
                _tHqFeatureFlags(
                  context,
                  isRevoked ? 'Revoked' : 'Revoke decision',
                ),
              ),
            ),
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
                      labelText: _tHqFeatureFlags(context, 'Rollback rationale'),
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
      final List<dynamic> payloads = await Future.wait<dynamic>(<Future<dynamic>>[
        _workflowBridge.listFederatedLearningExperiments(),
        _workflowBridge.listFederatedLearningExperimentReviewRecords(limit: 120),
        _workflowBridge.listFederatedLearningAggregationRuns(limit: 120),
        _workflowBridge.listFederatedLearningMergeArtifacts(limit: 120),
        _workflowBridge.listFederatedLearningCandidateModelPackages(limit: 120),
        _workflowBridge.listFederatedLearningCandidatePromotionRecords(limit: 120),
        _workflowBridge.listFederatedLearningCandidatePromotionRevocationRecords(limit: 120),
      ]);
      final List<FederatedLearningExperimentModel> loaded =
          (payloads[0] as List<Map<String, dynamic>>)
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
      final List<FederatedLearningAggregationRunModel> runs =
          (payloads[2] as List<Map<String, dynamic>>)
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
        runsByExp.putIfAbsent(
          run.experimentId,
          () => <FederatedLearningAggregationRunModel>[],
        ).add(run);
      }
      final List<FederatedLearningMergeArtifactModel> artifacts =
          (payloads[3] as List<Map<String, dynamic>>)
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
        artifactsByExp.putIfAbsent(
          artifact.experimentId,
          () => <FederatedLearningMergeArtifactModel>[],
        ).add(artifact);
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
        packagesByExp.putIfAbsent(
          package.experimentId,
          () => <FederatedLearningCandidateModelPackageModel>[],
        ).add(package);
      }
        final Map<String, FederatedLearningExperimentReviewRecordModel>
          reviewRecordsByExperimentId =
          <String, FederatedLearningExperimentReviewRecordModel>{};
        for (final FederatedLearningExperimentReviewRecordModel record
          in (payloads[1] as List<Map<String, dynamic>>)
            .map((Map<String, dynamic> row) =>
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
          in (payloads[5] as List<Map<String, dynamic>>)
              .map((Map<String, dynamic> row) =>
                  FederatedLearningCandidatePromotionRecordModel.fromMap(
                    (row['id'] as String?) ?? 'promotion_record',
                    row,
                  ))) {
        promotionsByPackageId[record.candidateModelPackageId] = record;
      }
      final Map<String, FederatedLearningCandidatePromotionRevocationRecordModel>
          revocationsByPackageId =
          <String, FederatedLearningCandidatePromotionRevocationRecordModel>{};
      for (final FederatedLearningCandidatePromotionRevocationRecordModel record
          in (payloads[6] as List<Map<String, dynamic>>)
              .map((Map<String, dynamic> row) =>
                  FederatedLearningCandidatePromotionRevocationRecordModel.fromMap(
                    (row['id'] as String?) ?? 'promotion_revocation_record',
                    row,
                  ))) {
        revocationsByPackageId[record.candidateModelPackageId] = record;
      }
      if (!mounted) return;
      setState(() {
        _experiments = loaded;
        _aggregationRunsByExperiment = runsByExp;
        _mergeArtifactsByExperiment = artifactsByExp;
        _candidatePackagesByExperiment = packagesByExp;
        _experimentReviewRecordsByExperimentId = reviewRecordsByExperimentId;
        _promotionRecordsByPackageId = promotionsByPackageId;
        _promotionRevocationRecordsByPackageId = revocationsByPackageId;
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
        _experimentReviewRecordsByExperimentId =
          <String, FederatedLearningExperimentReviewRecordModel>{};
        _promotionRecordsByPackageId =
          <String, FederatedLearningCandidatePromotionRecordModel>{};
        _promotionRevocationRecordsByPackageId =
          <String, FederatedLearningCandidatePromotionRevocationRecordModel>{};
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
