import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/app_state.dart';
import 'role_gate.dart';
import '../ui/auth/login_page.dart';
import '../ui/auth/register_page.dart';
import '../ui/error/fatal_error_screen.dart';
import '../dashboards/role_dashboard.dart';
import '../modules/attendance/attendance_page.dart';
import '../modules/provisioning/provisioning_page.dart';
import '../modules/hq_admin/hq_admin.dart';
import '../modules/checkin/checkin.dart';
import '../modules/missions/missions.dart';
import '../modules/habits/habits.dart';
import '../modules/messages/messages.dart';
import '../modules/parent/parent.dart';
import '../modules/educator/educator.dart';
import '../modules/learner/learner.dart';
import '../modules/profile/profile.dart';

/// Known routes registry - flip status when modules are done
/// Based on docs/49_ROUTE_FLIP_TRACKER.md
final Map<String, bool> kKnownRoutes = <String, bool>{
  // Shared
  '/messages': false,
  '/notifications': false,
  
  // Learner
  '/learner/today': true, // ENABLED - learner today page
  '/learner/missions': true, // ENABLED - missions module
  '/learner/habits': true, // ENABLED - habit coach module
  '/learner/portfolio': false,
  
  // Cross-role
  '/messages': true, // ENABLED - messages/notifications
  '/profile': true, // ENABLED - user profile/settings
  
  // Parent
  '/parent/summary': true, // ENABLED - parent summary view
  
  // Educator
  '/educator/today': true, // ENABLED - educator today page
  
  // Educator
  '/educator/today': false,
  '/educator/attendance': true, // ENABLED - implementing for running state
  '/educator/mission-plans': false,
  '/educator/review-queue': false,
  '/educator/learner-supports': false,
  '/educator/integrations': false,
  
  // Parent
  '/parent/summary': false,
  '/parent/schedule': false,
  '/parent/portfolio': false,
  '/parent/billing': false,
  
  // Site
  '/site/ops': false,
  '/site/checkin': true, // ENABLED - check-in/check-out module
  '/site/provisioning': true, // ENABLED - implementing for running state
  '/site/incidents': false,
  '/site/identity': false,
  '/site/integrations-health': false,
  '/site/billing': false,
  
  // Partner
  '/partner/listings': false,
  '/partner/contracts': false,
  '/partner/payouts': false,
  
  // HQ
  '/hq/user-admin': true, // Already wired per docs
  '/hq/approvals': false,
  '/hq/audit': false,
  '/hq/safety': false,
  '/hq/billing': false,
  '/hq/integrations-health': false,
};

/// Check if a route is enabled
bool isRouteEnabled(String route) => kKnownRoutes[route] ?? false;

/// Create the app router
GoRouter createAppRouter(AppState appState) {
  return GoRouter(
    refreshListenable: appState,
    initialLocation: '/',
    debugLogDiagnostics: true,
    
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoading = appState.isLoading;
      final bool isLoggedIn = appState.isAuthenticated;
      final bool isLoginRoute = state.matchedLocation == '/login';
      final bool isRegisterRoute = state.matchedLocation == '/register';
      final bool isAuthRoute = isLoginRoute || isRegisterRoute;
      
      // Still loading, stay on current route
      if (isLoading) return null;
      
      // Not logged in and not on auth route -> go to login
      if (!isLoggedIn && !isAuthRoute) return '/login';
      
      // Logged in and on auth route -> go to dashboard
      if (isLoggedIn && isAuthRoute) return '/';
      
      return null;
    },
    
    errorBuilder: (BuildContext context, GoRouterState state) => FatalErrorScreen(
      error: state.error?.toString() ?? 'Page not found',
      onRetry: () => context.go('/'),
    ),
    
    routes: <RouteBase>[
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
      
      // Placeholder routes for disabled features
      // These will show "not available" when accessed
    ],
  );
}
