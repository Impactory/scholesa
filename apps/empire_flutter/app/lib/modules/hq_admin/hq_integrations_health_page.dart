import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqIntegrations(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Integrations Health page for monitoring all site integrations
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class HqIntegrationsHealthPage extends StatefulWidget {
  const HqIntegrationsHealthPage({
    super.key,
    this.integrationsLoader,
    this.retryIntegrationRunner,
    this.sharedPreferences,
  });

  final Future<Map<String, dynamic>> Function()? integrationsLoader;
  final Future<void> Function(String siteId, String providerKey)?
      retryIntegrationRunner;
  final SharedPreferences? sharedPreferences;

  @override
  State<HqIntegrationsHealthPage> createState() =>
      _HqIntegrationsHealthPageState();
}

class _HqIntegrationsHealthPageState extends State<HqIntegrationsHealthPage> {
  List<_SiteIntegration> _sites = <_SiteIntegration>[];
  SharedPreferences? _prefsCache;
  Set<String> _expandedSiteIds = <String>{};
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreExpandedSites();
      if (!mounted) {
        return;
      }
      _loadIntegrationsHealth();
    });
  }

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? injected = widget.sharedPreferences;
    if (injected != null) {
      return injected;
    }
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  String _expandedSitesPrefsKey() {
    return 'hq_integrations_health.expanded_sites';
  }

  Future<void> _restoreExpandedSites() async {
    final SharedPreferences prefs = await _prefs();
    final List<String> expanded =
        prefs.getStringList(_expandedSitesPrefsKey()) ?? <String>[];
    if (!mounted) {
      return;
    }
    setState(() => _expandedSiteIds = expanded.toSet());
  }

  Future<void> _setExpandedSite(String siteId, bool expanded) async {
    final Set<String> next = Set<String>.from(_expandedSiteIds);
    if (expanded) {
      next.add(siteId);
    } else {
      next.remove(siteId);
    }
    final SharedPreferences prefs = await _prefs();
    await prefs.setStringList(_expandedSitesPrefsKey(), next.toList()..sort());
    if (!mounted) {
      return;
    }
    setState(() => _expandedSiteIds = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_tHqIntegrations(context, 'Integrations Health')),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_integrations_health',
                  'cta_id': 'refresh_integrations_health',
                  'surface': 'appbar',
                },
              );
              _refreshAllIntegrations();
            },
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildOverallHealth(context),
          const SizedBox(height: 24),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqIntegrations(context, 'Loading...'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          if (!_isLoading && _loadError != null && _sites.isEmpty)
            _buildLoadErrorCard(context, _loadError!),
          if (!_isLoading && _loadError != null && _sites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildStaleDataBanner(context, _loadError!),
            ),
          if (!_isLoading && _sites.isEmpty && _loadError == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqIntegrations(
                      context, 'No integration telemetry available'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          _buildSiteIntegrations(context, _sites),
        ],
      ),
    );
  }

  Widget _buildOverallHealth(BuildContext context) {
    final int healthyCount = _sites
        .expand((_SiteIntegration site) => site.integrations)
        .where(
            (_Integration integration) => integration.status == _Status.healthy)
        .length;
    final int warningCount = _sites
        .expand((_SiteIntegration site) => site.integrations)
        .where(
            (_Integration integration) => integration.status == _Status.warning)
        .length;
    final int errorCount = _sites
        .expand((_SiteIntegration site) => site.integrations)
        .where(
            (_Integration integration) => integration.status == _Status.error)
        .length;
    final int totalCount = healthyCount + warningCount + errorCount;
    final bool hasIssues = errorCount > 0 || warningCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasIssues
            ? const LinearGradient(
                colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)])
            : const LinearGradient(
                colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            hasIssues ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            hasIssues
                ? _tHqIntegrations(context, 'Attention Needed')
                : _tHqIntegrations(context, 'All Systems Operational'),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '$healthyCount ${_tHqIntegrations(context, 'healthy')} · $warningCount ${_tHqIntegrations(context, 'warning')} · $errorCount ${_tHqIntegrations(context, 'errors')} ($totalCount ${_tHqIntegrations(context, 'total')})',
            style: TextStyle(
                fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteIntegrations(
      BuildContext context, List<_SiteIntegration> sites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _tHqIntegrations(context, 'Sites'),
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...sites.map((site) => _buildSiteCard(context, site)),
      ],
    );
  }

  Widget _buildSiteCard(BuildContext context, _SiteIntegration site) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: PageStorageKey<String>('hq-integrations-${site.siteId}'),
        initiallyExpanded: _expandedSiteIds.contains(site.siteId),
        onExpansionChanged: (bool expanded) {
          _setExpandedSite(site.siteId, expanded);
          TelemetryService.instance.logEvent(
            event: 'cta.clicked',
            metadata: <String, dynamic>{
              'module': 'hq_integrations_health',
              'cta_id': expanded
                  ? 'expand_site_integrations'
                  : 'collapse_site_integrations',
              'surface': 'site_integration_card',
              'site_name': site.siteName,
            },
          );
        },
        title: Text(site.siteName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${site.integrations.length} ${_tHqIntegrations(context, 'integrations')}'),
        leading: _buildSiteStatusIcon(site),
        children: site.integrations
            .map((integration) => _buildIntegrationTile(context, integration))
            .toList(),
      ),
    );
  }

  Widget _buildSiteStatusIcon(_SiteIntegration site) {
    final bool hasError =
        site.integrations.any((_Integration i) => i.status == _Status.error);
    final bool hasWarning =
        site.integrations.any((_Integration i) => i.status == _Status.warning);

    Color color;
    IconData icon;
    if (hasError) {
      color = Colors.red;
      icon = Icons.error_rounded;
    } else if (hasWarning) {
      color = Colors.orange;
      icon = Icons.warning_rounded;
    } else {
      color = Colors.green;
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildIntegrationTile(BuildContext context, _Integration integration) {
    Color statusColor;
    switch (integration.status) {
      case _Status.healthy:
        statusColor = Colors.green;
      case _Status.warning:
        statusColor = Colors.orange;
      case _Status.error:
        statusColor = Colors.red;
    }

    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
      ),
      title: Text(integration.name),
      subtitle: Text(
          '${_tHqIntegrations(context, 'Last sync:')} ${_formatLastSync(integration)}'),
      trailing: integration.status == _Status.error
          ? TextButton(
              onPressed: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'hq_integrations_health',
                    'cta_id': 'retry_integration',
                    'surface': 'integration_row',
                    'site_id': integration.siteId,
                    'integration_name': integration.name,
                  },
                );
                _retryIntegration(integration);
              },
              child: Text(_tHqIntegrations(context, 'Retry')),
            )
          : null,
    );
  }

  Widget _buildLoadErrorCard(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.red.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              _tHqIntegrations(context, 'Integrations health is temporarily unavailable'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ScholesaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ScholesaColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadIntegrationsHealth,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tHqIntegrations(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleDataBanner(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_tHqIntegrations(context, 'Unable to refresh integrations health right now. Showing the last successful data.')} $message',
              style: const TextStyle(color: ScholesaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshAllIntegrations() {
    _loadIntegrationsHealth().then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loadError == null
                ? _tHqIntegrations(context, 'Integrations health refreshed')
                : _tHqIntegrations(
                    context,
                    'Unable to refresh integrations health right now.',
                  ),
          ),
        ),
      );
    });
  }

  Future<void> _retryIntegration(_Integration integration) async {
    try {
      if (widget.retryIntegrationRunner != null) {
        await widget.retryIntegrationRunner!(
          integration.siteId,
          integration.providerKey,
        );
      } else {
        final HttpsCallable callable = FirebaseFunctions.instance
            .httpsCallable('triggerIntegrationSyncJob');
        await callable.call(<String, dynamic>{
          'siteId': integration.siteId,
          'provider': integration.providerKey,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${integration.name} ${_tHqIntegrations(context, 'recovered successfully')}')),
      );
      await _loadIntegrationsHealth();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tHqIntegrations(context, 'Unable to retry this integration right now.'),
          ),
          backgroundColor: ScholesaColors.error,
        ),
      );
    }
  }

  Future<void> _loadIntegrationsHealth() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final Map<String, dynamic> payload;
      if (widget.integrationsLoader != null) {
        payload = await widget.integrationsLoader!();
      } else {
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('getIntegrationsHealth');
        final HttpsCallableResult<dynamic> result =
            await callable.call(<String, dynamic>{'scope': 'hq'});
        payload = _asMap(result.data);
      }
      final List<dynamic> syncRows =
          payload['syncJobs'] as List<dynamic>? ?? <dynamic>[];
      final List<dynamic> connectionRows =
          payload['connections'] as List<dynamic>? ?? <dynamic>[];

      final Map<String, String> siteNames = <String, String>{};
      for (final dynamic row in <dynamic>[...syncRows, ...connectionRows]) {
        final Map<String, dynamic> data = _asMap(row);
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isEmpty) continue;
        final String siteName = ((data['siteName'] as String?) ?? '').trim();
        siteNames[siteId] = siteName.isNotEmpty ? siteName : siteId;
      }

      final Map<String, Map<String, _Integration>> grouped =
          <String, Map<String, _Integration>>{};

      for (final dynamic row in syncRows) {
        final Map<String, dynamic> data = _asMap(row);
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isEmpty) continue;

        final String providerKey = _providerKeyFromType(
            ((data['provider'] as String?) ?? (data['type'] as String?) ?? '')
                .trim()
                .toLowerCase());
        if (providerKey.isEmpty) continue;

        final String statusRaw =
            ((data['status'] as String?) ?? '').trim().toLowerCase();
        final _Status status = _statusFromRaw(statusRaw);
        final DateTime? createdAt =
            _toDateTime(data['updatedAt'] ?? data['createdAt']);

        final Map<String, _Integration> byProvider =
            grouped.putIfAbsent(siteId, () => <String, _Integration>{});
        final _Integration? existing = byProvider[providerKey];
        if (existing == null ||
            ((createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).isAfter(
                existing.lastSyncAt ??
                    DateTime.fromMillisecondsSinceEpoch(0)))) {
          byProvider[providerKey] = _Integration(
            name: _providerName(providerKey),
            providerKey: providerKey,
            siteId: siteId,
            status: status,
            lastSyncAt: createdAt,
          );
        }
      }

      for (final dynamic row in connectionRows) {
        final Map<String, dynamic> data = _asMap(row);
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isEmpty) continue;

        final String providerKey = _providerKeyFromType(
            ((data['provider'] as String?) ??
                    (data['providerKey'] as String?) ??
                    '')
                .trim()
                .toLowerCase());
        if (providerKey.isEmpty) continue;

        final String statusRaw =
            ((data['status'] as String?) ?? '').trim().toLowerCase();
        final _Status status = _statusFromRaw(statusRaw);
        final DateTime? updatedAt = _toDateTime(data['updatedAt']);

        final Map<String, _Integration> byProvider =
            grouped.putIfAbsent(siteId, () => <String, _Integration>{});
        final _Integration? existing = byProvider[providerKey];
        if (existing == null ||
            status == _Status.error ||
            (status == _Status.warning && existing.status == _Status.healthy)) {
          byProvider[providerKey] = _Integration(
            name: _providerName(providerKey),
            providerKey: providerKey,
            siteId: siteId,
            status: status,
            lastSyncAt: updatedAt ?? existing?.lastSyncAt,
          );
        }
      }

      final List<_SiteIntegration> loaded = grouped.entries
          .map((entry) => _SiteIntegration(
                siteId: entry.key,
                siteName: siteNames[entry.key] ??
                _tHqIntegrations(context, 'Site unavailable'),
                integrations: entry.value.values.toList()
                  ..sort((_Integration a, _Integration b) =>
                      a.name.compareTo(b.name)),
              ))
          .toList()
        ..sort((_SiteIntegration a, _SiteIntegration b) =>
            a.siteName.compareTo(b.siteName));

      if (!mounted) return;
      setState(() {
        _sites = loaded;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = _tHqIntegrations(
          context,
          'We could not load integrations health. Retry to check the current state.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _providerKeyFromType(String type) {
    if (type.contains('github')) return 'github';
    if (type.contains('lti') || type.contains('grade_push')) return 'lti_1p3';
    if (type.contains('canvas')) return 'canvas';
    if (type.contains('google') || type.contains('classroom')) {
      return 'google_classroom';
    }
    return '';
  }

  String _providerName(String providerKey) {
    switch (providerKey) {
      case 'github':
        return 'GitHub';
      case 'lti_1p3':
        return 'LTI 1.3 / Grade Passback';
      case 'canvas':
        return 'Canvas LMS';
      default:
        return 'Google Classroom';
    }
  }

  _Status _statusFromRaw(String raw) {
    if (raw == 'failed' || raw == 'error') return _Status.error;
    if (raw == 'queued' ||
        raw == 'running' ||
        raw == 'in_progress' ||
        raw == 'degraded' ||
        raw == 'warning') {
      return _Status.warning;
    }
    if (raw == 'disconnected') return _Status.error;
    return _Status.healthy;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Map && value['seconds'] is int) {
      final int seconds = value['seconds'] as int;
      final int nanos = (value['nanoseconds'] as int?) ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanos ~/ 1000000));
    }
    if (value != null &&
        value is Object &&
        value.runtimeType.toString().contains('Timestamp') &&
        (value as dynamic).toDate is Function) {
      return (value as dynamic).toDate() as DateTime?;
    }
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _formatLastSync(_Integration integration) {
    final DateTime? value = integration.lastSyncAt;
    if (value == null) return _tHqIntegrations(context, 'Failed');
    final Duration diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return _tHqIntegrations(context, 'just now');
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((dynamic key, dynamic nestedValue) =>
          MapEntry<String, dynamic>(key.toString(), nestedValue));
    }
    return <String, dynamic>{};
  }
}

enum _Status { healthy, warning, error }

class _Integration {
  const _Integration(
      {required this.name,
      required this.providerKey,
      required this.siteId,
      required this.status,
      required this.lastSyncAt});
  final String name;
  final String providerKey;
  final String siteId;
  final _Status status;
  final DateTime? lastSyncAt;

  _Integration copyWith({
    String? name,
    String? providerKey,
    String? siteId,
    _Status? status,
    DateTime? lastSyncAt,
  }) {
    return _Integration(
      name: name ?? this.name,
      providerKey: providerKey ?? this.providerKey,
      siteId: siteId ?? this.siteId,
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class _SiteIntegration {
  const _SiteIntegration({
    required this.siteId,
    required this.siteName,
    required this.integrations,
  });
  final String siteId;
  final String siteName;
  final List<_Integration> integrations;

  _SiteIntegration copyWith({
    String? siteId,
    String? siteName,
    List<_Integration>? integrations,
  }) {
    return _SiteIntegration(
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      integrations: integrations ?? this.integrations,
    );
  }
}
