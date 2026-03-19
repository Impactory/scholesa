# Route Module Matrix

Last updated: 2026-03-18

This matrix maps the currently implemented route surfaces to their entry files and backing modules.

## Web Routing Model

- Public and auth pages are dedicated App Router pages under `app/[locale]/`.
- Role root pages such as `/learner` and `/hq` are redirect shells.
- Most protected workflow pages are thin wrappers over `src/features/workflows/WorkflowRoutePage.tsx`.
- Canonical web workflow metadata lives in `src/lib/routing/workflowRoutes.ts`.

## Web Public and Redirect Routes

| Route | Kind | Entrypoint | Backing module |
| --- | --- | --- | --- |
| `/:locale` | Public | `app/[locale]/page.tsx` | Dedicated landing page |
| `/:locale/login` | Public auth | `app/[locale]/(auth)/login/page.tsx` | Dedicated login flow |
| `/:locale/register` | Public auth | `app/[locale]/(auth)/register/page.tsx` | Dedicated registration flow |
| `/:locale/dashboard` | Redirect shell | `app/[locale]/(protected)/dashboard/page.tsx` | Redirect by authenticated role |
| `/:locale/learner` | Redirect shell | `app/[locale]/(protected)/learner/page.tsx` | Redirect to `/learner/today` |
| `/:locale/educator` | Redirect shell | `app/[locale]/(protected)/educator/page.tsx` | Redirect to `/educator/today` |
| `/:locale/parent` | Redirect shell | `app/[locale]/(protected)/parent/page.tsx` | Redirect to `/parent/summary` |
| `/:locale/site` | Redirect shell | `app/[locale]/(protected)/site/page.tsx` | Redirect to `/site/dashboard` |
| `/:locale/partner` | Redirect shell | `app/[locale]/(protected)/partner/page.tsx` | Redirect to `/partner/listings` |
| `/:locale/hq` | Redirect shell | `app/[locale]/(protected)/hq/page.tsx` | Redirect to `/hq/sites` |
| `/:locale/learner/profile` | Legacy redirect | `app/[locale]/(protected)/learner/profile/page.tsx` | Redirect to `/learner/portfolio` |

## Web Workflow Routes

All routes below render through `src/features/workflows/WorkflowRoutePage.tsx` with route metadata from `src/lib/routing/workflowRoutes.ts` and data loading or mutations from `src/features/workflows/workflowData.ts`.

