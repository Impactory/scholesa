import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../auth/app_state.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

const Map<String, String> _siteIntegrationsEs = <String, String>{
  'Integrations Health': 'Estado de integraciones',
  'Connected Services': 'Servicios conectados',
  'Healthy': 'Saludable',
  'Warning': 'Advertencia',
  'Issues': 'Incidencias',
  'Last Sync': 'Última sincronización',
  'Synced': 'Sincronizado',
  'Errors': 'Errores',
  'Never': 'Nunca',
  'items': 'elementos',
  'Connect': 'Conectar',
  'Force Sync': 'Forzar sincronización',
  'Retry Failed': 'Reintentar fallidos',
  'Settings': 'Configuración',
  'Disconnect': 'Desconectar',
  'Error': 'Error',
  'Disconnected': 'Desconectado',
  'Integrations refreshed': 'Integraciones actualizadas',
  'connected': 'conectado',
  'synced successfully': 'sincronizado correctamente',
  'Failed syncs retried successfully':
      'Sincronizaciones fallidas reintentadas correctamente',
  'disconnected': 'desconectado',
  'm ago': 'm atrás',
  'h ago': 'h atrás',
  'd ago': 'd atrás',
  'Loading...': 'Cargando...',
  'No connected integrations found': 'No se encontraron integraciones conectadas',
};

/// Site integrations health page
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class SiteIntegrationsHealthPage extends StatefulWidget {
  const SiteIntegrationsHealthPage({super.key});

  @override
  State<SiteIntegrationsHealthPage> createState() =>
      _SiteIntegrationsHealthPageState();
}

