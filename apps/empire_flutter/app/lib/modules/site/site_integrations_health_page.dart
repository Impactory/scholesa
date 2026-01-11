import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Site integrations health page
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class SiteIntegrationsHealthPage extends StatefulWidget {
  const SiteIntegrationsHealthPage({super.key});

  @override
  State<SiteIntegrationsHealthPage> createState() => _SiteIntegrationsHealthPageState();
}

class _SiteIntegrationsHealthPageState extends State<SiteIntegrationsHealthPage> {
  final List<_Integration> _integrations = <_Integration>[
    _Integration(
      id: '1',
      name: 'Google Classroom',
      icon: Icons.school_rounded,
      color: Colors.blue,
      status: _IntegrationStatus.healthy,
      lastSync: DateTime.now().subtract(const Duration(minutes: 15)),
      syncedItems: 45,
      errors: 0,
    ),
    _Integration(
      id: '2',
      name: 'GitHub',
      icon: Icons.code_rounded,
      color: Colors.black87,
      status: _IntegrationStatus.warning,
      lastSync: DateTime.now().subtract(const Duration(hours: 2)),
      syncedItems: 23,
      errors: 3,
    ),
    _Integration(
      id: '3',
      name: 'Canvas LMS',
      icon: Icons.dashboard_rounded,
      color: Colors.red,
      status: _IntegrationStatus.disconnected,
      lastSync: null,
      syncedItems: 0,
      errors: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Integrations Health'),
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing integrations...')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildOverallStatus(),
          const SizedBox(height: 24),
          const Text(
            'Connected Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._integrations.map((integration) => _buildIntegrationCard(integration)),
        ],
      ),
    );
  }

  Widget _buildOverallStatus() {
    final int healthyCount = _integrations.where((_Integration i) => i.status == _IntegrationStatus.healthy).length;
    final int warningCount = _integrations.where((_Integration i) => i.status == _IntegrationStatus.warning).length;
    final int errorCount = _integrations.where((_Integration i) => i.status == _IntegrationStatus.error || i.status == _IntegrationStatus.disconnected).length;

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
          Expanded(child: _buildStatusStat('Healthy', healthyCount, Icons.check_circle_rounded)),
          Container(width: 1, height: 50, color: Colors.white30),
          Expanded(child: _buildStatusStat('Warning', warningCount, Icons.warning_rounded)),
          Container(width: 1, height: 50, color: Colors.white30),
          Expanded(child: _buildStatusStat('Issues', errorCount, Icons.error_rounded)),
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
                  onPressed: () => _showIntegrationOptions(integration),
                ),
              ],
            ),
            if (integration.status != _IntegrationStatus.disconnected) ...<Widget>[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildMetric('Last Sync', integration.lastSync != null ? _formatTime(integration.lastSync!) : 'Never'),
                  _buildMetric('Synced', '${integration.syncedItems} items'),
                  _buildMetric('Errors', '${integration.errors}'),
                ],
              ),
            ],
            if (integration.status == _IntegrationStatus.disconnected) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connecting ${integration.name}...')),
                    );
                  },
                  child: const Text('Connect'),
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
          style: TextStyle(
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
        return 'Warning';
      case _IntegrationStatus.error:
        return 'Error';
      case _IntegrationStatus.disconnected:
        return 'Disconnected';
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
              title: const Text('Force Sync'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Syncing ${integration.name}...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Retry Failed'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retrying failed syncs...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded, color: Colors.red),
              title: const Text('Disconnect', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${integration.name} disconnected')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}

enum _IntegrationStatus { healthy, warning, error, disconnected }

class _Integration {
  const _Integration({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.status,
    required this.lastSync,
    required this.syncedItems,
    required this.errors,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final _IntegrationStatus status;
  final DateTime? lastSync;
  final int syncedItems;
  final int errors;
}
