import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../runtime/runtime.dart';
import '../../i18n/bos_coaching_i18n.dart';
import '../../auth/app_state.dart';
import 'educator_service.dart';

String _tEducatorIntegrations(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// Educator integrations page for managing external tool connections
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class EducatorIntegrationsPage extends StatefulWidget {
  const EducatorIntegrationsPage({
    super.key,
    this.healthLoader,
    this.syncJobTrigger,
    this.connectionStatusUpdater,
  });

  final Future<Map<String, dynamic>> Function(String siteId)? healthLoader;
  final Future<void> Function(String siteId, String provider)? syncJobTrigger;
  final Future<void> Function(String connectionId, String status)?
      connectionStatusUpdater;

  @override
  State<EducatorIntegrationsPage> createState() =>
      _EducatorIntegrationsPageState();
}

class _EducatorIntegrationsPageState extends State<EducatorIntegrationsPage> {
  List<_EducatorIntegration> _integrations = <_EducatorIntegration>[];
  bool _isLoading = false;
  String? _siteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EducatorService>().loadLearners();
      _loadIntegrations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tEducatorIntegrations(context, 'My Integrations')),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: Consumer<EducatorService>(
        builder: (BuildContext context, EducatorService service, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AiContextCoachSection(
                title: _tEducatorIntegrations(context, 'Integrations AI Coach'),
                subtitle: _tEducatorIntegrations(
                  context,
                  'Keep MiloOS loop active while syncing learner systems',
                ),
                module: 'educator_integrations',
                surface: 'integrations_management',
                actorRole: UserRole.educator,
                accentColor: ScholesaColors.educator,
                conceptTags: const <String>[
                  'integrations',
                  'sync_health',
                  'learner_data_flow',
                ],
              ),
              if (service.learners.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: BosLearnerLoopInsightsCard(
                    title: BosCoachingI18n.sessionLoopTitle(context),
                    subtitle: BosCoachingI18n.sessionLoopSubtitle(context),
                    emptyLabel: BosCoachingI18n.sessionLoopEmpty(context),
                    learnerId: service.learners.first.id,
                    learnerName: service.learners.first.name,
                    accentColor: ScholesaColors.educator,
                  ),
                ),
              _buildInfoCard(context),
              const SizedBox(height: 24),
              Text(
                _tEducatorIntegrations(context, 'Connected Services'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ScholesaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _tEducatorIntegrations(context, 'Loading...'),
                      style: const TextStyle(
                        color: ScholesaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              if (!_isLoading && _integrations.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _tEducatorIntegrations(
                        context,
                        'No integrations configured yet',
                      ),
                      style: const TextStyle(
                        color: ScholesaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ..._integrations.map(
                (_EducatorIntegration integration) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildIntegrationCard(
                    context,
                    integration: integration,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
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
              _tEducatorIntegrations(context,
                  'Connect external tools to sync assignments, grades, and learner progress automatically.'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationCard(
    BuildContext context, {
    required _EducatorIntegration integration,
  }) {
    return Card(
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: integration.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(integration.icon, color: integration.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    integration.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ScholesaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    integration.syncStatusLabel(context),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  if (integration.errorCount > 0) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      _tEducatorIntegrations(
                        context,
                        '${integration.errorCount} sync issues need attention',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            integration.isConnected
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (String value) async {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_integrations',
                          'cta_id': 'integration_menu_action',
                          'surface': 'connected_integration_card',
                          'integration_name': integration.name,
                          'action': value,
                        },
                      );
                      if (value == 'Sync') {
                        await _handleForceSyncIntegration(integration);
                      } else if (value == 'Disconnect') {
                        await _handleUpdateConnection(
                          integration,
                          'disconnected',
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_tEducatorIntegrations(context, value)} ${integration.name}',
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                          value: 'Sync',
                          child: Text(
                              _tEducatorIntegrations(context, 'Sync Now'))),
                      PopupMenuItem<String>(
                          value: 'Settings',
                          child: Text(
                              _tEducatorIntegrations(context, 'Settings'))),
                      PopupMenuItem<String>(
                          value: 'Disconnect',
                          child: Text(
                              _tEducatorIntegrations(context, 'Disconnect'))),
                    ],
                  )
                : ElevatedButton(
                    onPressed: () async {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_integrations',
                          'cta_id': 'connect_integration',
                          'surface': 'available_integration_card',
                          'integration_name': integration.name,
                        },
                      );
                      await _handleUpdateConnection(integration, 'active');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: integration.color,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_tEducatorIntegrations(context, 'Connect')),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadIntegrations() async {
    final AppState appState = context.read<AppState>();
    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    _siteId = siteId;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> payload = widget.healthLoader != null
          ? await widget.healthLoader!(siteId)
          : await _fetchHealthPayload(siteId);
      final List<Map<String, dynamic>> connectionsRows = (payload['connections']
                  as List<dynamic>? ??
              <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) => row.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value)))
          .toList();
      final List<Map<String, dynamic>> syncRows = (payload['syncJobs']
                  as List<dynamic>? ??
              <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) => row.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value)))
          .toList();

      final Set<String> providerKeys = <String>{
        'google_classroom',
        'github_classroom',
        'lti_1p3',
        'clever',
        'classlink',
        ...connectionsRows
            .map((Map<String, dynamic> row) =>
                ((row['provider'] as String?) ?? '').toLowerCase())
            .where((String provider) => provider.isNotEmpty),
      };

      final List<_EducatorIntegration> loaded = providerKeys
          .map((String providerKey) {
        final Map<String, dynamic>? connection =
            connectionsRows.cast<Map<String, dynamic>?>().firstWhere(
                  (Map<String, dynamic>? row) =>
                      ((row?['provider'] as String?) ?? '').toLowerCase() ==
                      providerKey,
                  orElse: () => null,
                );
        final List<Map<String, dynamic>> providerJobs = syncRows
            .where((Map<String, dynamic> row) => _typeMatchesProvider(
                  ((row['provider'] as String?) ??
                          (row['type'] as String?) ??
                          '')
                      .toLowerCase(),
                  providerKey,
                ))
            .toList();

        DateTime? lastSync;
        int errorCount = 0;
        for (final Map<String, dynamic> row in providerJobs) {
          final DateTime? created =
              _toDateTime(row['updatedAt']) ?? _toDateTime(row['createdAt']);
          if (created != null &&
              (lastSync == null || created.isAfter(lastSync))) {
            lastSync = created;
          }
          final String status =
              ((row['status'] as String?) ?? '').toLowerCase();
          if (status == 'failed' || status == 'error') {
            errorCount += 1;
          }
        }

        final ({String name, IconData icon, Color color}) visual =
            _providerVisual(providerKey);
        final String connectionStatus =
            ((connection?['status'] as String?) ?? 'disconnected')
                .toLowerCase();
        return _EducatorIntegration(
          id: (connection?['id'] as String?) ?? providerKey,
          providerKey: providerKey,
          name: visual.name,
          icon: visual.icon,
          color: visual.color,
          isConnected:
              connectionStatus == 'active' || connectionStatus == 'healthy',
          lastSync: lastSync,
          errorCount: errorCount,
        );
      }).toList()
        ..sort((_EducatorIntegration a, _EducatorIntegration b) =>
            a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() => _integrations = loaded);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchHealthPayload(String siteId) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('getIntegrationsHealth');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{'siteId': siteId});
    return Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
  }

  Future<void> _handleForceSyncIntegration(
      _EducatorIntegration integration) async {
    if (_siteId == null || _siteId!.isEmpty) {
      return;
    }
    if (widget.syncJobTrigger != null) {
      await widget.syncJobTrigger!(_siteId!, integration.providerKey);
    } else {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('triggerIntegrationSyncJob');
      await callable.call(<String, dynamic>{
        'siteId': _siteId,
        'provider': integration.providerKey,
      });
    }
    await _loadIntegrations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${integration.name} ${_tEducatorIntegrations(context, 'sync queued')}',
        ),
      ),
    );
  }

  Future<void> _handleUpdateConnection(
    _EducatorIntegration integration,
    String status,
  ) async {
    if (widget.connectionStatusUpdater != null) {
      await widget.connectionStatusUpdater!(integration.id, status);
    } else {
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('updateIntegrationConnectionStatus');
      await callable.call(<String, dynamic>{
        'id': integration.id,
        'status': status,
      });
    }
    await _loadIntegrations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${integration.name} ${_tEducatorIntegrations(context, status == 'active' ? 'connected' : 'disconnected')}',
        ),
      ),
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  bool _typeMatchesProvider(String type, String providerKey) {
    if (providerKey.contains('google')) {
      return type.contains('google') || type.contains('classroom');
    }
    if (providerKey.contains('github')) {
      return type.contains('github');
    }
    if (providerKey.contains('lti')) {
      return type.contains('lti') ||
          type.contains('grade_push') ||
          type.contains('canvas');
    }
    if (providerKey.contains('clever')) {
      return type.contains('clever');
    }
    if (providerKey.contains('classlink')) {
      return type.contains('classlink');
    }
    return type.contains(providerKey);
  }

  ({String name, IconData icon, Color color}) _providerVisual(
      String providerKey) {
    if (providerKey.contains('github')) {
      return (
        name: 'GitHub Classroom',
        icon: Icons.code_rounded,
        color: Colors.black87,
      );
    }
    if (providerKey.contains('lti')) {
      return (
        name: 'LTI 1.3 / Grade Passback',
        icon: Icons.link_rounded,
        color: Colors.deepOrange,
      );
    }
    if (providerKey.contains('clever')) {
      return (
        name: 'Clever',
        icon: Icons.apartment_rounded,
        color: Colors.orange,
      );
    }
    if (providerKey.contains('classlink')) {
      return (
        name: 'ClassLink',
        icon: Icons.hub_rounded,
        color: Colors.purple,
      );
    }
    return (
      name: 'Google Classroom',
      icon: Icons.school_rounded,
      color: Colors.blue,
    );
  }
}

class _EducatorIntegration {
  const _EducatorIntegration({
    required this.id,
    required this.providerKey,
    required this.name,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.lastSync,
    required this.errorCount,
  });

  final String id;
  final String providerKey;
  final String name;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final DateTime? lastSync;
  final int errorCount;

  String syncStatusLabel(BuildContext context) {
    if (!isConnected) {
      return _tEducatorIntegrations(context, 'Not connected');
    }
    if (lastSync == null) {
      return _tEducatorIntegrations(context, 'Ready to sync');
    }
    final Duration diff = DateTime.now().difference(lastSync!);
    if (diff.inMinutes < 60) {
      return '${_tEducatorIntegrations(context, 'Last synced')} ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${_tEducatorIntegrations(context, 'Last synced')} ${diff.inHours}h ago';
    }
    return '${_tEducatorIntegrations(context, 'Last synced')} ${diff.inDays}d ago';
  }
}
