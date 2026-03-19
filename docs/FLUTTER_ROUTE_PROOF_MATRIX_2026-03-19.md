# Flutter Route Proof Matrix

Last updated: 2026-03-19
Scope: enabled Flutter routes from `apps/empire_flutter/app/lib/router/app_router.dart`

Proof levels:

- `direct`: route has a page-specific test proving the page itself
- `workflow/regression`: route is only covered indirectly through shared, navigation, localization, or regression tests
- `none`: no convincing route proof was found

## Summary

- Enabled canonical routes audited: 52
- Direct: 44
- Workflow/regression only: 8
- None: 0

Highest-value remaining blind spots:

1. `/educator/integrations`
2. `/parent/schedule`
3. `/parent/portfolio`
4. `/educator/missions/review`
5. deeper failure and mutation coverage on `/educator/mission-plans`
6. learner- and parent-scoped alias-route proof for `/settings`

## Public, Auth, and Root

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/welcome` | direct | `apps/empire_flutter/app/test/public_entry_routes_test.dart` | Navigation-to-login proof exists; deeper multi-locale coverage is still light |
| `/login` | direct | `apps/empire_flutter/app/test/public_entry_routes_test.dart`, `apps/empire_flutter/app/test/login_page_recent_accounts_test.dart` | Required-field validation and recent-account behavior are proven |
| `/` | workflow/regression | `apps/empire_flutter/app/test/router_redirect_test.dart`, `apps/empire_flutter/app/test/role_workflow_smoke_test.dart` | Dashboard redirect behavior is covered more than dashboard rendering |

## Learner

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/learner/onboarding` | direct | `apps/empire_flutter/app/test/learner_onboarding_gate_test.dart` | Setup-mode visuals are lighter than redirect proof |
| `/learner/today` | direct | `apps/empire_flutter/app/test/learner_today_page_test.dart`, `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart` | Honest mission/habit error and stale-data states are now proven; deeper onboarding and AI paths still rely on separate tests |
| `/learner/missions` | direct | `apps/empire_flutter/app/test/missions_page_test.dart` | — |
| `/learner/habits` | direct | `apps/empire_flutter/app/test/habits_page_test.dart` | — |
| `/learner/portfolio` | direct | `apps/empire_flutter/app/test/learner_portfolio_honesty_test.dart` | — |
| `/learner/credentials` | direct | `apps/empire_flutter/app/test/learner_credentials_page_test.dart` | — |
| `/learner/settings` | workflow/regression | `apps/empire_flutter/app/test/settings_placeholder_actions_test.dart`, `apps/empire_flutter/app/test/shared_role_surfaces_localization_test.dart` | Learner-scoped settings behavior is not isolated |

## Educator

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/educator/today` | direct | `apps/empire_flutter/app/test/educator_today_page_test.dart`, `apps/empire_flutter/app/test/educator_live_session_mode_test.dart` | Honest mobile empty-state and zero-review dialog paths are now isolated; richer in-session mutations still rely on the live-session workflow test |
| `/educator/attendance` | direct | `apps/empire_flutter/app/test/attendance_placeholder_actions_test.dart` | — |
| `/educator/sessions` | direct | `apps/empire_flutter/app/test/educator_sessions_page_test.dart` | Explicit load-failure proof now exists; broader create/edit session flows still lack direct proof |
| `/educator/learners` | direct | `apps/empire_flutter/app/test/educator_learners_page_test.dart` | — |
| `/educator/missions/review` | workflow/regression | `apps/empire_flutter/app/test/router_redirect_test.dart`, `apps/empire_flutter/app/test/role_workflow_smoke_test.dart` | Review-page mechanics are not directly proven |
| `/educator/mission-plans` | direct | `apps/empire_flutter/app/test/educator_mission_plans_page_test.dart` | Creation flow is proven; explicit backend failure state is still not isolated |
| `/educator/learner-supports` | direct | `apps/empire_flutter/app/test/educator_learner_supports_page_test.dart` | Live learner-derived support rendering is proven; failure-state handling is still indirect |
| `/educator/integrations` | workflow/regression | `apps/empire_flutter/app/test/district_provider_integration_test.dart` | Role-specific page failure states are not isolated |

## Parent

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/parent/summary` | direct | `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart` | — |
| `/parent/child/:learnerId` | direct | `apps/empire_flutter/app/test/parent_child_page_test.dart` | — |
| `/parent/consent` | direct | `apps/empire_flutter/app/test/parent_consent_page_test.dart` | — |
| `/parent/billing` | direct | `apps/empire_flutter/app/test/parent_billing_page_test.dart` | — |
| `/parent/schedule` | workflow/regression | `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart` | Schedule rendering and recovery states are not isolated |
| `/parent/portfolio` | workflow/regression | `apps/empire_flutter/app/test/parent_surfaces_localization_test.dart` | Parent portfolio depth is not directly proven |
| `/parent/messages` | workflow/regression | `apps/empire_flutter/app/test/messages_pages_test.dart` | Parent-specific alias behavior is not isolated |
| `/parent/settings` | workflow/regression | `apps/empire_flutter/app/test/settings_placeholder_actions_test.dart` | Parent-scoped settings behavior is not isolated |

