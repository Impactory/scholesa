import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/app_state.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/landing/landing_page.dart';
import 'features/dashboards/role_dashboards.dart';
import 'features/dashboards/role_selector_page.dart';
import 'features/cms/cms_page.dart';
import 'features/offline/offline_banner.dart';
import 'features/offline/offline_dispatchers.dart';
import 'features/offline/offline_queue.dart';
import 'features/offline/offline_service.dart';
import 'features/messaging/messaging_screen.dart';
import 'features/educator/educator_today_screen.dart';
import 'features/educator/attendance_screen.dart';
import 'features/educator/educator_integrations_screen.dart';
import 'features/educator/educator_review_queue_screen.dart';
import 'features/site/site_ops_today_screen.dart';
import 'features/site/site_checkin_screen.dart';
import 'features/site/site_provisioning_screen.dart';
import 'features/site/site_incidents_screen.dart';
import 'features/site/site_identity_screen.dart';
import 'features/site/site_consent_screen.dart';
import 'features/site/site_integrations_screen.dart';
import 'features/hq/hq_approvals_screen.dart';
import 'features/hq/hq_audit_logs_screen.dart';
import 'features/hq/hq_billing_admin_screen.dart';
import 'features/hq/hq_safety_screen.dart';
import 'features/hq/hq_integrations_screen.dart';
import 'features/learner/learner_today_screen.dart';
import 'features/learner/learner_missions_screen.dart';
import 'features/learner/learner_habits_screen.dart';
import 'features/learner/learner_portfolio_screen.dart';
import 'features/parent/parent_summary_screen.dart';
import 'features/parent/parent_schedule_screen.dart';
import 'features/parent/parent_portfolio_screen.dart';
import 'features/parent/parent_billing_screen.dart';
import 'features/partner/partner_listings_screen.dart';
import 'features/partner/partner_contracts_screen.dart';
import 'features/partner/partner_payouts_screen.dart';
import 'features/marketplace/marketplace_screen.dart';
import 'features/analytics/analytics_dashboard_screen.dart';
import 'theme.dart';

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text('This screen is scaffolded and ready to wire to feature modules.'),
            ],
          ),
        ),
      ),
    );
  }
}

