# Honesty Audit Remediation Plan

Last updated: 2026-03-18
Status: Not gold-ready
Scope: Flutter app under `apps/empire_flutter/app`

This plan converts the March 18 honesty audit into execution work. It is intentionally blunt. Any route that remains enabled while failing these conditions is a release decision, not an engineering misunderstanding.

## Audit Decision

- No gold release with these P1 blockers open.
- Controlled beta is possible if the team accepts delegated billing, incomplete educator intervention follow-through, and partial site operator telemetry.

Severity model aligned to `docs/19_AUDIT_AND_FIX_PLAYBOOK.md`:

- P0: build broken, security leak, corruption, billing exploit
- P1: core workflow not actually completable
- P2: important but non-core degraded or ambiguous
- P3: polish

## Blocking Workstreams

### WS1: Site Dashboard Truthfulness

Severity: P1

Problem:
- The site dashboard exposes a pillar-progress card that is visibly part of the main product promise.
- The card is not wired and explicitly says telemetry is unavailable.
- Gold release cannot ship a strategic dashboard card that is knowingly disconnected.

Primary evidence:
- `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart`

Target files:
- `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart`
- `apps/empire_flutter/app/lib/i18n/site_dashboard_i18n.dart`
- `apps/empire_flutter/app/lib/services/analytics_service.dart`
- `apps/empire_flutter/app/lib/services/firestore_service.dart`
- `functions/src/telemetryAggregator.ts`
- `functions/src/index.ts`
- `docs/18_ANALYTICS_TELEMETRY_SPEC.md`

Required end-to-end solution:
1. Decide whether pillar progress is shipping now or is deferred.
2. If shipping now:
   - define the site-scoped KPI payload contract
   - expose the contract through callable or repository-backed data access
   - render loading, empty, success, and retry states
   - remove all placeholder copy from the main card
3. If deferred:
   - remove the card from the default site dashboard
   - move it behind an operator or feature-flagged preview surface
   - stop promising data that does not exist

Implementation tasks:
1. Add a typed site pillar summary model and loader boundary.
2. Replace static unavailable copy with real data render or remove the card.
3. Add retry handling when the telemetry source fails.
4. Ensure site scoping is explicit in every query or callable payload.
5. Update localized copy only after the real product behavior is final.

Verification:
1. Widget test for loading state.
2. Widget test for empty-data state.
3. Widget test for populated-data state.
4. Widget test for recoverable error state with retry.
5. Manual mobile proof on Android.

Exit criteria:
- The card either shows real pillar data or does not appear on the main dashboard.
- No copy on the main dashboard implies future availability without a real path.

### WS2: Educator Learner Support Completion

Severity: P1

Problem:
- The educator learner detail flow stops exactly when follow-through is needed.
- The screen explicitly says direct messaging and full learner profiles are not available from the sheet.
- That makes the support workflow observational rather than operational.

Primary evidence:
- `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart`

Target files:
- `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart`
- `apps/empire_flutter/app/lib/modules/messages/messages_page.dart`
- `apps/empire_flutter/app/lib/modules/profile/profile_page.dart`
- `apps/empire_flutter/app/lib/modules/messages/message_service.dart`
- `apps/empire_flutter/app/lib/services/firestore_service.dart`
- `apps/empire_flutter/app/lib/router/app_router.dart`
- `apps/empire_flutter/app/lib/i18n/workflow_surface_i18n.dart`
- `firestore.rules`

Required end-to-end solution:
1. Provide a real educator-safe path to learner detail.
2. Provide a real educator-safe path to act from the support sheet.
3. Fail closed on unauthorized access rather than exposing cross-role leakage.

Implementation tasks:
1. Add a learner detail action from the educator learner sheet.
2. Define whether that action opens:
   - a read-only learner detail page, or
   - a dedicated educator learner profile view
3. Add a message or escalation action that persists through `MessageService` or support-request infrastructure.
4. Remove the dead-end informational box once actions exist.
5. Add clear unavailable-state handling only for genuinely blocked permission cases.

Verification:
1. Widget test for opening learner detail from the sheet.
2. Widget test for the messaging or escalation CTA.
3. Persistence test proving the created message or support action is written.
4. Rules test for wrong-role denial.
5. Manual educator flow smoke from dashboard card to learner action completion.

Exit criteria:
- An educator can move from identifying a support need to taking an in-app action without hitting a dead end.

### WS3: Parent Billing Honesty

Severity: P1

Problem:
- The route is named and presented as billing.
- Core billing actions are not self-service.
- The app currently delegates payment method changes, plan changes, and invoice actions to HQ or site staff.

Primary evidence:
- `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart`

Target files:
- `apps/empire_flutter/app/lib/modules/parent/parent_billing_page.dart`
- `apps/empire_flutter/app/lib/modules/parent/parent_service.dart`
- `apps/empire_flutter/app/lib/services/billing_service.dart`
- `apps/empire_flutter/app/lib/services/firestore_service.dart`
- `functions/src/workflowOps.ts`
- `functions/src/index.ts`
- `docs/13_PAYMENTS_BILLING_SPEC.md`
- `firestore.rules`

Decision required before implementation:
1. Ship true self-service billing.
2. Reframe the route as billing overview plus support handoff.

Path A: true self-service billing
1. Add payment method management through Stripe or equivalent.
2. Add plan change flow through portal or callable-backed mutation.
3. Add invoice viewing and payment action.
4. Support mobile return/deep-link flow after external portal transitions.
5. Refresh in-app summary after successful return.

