import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/app_state.dart';
import 'role_gate.dart';
import '../ui/landing/landing_page.dart';
import '../ui/auth/login_page.dart';
import '../ui/auth/register_page.dart';
import '../ui/error/fatal_error_screen.dart';
import '../dashboards/role_dashboard.dart';
import '../modules/attendance/attendance_page.dart';
import '../modules/provisioning/provisioning_page.dart';
import '../modules/hq_admin/hq_admin.dart';
import '../modules/hq_admin/hq_role_switcher_page.dart';
import '../modules/checkin/checkin.dart';
import '../modules/missions/missions.dart';
import '../modules/habits/habits.dart';
import '../modules/messages/messages.dart';
import '../modules/parent/parent.dart';
import '../modules/educator/educator.dart';
import '../modules/learner/learner.dart';
import '../modules/profile/profile.dart';
import '../modules/site/site.dart';
import '../modules/settings/settings.dart';
import '../modules/partner/partner.dart';

/// Known routes registry - flip status when modules are done
/// Based on docs/49_ROUTE_FLIP_TRACKER.md
final Map<String, bool> kKnownRoutes = <String, bool>{
  // Public
  '/welcome': true,
  
  // Auth
  '/login': true,
  '/register': true,
  
  // Dashboard
  '/': true,
  
  // Learner
  '/learner/today': true,
  '/learner/missions': true,
  '/learner/habits': true,
  '/learner/portfolio': true,
  
  // Educator
  '/educator/today': true,
  '/educator/attendance': true,
  '/educator/sessions': true,
  '/educator/learners': true,
  '/educator/missions/review': true,
  '/educator/mission-plans': true,
  '/educator/learner-supports': true,
  '/educator/integrations': true,
  '/educator/review-queue': true, // alias for missions/review
  
  // Parent
  '/parent/summary': true,
  '/parent/billing': true,
  '/parent/schedule': true,
  '/parent/portfolio': true,
  
  // Site
  '/site/checkin': true,
  '/site/provisioning': true,
  '/site/dashboard': true,
  '/site/sessions': true,
  '/site/ops': true,
  '/site/incidents': true,
  '/site/identity': true,
  '/site/integrations-health': true,
  '/site/billing': true,
  
  // Partner
  '/partner/listings': true,
  '/partner/contracts': true,
  '/partner/payouts': true,
  
  // HQ
  '/hq/user-admin': true,
  '/hq/role-switcher': true,
  '/hq/sites': true,
  '/hq/analytics': true,
  '/hq/billing': true,
  '/hq/approvals': true,
  '/hq/audit': true,
  '/hq/safety': true,
  '/hq/integrations-health': true,
  '/hq/curriculum': true,
  '/hq/feature-flags': true,
  
  // Cross-role
  '/messages': true,
  '/notifications': true,
  '/profile': true,
  '/settings': true,
};

/// Check if a route is enabled
bool isRouteEnabled(String route) => kKnownRoutes[route] ?? false;