class ScholesaApp extends StatelessWidget {
  const ScholesaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(
          create: (_) {
            final queue = OfflineQueue();
            queue.load();
            registerOfflineDispatchers(queue);
            return queue;
          },
        ),
        ChangeNotifierProvider(create: (_) => OfflineService()),
      ],
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final appState = context.read<AppState>();
          final user = snapshot.data;
          if (user != null) {
            appState.setUser(user);
            // Refresh entitlements from custom claims then Firestore profile.
            appState.refreshEntitlements();
          } else {
            appState.clearAuth();
          }

          final routes = <String, WidgetBuilder>{
            '/': (context) => const LandingPage(),
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegisterPage(),
            '/roles': (context) => const RoleSelectorPage(),
            '/dashboard/learner': (context) => const RoleDashboard(role: 'learner'),
            '/dashboard/educator': (context) => const RoleDashboard(role: 'educator'),
            '/dashboard/parent': (context) => const RoleDashboard(role: 'parent'),
            '/dashboard/site': (context) => const RoleDashboard(role: 'site'),
            '/dashboard/partner': (context) => const RoleDashboard(role: 'partner'),
            '/dashboard/hq': (context) => const RoleDashboard(role: 'hq'),

            // Shared
            '/messaging': (context) => const MessagingScreen(),
            '/marketplace': (context) => const MarketplaceScreen(),
            '/analytics': (context) => const AnalyticsDashboardScreen(),
            '/notifications': (context) => const _PlaceholderScreen(title: 'Notifications', subtitle: 'Alerts and notification center'),

            // Learner
            '/learner/today': (context) => const LearnerTodayScreen(),
            '/learner/missions': (context) => const LearnerMissionsScreen(),
            '/learner/habits': (context) => const LearnerHabitsScreen(),
            '/learner/portfolio': (context) => const LearnerPortfolioScreen(),

            // Educator
            '/educator/today': (context) => const EducatorTodayScreen(),
            '/educator/attendance': (context) => const EducatorAttendanceScreen(),
            '/educator/plan': (context) => const _PlaceholderScreen(title: 'Plan Missions', subtitle: 'Create and duplicate mission plans'),
            '/educator/review-queue': (context) => const EducatorReviewQueueScreen(),
            '/educator/supports': (context) => const _PlaceholderScreen(title: 'Learner Supports', subtitle: 'Insights and interventions'),
            '/educator/integrations': (context) => const EducatorIntegrationsScreen(),

            // Parent
            '/parent/summary': (context) => const ParentSummaryScreen(),
            '/parent/schedule': (context) => const ParentScheduleScreen(),
            '/parent/portfolio': (context) => const ParentPortfolioScreen(),
            '/parent/billing': (context) => const ParentBillingScreen(),

            // Site
            '/site/ops-today': (context) => const SiteOpsTodayScreen(),
            '/site/checkin': (context) => const SiteCheckInScreen(),
            '/site/provisioning': (context) => const SiteProvisioningScreen(),
            '/site/incidents': (context) => const SiteIncidentsScreen(),
            '/site/identity-resolution': (context) => const SiteIdentityScreen(),
            '/site/consent': (context) => const SiteConsentScreen(),
            '/site/integrations': (context) => const SiteIntegrationsScreen(),
            '/site/billing': (context) => const _PlaceholderScreen(title: 'Site Billing', subtitle: 'Subscriptions & entitlements'),

            // Partner
            '/partner/listings': (context) => const PartnerListingsScreen(),
            '/partner/contracts': (context) => const PartnerContractsScreen(),
            '/partner/payouts': (context) => const PartnerPayoutsScreen(),

            // HQ
            '/hq/user-admin': (context) => const _PlaceholderScreen(title: 'User Administration', subtitle: 'Roles and access'),
            '/hq/approvals': (context) => const HqApprovalsScreen(),
            '/hq/audit-logs': (context) => const HqAuditLogsScreen(),
            '/hq/safety': (context) => const HqSafetyScreen(),
            '/hq/billing-admin': (context) => const HqBillingAdminScreen(),
            '/hq/integrations': (context) => const HqIntegrationsScreen(),
          };

          const publicRoutes = <String>{'/', '/login', '/register', '/roles'};

          const routeRoles = <String, List<String>>{
            '/dashboard/learner': <String>['learner'],
            '/dashboard/educator': <String>['educator'],
            '/dashboard/parent': <String>['parent'],
            '/dashboard/site': <String>['site'],
            '/dashboard/partner': <String>['partner'],
            '/dashboard/hq': <String>['hq'],

            '/messaging': <String>['all'],
            '/marketplace': <String>['learner', 'parent', 'educator'],
            '/analytics': <String>['hq', 'site', 'educator'],
            '/notifications': <String>['all'],

            '/learner/today': <String>['learner'],
            '/learner/missions': <String>['learner'],
            '/learner/habits': <String>['learner'],
            '/learner/portfolio': <String>['learner'],

            '/educator/today': <String>['educator'],
            '/educator/attendance': <String>['educator'],
            '/educator/plan': <String>['educator'],
            '/educator/review-queue': <String>['educator'],
            '/educator/supports': <String>['educator'],
            '/educator/integrations': <String>['educator'],

            '/parent/summary': <String>['parent'],
            '/parent/schedule': <String>['parent'],
            '/parent/portfolio': <String>['parent'],
            '/parent/billing': <String>['parent'],

            '/site/ops-today': <String>['site'],
            '/site/checkin': <String>['site'],
            '/site/provisioning': <String>['site'],
            '/site/incidents': <String>['site'],
            '/site/identity-resolution': <String>['site'],
            '/site/consent': <String>['site'],
            '/site/integrations': <String>['site'],
            '/site/billing': <String>['site'],

            '/partner/listings': <String>['partner'],
            '/partner/contracts': <String>['partner'],
            '/partner/payouts': <String>['partner'],

            '/hq/user-admin': <String>['hq'],
            '/hq/approvals': <String>['hq'],
            '/hq/audit-logs': <String>['hq'],
            '/hq/safety': <String>['hq'],
            '/hq/billing-admin': <String>['hq'],
            '/hq/integrations': <String>['hq'],
          };

          return MaterialApp(
            title: 'Scholesa EDU',
            theme: AppTheme.light(),
            initialRoute: '/',
            builder: (context, child) => OfflineBanner(
              child: child ?? const SizedBox.shrink(),
            ),
            routes: routes,
            onGenerateRoute: (settings) {
              final name = settings.name ?? '/';
              if (name.startsWith('/p/')) {
                final slug = name.substring(3);
                return MaterialPageRoute(builder: (_) => CmsPageScreen(slug: slug));
              }
              final builder = routes[name];
              if (builder != null) {
                final isPublic = publicRoutes.contains(name);
                final requiresAuth = !isPublic;
                final currentRole = appState.role;
                if (requiresAuth && appState.user == null) {
                  return MaterialPageRoute(builder: (_) => const LoginPage());
                }
                final allowedRoles = routeRoles[name];
                final roleAllowed = allowedRoles == null ||
                    (allowedRoles.contains('all') && currentRole != null) ||
                    (currentRole != null && allowedRoles.contains(currentRole));
                if (!roleAllowed) {
                  return MaterialPageRoute(builder: (_) => const LandingPage());
                }
                return MaterialPageRoute(builder: builder);
              }
              return MaterialPageRoute(builder: (_) => const LandingPage());
            },
          );
        },
      ),
    );
  }
}