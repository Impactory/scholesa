import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// Educator integrations page for managing external tool connections
/// Based on docs/31_GOOGLE_CLASSROOM_SYNC_JOBS.md and docs/37_GITHUB_WEBHOOKS_EVENTS_AND_SYNC.md
class EducatorIntegrationsPage extends StatelessWidget {
  const EducatorIntegrationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('My Integrations'),
        backgroundColor: ScholesaColors.educatorGradient.colors.first,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildInfoCard(),
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
          _buildIntegrationCard(
            context,
            name: 'Google Classroom',
            icon: Icons.school_rounded,
            color: Colors.blue,
            isConnected: true,
            syncStatus: 'Last synced 15 min ago',
          ),
          const SizedBox(height: 12),
          _buildIntegrationCard(
            context,
            name: 'GitHub Classroom',
            icon: Icons.code_rounded,
            color: Colors.black87,
            isConnected: true,
            syncStatus: '3 repos connected',
          ),
          const SizedBox(height: 24),
          const Text(
            'Available Integrations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ScholesaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildIntegrationCard(
            context,
            name: 'Canvas LMS',
            icon: Icons.dashboard_rounded,
            color: Colors.red,
            isConnected: false,
            syncStatus: null,
          ),
          const SizedBox(height: 12),
          _buildIntegrationCard(
            context,
            name: 'Microsoft Teams',
            icon: Icons.groups_rounded,
            color: Colors.purple,
            isConnected: false,
            syncStatus: null,
          ),
        ],
      ),
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
              'Connect external tools to sync assignments, grades, and learner progress automatically.',
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
    required String name,
    required IconData icon,
    required Color color,
    required bool isConnected,
    String? syncStatus,
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ScholesaColors.textPrimary,
                    ),
                  ),
                  if (syncStatus != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          syncStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: ScholesaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            isConnected
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (String value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$value $name')),
                      );
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(value: 'Sync', child: Text('Sync Now')),
                      const PopupMenuItem<String>(value: 'Settings', child: Text('Settings')),
                      const PopupMenuItem<String>(value: 'Disconnect', child: Text('Disconnect')),
                    ],
                  )
                : ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Connecting $name...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Connect'),
                  ),
          ],
        ),
      ),
    );
  }
}
