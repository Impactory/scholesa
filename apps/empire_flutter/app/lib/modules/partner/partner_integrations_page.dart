import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/app_state.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/auth/global_session_menu.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tPartnerIntegrations(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

typedef PartnerConnectionsLoader =
    Future<List<IntegrationConnectionModel>> Function(
      FirestoreService firestoreService,
      String partnerId,
    );

class PartnerIntegrationsPage extends StatefulWidget {
  const PartnerIntegrationsPage({
    this.connectionsLoader,
    super.key,
  });

  final PartnerConnectionsLoader? connectionsLoader;

  @override
  State<PartnerIntegrationsPage> createState() => _PartnerIntegrationsPageState();
}

class _PartnerIntegrationsPageState extends State<PartnerIntegrationsPage> {
  bool _isLoading = false;
  String? _error;
  List<IntegrationConnectionModel> _connections =
      const <IntegrationConnectionModel>[];

  String _t(String input) => _tPartnerIntegrations(context, input);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConnections();
    });
  }

  FirestoreService? _maybeFirestoreService() {
    try {
      return context.read<FirestoreService>();
    } catch (_) {
      return null;
    }
  }

  String _partnerId() {
    final AppState appState = context.read<AppState>();
    return appState.userId?.trim() ?? '';
  }

  Future<void> _loadConnections() async {
    final FirestoreService? firestoreService = _maybeFirestoreService();
    final String partnerId = _partnerId();

    if (firestoreService == null) {
      setState(() {
        _error = _t('Integration storage unavailable right now.');
        _isLoading = false;
      });
      return;
    }
    if (partnerId.isEmpty) {
      setState(() {
        _error = _t('Partner identity unavailable right now.');
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<IntegrationConnectionModel> connections =
          widget.connectionsLoader != null
              ? await widget.connectionsLoader!(firestoreService, partnerId)
              : await _loadConnectionsFromRepository(firestoreService, partnerId);
      if (!mounted) return;
      setState(() {
        _connections = connections;
        _error = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('Unable to load partner integrations right now.');
        _isLoading = false;
      });
    }
  }

  Future<List<IntegrationConnectionModel>> _loadConnectionsFromRepository(
    FirestoreService firestoreService,
    String partnerId,
  ) async {
    final IntegrationConnectionRepository repository =
        IntegrationConnectionRepository(firestore: firestoreService.firestore);
    return repository.listByOwner(partnerId, limit: 50);
  }

  String _providerLabel(String provider) {
    switch (provider.trim().toLowerCase()) {
      case 'google_classroom':
        return 'Google Classroom';
      case 'classlink':
        return 'ClassLink';
      case 'clever':
        return 'Clever';
      case 'github':
        return 'GitHub';
      case 'lti':
        return 'LTI';
      default:
        final String normalized = provider.trim();
        if (normalized.isEmpty) {
          return _t('Provider unavailable');
        }
        return normalized
            .split('_')
            .map((String part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'connected':
        return ScholesaColors.success;
      case 'error':
      case 'revoked':
        return ScholesaColors.error;
      case 'pending':
        return ScholesaColors.warning;
      default:
        return ScholesaColors.info;
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'connected':
        return _t('Connected');
      case 'error':
        return _t('Error');
      case 'revoked':
        return _t('Revoked');
      case 'pending':
        return _t('Pending');
      default:
        final String normalized = status.trim();
        return normalized.isEmpty ? _t('Unknown') : normalized;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return _t('Not scheduled');
    final DateTime value = timestamp.toDate();
    return '${value.month}/${value.day}/${value.year}';
  }

  Widget _buildConnectionCard(IntegrationConnectionModel connection) {
    final Color color = _statusColor(connection.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.hub_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _providerLabel(connection.provider),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(connection.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_t('Last updated')}: ${_formatDate(connection.updatedAt ?? connection.createdAt)}',
              style: TextStyle(color: context.schTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '${_t('Scopes granted')}: ${connection.scopesGranted?.length ?? 0}',
              style: TextStyle(color: context.schTextSecondary),
            ),
            if ((connection.lastError ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${_t('Last error')}: ${connection.lastError!.trim()}',
                style: const TextStyle(color: ScholesaColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: Text(_t('Partner Integrations')),
        backgroundColor: ScholesaColors.partnerGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _t('Refresh'),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'module': 'partner_integrations',
                  'cta_id': 'refresh_integrations',
                },
              );
              _loadConnections();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SessionMenuButton(
            foregroundColor: Colors.white,
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (_isLoading && _connections.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && _connections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildLoadErrorState(),
              ),
            );
          }
          if (_connections.isEmpty) {
            return _PartnerIntegrationsEmptyState(
              title: _t('No partner integrations connected yet'),
              message: _t(
                'Connected integrations will appear here when partner-owned links are configured.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _loadConnections,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildStaleDataBanner(),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _t(
                      'Review the current status of partner-owned external integrations.',
                    ),
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
                ..._connections.map(_buildConnectionCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: ScholesaColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t('We could not load partner integrations right now. Retry to check the current state.'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ScholesaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? _t('Unable to load partner integrations right now.'),
            style: TextStyle(color: context.schTextSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _loadConnections,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_t('Retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleDataBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _t('Unable to refresh partner integrations right now. Showing the last successful data.') +
                  (_error == null ? '' : ' ${_error!}'),
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerIntegrationsEmptyState extends StatelessWidget {
  const _PartnerIntegrationsEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.hub_outlined,
              size: 48,
              color: ScholesaColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.schTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
