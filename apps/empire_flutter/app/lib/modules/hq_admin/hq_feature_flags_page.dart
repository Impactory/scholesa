import 'package:flutter/material.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Feature Flags page for managing feature toggles
/// Based on docs/49_ROUTE_FLIP_TRACKER.md
class HqFeatureFlagsPage extends StatefulWidget {
  const HqFeatureFlagsPage({super.key});

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
  final List<_FeatureFlag> _flags = <_FeatureFlag>[
    _FeatureFlag(
      id: '1',
      name: 'new_dashboard',
      description: 'Enable redesigned dashboard layout with improved metrics',
      isEnabled: true,
      scope: 'global',
    ),
    _FeatureFlag(
      id: '2',
      name: 'ai_reflections',
      description: 'Enable AI-powered reflection prompts for learners',
      isEnabled: true,
      scope: 'global',
    ),
    _FeatureFlag(
      id: '3',
      name: 'github_integration',
      description: 'Enable GitHub classroom integration for coding missions',
      isEnabled: false,
      scope: 'site',
      enabledSites: <String>['Downtown Studio', 'Tech Campus'],
    ),
    _FeatureFlag(
      id: '4',
      name: 'parent_portfolio_view',
      description: 'Allow parents to view detailed learner portfolios',
      isEnabled: true,
      scope: 'global',
    ),
    _FeatureFlag(
      id: '5',
      name: 'beta_missions',
      description: 'Show beta missions to selected educators',
      isEnabled: false,
      scope: 'user',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Feature Flags'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening change history...')),
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
          ..._flags.map((flag) => _buildFlagCard(flag)),
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
              'Feature flags control which features are available to users. Changes take effect immediately.',
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
                        flag.description,
                        style: TextStyle(fontSize: 13, color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: flag.isEnabled,
                  onChanged: (bool value) {
                    setState(() => flag.isEnabled = value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${flag.name} ${value ? "enabled" : "disabled"}'),
                        backgroundColor: value ? Colors.green : Colors.orange,
                      ),
                    );
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            if (flag.scope == 'site' && flag.enabledSites != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: flag.enabledSites!.map((String site) => Chip(
                  label: Text(site, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip(String scope) {
    Color color;
    IconData icon;
    switch (scope) {
      case 'global':
        color = Colors.green;
        icon = Icons.public_rounded;
      case 'site':
        color = Colors.blue;
        icon = Icons.location_on_rounded;
      case 'user':
        color = Colors.purple;
        icon = Icons.person_rounded;
      default:
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
          Text(scope, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