/// Create the app router
GoRouter createAppRouter(AppState appState) {
  return GoRouter(
    refreshListenable: appState,
    initialLocation: '/welcome',
    debugLogDiagnostics: true,
    
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoading = appState.isLoading;
      final bool isLoggedIn = appState.isAuthenticated;
      final bool isWelcomeRoute = state.matchedLocation == '/welcome';
      final bool isLoginRoute = state.matchedLocation == '/login';
      final bool isRegisterRoute = state.matchedLocation == '/register';
      final bool isPublicRoute = isWelcomeRoute || isLoginRoute || isRegisterRoute;
      
      // Still loading and on public route, stay there (show landing page while loading)
      if (isLoading && isPublicRoute) return null;
      
      // Still loading and NOT on public route, go to welcome page
      if (isLoading && !isPublicRoute) return '/welcome';
      
      // Not logged in and not on public route -> go to landing page
      if (!isLoggedIn && !isPublicRoute) return '/welcome';
      
      // Logged in and on public route -> go to dashboard
      if (isLoggedIn && isPublicRoute) return '/';
      
      return null;
    },
    
    errorBuilder: (BuildContext context, GoRouterState state) => FatalErrorScreen(
      error: state.error?.toString() ?? 'Page not found',
      onRetry: () => context.go('/'),
    ),
    
    routes: <RouteBase>[
      // Public landing page
      GoRoute(
        path: '/welcome',
        builder: (BuildContext context, GoRouterState state) => const LandingPage(),
      ),
      
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) => const RegisterPage(),
      ),
      
      // Dashboard - redirects to role-specific dashboard
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const RoleDashboard(),
      ),
      
      // Educator routes
      GoRoute(
        path: '/educator/attendance',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: AttendancePage(),
        ),
      ),
      
      // Site routes
      GoRoute(
        path: '/site/provisioning',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: ProvisioningPage(),
        ),
      ),
      GoRoute(
        path: '/site/checkin',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: CheckinPage(),
        ),
      ),
      
      // HQ routes
      GoRoute(
        path: '/hq/user-admin',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: UserAdminPage(),
        ),
      ),
      GoRoute(
        path: '/hq/role-switcher',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqRoleSwitcherPage(),
        ),
      ),
      
      // Learner routes
      GoRoute(
        path: '/learner/today',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.learner, UserRole.educator, UserRole.hq],
          child: LearnerTodayPage(),
        ),
      ),
      GoRoute(
        path: '/learner/missions',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.learner, UserRole.educator, UserRole.hq],
          child: MissionsPage(),
        ),
      ),
      GoRoute(
        path: '/learner/habits',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.learner, UserRole.educator, UserRole.hq],
          child: HabitsPage(),
        ),
      ),
      
      // Messages route (all authenticated users)
      GoRoute(
        path: '/messages',
        builder: (BuildContext context, GoRouterState state) => const MessagesPage(),
      ),
      
      // Profile route (all authenticated users)
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) => const ProfilePage(),
      ),
      
      // Parent routes
      GoRoute(
        path: '/parent/summary',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.parent, UserRole.hq],
          child: ParentSummaryPage(),
        ),
      ),
      
      // Educator routes
      GoRoute(
        path: '/educator/today',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorTodayPage(),
        ),
      ),
      GoRoute(
        path: '/educator/sessions',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorSessionsPage(),
        ),
      ),
      GoRoute(
        path: '/educator/learners',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorLearnersPage(),
        ),
      ),
      GoRoute(
        path: '/educator/missions/review',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorMissionReviewPage(),
        ),
      ),
      
      // Site routes
      GoRoute(
        path: '/site/dashboard',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteDashboardPage(),
        ),
      ),
      GoRoute(
        path: '/site/sessions',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteSessionsPage(),
        ),
      ),
      
      // HQ routes
      GoRoute(
        path: '/hq/sites',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqSitesPage(),
        ),
      ),
      GoRoute(
        path: '/hq/analytics',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqAnalyticsPage(),
        ),
      ),
      GoRoute(
        path: '/hq/billing',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqBillingPage(),
        ),
      ),
      
      // Parent routes
      GoRoute(
        path: '/parent/billing',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.parent, UserRole.hq],
          child: ParentBillingPage(),
        ),
      ),
      GoRoute(
        path: '/parent/schedule',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.parent, UserRole.hq],
          child: ParentSchedulePage(),
        ),
      ),
      
      // Learner routes
      GoRoute(
        path: '/learner/portfolio',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.learner, UserRole.educator, UserRole.hq],
          child: LearnerPortfolioPage(),
        ),
      ),
      
      // Settings route (all authenticated users)
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) => const SettingsPage(),
      ),

      // ─────────────────────────────────────────────────────────────
      // NEW ROUTES - Partner Module
      // ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/partner/listings',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.partner, UserRole.hq],
          child: PartnerListingsPage(),
        ),
      ),
      GoRoute(
        path: '/partner/contracts',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.partner, UserRole.hq],
          child: PartnerContractsPage(),
        ),
      ),
      GoRoute(
        path: '/partner/payouts',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.partner, UserRole.hq],
          child: PartnerPayoutsPage(),
        ),
      ),

      // ─────────────────────────────────────────────────────────────
      // NEW ROUTES - Site Module (Extended)
      // ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/site/ops',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteOpsPage(),
        ),
      ),
      GoRoute(
        path: '/site/incidents',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteIncidentsPage(),
        ),
      ),
      GoRoute(
        path: '/site/identity',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteIdentityPage(),
        ),
      ),
      GoRoute(
        path: '/site/integrations-health',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteIntegrationsHealthPage(),
        ),
      ),
      GoRoute(
        path: '/site/billing',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.site, UserRole.hq],
          child: SiteBillingPage(),
        ),
      ),

      // ─────────────────────────────────────────────────────────────
      // NEW ROUTES - Educator Module (Extended)
      // ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/educator/mission-plans',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorMissionPlansPage(),
        ),
      ),
      GoRoute(
        path: '/educator/learner-supports',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorLearnerSupportsPage(),
        ),
      ),
      GoRoute(
        path: '/educator/integrations',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.educator, UserRole.site, UserRole.hq],
          child: EducatorIntegrationsPage(),
        ),
      ),

      // ─────────────────────────────────────────────────────────────
      // NEW ROUTES - Parent Module (Extended)
      // ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/parent/portfolio',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.parent, UserRole.hq],
          child: ParentPortfolioPage(),
        ),
      ),

      // ─────────────────────────────────────────────────────────────
      // NEW ROUTES - HQ Admin Module (Extended)
      // ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/hq/approvals',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqApprovalsPage(),
        ),
      ),
      GoRoute(
        path: '/hq/audit',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqAuditPage(),
        ),
      ),
      GoRoute(
        path: '/hq/safety',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqSafetyPage(),
        ),
      ),
      GoRoute(
        path: '/hq/integrations-health',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqIntegrationsHealthPage(),
        ),
      ),
      GoRoute(
        path: '/hq/curriculum',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqCurriculumPage(),
        ),
      ),
      GoRoute(
        path: '/hq/feature-flags',
        builder: (BuildContext context, GoRouterState state) => const RoleGate(
          allowedRoles: <UserRole>[UserRole.hq],
          child: HqFeatureFlagsPage(),
        ),
      ),

      // ─────────────────────────────────────────────────────────────
      // NEW ROUTES - Cross-Role (Notifications)
      // ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) => const NotificationsPage(),
      ),

      // Placeholder routes for disabled features
      // These will show "not available" when accessed
    ],
  );
}
