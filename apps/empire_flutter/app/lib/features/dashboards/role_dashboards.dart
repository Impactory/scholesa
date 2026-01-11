import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';

const String buildTag = '2026-01-05c';

class CardDefinition {
  const CardDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.roles,
    this.route,
    this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> roles;
  final String? route;
  final IconData? icon;
}

/// Routes that are enabled in the current build; others show a snackbar.
/// Aligns with docs/49_ROUTE_FLIP_TRACKER.md (most routes disabled until verified).
const Map<String, bool> kKnownRoutes = <String, bool>{
  '/messaging': false,
  '/marketplace': true,
  '/analytics': true,
  '/notifications': false,

  // Dashboards
  '/dashboard/learner': true,
  '/dashboard/educator': true,
  '/dashboard/parent': true,
  '/dashboard/site': true,
  '/dashboard/partner': true,
  '/dashboard/hq': true,

  // Learner
  '/learner/today': false,
  '/learner/missions': false,
  '/learner/habits': false,
  '/learner/portfolio': false,

  // Educator
  '/educator/today': false,
  '/educator/attendance': false,
  '/educator/plan': false,
  '/educator/review-queue': false,
  '/educator/supports': false,
  '/educator/integrations': false,

  // Parent
  '/parent/summary': false,
  '/parent/schedule': false,
  '/parent/portfolio': false,
  '/parent/billing': false,

  // Site
  '/site/ops-today': false,
  '/site/checkin': false,
  '/site/provisioning': false,
  '/site/incidents': false,
  '/site/identity-resolution': false,
  '/site/consent': false,
  '/site/integrations': false,
  '/site/billing': false,

  // Partner
  '/partner/listings': false,
  '/partner/contracts': false,
  '/partner/payouts': false,

  // HQ
  '/hq/user-admin': true, // enabled per route flip tracker
  '/hq/approvals': false,
  '/hq/audit-logs': false,
  '/hq/safety': false,
  '/hq/billing-admin': false,
  '/hq/integrations': false,
};

