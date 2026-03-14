import 'package:flutter/material.dart';
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
  Map<String, FederatedLearningAggregationRunModel> _latestAggregationRuns =
      <String, FederatedLearningAggregationRunModel>{};
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
    final FederatedLearningAggregationRunModel? latestRun =
        _latestAggregationRuns[experiment.id];
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
                OutlinedButton.icon(
                  onPressed: () => _showExperimentDialog(existing: experiment),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(_tHqFeatureFlags(context, 'Edit')),
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
          ],
        ),
      ),
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
      final List<dynamic> payloads = await Future.wait<dynamic>(<Future<dynamic>>[
        _workflowBridge.listFederatedLearningExperiments(),
        _workflowBridge.listFederatedLearningAggregationRuns(limit: 120),
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
          (payloads[1] as List<Map<String, dynamic>>)
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
      final Map<String, FederatedLearningAggregationRunModel> latestRuns =
          <String, FederatedLearningAggregationRunModel>{};
      for (final FederatedLearningAggregationRunModel run in runs) {
        latestRuns.putIfAbsent(run.experimentId, () => run);
      }
      if (!mounted) return;
      setState(() {
        _experiments = loaded;
        _latestAggregationRuns = latestRuns;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _experiments = <FederatedLearningExperimentModel>[];
        _latestAggregationRuns = <String, FederatedLearningAggregationRunModel>{};
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