class _SiteIntegrationsHealthPageState
    extends State<SiteIntegrationsHealthPage> {
  String _t(String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _siteIntegrationsEs[input] ?? input;
  }

  List<_Integration> _integrations = <_Integration>[];
  bool _isLoading = false;
  String? _siteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIntegrations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_t('Integrations Health')),
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'site_integrations_health',
                  'cta_id': 'refresh_integrations',
                  'surface': 'appbar',
                },
              );
              _handleRefreshIntegrations();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildOverallStatus(),
          const SizedBox(height: 24),
          Text(
            _t('Connected Services'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _t('Loading...'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          if (!_isLoading && _integrations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  _t('No connected integrations found'),
                  style: const TextStyle(color: ScholesaColors.textSecondary),
                ),
              ),
            ),
          ..._integrations
              .map((integration) => _buildIntegrationCard(integration)),
        ],
      ),
    );
  }

  Widget _buildOverallStatus() {
    final int healthyCount = _integrations
        .where((_Integration i) => i.status == _IntegrationStatus.healthy)
        .length;
    final int warningCount = _integrations
        .where((_Integration i) => i.status == _IntegrationStatus.warning)
        .length;
    final int errorCount = _integrations
        .where((_Integration i) =>
            i.status == _IntegrationStatus.error ||
            i.status == _IntegrationStatus.disconnected)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
              child: _buildStatusStat(
                _t('Healthy'), healthyCount, Icons.check_circle_rounded)),
          Container(width: 1, height: 50, color: Colors.white30),
          Expanded(
              child: _buildStatusStat(
                _t('Warning'), warningCount, Icons.warning_rounded)),
          Container(width: 1, height: 50, color: Colors.white30),
          Expanded(
              child:
                _buildStatusStat(_t('Issues'), errorCount, Icons.error_rounded)),
        ],
      ),
    );
  }

  Widget _buildStatusStat(String label, int count, IconData icon) {
    return Column(
      children: <Widget>[
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildIntegrationCard(_Integration integration) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: integration.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(integration.icon,
                      color: integration.color, size: 28),
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
                      Row(
                        children: <Widget>[
                          _buildStatusIndicator(integration.status),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusLabel(integration.status),
                            style: TextStyle(
                              fontSize: 13,
                              color: _getStatusColor(integration.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'site_integrations_health',
                        'cta_id': 'open_integration_options',
                        'surface': 'integration_card',
                        'integration_id': integration.id,
                      },
                    );
                    _showIntegrationOptions(integration);
                  },
                ),
              ],
            ),
            if (integration.status !=
                _IntegrationStatus.disconnected) ...<Widget>[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildMetric(
                      _t('Last Sync'),
                      integration.lastSync != null
                          ? _formatTime(integration.lastSync!)
                          : _t('Never')),
                  _buildMetric(_t('Synced'), '${integration.syncedItems} ${_t('items')}'),
                  _buildMetric(_t('Errors'), '${integration.errors}'),
                ],
              ),
            ],
            if (integration.status ==
                _IntegrationStatus.disconnected) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'site_integrations_health',
                        'cta_id': 'connect_integration',
                        'surface': 'integration_card',
                        'integration_id': integration.id,
                      },
                    );
                    _handleConnectIntegration(integration);
                  },
                  child: Text(_t('Connect')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(_IntegrationStatus status) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ScholesaColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ScholesaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(_IntegrationStatus status) {
    switch (status) {
      case _IntegrationStatus.healthy:
        return Colors.green;
      case _IntegrationStatus.warning:
        return Colors.orange;
      case _IntegrationStatus.error:
        return Colors.red;
      case _IntegrationStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusLabel(_IntegrationStatus status) {
    switch (status) {
      case _IntegrationStatus.healthy:
        return 'Healthy';
      case _IntegrationStatus.warning:
        return _t('Warning');
      case _IntegrationStatus.error:
        return _t('Error');
      case _IntegrationStatus.disconnected:
        return _t('Disconnected');
    }
  }

  void _showIntegrationOptions(_Integration integration) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: Text(_t('Force Sync')),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'site_integrations_health',
                    'cta_id': 'force_sync_integration',
                    'surface': 'integration_options_sheet',
                    'integration_id': integration.id,
                  },
                );
                Navigator.pop(context);
                _handleForceSyncIntegration(integration);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(_t('Retry Failed')),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'site_integrations_health',
                    'cta_id': 'retry_failed_syncs',
                    'surface': 'integration_options_sheet',
                    'integration_id': integration.id,
                  },
                );
                Navigator.pop(context);
                _handleRetryFailedSyncs(integration);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: Text(_t('Settings')),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'site_integrations_health',
                    'cta_id': 'open_integration_settings',
                    'surface': 'integration_options_sheet',
                    'integration_id': integration.id,
                  },
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded, color: Colors.red),
              title: Text(_t('Disconnect'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                TelemetryService.instance.logEvent(
                  event: 'cta.clicked',
                  metadata: <String, dynamic>{
                    'module': 'site_integrations_health',
                    'cta_id': 'disconnect_integration',
                    'surface': 'integration_options_sheet',
                    'integration_id': integration.id,
                  },
                );
                Navigator.pop(context);
                _handleDisconnectIntegration(integration);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleRefreshIntegrations() {
    _loadIntegrations().then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Integrations refreshed'))),
      );
    });
  }

  Future<void> _handleConnectIntegration(_Integration integration) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    await firestoreService.firestore
        .collection('integrationConnections')
        .doc(integration.id)
        .set(<String, dynamic>{
      'status': 'active',
      'lastError': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _loadIntegrations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${integration.name} ${_t('connected')}')),
    );
  }

  Future<void> _handleForceSyncIntegration(_Integration integration) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    await firestoreService.firestore.collection('syncJobs').add(<String, dynamic>{
      'type': '${integration.providerKey}_manual_sync',
      'requestedBy': FirebaseAuth.instance.currentUser?.uid,
      'status': 'queued',
      if ((_siteId ?? '').isNotEmpty) 'siteId': _siteId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _loadIntegrations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${integration.name} ${_t('synced successfully')}')),
    );
  }

  Future<void> _handleRetryFailedSyncs(_Integration integration) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    Query<Map<String, dynamic>> query =
        firestoreService.firestore.collection('syncJobs');
    if ((_siteId ?? '').isNotEmpty) {
      query = query.where('siteId', isEqualTo: _siteId);
    }
    query = query.where('status', isEqualTo: 'failed').limit(25);
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final WriteBatch batch = firestoreService.firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      final String type = ((doc.data()['type'] as String?) ?? '').toLowerCase();
      if (!_typeMatchesProvider(type, integration.providerKey)) continue;
      batch.set(doc.reference, <String, dynamic>{
        'status': 'queued',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    await _loadIntegrations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Failed syncs retried successfully'))),
    );
  }

  Future<void> _handleDisconnectIntegration(_Integration integration) async {
    final FirestoreService firestoreService = context.read<FirestoreService>();
    await firestoreService.firestore
        .collection('integrationConnections')
        .doc(integration.id)
        .set(<String, dynamic>{
      'status': 'disconnected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _loadIntegrations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${integration.name} ${_t('disconnected')}')),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${_t('m ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}${_t('h ago')}';
    }
    return '${diff.inDays}${_t('d ago')}';
  }

  Future<void> _loadIntegrations() async {
    final AppState appState = context.read<AppState>();
    final FirestoreService firestoreService = context.read<FirestoreService>();
    final String siteId = (appState.activeSiteId ??
            (appState.siteIds.isNotEmpty ? appState.siteIds.first : ''))
        .trim();
    _siteId = siteId;
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> connectionsQuery =
          firestoreService.firestore.collection('integrationConnections');
      if (uid.isNotEmpty) {
        connectionsQuery = connectionsQuery.where('ownerUserId', isEqualTo: uid);
      }

      QuerySnapshot<Map<String, dynamic>> connectionsSnap;
      try {
        connectionsSnap =
            await connectionsQuery.orderBy('createdAt', descending: true).get();
      } catch (_) {
        connectionsSnap = await connectionsQuery.get();
      }

      Query<Map<String, dynamic>> syncQuery =
          firestoreService.firestore.collection('syncJobs');
      if (siteId.isNotEmpty) {
        syncQuery = syncQuery.where('siteId', isEqualTo: siteId);
      }

      QuerySnapshot<Map<String, dynamic>> syncSnap;
      try {
        syncSnap = await syncQuery.orderBy('createdAt', descending: true).limit(200).get();
      } catch (_) {
        syncSnap = await syncQuery.limit(200).get();
      }

      final List<Map<String, dynamic>> syncRows =
          syncSnap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return <String, dynamic>{'id': doc.id, ...doc.data()};
      }).toList();

      final List<_Integration> loaded = connectionsSnap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();
        final String providerKey =
            ((data['provider'] as String?) ?? 'google_classroom').toLowerCase();
        final List<Map<String, dynamic>> providerJobs = syncRows
            .where((Map<String, dynamic> row) =>
                _typeMatchesProvider(
                    ((row['type'] as String?) ?? '').toLowerCase(), providerKey))
            .toList();

        DateTime? lastSync;
        int synced = 0;
        int errors = 0;
        for (final Map<String, dynamic> row in providerJobs) {
          final String status = ((row['status'] as String?) ?? '').toLowerCase();
          final DateTime? created = _toDateTime(row['createdAt']);
          if (created != null && (lastSync == null || created.isAfter(lastSync))) {
            lastSync = created;
          }
          if (status == 'completed' || status == 'success' || status == 'done') {
            synced += 1;
          }
          if (status == 'failed' || status == 'error') {
            errors += 1;
          }
        }

        final String connectionStatus =
            ((data['status'] as String?) ?? 'active').toLowerCase();
        final String? lastError = data['lastError'] as String?;
        final _IntegrationStatus status = connectionStatus == 'disconnected' ||
                connectionStatus == 'revoked' ||
                connectionStatus == 'inactive'
            ? _IntegrationStatus.disconnected
            : (errors > 0 || (lastError?.trim().isNotEmpty ?? false))
                ? _IntegrationStatus.warning
                : _IntegrationStatus.healthy;

        final ({String name, IconData icon, Color color}) visual =
            _providerVisual(providerKey);

        return _Integration(
          id: doc.id,
          providerKey: providerKey,
          name: visual.name,
          icon: visual.icon,
          color: visual.color,
          status: status,
          lastSync: lastSync,
          syncedItems: synced,
          errors: errors,
        );
      }).toList();

      loaded.sort((_Integration a, _Integration b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() => _integrations = loaded);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  bool _typeMatchesProvider(String type, String providerKey) {
    if (providerKey.contains('google')) {
      return type.contains('google') || type.contains('classroom');
    }
    if (providerKey.contains('github')) {
      return type.contains('github');
    }
    if (providerKey.contains('canvas')) {
      return type.contains('canvas');
    }
    return type.contains(providerKey);
  }

  ({String name, IconData icon, Color color}) _providerVisual(
      String providerKey) {
    if (providerKey.contains('github')) {
      return (
        name: 'GitHub',
        icon: Icons.code_rounded,
        color: Colors.black87,
      );
    }
    if (providerKey.contains('canvas')) {
      return (
        name: 'Canvas LMS',
        icon: Icons.dashboard_rounded,
        color: Colors.red,
      );
    }
    return (
      name: 'Google Classroom',
      icon: Icons.school_rounded,
      color: Colors.blue,
    );
  }
}

enum _IntegrationStatus { healthy, warning, error, disconnected }

class _Integration {
  const _Integration({
    required this.id,
    required this.providerKey,
    required this.name,
    required this.icon,
    required this.color,
    required this.status,
    required this.lastSync,
    required this.syncedItems,
    required this.errors,
  });

  final String id;
  final String providerKey;
  final String name;
  final IconData icon;
  final Color color;
  final _IntegrationStatus status;
  final DateTime? lastSync;
  final int syncedItems;
  final int errors;

  _Integration copyWith({
    String? id,
    String? providerKey,
    String? name,
    IconData? icon,
    Color? color,
    _IntegrationStatus? status,
    DateTime? lastSync,
    int? syncedItems,
    int? errors,
    bool clearLastSync = false,
  }) {
    return _Integration(
      id: id ?? this.id,
      providerKey: providerKey ?? this.providerKey,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      status: status ?? this.status,
      lastSync: clearLastSync ? null : (lastSync ?? this.lastSync),
      syncedItems: syncedItems ?? this.syncedItems,
      errors: errors ?? this.errors,
    );
  }
}