/// Registry derived from docs/47_ROLE_DASHBOARD_CARD_REGISTRY.md
const List<CardDefinition> kRoleCards = <CardDefinition>[
  // Shared
  CardDefinition(id: 'messages', title: 'Messages', subtitle: 'Threads and replies', roles: <String>['all'], route: '/messaging', icon: Icons.chat_bubble_outline),
  CardDefinition(id: 'marketplace', title: 'Marketplace', subtitle: 'Browse listings and enroll', roles: <String>['learner', 'parent', 'educator'], route: '/marketplace', icon: Icons.shopping_bag_outlined),
  CardDefinition(id: 'analytics', title: 'Analytics & KPIs', subtitle: 'Telemetry-driven rollups', roles: <String>['hq', 'site', 'educator'], route: '/analytics', icon: Icons.insights),
  CardDefinition(id: 'notifications', title: 'Notifications', subtitle: 'Alerts and requests', roles: <String>['all'], route: '/notifications', icon: Icons.notifications_outlined),

  // Learner
  CardDefinition(id: 'learner_today', title: 'Today', subtitle: 'Schedule & sessions', roles: <String>['learner'], route: '/learner/today', icon: Icons.today),
  CardDefinition(id: 'learner_missions', title: 'My Missions', subtitle: 'Start or continue', roles: <String>['learner'], route: '/learner/missions', icon: Icons.flag_outlined),
  CardDefinition(id: 'learner_habits', title: 'Habit Coach', subtitle: 'Do-now and reflect', roles: <String>['learner'], route: '/learner/habits', icon: Icons.timer),
  CardDefinition(id: 'learner_portfolio', title: 'Portfolio', subtitle: 'Highlights & credentials', roles: <String>['learner'], route: '/learner/portfolio', icon: Icons.workspace_premium),

  // Educator
  CardDefinition(id: 'educator_today_classes', title: "Today's Classes", subtitle: 'Open roster/plan', roles: <String>['educator'], route: '/educator/today', icon: Icons.class_),
  CardDefinition(id: 'educator_attendance', title: 'Take Attendance', subtitle: 'Mark present/late/absent', roles: <String>['educator'], route: '/educator/attendance', icon: Icons.check_circle),
  CardDefinition(id: 'educator_plan', title: 'Plan Missions', subtitle: 'Create/duplicate plans', roles: <String>['educator'], route: '/educator/plan', icon: Icons.assignment),
  CardDefinition(id: 'educator_review_queue', title: 'Review Queue', subtitle: 'Review attempts & rubrics', roles: <String>['educator'], route: '/educator/review-queue', icon: Icons.rate_review),
  CardDefinition(id: 'educator_supports', title: 'Learner Supports', subtitle: 'Insights & interventions', roles: <String>['educator'], route: '/educator/supports', icon: Icons.lightbulb_outline),
  CardDefinition(id: 'educator_integrations', title: 'Integrations', subtitle: 'Classroom + GitHub sync', roles: <String>['educator'], route: '/educator/integrations', icon: Icons.cloud_sync),

  // Parent
  CardDefinition(id: 'parent_child_summary', title: 'Child Summary', subtitle: 'Weekly overview', roles: <String>['parent'], route: '/parent/summary', icon: Icons.insights),
  CardDefinition(id: 'parent_schedule', title: 'Schedule', subtitle: 'Upcoming sessions', roles: <String>['parent'], route: '/parent/schedule', icon: Icons.event),
  CardDefinition(id: 'parent_portfolio', title: 'Portfolio Highlights', subtitle: 'Parent-safe artifacts', roles: <String>['parent'], route: '/parent/portfolio', icon: Icons.photo_album),
  CardDefinition(id: 'parent_billing', title: 'Billing', subtitle: 'Receipts and status', roles: <String>['parent'], route: '/parent/billing', icon: Icons.receipt_long),

  // Site
  CardDefinition(id: 'site_ops_today', title: 'Today Operations', subtitle: 'Open/close day', roles: <String>['site'], route: '/site/ops-today', icon: Icons.dashboard_customize),
  CardDefinition(id: 'site_checkin_checkout', title: 'Check-in / Check-out', subtitle: 'Scan and validate pickup', roles: <String>['site'], route: '/site/checkin', icon: Icons.qr_code_scanner),
  CardDefinition(id: 'site_provisioning', title: 'Provisioning', subtitle: 'Create users and links', roles: <String>['site'], route: '/site/provisioning', icon: Icons.group_add),
  CardDefinition(id: 'site_incidents', title: 'Safety & Incidents', subtitle: 'Review and escalate', roles: <String>['site'], route: '/site/incidents', icon: Icons.shield_moon),
  CardDefinition(id: 'site_consent', title: 'Consents & Pickup', subtitle: 'Media + authorized pickup', roles: <String>['site'], route: '/site/consent', icon: Icons.fact_check),
  CardDefinition(id: 'site_identity_resolution', title: 'Identity Resolution', subtitle: 'Approve matches', roles: <String>['site'], route: '/site/identity-resolution', icon: Icons.perm_identity),
  CardDefinition(id: 'site_integrations_health', title: 'Integrations Health', subtitle: 'Sync job status', roles: <String>['site'], route: '/site/integrations', icon: Icons.monitor_heart),
  CardDefinition(id: 'site_billing', title: 'Site Billing', subtitle: 'Subscriptions & entitlements', roles: <String>['site'], route: '/site/billing', icon: Icons.account_balance_wallet),

  // Partner
  CardDefinition(id: 'partner_listings', title: 'Listings', subtitle: 'Create/edit marketplace listings', roles: <String>['partner'], route: '/partner/listings', icon: Icons.storefront),
  CardDefinition(id: 'partner_contracts', title: 'Contracts', subtitle: 'Submit deliverables', roles: <String>['partner'], route: '/partner/contracts', icon: Icons.handshake),
  CardDefinition(id: 'partner_payouts', title: 'Payouts', subtitle: 'View status/history', roles: <String>['partner'], route: '/partner/payouts', icon: Icons.payments_outlined),

  // HQ
  CardDefinition(id: 'hq_user_admin', title: 'User Administration', subtitle: 'Roles and access', roles: <String>['hq'], route: '/hq/user-admin', icon: Icons.admin_panel_settings),
  CardDefinition(id: 'hq_approvals', title: 'Approvals Queue', subtitle: 'Listings, contracts, payouts', roles: <String>['hq'], route: '/hq/approvals', icon: Icons.rule_folder),
  CardDefinition(id: 'hq_audit_logs', title: 'Audit & Logs', subtitle: 'Review exports', roles: <String>['hq'], route: '/hq/audit-logs', icon: Icons.history),
  CardDefinition(id: 'hq_safety_oversight', title: 'Safety Oversight', subtitle: 'Major incidents', roles: <String>['hq'], route: '/hq/safety', icon: Icons.health_and_safety),
  CardDefinition(id: 'hq_billing_admin', title: 'Billing Admin', subtitle: 'Entitlements and accounts', roles: <String>['hq'], route: '/hq/billing-admin', icon: Icons.receipt_long),
  CardDefinition(id: 'hq_integrations_health', title: 'Integrations Health', subtitle: 'Sync failures across sites', roles: <String>['hq'], route: '/hq/integrations', icon: Icons.cloud_off),
];

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentRole = appState.role ?? role;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(currentRole)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              appState.clearRole();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          )
        ],
      ),
      body: _buildContent(context, currentRole),
    );
  }

  String _titleFor(String currentRole) {
    switch (currentRole) {
      case 'learner':
        return 'Learner Dashboard';
      case 'educator':
        return 'Educator Dashboard';
      case 'parent':
        return 'Parent Dashboard';
      case 'site':
        return 'Site Lead Dashboard';
      case 'partner':
        return 'Partner Dashboard';
      case 'hq':
        return 'HQ Dashboard';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(BuildContext context, String currentRole) {
    final cards = kRoleCards.where((c) => c.roles.contains(currentRole) || c.roles.contains('all')).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final card in cards) _navCard(context, card: card),
        const SizedBox(height: 12),
        Text('Build: $buildTag', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

  Widget _navCard(BuildContext context, {required CardDefinition card}) {
    return Tooltip(
      message: card.subtitle,
      child: Card(
        child: ListTile(
          leading: Icon(card.icon ?? Icons.dashboard_customize),
          title: Text(card.title),
          subtitle: Text(card.subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleTap(context, card),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, CardDefinition card) {
    final route = card.route;
    final enabled = route != null && (kKnownRoutes[route] ?? false);
    if (enabled) {
      Navigator.pushNamed(context, route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${card.title} coming soon')),
      );
    }
  }
}