| Route | Roles | Page file | Data mode |
| --- | --- | --- | --- |
| `/:locale/learner/today` | learner, educator, hq | `app/[locale]/(protected)/learner/today/page.tsx` | firestore |
| `/:locale/learner/missions` | learner, educator, hq | `app/[locale]/(protected)/learner/missions/page.tsx` | firestore |
| `/:locale/learner/habits` | learner, educator, hq | `app/[locale]/(protected)/learner/habits/page.tsx` | firestore |
| `/:locale/learner/portfolio` | learner, educator, hq | `app/[locale]/(protected)/learner/portfolio/page.tsx` | firestore |
| `/:locale/educator/today` | educator, site, hq | `app/[locale]/(protected)/educator/today/page.tsx` | firestore |
| `/:locale/educator/attendance` | educator, site, hq | `app/[locale]/(protected)/educator/attendance/page.tsx` | firestore |
| `/:locale/educator/sessions` | educator, site, hq | `app/[locale]/(protected)/educator/sessions/page.tsx` | firestore |
| `/:locale/educator/learners` | educator, site, hq | `app/[locale]/(protected)/educator/learners/page.tsx` | firestore |
| `/:locale/educator/missions/review` | educator, site, hq | `app/[locale]/(protected)/educator/missions/review/page.tsx` | firestore |
| `/:locale/educator/mission-plans` | educator, site, hq | `app/[locale]/(protected)/educator/mission-plans/page.tsx` | firestore |
| `/:locale/educator/learner-supports` | educator, site, hq | `app/[locale]/(protected)/educator/learner-supports/page.tsx` | firestore |
| `/:locale/educator/integrations` | educator, site, hq | `app/[locale]/(protected)/educator/integrations/page.tsx` | callable |
| `/:locale/parent/summary` | parent, hq | `app/[locale]/(protected)/parent/summary/page.tsx` | hybrid |
| `/:locale/parent/billing` | parent, hq | `app/[locale]/(protected)/parent/billing/page.tsx` | callable |
| `/:locale/parent/schedule` | parent, hq | `app/[locale]/(protected)/parent/schedule/page.tsx` | firestore |
| `/:locale/parent/portfolio` | parent, hq | `app/[locale]/(protected)/parent/portfolio/page.tsx` | firestore |
| `/:locale/site/checkin` | site, hq | `app/[locale]/(protected)/site/checkin/page.tsx` | firestore |
| `/:locale/site/provisioning` | site, hq | `app/[locale]/(protected)/site/provisioning/page.tsx` | firestore |
| `/:locale/site/dashboard` | site, hq | `app/[locale]/(protected)/site/dashboard/page.tsx` | hybrid |
| `/:locale/site/sessions` | site, hq | `app/[locale]/(protected)/site/sessions/page.tsx` | firestore |
| `/:locale/site/ops` | site, hq | `app/[locale]/(protected)/site/ops/page.tsx` | firestore |
| `/:locale/site/incidents` | site, hq | `app/[locale]/(protected)/site/incidents/page.tsx` | callable |
| `/:locale/site/identity` | site, hq | `app/[locale]/(protected)/site/identity/page.tsx` | callable |
| `/:locale/site/clever` | site, hq | `app/[locale]/(protected)/site/clever/page.tsx` | hybrid |
| `/:locale/site/integrations-health` | site, hq | `app/[locale]/(protected)/site/integrations-health/page.tsx` | callable |
| `/:locale/site/billing` | site, hq | `app/[locale]/(protected)/site/billing/page.tsx` | callable |
| `/:locale/partner/listings` | partner, hq | `app/[locale]/(protected)/partner/listings/page.tsx` | firestore |
| `/:locale/partner/contracts` | partner, hq | `app/[locale]/(protected)/partner/contracts/page.tsx` | firestore |
| `/:locale/partner/deliverables` | partner, hq | `app/[locale]/(protected)/partner/deliverables/page.tsx` | firestore |
| `/:locale/partner/integrations` | partner, hq | `app/[locale]/(protected)/partner/integrations/page.tsx` | firestore |
| `/:locale/partner/payouts` | partner, hq | `app/[locale]/(protected)/partner/payouts/page.tsx` | firestore |
| `/:locale/hq/user-admin` | hq | `app/[locale]/(protected)/hq/user-admin/page.tsx` | callable |
| `/:locale/hq/role-switcher` | hq | `app/[locale]/(protected)/hq/role-switcher/page.tsx` | callable |
| `/:locale/hq/sites` | hq | `app/[locale]/(protected)/hq/sites/page.tsx` | callable |
| `/:locale/hq/analytics` | hq | `app/[locale]/(protected)/hq/analytics/page.tsx` | callable |
| `/:locale/hq/billing` | hq | `app/[locale]/(protected)/hq/billing/page.tsx` | callable |
| `/:locale/hq/approvals` | hq | `app/[locale]/(protected)/hq/approvals/page.tsx` | callable |
| `/:locale/hq/audit` | hq | `app/[locale]/(protected)/hq/audit/page.tsx` | callable |
| `/:locale/hq/safety` | hq | `app/[locale]/(protected)/hq/safety/page.tsx` | callable |
| `/:locale/hq/integrations-health` | hq | `app/[locale]/(protected)/hq/integrations-health/page.tsx` | callable |
| `/:locale/hq/curriculum` | hq | `app/[locale]/(protected)/hq/curriculum/page.tsx` | callable |
| `/:locale/hq/feature-flags` | hq | `app/[locale]/(protected)/hq/feature-flags/page.tsx` | callable |
| `/:locale/messages` | all authenticated roles | `app/[locale]/(protected)/messages/page.tsx` | firestore |
| `/:locale/notifications` | all authenticated roles | `app/[locale]/(protected)/notifications/page.tsx` | firestore |
| `/:locale/profile` | all authenticated roles | `app/[locale]/(protected)/profile/page.tsx` | firestore |
| `/:locale/settings` | all authenticated roles | `app/[locale]/(protected)/settings/page.tsx` | firestore |

## Flutter Routing Model

