import 'package:flutter/material.dart';
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
  const EducatorIntegrationsPage({super.key});

  @override
  State<EducatorIntegrationsPage> createState() =>
      _EducatorIntegrationsPageState();
}

class _EducatorIntegrationsPageState extends State<EducatorIntegrationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EducatorService>().loadLearners();
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
                  'Keep BOS/MIA loop active while syncing learner systems',
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
              _buildIntegrationCard(
                context,
                name: 'Google Classroom',
                icon: Icons.school_rounded,
                color: Colors.blue,
                isConnected: true,
                syncStatus:
                    _tEducatorIntegrations(context, 'Last synced 15 min ago'),
              ),
              const SizedBox(height: 12),
              _buildIntegrationCard(
                context,
                name: 'GitHub Classroom',
                icon: Icons.code_rounded,
                color: Colors.black87,
                isConnected: true,
                syncStatus: _tEducatorIntegrations(context, '3 repos connected'),
              ),
              const SizedBox(height: 24),
              Text(
                _tEducatorIntegrations(context, 'Available Integrations'),
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
                          style: const TextStyle(
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
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_integrations',
                          'cta_id': 'integration_menu_action',
                          'surface': 'connected_integration_card',
                          'integration_name': name,
                          'action': value,
                        },
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_tEducatorIntegrations(context, value)} $name')),
                      );
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
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: <String, dynamic>{
                          'module': 'educator_integrations',
                          'cta_id': 'connect_integration',
                          'surface': 'available_integration_card',
                          'integration_name': name,
                        },
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${_tEducatorIntegrations(context, 'Connecting')} $name...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_tEducatorIntegrations(context, 'Connect')),
                  ),
          ],
        ),
      ),
    );
  }
}