## Site

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/site/checkin` | direct | `apps/empire_flutter/app/test/checkin_placeholder_actions_test.dart` | — |
| `/site/provisioning` | direct | `apps/empire_flutter/app/test/provisioning_page_test.dart`, `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Learner-tab failure and stale-data truth are now isolated; parent/link/cohort depth still leans on broader workflow tests |
| `/site/dashboard` | direct | `apps/empire_flutter/app/test/site_dashboard_page_test.dart` | — |
| `/site/sessions` | direct | `apps/empire_flutter/app/test/site_sessions_page_test.dart`, `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Date-based reload and stale-data recovery are now isolated; create/edit depth still relies on broader workflow tests |
| `/site/ops` | direct | `apps/empire_flutter/app/test/site_ops_page_test.dart`, `apps/empire_flutter/app/test/site_ops_honesty_test.dart` | — |
| `/site/incidents` | direct | `apps/empire_flutter/app/test/site_incidents_honesty_test.dart` | — |
| `/site/identity` | direct | `apps/empire_flutter/app/test/site_identity_page_test.dart` | — |
| `/site/pickup-auth` | direct | `apps/empire_flutter/app/test/site_pickup_auth_page_test.dart` | — |
| `/site/consent` | direct | `apps/empire_flutter/app/test/site_consent_page_test.dart` | — |
| `/site/integrations-health` | direct | `apps/empire_flutter/app/test/site_integrations_health_page_test.dart`, `apps/empire_flutter/app/test/district_provider_integration_test.dart` | Failure-state truth and basic provider rendering are proven; deeper action flows remain indirect |
| `/site/billing` | direct | `apps/empire_flutter/app/test/site_billing_page_test.dart`, `apps/empire_flutter/app/test/site_billing_marketplace_test.dart` | — |
| `/site/audit` | direct | `apps/empire_flutter/app/test/site_audit_page_test.dart` | — |

## Partner

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/partner/listings` | direct | `apps/empire_flutter/app/test/partner_listings_page_test.dart` | Create-and-persist path is proven; edit flow still lacks direct proof |
| `/partner/contracts` | direct | `apps/empire_flutter/app/test/partner_contracting_workflow_test.dart` | Happy-path contracts/launches and launch-failure honesty are proven; deeper mutation flows still rely on broader workflow tests |
| `/partner/deliverables` | direct | `apps/empire_flutter/app/test/partner_deliverables_page_test.dart` | — |
| `/partner/integrations` | direct | `apps/empire_flutter/app/test/partner_integrations_page_test.dart` | — |
| `/partner/payouts` | direct | `apps/empire_flutter/app/test/partner_payouts_page_test.dart` | — |

## HQ

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/hq/user-admin` | direct | `apps/empire_flutter/app/test/hq_user_admin_profile_edit_test.dart` | — |
| `/hq/role-switcher` | direct | `apps/empire_flutter/app/test/hq_role_switcher_page_test.dart` | — |
| `/hq/sites` | direct | `apps/empire_flutter/app/test/hq_sites_page_test.dart` | — |
| `/hq/analytics` | direct | `apps/empire_flutter/app/test/hq_analytics_page_test.dart` | — |
| `/hq/billing` | direct | `apps/empire_flutter/app/test/hq_billing_page_test.dart`, `apps/empire_flutter/app/test/hq_admin_placeholder_actions_test.dart` | — |
| `/hq/approvals` | direct | `apps/empire_flutter/app/test/hq_approvals_page_test.dart` | — |
| `/hq/audit` | direct | `apps/empire_flutter/app/test/hq_audit_page_test.dart`, `apps/empire_flutter/app/test/hq_audit_page_localization_test.dart` | — |
| `/hq/safety` | direct | `apps/empire_flutter/app/test/hq_admin_placeholder_actions_test.dart` | Direct proof is narrower than full workflow depth |
| `/hq/exports` | direct | `apps/empire_flutter/app/test/hq_exports_page_test.dart` | — |
| `/hq/integrations-health` | direct | `apps/empire_flutter/app/test/hq_admin_placeholder_actions_test.dart` | Direct proof is narrower than full aggregation behavior |
| `/hq/curriculum` | direct | `apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart` | — |
| `/hq/feature-flags` | direct | `apps/empire_flutter/app/test/hq_feature_flags_page_test.dart` | Honest empty-state, flag-toggle persistence, and failed-save truth are directly proven; deeper federated rollout governance breadth still leans on the large prototype workflow suite |

## Cross-Role

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/messages` | direct | `apps/empire_flutter/app/test/messages_pages_test.dart` | — |
| `/notifications` | direct | `apps/empire_flutter/app/test/messages_pages_test.dart` | — |
| `/profile` | direct | `apps/empire_flutter/app/test/profile_placeholder_actions_test.dart` | — |
| `/settings` | direct | `apps/empire_flutter/app/test/settings_placeholder_actions_test.dart` | — |

## Aliases

| Alias | Canonical route | Evidence |
| --- | --- | --- |
| `/educator/review-queue` | `/educator/missions/review` | `apps/empire_flutter/app/test/router_redirect_test.dart` |
| `/site/scheduling` | `/site/sessions` | `apps/empire_flutter/app/test/router_redirect_test.dart` |
| `/hq/cms` | `/hq/curriculum` | `apps/empire_flutter/app/test/router_redirect_test.dart` |

## Recommendation

Prioritize direct proof next for:

1. `/educator/integrations`
2. `/parent/schedule`
3. `/parent/portfolio`
4. `/educator/missions/review`
5. deeper failure and mutation coverage on `/educator/mission-plans`
6. learner- and parent-scoped alias-route proof for `/settings`

Then upgrade the workflow-only cluster with page-specific failure-state tests for the operationally risky routes before claiming gold.
