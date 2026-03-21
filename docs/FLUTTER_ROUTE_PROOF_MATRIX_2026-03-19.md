# Flutter Route Proof Matrix

Last updated: 2026-03-19
Scope: enabled Flutter routes from `apps/empire_flutter/app/lib/router/app_router.dart`

Proof levels:

- `direct`: route has a page-specific test proving the page itself
- `workflow/regression`: route is only covered indirectly through shared, navigation, localization, or regression tests
- `none`: no convincing route proof was found

Interpretation:

- `direct` does not automatically mean full-flow verified
- stale-refresh proof only certifies honest degraded behavior, not live end-to-end health
- gold confidence requires read, mutate where applicable, authoritative reload, failure, recovery, and scope proof on the same route or tightly coupled workflow

## Summary

- Enabled canonical routes audited: 52
- Direct: 51
- Workflow/regression only: 1
- None: 0
- Full-flow certified count: not claimed by this matrix
- Gold-ready certified count: not claimed by this matrix

Highest-value remaining blind spots:

1. scope certification plus deeper control/escalation traceability proof on `/hq/feature-flags`
2. broader mutation depth on `/site/sessions` and `/site/provisioning`
3. partner listings edit depth beyond create-and-persist proof
4. root redirect proof is still stronger than direct home-surface rendering proof

Use this matrix together with the stricter full-flow gate in `docs/FULL_HONESTY_AUDIT_2026-03-19.md`. This file measures route-proof presence, not final workflow certification.

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
| `/learner/settings` | direct | `apps/empire_flutter/app/test/settings_placeholder_actions_test.dart`, `apps/empire_flutter/app/test/shared_role_surfaces_localization_test.dart` | Learner-scoped alias rendering is now isolated; deeper settings mutation depth remains shared with the canonical settings surface |

## Educator

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/educator/today` | direct | `apps/empire_flutter/app/test/educator_today_page_test.dart`, `apps/empire_flutter/app/test/educator_live_session_mode_test.dart` | Honest mobile empty-state and zero-review dialog paths are now isolated; richer in-session mutations still rely on the live-session workflow test |
| `/educator/attendance` | direct | `apps/empire_flutter/app/test/attendance_placeholder_actions_test.dart` | Attendance list and roster now have direct first-load and stale-refresh honesty proof; attendance save depth remains outside this route-specific regression |
| `/educator/sessions` | direct | `apps/empire_flutter/app/test/educator_sessions_page_test.dart` | Explicit load-failure proof now exists; broader create/edit session flows still lack direct proof |
| `/educator/learners` | direct | `apps/empire_flutter/app/test/educator_learners_page_test.dart` | — |
| `/educator/missions/review` | direct | `apps/empire_flutter/app/test/educator_mission_review_page_test.dart`, `apps/empire_flutter/app/test/educator_honesty_regression_test.dart`, `apps/empire_flutter/app/test/persistence_blockers_regression_test.dart` | Canonical review queue now runs on `missionAttempts` with direct load failure, active-site scoped retry, failed review submission, and canonical grading persistence proof; legacy `missionSubmissions` fallback is still transitional |
| `/educator/mission-plans` | direct | `apps/empire_flutter/app/test/educator_mission_plans_page_test.dart` | Create, load-failure, create-failure, edit-persist, archive-persist, and archive-failure truth are directly proven; future assignment breadth remains separate |
| `/educator/learner-supports` | direct | `apps/empire_flutter/app/test/educator_learner_supports_page_test.dart` | First-load learner outage, saved-plan outage, persisted edit/save behavior, search filtering, and stale saved-plan refresh truth are directly proven |
| `/educator/integrations` | direct | `apps/empire_flutter/app/test/educator_integrations_page_test.dart`, `apps/empire_flutter/app/test/district_provider_integration_test.dart` | Honest load failure, retry, and sync-action failure states are now isolated; broader provider breadth still relies on the district and provider workflow tests |

## Parent

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/parent/summary` | direct | `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart` | — |
| `/parent/child/:learnerId` | direct | `apps/empire_flutter/app/test/parent_child_page_test.dart` | — |
| `/parent/consent` | direct | `apps/empire_flutter/app/test/parent_consent_page_test.dart` | — |
| `/parent/billing` | direct | `apps/empire_flutter/app/test/parent_billing_page_test.dart` | — |
| `/parent/schedule` | direct | `apps/empire_flutter/app/test/parent_schedule_page_test.dart`, `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart` | Honest load failure and reminder-request flow are now directly proven |
| `/parent/portfolio` | direct | `apps/empire_flutter/app/test/parent_portfolio_page_test.dart`, `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart` | Honest load failure, share request, and summary download are now directly proven |
| `/parent/messages` | direct | `apps/empire_flutter/app/test/messages_pages_test.dart` | Parent alias rendering is now isolated; deeper message-action breadth still relies on the shared messages surface |
| `/parent/settings` | direct | `apps/empire_flutter/app/test/settings_placeholder_actions_test.dart` | Parent-scoped alias rendering is now isolated; deeper settings mutation depth remains shared with the canonical settings surface |