Path B: honest billing overview
1. Rename the route and dashboard card to a view-only billing summary.
2. Remove action framing that implies self-service.
3. Replace scattered support text with one explicit request flow.
4. Persist the support request and expose confirmation plus status.

Implementation tasks common to either path:
1. Remove misleading action affordances.
2. Update tri-locale copy to match the real product shape.
3. Add error state and retry for billing summary load.
4. Add empty state for accounts without billing configuration.

Verification:
1. Widget test for billing summary load and error states.
2. Widget test for self-service launch or support-request submission.
3. Persistence test for the chosen action path.
4. Manual Android test for billing flow completion.

Exit criteria:
- The route name, CTA set, and actual completion path all match.
- No family is told a billing action exists when the app cannot perform it.

### WS4: Gold-Path Test Coverage

Severity: P1

Problem:
- There are 52 Flutter module page files and only 10 page-specific page tests.
- Focused regression suites exist, but direct page coverage is too sparse for a gold claim.

Primary evidence:
- `apps/empire_flutter/app/lib/modules/`
- `apps/empire_flutter/app/test/`

Target files:
- New tests under `apps/empire_flutter/app/test/`

Priority order:
1. `site_dashboard_page`
2. `educator_learners_page`
3. `parent_billing_page`
4. `site_ops_page`
5. `missions_page`
6. `habits_page`
7. `site_billing_page`

Required test shape for each gold-path page:
1. loading state
2. empty state
3. success state
4. error state with retry or fail-closed proof
5. one real primary action path

Exit criteria:
- Every gold-path page has direct widget or page coverage.
- Regression evidence is sufficient to support a gold recommendation.

## Non-Blocking But Required Workstreams

### WS5: AI Coach Degradation UX

Severity: P2

Primary evidence:
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`
- `apps/empire_flutter/app/lib/modules/habits/habits_page.dart`

Problem:
- AI coach panels degrade to a dead text label when runtime is absent.

Tasks:
1. Replace static “AI Coach not available” text with a structured fallback panel.
2. Explain why the feature is unavailable.
3. Offer next actions: retry, continue without AI, or educator escalation when appropriate.
4. Emit telemetry for runtime-unavailable states.

Verification:
1. Widget tests for runtime-present and runtime-missing states.
2. Manual learner flow proof on mobile.

### WS6: Route Canonicalization

Severity: P2

Primary evidence:
- `apps/empire_flutter/app/lib/router/app_router.dart`

Problem:
- Flutter still exposes route aliases for:
  - `/educator/review-queue`
  - `/site/scheduling`
  - `/hq/cms`

Tasks:
1. Pick canonical routes.
2. Convert aliases into redirects or remove them.
3. Update dashboard cards, docs, tests, and telemetry labels.

Verification:
1. Router redirect tests.
2. Deep-link smoke tests.

### WS7: Direct Firestore Coupling Reduction

Severity: P2

Primary evidence:
- `apps/empire_flutter/app/lib/runtime/global_ai_assistant_overlay.dart`
- `apps/empire_flutter/app/lib/domain/repositories.dart`

Problem:
- UI and domain layers still reach for `FirebaseFirestore.instance` directly.
- This makes harnessing and failure-path testing brittle.

Tasks:
1. Route runtime overlay reads through injected services or repositories.
2. Prefer constructor-injected Firestore or `FirestoreService` boundaries in gold-path surfaces.
3. Keep fail-closed behavior when providers are absent.

Verification:
1. Widget tests with fake Firestore or fake services.
2. No `core/no-app` regressions in gold-path test harnesses.

### WS8: Stale Copy and i18n Drift

Severity: P3

Primary evidence:
- `apps/empire_flutter/app/lib/i18n/workflow_surface_i18n.dart`
- `apps/empire_flutter/app/lib/i18n/site_dashboard_i18n.dart`

Problem:
- The copy catalog still contains strings for earlier placeholder states and removed dead ends.

Tasks:
1. Remove or rewrite stale unavailable strings once the real product behavior is finalized.
2. Keep `en`, `zh-CN`, and `zh-TW` aligned.
3. Re-run locale confidence gates after each copy update.

Verification:
1. Grep for legacy placeholder copy under `apps/empire_flutter/app/lib/modules` and `apps/empire_flutter/app/lib/i18n`.
2. Focused localization tests where affected.

## Recommended Execution Order

1. WS3 Parent Billing product decision
2. WS1 Site Dashboard Truthfulness
3. WS2 Educator Learner Support Completion
4. WS4 Gold-Path Test Coverage for the above routes
5. WS5 AI Coach Degradation UX
6. WS6 Route Canonicalization
7. WS7 Direct Firestore Coupling Reduction
8. WS8 Stale Copy and i18n Drift

## Evidence Required To Close The Plan

For each closed workstream, add:
1. file list changed
2. tests added
3. commands run
4. result summary
5. remaining risks

Minimum command set for blocker closure:

```bash
cd apps/empire_flutter/app
flutter analyze
flutter test
flutter build apk --debug
```

Focused tests should also be run for each modified route or service.

## Gold Release Gate For These Findings

Do not mark the Flutter app gold-ready until all of the following are true:

1. Site dashboard contains no knowingly disconnected primary KPI card.
2. Educator learner support flow includes a real action path.
3. Parent billing either supports real completion or is explicitly reframed as view-only with a real support path.
4. Gold-path page coverage is materially expanded beyond the current 10 page-specific tests.
5. Alias-route drift is contained enough that route analytics and operator instructions stay canonical.

Until then, “works” is not the same as “complete.”