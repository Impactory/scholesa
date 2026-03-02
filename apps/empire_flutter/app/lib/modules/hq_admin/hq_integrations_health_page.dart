import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _hqIntegrationsEs = <String, String>{
  'Integrations Health': 'Estado de integraciones',
  'Attention Needed': 'Se requiere atención',
  'All Systems Operational': 'Todos los sistemas operativos',
  'healthy': 'saludables',
  'warning': 'advertencia',
  'errors': 'errores',
  'total': 'total',
  'Sites': 'Sedes',
  'integrations': 'integraciones',
  'Last sync:': 'Última sincronización:',
  'Retry': 'Reintentar',
  'just now': 'justo ahora',
  'Integrations health refreshed':
      'Estado de integraciones actualizado',
  'recovered successfully': 'recuperada correctamente',
  '5 min ago': '5 min atrás',
  '15 min ago': '15 min atrás',
  '2 hrs ago': '2 h atrás',
  '30 min ago': '30 min atrás',
  'Failed': 'Falló',
  'Loading...': 'Cargando...',
  'No integration telemetry available': 'No hay telemetría de integración disponible',
  'Unknown Site': 'Sede desconocida',
};

String _tHqIntegrations(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _hqIntegrationsEs[input] ?? input;
}

/// HQ Integrations Health page for monitoring all site integrations
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class HqIntegrationsHealthPage extends StatefulWidget {
  const HqIntegrationsHealthPage({super.key});

  @override
  State<HqIntegrationsHealthPage> createState() =>
      _HqIntegrationsHealthPageState();
}

class _HqIntegrationsHealthPageState extends State<HqIntegrationsHealthPage> {
  final List<_SiteIntegration> _fallbackSites = <_SiteIntegration>[
    const _SiteIntegration(
      siteId: 'site-1',
      siteName: 'Downtown Studio',
      integrations: <_Integration>[
        _Integration(
            name: 'Google Classroom',
            providerKey: 'google_classroom',
          siteId: 'site-1',
            status: _Status.healthy,
            lastSyncAt: null),
        _Integration(
            name: 'GitHub',
            providerKey: 'github',
          siteId: 'site-1',
            status: _Status.healthy,
            lastSyncAt: null),
      ],
    ),
    const _SiteIntegration(
      siteId: 'site-2',
      siteName: 'Westside Campus',
      integrations: <_Integration>[
        _Integration(
            name: 'Google Classroom',
            providerKey: 'google_classroom',
          siteId: 'site-2',
            status: _Status.warning,
            lastSyncAt: null),
        _Integration(
            name: 'Canvas LMS',
            providerKey: 'canvas',
          siteId: 'site-2',
            status: _Status.healthy,
            lastSyncAt: null),
      ],
    ),
    const _SiteIntegration(
      siteId: 'site-3',
      siteName: 'North Branch',
      integrations: <_Integration>[
        _Integration(
            name: 'Google Classroom',
            providerKey: 'google_classroom',
          siteId: 'site-3',
            status: _Status.error,
            lastSyncAt: null),
      ],
    ),
  ];
  List<_SiteIntegration> _sites = <_SiteIntegration>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIntegrationsHealth();
    });
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
          if (!_isLoading && _sites.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _tHqIntegrations(context, 'No integration telemetry available'),
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
        onExpansionChanged: (bool expanded) {
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

  void _refreshAllIntegrations() {
    _loadIntegrationsHealth().then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _tHqIntegrations(context, 'Integrations health refreshed'))),
      );
    });
  }

  Future<void> _retryIntegration(_Integration integration) async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      return;
    }

    try {
      await firestoreService.firestore.collection('syncJobs').add(<String, dynamic>{
        'type': '${integration.providerKey}_manual_retry',
        'status': 'queued',
        'siteId': integration.siteId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${integration.name} ${_tHqIntegrations(context, 'recovered successfully')}')),
      );
      await _loadIntegrationsHealth();
    } catch (_) {}
  }

  Future<void> _loadIntegrationsHealth() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    if (firestoreService == null) {
      if (!mounted) return;
      setState(() {
        _sites = _fallbackSites;
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      QuerySnapshot<Map<String, dynamic>> sitesSnap;
      try {
        sitesSnap = await firestoreService.firestore
            .collection('sites')
            .orderBy('name')
            .limit(200)
            .get();
      } catch (_) {
        sitesSnap = await firestoreService.firestore
            .collection('sites')
            .limit(200)
            .get();
      }

      final Map<String, String> siteNames = <String, String>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in sitesSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        siteNames[doc.id] =
            (data['name'] as String?)?.trim().isNotEmpty == true
                ? (data['name'] as String).trim()
                : doc.id;
      }

      QuerySnapshot<Map<String, dynamic>> syncSnap;
      try {
        syncSnap = await firestoreService.firestore
            .collection('syncJobs')
            .orderBy('createdAt', descending: true)
            .limit(400)
            .get();
      } catch (_) {
        syncSnap = await firestoreService.firestore
            .collection('syncJobs')
            .limit(400)
            .get();
      }

      final Map<String, Map<String, _Integration>> grouped =
          <String, Map<String, _Integration>>{};

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in syncSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final String siteId = ((data['siteId'] as String?) ?? '').trim();
        if (siteId.isEmpty) continue;

        final String providerKey = _providerKeyFromType(
            ((data['type'] as String?) ?? '').trim().toLowerCase());
        if (providerKey.isEmpty) continue;

        final String statusRaw =
            ((data['status'] as String?) ?? '').trim().toLowerCase();
        final _Status status = _statusFromRaw(statusRaw);
        final DateTime? createdAt = _toDateTime(data['createdAt']);

        final Map<String, _Integration> byProvider =
            grouped.putIfAbsent(siteId, () => <String, _Integration>{});
        final _Integration? existing = byProvider[providerKey];
        if (existing == null ||
            ((createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .isAfter(existing.lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0)))) {
          byProvider[providerKey] = _Integration(
            name: _providerName(providerKey),
            providerKey: providerKey,
            siteId: siteId,
            status: status,
            lastSyncAt: createdAt,
          );
        }
      }

      final List<_SiteIntegration> loaded = grouped.entries
          .map((entry) => _SiteIntegration(
                siteId: entry.key,
                siteName: siteNames[entry.key] ?? _tHqIntegrations(context, 'Unknown Site'),
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sites = _fallbackSites;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _providerKeyFromType(String type) {
    if (type.contains('github')) return 'github';
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
      case 'canvas':
        return 'Canvas LMS';
      default:
        return 'Google Classroom';
    }
  }

  _Status _statusFromRaw(String raw) {
    if (raw == 'failed' || raw == 'error') return _Status.error;
    if (raw == 'queued' || raw == 'running' || raw == 'in_progress') {
      return _Status.warning;
    }
    return _Status.healthy;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
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

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
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