## Site

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/site/checkin` | direct | `apps/empire_flutter/app/test/checkin_placeholder_actions_test.dart` | — |
| `/site/provisioning` | direct | `apps/empire_flutter/app/test/provisioning_page_test.dart`, `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Learner-tab failure and stale-data truth are now isolated; parent/link/cohort depth still leans on broader workflow tests |
| `/site/dashboard` | direct | `apps/empire_flutter/app/test/site_dashboard_page_test.dart` | — |
| `/site/sessions` | direct | `apps/empire_flutter/app/test/site_sessions_page_test.dart`, `apps/empire_flutter/app/test/site_ops_provisioning_workflow_test.dart` | Date-based reload and stale-data recovery are now isolated; create/edit depth still relies on broader workflow tests |
| `/site/ops` | direct | `apps/empire_flutter/app/test/site_ops_page_test.dart`, `apps/empire_flutter/app/test/site_ops_honesty_test.dart` | Runtime rollout first-load outage, stale-refresh truth, and direct in-surface refresh/retry recovery are now proven; deeper activity mutation breadth still leans on the broader workflow tests |
| `/site/incidents` | direct | `apps/empire_flutter/app/test/site_incidents_honesty_test.dart` | First-load outage, stale-refresh retention, identity fallback labels, and visible refresh-failure detail are directly proven; broader incident mutation depth is still outside the focused audit |
| `/site/identity` | direct | `apps/empire_flutter/app/test/site_identity_page_test.dart` | First-load outage, stale-refresh retention, and visible refresh-failure detail are directly proven; deeper resolution-action breadth still extends beyond the focused audit |
| `/site/pickup-auth` | direct | `apps/empire_flutter/app/test/site_pickup_auth_page_test.dart` | — |
| `/site/consent` | direct | `apps/empire_flutter/app/test/site_consent_page_test.dart` | — |
| `/site/integrations-health` | direct | `apps/empire_flutter/app/test/site_integrations_health_page_test.dart`, `apps/empire_flutter/app/test/district_provider_integration_test.dart` | Failure-state truth, stale-refresh detail visibility, labeled refresh control, and basic provider rendering are proven; deeper action flows remain indirect |
| `/site/billing` | direct | `apps/empire_flutter/app/test/site_billing_page_test.dart`, `apps/empire_flutter/app/test/site_billing_marketplace_test.dart` | — |
| `/site/audit` | direct | `apps/empire_flutter/app/test/site_audit_page_test.dart` | — |

## Partner

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/partner/listings` | direct | `apps/empire_flutter/app/test/partner_listings_page_test.dart` | First-load outage, stale-refresh retention, and create-and-persist proof are direct; edit flow still lacks direct proof |
| `/partner/contracts` | direct | `apps/empire_flutter/app/test/partner_contracting_workflow_test.dart` | Happy-path contracts/launches, launch-failure honesty, and stale contract/launch refresh truth are directly proven; deeper mutation flows still rely on broader workflow tests |
| `/partner/deliverables` | direct | `apps/empire_flutter/app/test/partner_deliverables_page_test.dart` | Honest first-load outage, stale-refresh retention, and submit flow are directly proven; deeper contract mutation breadth still lives on the contracts workflow |
| `/partner/integrations` | direct | `apps/empire_flutter/app/test/partner_integrations_page_test.dart` | First-load outage, stale-refresh retention, live connection rendering, and honest localized empty-state copy are directly proven |
| `/partner/payouts` | direct | `apps/empire_flutter/app/test/partner_payouts_page_test.dart` | — |

## HQ

| Route | Proof | Primary evidence | Blind spot |
| --- | --- | --- | --- |
| `/hq/user-admin` | direct | `apps/empire_flutter/app/test/hq_user_admin_profile_edit_test.dart` | Users, sites, audit-log first-load failure, and stale audit-log refresh truth are directly proven; deeper user mutation breadth is still wider than the focused audit-log proof |
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
| `/hq/feature-flags` | direct | `apps/empire_flutter/app/test/hq_feature_flags_page_test.dart` | Honest empty-state, first-load failure detail, stale-refresh detail visibility, labeled app-bar recovery controls, flag-toggle persistence, failed-save truth, rollout-alert triage save-plus-reload and failure truth, rollout-control validation/save-plus-reload plus failure truth, rollout-escalation validation/save-plus-reload plus failure truth, and alert-history reflection of saved triage notes are directly proven; scope certification and deeper control/escalation traceability still lean on the large prototype workflow suite |

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

1. scope proof and deeper control/escalation traceability proof on `/hq/feature-flags` after consequential governance mutations
2. broader create, edit, and recovery depth on `/site/sessions` and `/site/provisioning`
3. partner listings edit depth beyond create-and-persist proof
4. stronger direct rendering proof around the `/` entry surface beyond redirect behavior

Then close the final workflow-only root-entry gap and deepen mutation and failure-path proof on the operationally risky routes before claiming gold.

Under the tightened honesty standard, prioritize in this order:

1. operator mutations with governance consequences
2. routes that claim persisted change without authoritative reload proof
3. evidence-bearing learner and educator flows that can imply growth or mastery
4. remaining rendering-only or redirect-only route coverage gaps
