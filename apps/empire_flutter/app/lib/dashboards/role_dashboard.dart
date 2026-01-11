import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../router/app_router.dart';
import '../ui/theme/scholesa_theme.dart';
import '../ui/widgets/cards.dart';

/// Dashboard card definition from docs/47_ROLE_DASHBOARD_CARD_REGISTRY.md
class DashboardCard {

  const DashboardCard({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.route,
    required this.gradient,
    this.badgeText,
  });
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String route;
  final LinearGradient gradient;
  final String? badgeText;
}

/// Card registry per role - based on docs/47
final Map<UserRole, List<DashboardCard>> _cardRegistry = <UserRole, List<DashboardCard>>{
  // ═══════════════════════════════════════════════════════════════════════════
  // LEARNER DASHBOARD - Cyan/Blue theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.learner: <DashboardCard>[
    const DashboardCard(
      id: 'learner_today',
      title: 'Today',
      subtitle: 'Your schedule for today',
      icon: Icons.today_rounded,
      route: '/learner/today',
      gradient: ScholesaColors.scheduleGradient,
    ),
    const DashboardCard(
      id: 'learner_missions',
      title: 'My Missions',
      subtitle: 'Start and continue missions',
      icon: Icons.rocket_launch_rounded,
      route: '/learner/missions',
      gradient: ScholesaColors.missionGradient,
      badgeText: '3 Active',
    ),
    const DashboardCard(
      id: 'learner_habits',
      title: 'Habit Coach',
      subtitle: 'Build great habits daily',
      icon: Icons.psychology_rounded,
      route: '/learner/habits',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF10B981), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'learner_portfolio',
      title: 'Portfolio',
      subtitle: 'Your achievements & work',
      icon: Icons.folder_special_rounded,
      route: '/learner/portfolio',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // EDUCATOR DASHBOARD - Purple theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.educator: <DashboardCard>[
    const DashboardCard(
      id: 'educator_today_classes',
      title: "Today's Classes",
      subtitle: 'View roster and plans',
      icon: Icons.calendar_today_rounded,
      route: '/educator/today',
      gradient: ScholesaColors.scheduleGradient,
      badgeText: '4 Classes',
    ),
    const DashboardCard(
      id: 'educator_attendance',
      title: 'Take Attendance',
      subtitle: 'Mark student attendance',
      icon: Icons.fact_check_rounded,
      route: '/educator/attendance',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'educator_plan',
      title: 'Plan Missions',
      subtitle: 'Create and edit lesson plans',
      icon: Icons.edit_note_rounded,
      route: '/educator/mission-plans',
      gradient: ScholesaColors.missionGradient,
    ),
    const DashboardCard(
      id: 'educator_review_queue',
      title: 'Review Queue',
      subtitle: 'Review student submissions',
      icon: Icons.rate_review_rounded,
      route: '/educator/review-queue',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      badgeText: '12 Pending',
    ),
    const DashboardCard(
      id: 'educator_supports',
      title: 'Learner Supports',
      subtitle: 'Track interventions',
      icon: Icons.support_agent_rounded,
      route: '/educator/learner-supports',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF06B6D4), Color(0xFF22D3EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'educator_integrations',
      title: 'Integrations',
      subtitle: 'Classroom & GitHub',
      icon: Icons.integration_instructions_rounded,
      route: '/educator/integrations',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF64748B), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // PARENT DASHBOARD - Amber/Warm theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.parent: <DashboardCard>[
    const DashboardCard(
      id: 'parent_child_summary',
      title: 'Child Summary',
      subtitle: 'Weekly progress overview',
      icon: Icons.child_care_rounded,
      route: '/parent/summary',
      gradient: ScholesaColors.parentGradient,
    ),
    const DashboardCard(
      id: 'parent_schedule',
      title: 'Schedule',
      subtitle: 'Upcoming classes',
      icon: Icons.schedule_rounded,
      route: '/parent/schedule',
      gradient: ScholesaColors.scheduleGradient,
    ),
    const DashboardCard(
      id: 'parent_portfolio',
      title: 'Portfolio Highlights',
      subtitle: 'Shared achievements',
      icon: Icons.photo_library_rounded,
      route: '/parent/portfolio',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'parent_billing',
      title: 'Billing',
      subtitle: 'Invoices and payments',
      icon: Icons.receipt_long_rounded,
      route: '/parent/billing',
      gradient: ScholesaColors.billingGradient,
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // SITE DASHBOARD - Teal theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.site: <DashboardCard>[
    const DashboardCard(
      id: 'site_ops_today',
      title: 'Today Operations',
      subtitle: 'Daily overview',
      icon: Icons.dashboard_rounded,
      route: '/site/ops',
      gradient: ScholesaColors.siteGradient,
    ),
    const DashboardCard(
      id: 'site_checkin_checkout',
      title: 'Check-in / Check-out',
      subtitle: 'Manage arrivals and pickups',
      icon: Icons.qr_code_scanner_rounded,
      route: '/site/checkin',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF3B82F6), Color(0xFF60A5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_provisioning',
      title: 'Provisioning',
      subtitle: 'Manage users and links',
      icon: Icons.person_add_rounded,
      route: '/site/provisioning',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_incidents',
      title: 'Safety & Incidents',
      subtitle: 'Review and manage incidents',
      icon: Icons.warning_rounded,
      route: '/site/incidents',
      gradient: ScholesaColors.safetyGradient,
      badgeText: '2 Open',
    ),
    const DashboardCard(
      id: 'site_identity_resolution',
      title: 'Identity Resolution',
      subtitle: 'Match external accounts',
      icon: Icons.link_rounded,
      route: '/site/identity',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF64748B), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_integrations_health',
      title: 'Integrations Health',
      subtitle: 'Sync status',
      icon: Icons.sync_rounded,
      route: '/site/integrations-health',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'site_billing',
      title: 'Site Billing',
      subtitle: 'Subscription management',
      icon: Icons.payment_rounded,
      route: '/site/billing',
      gradient: ScholesaColors.billingGradient,
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // PARTNER DASHBOARD - Pink theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.partner: <DashboardCard>[
    const DashboardCard(
      id: 'partner_listings',
      title: 'Listings',
      subtitle: 'Manage marketplace listings',
      icon: Icons.storefront_rounded,
      route: '/partner/listings',
      gradient: ScholesaColors.partnerGradient,
    ),
    const DashboardCard(
      id: 'partner_contracts',
      title: 'Contracts',
      subtitle: 'View and manage contracts',
      icon: Icons.description_rounded,
      route: '/partner/contracts',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'partner_payouts',
      title: 'Payouts',
      subtitle: 'Payment history',
      icon: Icons.account_balance_rounded,
      route: '/partner/payouts',
      gradient: ScholesaColors.billingGradient,
    ),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // HQ DASHBOARD - Indigo theme
  // ═══════════════════════════════════════════════════════════════════════════
  UserRole.hq: <DashboardCard>[
    const DashboardCard(
      id: 'hq_user_admin',
      title: 'User Administration',
      subtitle: 'Manage all users',
      icon: Icons.admin_panel_settings_rounded,
      route: '/hq/user-admin',
      gradient: ScholesaColors.hqGradient,
    ),
    const DashboardCard(
      id: 'hq_approvals',
      title: 'Approvals Queue',
      subtitle: 'Review submissions',
      icon: Icons.approval_rounded,
      route: '/hq/approvals',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      badgeText: '5 Pending',
    ),
    const DashboardCard(
      id: 'hq_audit_logs',
      title: 'Audit & Logs',
      subtitle: 'System audit trail',
      icon: Icons.history_rounded,
      route: '/hq/audit',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF64748B), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_safety_oversight',
      title: 'Safety Oversight',
      subtitle: 'Critical incidents',
      icon: Icons.shield_rounded,
      route: '/hq/safety',
      gradient: ScholesaColors.safetyGradient,
    ),
    const DashboardCard(
      id: 'hq_billing_admin',
      title: 'Billing Admin',
      subtitle: 'Platform billing',
      icon: Icons.monetization_on_rounded,
      route: '/hq/billing',
      gradient: ScholesaColors.billingGradient,
    ),
    const DashboardCard(
      id: 'hq_integrations_health',
      title: 'Integrations Health',
      subtitle: 'Global sync status',
      icon: Icons.health_and_safety_rounded,
      route: '/hq/integrations-health',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF22C55E), Color(0xFF4ADE80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ],
};

/// Shared cards for all roles
final List<DashboardCard> _sharedCards = <DashboardCard>[
  const DashboardCard(
    id: 'messages',
    title: 'Messages',
    subtitle: 'Conversations',
    icon: Icons.message_rounded,
    route: '/messages',
    gradient: LinearGradient(
      colors: <Color>[Color(0xFF3B82F6), Color(0xFF60A5FA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  const DashboardCard(
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Recent alerts',
    icon: Icons.notifications_rounded,
    route: '/notifications',
    gradient: LinearGradient(
      colors: <Color>[Color(0xFFF59E0B), Color(0xFFFBBF24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    badgeText: '5 New',
  ),
];

/// Main role-based dashboard with beautiful colorful UI
class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final UserRole? role = appState.role;
        
        if (role == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final List<DashboardCard> cards = <DashboardCard>[...(_cardRegistry[role] ?? <DashboardCard>[]), ..._sharedCards];
        final LinearGradient roleGradient = role.name.roleGradient;
        final Color roleColor = role.name.roleColor;

        return Scaffold(
          backgroundColor: ScholesaColors.background,
          body: CustomScrollView(
            slivers: <Widget>[
              // Beautiful gradient header
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: roleColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(gradient: roleGradient),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                UserAvatar(
                                  name: appState.displayName ?? 'User',
                                  size: 50,
                                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Welcome back,',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                      Text(
                                        appState.displayName ?? 'User',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    _getRoleIcon(role),
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${role.name[0].toUpperCase()}${role.name.substring(1)} Dashboard',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: <Widget>[
                  if (appState.siteIds.length > 1)
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      tooltip: 'Switch site',
                      onPressed: () => _showSiteSwitcher(context, appState),
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    tooltip: 'Settings',
                    onPressed: () {
                      // TODO: Navigate to settings
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Sign out',
                    onPressed: () => _showLogoutDialog(context),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Quick stats section (optional based on role)
              if (role == UserRole.educator || role == UserRole.site || role == UserRole.hq)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: _buildQuickStats(role),
                  ),
                ),

              // Section title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: <Widget>[
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ScholesaColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              // Cards grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final DashboardCard card = cards[index];
                      final bool isEnabled = isRouteEnabled(card.route);
                      
                      return GradientCard(
                        title: card.title,
                        subtitle: card.subtitle,
                        icon: card.icon,
                        gradient: card.gradient,
                        isEnabled: isEnabled,
                        badgeText: isEnabled ? card.badgeText : null,
                        onTap: () => _handleCardTap(context, card, isEnabled),
                      );
                    },
                    childCount: cards.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats(UserRole role) {
    final List<Map<String, dynamic>> stats = _getStatsForRole(role);
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> stat = stats[index];
          return SizedBox(
            width: 140,
            child: StatCard(
              label: stat['label'] as String,
              value: stat['value'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
              trend: stat['trend'] as String?,
              isPositive: stat['positive'] as bool? ?? true,
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getStatsForRole(UserRole role) {
    switch (role) {
      case UserRole.educator:
        return <Map<String, dynamic>>[
          <String, dynamic>{'label': 'Students Today', 'value': '24', 'icon': Icons.people, 'color': ScholesaColors.info, 'trend': '+3'},
          <String, dynamic>{'label': 'Attendance', 'value': '96%', 'icon': Icons.check_circle, 'color': ScholesaColors.success, 'trend': '+2%'},
          <String, dynamic>{'label': 'To Review', 'value': '12', 'icon': Icons.rate_review, 'color': ScholesaColors.warning},
        ];
      case UserRole.site:
        return <Map<String, dynamic>>[
          <String, dynamic>{'label': 'On Site', 'value': '45', 'icon': Icons.location_on, 'color': ScholesaColors.info},
          <String, dynamic>{'label': 'Checked In', 'value': '42', 'icon': Icons.login, 'color': ScholesaColors.success, 'trend': '+5'},
          <String, dynamic>{'label': 'Open Incidents', 'value': '2', 'icon': Icons.warning, 'color': ScholesaColors.error},
        ];
      case UserRole.hq:
        return <Map<String, dynamic>>[
          <String, dynamic>{'label': 'Active Sites', 'value': '12', 'icon': Icons.business, 'color': ScholesaColors.primary},
          <String, dynamic>{'label': 'Total Users', 'value': '1.2K', 'icon': Icons.people, 'color': ScholesaColors.info, 'trend': '+8%'},
          <String, dynamic>{'label': 'Pending', 'value': '5', 'icon': Icons.pending_actions, 'color': ScholesaColors.warning},
        ];
      default:
        return <Map<String, dynamic>>[];
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return Icons.school_rounded;
      case UserRole.educator:
        return Icons.cast_for_education_rounded;
      case UserRole.parent:
        return Icons.family_restroom_rounded;
      case UserRole.site:
        return Icons.business_rounded;
      case UserRole.partner:
        return Icons.handshake_rounded;
      case UserRole.hq:
        return Icons.corporate_fare_rounded;
    }
  }

  void _handleCardTap(BuildContext context, DashboardCard card, bool isEnabled) {
    if (isEnabled) {
      context.push(card.route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${card.title} is coming soon!'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ScholesaColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSiteSwitcher(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Switch Site',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ...appState.siteIds.map((String siteId) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ScholesaColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: siteId == appState.activeSiteId 
                      ? ScholesaColors.primary 
                      : ScholesaColors.textMuted,
                ),
              ),
              title: Text(siteId),
              trailing: siteId == appState.activeSiteId
                  ? const Icon(Icons.check_circle, color: ScholesaColors.success)
                  : null,
              onTap: () {
                appState.switchSite(siteId);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: <Widget>[
            Icon(Icons.logout, color: ScholesaColors.error),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ScholesaColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
