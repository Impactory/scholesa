import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import '../router/app_router.dart';
import '../services/telemetry_service.dart';
import '../ui/theme/scholesa_theme.dart';
import '../ui/widgets/cards.dart';

const Map<String, String> _roleDashboardEs = <String, String>{
  'Today': 'Hoy',
  'Your schedule for today': 'Tu horario de hoy',
  'My Missions': 'Mis misiones',
  'Start and continue missions': 'Inicia y continúa misiones',
  '3 Active': '3 activas',
  'Habit Coach': 'Coach de hábitos',
  'Build great habits daily': 'Construye hábitos diarios',
  'Portfolio': 'Portafolio',
  'Your achievements & work': 'Tus logros y trabajo',
  "Today's Classes": 'Clases de hoy',
  'View roster and plans': 'Ver lista y planes',
  '4 Classes': '4 clases',
  'Take Attendance': 'Tomar asistencia',
  'Mark student attendance': 'Marcar asistencia de estudiantes',
  'Plan Missions': 'Planificar misiones',
  'Create and edit lesson plans': 'Crear y editar planes de clase',
  'Review Queue': 'Cola de revisión',
  'Review student submissions': 'Revisar entregas de estudiantes',
  '12 Pending': '12 pendientes',
  'Learner Supports': 'Apoyos al estudiante',
  'Track interventions': 'Seguimiento de intervenciones',
  'Integrations': 'Integraciones',
  'Classroom & GitHub': 'Classroom y GitHub',
  'Child Summary': 'Resumen del estudiante',
  'Weekly progress overview': 'Resumen semanal de progreso',
  'Schedule': 'Horario',
  'Upcoming classes': 'Próximas clases',
  'Portfolio Highlights': 'Destacados del portafolio',
  'Shared achievements': 'Logros compartidos',
  'Billing': 'Facturación',
  'Invoices and payments': 'Facturas y pagos',
  'Today Operations': 'Operaciones de hoy',
  'Daily overview': 'Resumen diario',
  'Check-in / Check-out': 'Entrada / salida',
  'Manage arrivals and pickups': 'Gestionar llegadas y retiros',
  'Provisioning': 'Aprovisionamiento',
  'Manage users and links': 'Gestionar usuarios y vínculos',
  'Safety & Incidents': 'Seguridad e incidentes',
  'Review and manage incidents': 'Revisar y gestionar incidentes',
  '2 Open': '2 abiertos',
  'Identity Resolution': 'Resolución de identidad',
  'Match external accounts': 'Vincular cuentas externas',
  'Integrations Health': 'Estado de integraciones',
  'Sync status': 'Estado de sincronización',
  'Site Billing': 'Facturación del sitio',
  'Subscription management': 'Gestión de suscripciones',
  'Listings': 'Publicaciones',
  'Manage marketplace listings': 'Gestionar publicaciones del marketplace',
  'Contracts': 'Contratos',
  'View and manage contracts': 'Ver y gestionar contratos',
  'Payouts': 'Pagos',
  'Payment history': 'Historial de pagos',
  'User Administration': 'Administración de usuarios',
  'Manage all users': 'Gestionar todos los usuarios',
  'Approvals Queue': 'Cola de aprobaciones',
  'Review submissions': 'Revisar envíos',
  '5 Pending': '5 pendientes',
  'Audit & Logs': 'Auditoría y registros',
  'System audit trail': 'Rastro de auditoría del sistema',
  'Safety Oversight': 'Supervisión de seguridad',
  'Critical incidents': 'Incidentes críticos',
  'Billing Admin': 'Administración de facturación',
  'Platform billing': 'Facturación de la plataforma',
  'Global sync status': 'Estado global de sincronización',
  'Site Management': 'Gestión de sedes',
  'All sites overview': 'Resumen de todas las sedes',
  'Platform Analytics': 'Analítica de la plataforma',
  'Global metrics & insights': 'Métricas e insights globales',
  'Role Impersonation': 'Suplantación de rol',
  'Test other role views': 'Probar vistas de otros roles',
  'Curriculum Builder': 'Constructor curricular',
  'Pillars, skills, missions': 'Pilares, habilidades, misiones',
  'Feature Flags': 'Feature flags',
  'Toggle platform features': 'Activar/desactivar funciones',
  'Messages': 'Mensajes',
  'Conversations': 'Conversaciones',
  'Notifications': 'Notificaciones',
  'Recent alerts': 'Alertas recientes',
  '5 New': '5 nuevas',
  'Welcome back,': 'Bienvenido de nuevo,',
  'User': 'Usuario',
  'Dashboard': 'Panel',
  'Switch site': 'Cambiar sede',
  'Settings': 'Configuración',
  'Sign out': 'Cerrar sesión',
  'Quick Actions': 'Acciones rápidas',
  'View All': 'Ver todo',
  'All Quick Actions': 'Todas las acciones rápidas',
  'This action is not available for your current role or site setup. You can review your access in Settings.':
      'Esta acción no está disponible para tu rol actual o configuración de sede. Puedes revisar tu acceso en Configuración.',
  'Close': 'Cerrar',
  'Open Settings': 'Abrir configuración',
  'Switch Site': 'Cambiar sede',
  'Students Today': 'Estudiantes hoy',
  'Attendance': 'Asistencia',
  'To Review': 'Por revisar',
  'On Site': 'En sede',
  'Checked In': 'Registrados',
  'Open Incidents': 'Incidentes abiertos',
  'Active Sites': 'Sedes activas',
  'Total Users': 'Usuarios totales',
  'Pending': 'Pendiente',
  '7-day': '7 días',
  'within SLA': 'dentro de SLA',
  'hours': 'horas',
  'Sign Out': 'Cerrar sesión',
  'Are you sure you want to sign out?': '¿Seguro que quieres cerrar sesión?',
  'learner': 'Estudiante',
  'educator': 'Educador',
  'parent': 'Familia',
  'site': 'Sede',
  'partner': 'Aliado',
  'hq': 'HQ',
};

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
final Map<UserRole, List<DashboardCard>> _cardRegistry =
    <UserRole, List<DashboardCard>>{
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
      route: '/educator/missions/review',
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
    const DashboardCard(
      id: 'hq_sites',
      title: 'Site Management',
      subtitle: 'All sites overview',
      icon: Icons.business_rounded,
      route: '/hq/sites',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_analytics',
      title: 'Platform Analytics',
      subtitle: 'Global metrics & insights',
      icon: Icons.analytics_rounded,
      route: '/hq/analytics',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_role_switcher',
      title: 'Role Impersonation',
      subtitle: 'Test other role views',
      icon: Icons.swap_horizontal_circle_rounded,
      route: '/hq/role-switcher',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFFEC4899), Color(0xFFF472B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_curriculum',
      title: 'Curriculum Builder',
      subtitle: 'Pillars, skills, missions',
      icon: Icons.school_rounded,
      route: '/hq/curriculum',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF059669), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    const DashboardCard(
      id: 'hq_feature_flags',
      title: 'Feature Flags',
      subtitle: 'Toggle platform features',
      icon: Icons.flag_rounded,
      route: '/hq/feature-flags',
      gradient: LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF818CF8)],
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

  String _t(BuildContext context, String input) {
    final String locale = Localizations.localeOf(context).languageCode;
    if (locale != 'es') return input;
    return _roleDashboardEs[input] ?? input;
  }

  String _roleLabel(BuildContext context, UserRole role) {
    final String localizedRole = _t(context, role.name);
    return '$localizedRole ${_t(context, 'Dashboard')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState appState, _) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final UserRole? role = appState.role;

        if (role == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final List<DashboardCard> cards = <DashboardCard>[
          ...(_cardRegistry[role] ?? <DashboardCard>[]),
          ..._sharedCards
        ];
        final LinearGradient roleGradient = role.name.roleGradient;
        final Color roleColor = role.name.roleColor;

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          body: CustomScrollView(
            slivers: <Widget>[
              // Beautiful gradient header
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: roleColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(gradient: roleGradient),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color.fromRGBO(0, 0, 0, 0.22),
                              Color.fromRGBO(0, 0, 0, 0.12),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  UserAvatar(
                                    name: appState.displayName ??
                                        _t(context, 'User'),
                                    size: 50,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.25),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _t(context, 'Welcome back,'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          appState.displayName ??
                                              _t(context, 'User'),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
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
                                      _roleLabel(context, role),
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
                    ],
                  ),
                ),
                actions: <Widget>[
                  if (appState.siteIds.length > 1)
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      tooltip: _t(context, 'Switch site'),
                      onPressed: () {
                        TelemetryService.instance.logEvent(
                          event: 'cta.clicked',
                          metadata: const <String, dynamic>{
                            'cta': 'role_dashboard_open_site_switcher',
                            'surface': 'appbar',
                          },
                        );
                        _showSiteSwitcher(context, appState);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                    tooltip: _t(context, 'Settings'),
                    onPressed: () {
                      TelemetryService.instance.logEvent(
                        event: 'cta.clicked',
                        metadata: const <String, dynamic>{
                          'cta': 'role_dashboard_open_settings',
                          'surface': 'appbar',
                        },
                      );
                      context.push('/settings');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: _t(context, 'Sign out'),
                    onPressed: () => _showLogoutDialog(context),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Quick stats section (optional based on role)
              if (role == UserRole.educator ||
                  role == UserRole.site ||
                  role == UserRole.hq)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: _buildQuickStats(role, appState),
                  ),
                ),

              // Section title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _t(context, 'Quick Actions'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showAllActionsSheet(context, cards),
                        child: Text(_t(context, 'View All')),
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
                        title: _t(context, card.title),
                        subtitle: card.subtitle == null
                            ? null
                            : _t(context, card.subtitle!),
                        icon: card.icon,
                        gradient: card.gradient,
                        isEnabled: isEnabled,
                        badgeText: isEnabled && card.badgeText != null
                            ? _t(context, card.badgeText!)
                            : null,
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

  Widget _buildQuickStats(UserRole role, AppState appState) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRoleStats(role, appState),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
      ) {
        final List<Map<String, dynamic>> stats =
            snapshot.data ?? const <Map<String, dynamic>>[];
        if (stats.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text(
                _t(context, 'No live metrics yet'),
                style: const TextStyle(color: ScholesaColors.textSecondary),
              ),
            ),
          );
        }
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
                  label: _t(context, stat['label'] as String),
                  value: stat['value'] as String,
                  icon: stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  trend: (stat['trend'] as String?) == null
                      ? null
                      : _t(context, stat['trend'] as String),
                  isPositive: stat['positive'] as bool? ?? true,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRoleStats(
    UserRole role,
    AppState appState,
  ) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('getRoleDashboardSnapshot');
    final HttpsCallableResult<dynamic> result =
        await callable.call(<String, dynamic>{
      'role': role.name,
      'siteId': appState.activeSiteId,
      'period': 'week',
    });
    final Map<String, dynamic>? payload = _asStringDynamicMap(result.data);
    if (payload == null) return <Map<String, dynamic>>[];
    final List<dynamic> rawStats =
        payload['stats'] as List<dynamic>? ?? <dynamic>[];
    if (rawStats.isEmpty) return <Map<String, dynamic>>[];

    final List<Map<String, dynamic>> stats = <Map<String, dynamic>>[];
    for (final dynamic raw in rawStats) {
      final Map<String, dynamic>? item = _asStringDynamicMap(raw);
      if (item == null) continue;
      final String label = (item['label'] as String? ?? '').trim();
      final String value = (item['value'] as String? ?? '').trim();
      if (label.isEmpty || value.isEmpty) continue;
      final String iconKey = (item['icon'] as String? ?? '').trim();
      final String colorKey = (item['color'] as String? ?? '').trim();
      stats.add(<String, dynamic>{
        'label': label,
        'value': value,
        'icon': _iconFromKey(iconKey),
        'color': _colorFromKey(colorKey),
        if (item['trend'] is String) 'trend': item['trend'] as String,
        if (item['positive'] is bool) 'positive': item['positive'] as bool,
      });
    }
    if (stats.isEmpty) return <Map<String, dynamic>>[];
    return stats;
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((dynamic key, dynamic nestedValue) =>
          MapEntry<String, dynamic>(key.toString(), nestedValue));
    }
    return null;
  }

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'people':
        return Icons.people;
      case 'check_circle':
        return Icons.check_circle;
      case 'rate_review':
        return Icons.rate_review;
      case 'location_on':
        return Icons.location_on;
      case 'login':
        return Icons.login;
      case 'warning':
        return Icons.warning;
      case 'business':
        return Icons.business;
      case 'pending_actions':
        return Icons.pending_actions;
      default:
        return Icons.bar_chart;
    }
  }

  Color _colorFromKey(String key) {
    switch (key) {
      case 'primary':
        return ScholesaColors.primary;
      case 'info':
        return ScholesaColors.info;
      case 'success':
        return ScholesaColors.success;
      case 'warning':
        return ScholesaColors.warning;
      case 'error':
        return ScholesaColors.error;
      default:
        return ScholesaColors.primary;
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

  void _handleCardTap(
      BuildContext context, DashboardCard card, bool isEnabled) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: <String, dynamic>{
        'cta': 'role_dashboard_card_tap',
        'card_id': card.id,
        'route': card.route,
        'enabled': isEnabled,
      },
    );
    if (isEnabled) {
      context.push(card.route);
    } else {
      _showUnavailableActionDialog(context, card);
    }
  }

  void _showAllActionsSheet(BuildContext context, List<DashboardCard> cards) {
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'role_dashboard_view_all_actions'
      },
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: cards.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  _t(sheetContext, 'All Quick Actions'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
              );
            }

            final DashboardCard card = cards[index - 1];
            final bool enabled = isRouteEnabled(card.route);
            return ListTile(
              leading: Icon(card.icon,
                  color: enabled
                      ? null
                      : Theme.of(sheetContext).colorScheme.onSurfaceVariant),
              title: Text(_t(sheetContext, card.title)),
              subtitle: Text(card.subtitle == null
                  ? ''
                  : _t(sheetContext, card.subtitle!)),
              trailing: Icon(
                enabled ? Icons.arrow_forward_ios : Icons.lock_outline,
                size: 16,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleCardTap(context, card, enabled);
              },
            );
          },
        ),
      ),
    );
  }

  void _showUnavailableActionDialog(BuildContext context, DashboardCard card) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_t(dialogContext, card.title)),
        content: Text(
          _t(
            dialogContext,
            'This action is not available for your current role or site setup. You can review your access in Settings.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_close_unavailable_action_dialog',
                  'surface': 'unavailable_action_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t(dialogContext, 'Close')),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_open_settings_from_unavailable_action',
                  'surface': 'unavailable_action_dialog',
                },
              );
              Navigator.pop(dialogContext);
              context.push('/settings');
            },
            child: Text(_t(dialogContext, 'Open Settings')),
          ),
        ],
      ),
    );
  }

  void _showSiteSwitcher(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                _t(context, 'Switch Site'),
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
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(siteId),
                  trailing: siteId == appState.activeSiteId
                      ? const Icon(Icons.check_circle,
                          color: ScholesaColors.success)
                      : null,
                  onTap: () {
                    TelemetryService.instance.logEvent(
                      event: 'cta.clicked',
                      metadata: <String, dynamic>{
                        'cta': 'role_dashboard_switch_site',
                        'surface': 'site_switcher_sheet',
                        'site_id': siteId,
                      },
                    );
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
    TelemetryService.instance.logEvent(
      event: 'cta.clicked',
      metadata: const <String, dynamic>{
        'cta': 'role_dashboard_open_sign_out_dialog'
      },
    );
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: <Widget>[
            const Icon(Icons.logout, color: ScholesaColors.error),
            const SizedBox(width: 12),
            Text(_t(dialogContext, 'Sign Out')),
          ],
        ),
        content: Text(_t(dialogContext, 'Are you sure you want to sign out?')),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_cancel_sign_out',
                  'surface': 'sign_out_dialog',
                },
              );
              Navigator.pop(dialogContext);
            },
            child: Text(_t(dialogContext, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              TelemetryService.instance.logEvent(
                event: 'cta.clicked',
                metadata: const <String, dynamic>{
                  'cta': 'role_dashboard_confirm_sign_out'
                },
              );
              Navigator.pop(dialogContext);
              // Clear app state and go to login
              final AppState appState = context.read<AppState>();
              appState.clear();
              if (context.mounted) {
                context.go('/welcome');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ScholesaColors.error,
            ),
            child: Text(_t(dialogContext, 'Sign Out')),
          ),
        ],
      ),
    );
  }
}
