# Flutter Route Proof Matrix

Last updated: 2026-03-19
Scope: enabled Flutter routes from `apps/empire_flutter/app/lib/router/app_router.dart`

Proof levels:

- `direct`: route has a page-specific test proving the page itself
- `workflow/regression`: route is only covered indirectly through shared, navigation, localization, or regression tests
- `none`: no convincing route proof was found

## Summary

- Enabled canonical routes audited: 52
- Direct: 31
- Workflow/regression only: 15
- None: 6

Highest-value remaining blind spots:

1. `/welcome`
2. `/login`
3. `/educator/mission-plans`
4. `/educator/learner-supports`
5. `/partner/listings`
6. `/hq/feature-flags`

## Public, Auth, and Root

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/welcome` | none | — | Public landing route has no direct proof |
| `/login` | none | — | Login page behavior is not directly proven |
| `/` | workflow/regression | `apps/empire_flutter/app/test/router_redirect_test.dart`, `apps/empire_flutter/app/test/role_workflow_smoke_test.dart` | Dashboard redirect behavior is covered more than dashboard rendering |

## Learner

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/learner/onboarding` | direct | `apps/empire_flutter/app/test/learner_onboarding_gate_test.dart` | Setup-mode visuals are lighter than redirect proof |
| `/learner/today` | workflow/regression | `apps/empire_flutter/app/test/role_workflow_smoke_test.dart`, `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart` | No dedicated today-page widget test |
| `/learner/missions` | direct | `apps/empire_flutter/app/test/missions_page_test.dart` | — |
| `/learner/habits` | direct | `apps/empire_flutter/app/test/habits_page_test.dart` | — |
| `/learner/portfolio` | direct | `apps/empire_flutter/app/test/learner_portfolio_honesty_test.dart` | — |
| `/learner/credentials` | direct | `apps/empire_flutter/app/test/learner_credentials_page_test.dart` | — |
| `/learner/settings` | workflow/regression | `apps/empire_flutter/app/test/settings_placeholder_actions_test.dart`, `apps/empire_flutter/app/test/shared_role_surfaces_localization_test.dart` | Learner-scoped settings behavior is not isolated |

## Educator

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/educator/today` | workflow/regression | `apps/empire_flutter/app/test/role_workflow_smoke_test.dart`, `apps/empire_flutter/app/test/educator_honesty_regression_test.dart` | No dedicated today-page test |
| `/educator/attendance` | direct | `apps/empire_flutter/app/test/attendance_placeholder_actions_test.dart` | — |
| `/educator/sessions` | workflow/regression | `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Session rendering and recovery states are not isolated |
| `/educator/learners` | direct | `apps/empire_flutter/app/test/educator_learners_page_test.dart` | — |
| `/educator/missions/review` | workflow/regression | `apps/empire_flutter/app/test/router_redirect_test.dart`, `apps/empire_flutter/app/test/role_workflow_smoke_test.dart` | Review-page mechanics are not directly proven |
| `/educator/mission-plans` | none | — | Enabled route with no convincing proof |
| `/educator/learner-supports` | none | — | Enabled route with no convincing proof |
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
| `/site/provisioning` | workflow/regression | `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Provisioning page itself is not isolated |
| `/site/dashboard` | direct | `apps/empire_flutter/app/test/site_dashboard_page_test.dart` | — |
| `/site/sessions` | workflow/regression | `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Session-specific filters and recovery are not isolated |
| `/site/ops` | direct | `apps/empire_flutter/app/test/site_ops_page_test.dart`, `apps/empire_flutter/app/test/site_ops_honesty_test.dart` | — |
| `/site/incidents` | direct | `apps/empire_flutter/app/test/site_incidents_honesty_test.dart` | — |
| `/site/identity` | direct | `apps/empire_flutter/app/test/site_identity_page_test.dart` | — |
| `/site/pickup-auth` | direct | `apps/empire_flutter/app/test/site_pickup_auth_page_test.dart` | — |
| `/site/consent` | direct | `apps/empire_flutter/app/test/site_consent_page_test.dart` | — |
| `/site/integrations-health` | workflow/regression | `apps/empire_flutter/app/test/district_provider_integration_test.dart` | HQ/site aggregation and alert states are not isolated |
| `/site/billing` | direct | `apps/empire_flutter/app/test/site_billing_page_test.dart`, `apps/empire_flutter/app/test/site_billing_marketplace_test.dart` | — |
| `/site/audit` | direct | `apps/empire_flutter/app/test/site_audit_page_test.dart` | — |

## Partner

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/partner/listings` | none | — | Enabled route with no convincing proof |
| `/partner/contracts` | workflow/regression | `apps/empire_flutter/app/test/partner_contracting_workflow_test.dart` | Contract page mechanics are not isolated |
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
| `/hq/feature-flags` | none | — | Enabled route with no convincing proof |

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

1. `/educator/mission-plans`
2. `/educator/learner-supports`
3. `/partner/listings`
4. `/hq/feature-flags`
5. `/welcome`
6. `/login`

Then upgrade the workflow-only cluster with page-specific failure-state tests for the operationally risky routes before claiming gold.