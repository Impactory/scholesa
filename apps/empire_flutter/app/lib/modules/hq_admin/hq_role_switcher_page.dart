import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../i18n/workflow_surface_i18n.dart';
import '../../auth/app_state.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

String _tHqRoleSwitcher(BuildContext context, String input) {
  return WorkflowSurfaceI18n.text(context, input);
}

/// HQ Role Switcher Page
/// Allows HQ users to impersonate other roles for testing/support
class HqRoleSwitcherPage extends StatelessWidget {
  const HqRoleSwitcherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              ScholesaColors.hq.withValues(alpha: 0.05),
              Colors.white,
              ScholesaColors.purple.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              _buildCurrentRoleInfo(context),
              Expanded(child: _buildRoleGrid(context)),
              _buildFooterNote(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: <String, dynamic>{
                  'module': 'hq_role_switcher',
                  'cta_id': 'navigate_back',
                  'surface': 'header',
                },
              );
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[ScholesaColors.hq, ScholesaColors.purple],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ScholesaColors.hq.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.swap_horizontal_circle_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tHqRoleSwitcher(context, 'Role Impersonation'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ScholesaColors.hq,
                      ),
                ),
                Text(
                  _tHqRoleSwitcher(
                      context, 'Test the platform as different user roles'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentRoleInfo(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final UserRole? currentRole = appState.role;
        final UserRole? viewingAs = appState.impersonatingRole;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScholesaColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.person_outline,
                color: currentRole?.name.roleColor ?? ScholesaColors.hq,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tHqRoleSwitcher(context, 'Your actual role'),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      currentRole?.name.toUpperCase() ??
                          _tHqRoleSwitcher(context, 'HQ'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentRole?.name.roleColor ?? ScholesaColors.hq,
                      ),
                    ),
                  ],
                ),
              ),
              if (viewingAs != null) ...<Widget>[
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: viewingAs.name.roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: viewingAs.name.roleColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.visibility,
                        color: viewingAs.name.roleColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_tHqRoleSwitcher(context, 'Viewing as')} ${viewingAs.name}',
                        style: TextStyle(
                          color: viewingAs.name.roleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'module': 'hq_role_switcher',
                        'cta_id': 'clear_impersonation',
                        'surface': 'current_role_info',
                      },
                    );
                    appState.clearImpersonation();
                  },
                  tooltip: _tHqRoleSwitcher(context, 'Exit impersonation'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleGrid(BuildContext context) {
    final List<_RoleOption> roles = <_RoleOption>[
      const _RoleOption(
        role: UserRole.learner,
        title: 'Learner',
        description: 'View missions, habits, and portfolio',
        icon: Icons.school_rounded,
        features: <String>[
          'Today\'s schedule',
          'Mission progress',
          'Habit tracking',
          'Portfolio showcase',
        ],
      ),
      const _RoleOption(
        role: UserRole.educator,
        title: 'Educator',
        description: 'Manage classes and review submissions',
        icon: Icons.person_rounded,
        features: <String>[
          'Class rosters',
          'Attendance',
          'Mission planning',
          'Student reviews',
        ],
      ),
      const _RoleOption(
        role: UserRole.parent,
        title: 'Parent',
        description: 'Monitor child progress and billing',
        icon: Icons.family_restroom_rounded,
        features: <String>[
          'Child summary',
          'Schedule view',
          'Portfolio highlights',
          'Billing & invoices',
        ],
      ),
      const _RoleOption(
        role: UserRole.site,
        title: 'Site Admin',
        description: 'Manage site operations',
        icon: Icons.business_rounded,
        features: <String>[
          'Check-in/out',
          'Provisioning',
          'Incidents',
          'Site billing',
        ],
      ),
      const _RoleOption(
        role: UserRole.partner,
        title: 'Partner',
        description: 'Marketplace and contracts',
        icon: Icons.handshake_rounded,
        features: <String>[
          'Listings',
          'Contracts',
          'Payouts',
        ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: roles.length,
      itemBuilder: (BuildContext context, int index) {
        return _RoleCard(option: roles[index]);
      },
    );
  }

  Widget _buildFooterNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ScholesaColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ScholesaColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline,
              color: ScholesaColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tHqRoleSwitcher(context,
                  'Impersonation is logged for audit purposes. Any actions taken will be attributed to your HQ account.'),
              style: TextStyle(
                fontSize: 13,
                color: ScholesaColors.warning.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
    required this.features,
  });

  final UserRole role;
  final String title;
  final String description;
  final IconData icon;
  final List<String> features;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.option});

  final _RoleOption option;

  @override
  Widget build(BuildContext context) {
    final Color roleColor = option.role.name.roleColor;

    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final bool isActive = appState.impersonatingRole == option.role;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? roleColor : ScholesaColors.border,
              width: isActive ? 2 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isActive
                    ? roleColor.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isActive ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (isActive) {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'hq_role_switcher',
                      'cta_id': 'deactivate_role_impersonation',
                      'surface': 'role_card',
                      'role': option.role.name,
                    },
                  );
                  appState.clearImpersonation();
                } else {
                  TelemetryService.instance.logEvent(
                    event: 'cta.clicked',
                    metadata: <String, dynamic>{
                      'module': 'hq_role_switcher',
                      'cta_id': 'activate_role_impersonation',
                      'surface': 'role_card',
                      'role': option.role.name,
                    },
                  );
                  appState.setImpersonation(option.role);
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: option.role.name.roleGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            option.icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _tHqRoleSwitcher(context, option.title),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                              Text(
                                _tHqRoleSwitcher(context, option.description),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.visibility,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _tHqRoleSwitcher(context, 'Active'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: option.features.map((String feature) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _tHqRoleSwitcher(context, feature),
                            style: TextStyle(
                              fontSize: 12,
                              color: roleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