- The canonical Flutter route registry is `apps/empire_flutter/app/lib/router/app_router.dart`.
- Route discoverability is driven by `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`.
- Access control is enforced with `RoleGate` in `apps/empire_flutter/app/lib/router/role_gate.dart`.
- Flutter includes a small number of alias routes that currently resolve to the same page as the canonical route.

## Flutter Routes

| Route | Page class | File | Notes |
| --- | --- | --- | --- |
| `/welcome` | `LandingPage` | `apps/empire_flutter/app/lib/ui/landing/landing_page.dart` | Public landing |
| `/login` | `LoginPage` | `apps/empire_flutter/app/lib/ui/auth/login_page.dart` | Public auth |
| `/register` | redirect to `/login` | `apps/empire_flutter/app/lib/router/app_router.dart` | Alias-only route |
| `/` | `RoleDashboard` | `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` | Redirect target after auth |
| `/learner/onboarding` | `LearnerTodayPage` via `LearnerOnboardingGate` | `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` | Setup mode |
| `/learner/today` | `LearnerTodayPage` | `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` | Canonical learner home |
| `/learner/missions` | `MissionsPage` | `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` | Learner mission flow |
| `/learner/habits` | `HabitsPage` | `apps/empire_flutter/app/lib/modules/habits/habits_page.dart` | Habit workflow |
| `/learner/portfolio` | `LearnerPortfolioPage` | `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` | Portfolio surface |
| `/learner/credentials` | `LearnerCredentialsPage` | `apps/empire_flutter/app/lib/modules/learner/learner_credentials_page.dart` | Credentials surface |
| `/learner/settings` | `SettingsPage` | `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` | Learner-specific alias to shared settings |
| `/educator/today` | `EducatorTodayPage` | `apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart` | Canonical educator home |
| `/educator/attendance` | `AttendancePage` | `apps/empire_flutter/app/lib/modules/attendance/attendance_page.dart` | Attendance workflow |
| `/educator/sessions` | `EducatorSessionsPage` | `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` | Session management |
| `/educator/learners` | `EducatorLearnersPage` | `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart` | Roster and learner detail |
| `/educator/missions/review` | `EducatorMissionReviewPage` | `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` | Canonical review queue |
| `/educator/review-queue` | `EducatorMissionReviewPage` | `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` | Alias of `/educator/missions/review` |
| `/educator/mission-plans` | `EducatorMissionPlansPage` | `apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart` | Lesson planning |
| `/educator/learner-supports` | `EducatorLearnerSupportsPage` | `apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart` | Intervention planning |
| `/educator/integrations` | `EducatorIntegrationsPage` | `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart` | Integration ops |
| `/parent/summary` | `ParentSummaryPage` | `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart` | Canonical parent home |
| `/parent/child/:learnerId` | `ParentChildPage` | `apps/empire_flutter/app/lib/modules/parent/parent_child_page.dart` | Param route |
| `/parent/consent` | `ParentConsentPage` | `apps/empire_flutter/app/lib/modules/parent/parent_consent_page.dart` | Consent surface |
| `/parent/billing` | `ParentBillingPage` | `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart` | Billing view |
| `/parent/messages` | `MessagesPage` | `apps/empire_flutter/app/lib/modules/messages/messages_page.dart` | Parent-scoped alias to shared messages |
| `/parent/schedule` | `ParentSchedulePage` | `apps/empire_flutter/app/lib/modules/parent/parent_schedule_page.dart` | Schedule view |
| `/parent/portfolio` | `ParentPortfolioPage` | `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` | Parent portfolio |
| `/parent/settings` | `SettingsPage` | `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` | Parent-specific alias to shared settings |
| `/site/checkin` | `CheckinPage` | `apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart` | Arrival and pickup ops |
| `/site/provisioning` | `ProvisioningPage` | `apps/empire_flutter/app/lib/modules/provisioning/provisioning_page.dart` | Provisioning and links |
| `/site/dashboard` | `SiteDashboardPage` | `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart` | Canonical site home |
| `/site/sessions` | `SiteSessionsPage` | `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart` | Canonical sessions view |
| `/site/scheduling` | `SiteSessionsPage` | `apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart` | Alias of `/site/sessions` |
| `/site/ops` | `SiteOpsPage` | `apps/empire_flutter/app/lib/modules/site/site_ops_page.dart` | Daily site operations |
| `/site/incidents` | `SiteIncidentsPage` | `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart` | Incident management |
| `/site/identity` | `SiteIdentityPage` | `apps/empire_flutter/app/lib/modules/site/site_identity_page.dart` | Identity reconciliation |
| `/site/pickup-auth` | `SitePickupAuthPage` | `apps/empire_flutter/app/lib/modules/site/site_pickup_auth_page.dart` | Pickup authorization |
| `/site/consent` | `SiteConsentPage` | `apps/empire_flutter/app/lib/modules/site/site_consent_page.dart` | Consent operations |
| `/site/integrations-health` | `SiteIntegrationsHealthPage` | `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart` | Integration health |
| `/site/billing` | `SiteBillingPage` | `apps/empire_flutter/app/lib/modules/site/site_billing_page.dart` | Site billing |
| `/site/audit` | `SiteAuditPage` | `apps/empire_flutter/app/lib/modules/site/site_audit_page.dart` | Site audit surface |
| `/partner/listings` | `PartnerListingsPage` | `apps/empire_flutter/app/lib/modules/partner/partner_listings_page.dart` | Canonical partner home |
| `/partner/contracts` | `PartnerContractsPage` | `apps/empire_flutter/app/lib/modules/partner/partner_contracts_page.dart` | Contract management |
| `/partner/deliverables` | `PartnerDeliverablesPage` | `apps/empire_flutter/app/lib/modules/partner/partner_deliverables_page.dart` | Deliverables |
| `/partner/integrations` | `PartnerIntegrationsPage` | `apps/empire_flutter/app/lib/modules/partner/partner_integrations_page.dart` | Partner integrations |
| `/partner/payouts` | `PartnerPayoutsPage` | `apps/empire_flutter/app/lib/modules/partner/partner_payouts_page.dart` | Payouts |
| `/hq/user-admin` | `UserAdminPage` | `apps/empire_flutter/app/lib/modules/hq_admin/user_admin_page.dart` | User admin |
| `/hq/role-switcher` | `HqRoleSwitcherPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_role_switcher_page.dart` | Role impersonation |
| `/hq/sites` | `HqSitesPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_sites_page.dart` | Canonical HQ home |
| `/hq/analytics` | `HqAnalyticsPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_analytics_page.dart` | Platform analytics |
| `/hq/billing` | `HqBillingPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_billing_page.dart` | Platform billing |
| `/hq/approvals` | `HqApprovalsPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_approvals_page.dart` | Approvals queue |
| `/hq/audit` | `HqAuditPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_audit_page.dart` | Audit view |
| `/hq/safety` | `HqSafetyPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_safety_page.dart` | Safety oversight |
| `/hq/exports` | `HqExportsPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_exports_page.dart` | Export center |
| `/hq/integrations-health` | `HqIntegrationsHealthPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_integrations_health_page.dart` | Integration health |
| `/hq/cms` | `HqCurriculumPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` | Alias of `/hq/curriculum` |
| `/hq/curriculum` | `HqCurriculumPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` | Canonical curriculum builder |
| `/hq/feature-flags` | `HqFeatureFlagsPage` | `apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart` | Feature flag control |
| `/messages` | `MessagesPage` | `apps/empire_flutter/app/lib/modules/messages/messages_page.dart` | Shared cross-role route |
| `/notifications` | `NotificationsPage` | `apps/empire_flutter/app/lib/modules/messages/notifications_page.dart` | Shared cross-role route |
| `/profile` | `ProfilePage` | `apps/empire_flutter/app/lib/modules/profile/profile_page.dart` | Shared cross-role route |
| `/settings` | `SettingsPage` | `apps/empire_flutter/app/lib/modules/settings/settings_page.dart` | Shared cross-role route |

## Current Drift to Watch

| Platform | Drift |
| --- | --- |
| Web | Protected workflow pages are centralized behind the generic workflow renderer, so behavior changes often belong in `workflowData.ts` or `workflowRoutes.ts`, not in the page wrappers |
| Flutter | Alias routes still exist for `/educator/review-queue`, `/site/scheduling`, and `/hq/cms` |
| Cross-platform | Web and Flutter cover many of the same business surfaces but not always with identical route names or the same level of feature completeness |