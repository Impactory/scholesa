import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Integrations Health page for monitoring all site integrations
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class HqIntegrationsHealthPage extends StatelessWidget {
  const HqIntegrationsHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Integrations Health'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing all integrations...')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildOverallHealth(context),
          const SizedBox(height: 24),
          _buildSiteIntegrations(context),
        ],
      ),
    );
  }

  Widget _buildOverallHealth(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'All Systems Operational',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '12 integrations active across 5 sites',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteIntegrations(BuildContext context) {
    final List<_SiteIntegration> sites = <_SiteIntegration>[
      _SiteIntegration(
        siteName: 'Downtown Studio',
        integrations: <_Integration>[
          _Integration(name: 'Google Classroom', status: _Status.healthy, lastSync: '5 min ago'),
          _Integration(name: 'GitHub', status: _Status.healthy, lastSync: '15 min ago'),
        ],
      ),
      _SiteIntegration(
        siteName: 'Westside Campus',
        integrations: <_Integration>[
          _Integration(name: 'Google Classroom', status: _Status.warning, lastSync: '2 hrs ago'),
          _Integration(name: 'Canvas LMS', status: _Status.healthy, lastSync: '30 min ago'),
        ],
      ),
      _SiteIntegration(
        siteName: 'North Branch',
        integrations: <_Integration>[
          _Integration(name: 'Google Classroom', status: _Status.error, lastSync: 'Failed'),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Sites',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ScholesaColors.textPrimary),
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
        title: Text(site.siteName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${site.integrations.length} integrations'),
        leading: _buildSiteStatusIcon(site),
        children: site.integrations.map((integration) => _buildIntegrationTile(context, integration)).toList(),
      ),
    );
  }

  Widget _buildSiteStatusIcon(_SiteIntegration site) {
    final bool hasError = site.integrations.any((_Integration i) => i.status == _Status.error);
    final bool hasWarning = site.integrations.any((_Integration i) => i.status == _Status.warning);
    
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
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
      subtitle: Text('Last sync: ${integration.lastSync}'),
      trailing: integration.status == _Status.error
          ? TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Retrying ${integration.name}...')),
                );
              },
              child: const Text('Retry'),
            )
          : null,
    );
  }
}

enum _Status { healthy, warning, error }

class _Integration {
  const _Integration({required this.name, required this.status, required this.lastSync});
  final String name;
  final _Status status;
  final String lastSync;
}

class _SiteIntegration {
  const _SiteIntegration({required this.siteName, required this.integrations});
  final String siteName;
  final List<_Integration> integrations;
}
