# Honesty Audit Remediation Plan

Last updated: 2026-03-18
Status: Beta ready, not gold-ready
Scope: Flutter app plus release operations for web and native surfaces

This plan converts the March 18 honesty audit into execution work. It is intentionally blunt. It has been updated after remediation, release-path hardening, and reopened verification.

## Audit Decision

- No gold release until native distribution is proven end to end.
- Controlled beta is now possible because the audited app flows are materially more honest and completable than the original audit state.

Severity model aligned to `docs/19_AUDIT_AND_FIX_PLAYBOOK.md`:

- P0: build broken, security leak, corruption, billing exploit
- P1: core workflow not actually completable
- P2: important but non-core degraded or ambiguous
- P3: polish

## Blocking Workstreams

### WS1: Site Dashboard Truthfulness

Severity: P1
Current status: Closed

Resolution:
- The disconnected pillar-progress card was removed from the main site dashboard path.
- The gold-path dashboard no longer promises pillar telemetry that does not exist.

Primary evidence:
- `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart`

Key changed files:
- `apps/empire_flutter/app/lib/modules/site/site_dashboard_page.dart`
- `apps/empire_flutter/app/test/dashboard_cta_regression_test.dart`

Verification evidence:
1. Focused regression updated to assert the disconnected card is absent.
2. The audited dashboard no longer contains the strategic but unwired telemetry card.

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

Exit criteria status:
- Met.

### WS2: Educator Learner Support Completion

Severity: P1
Current status: Closed

Resolution:
- The educator learner detail flow now supports a real persisted follow-up request.
- The dead-end informational box was replaced by a completion path.

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

Key changed files:
- `apps/empire_flutter/app/lib/modules/educator/educator_learners_page.dart`
- `apps/empire_flutter/app/test/educator_differentiation_workflow_test.dart`
- `apps/empire_flutter/app/test/educator_learners_page_test.dart`

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

Verification evidence:
1. Focused educator regressions passed.
2. Direct page coverage exists for `educator_learners_page`.

Exit criteria status:
- Met.

### WS3: Parent Billing Honesty

Severity: P1
Current status: Closed as honest view-only behavior

Resolution:
- The route currently behaves as a billing overview and support-handoff surface.
- Tests verify the surface does not expose fake self-service actions.

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

Current decision:
1. Billing is shipping as honest view-only overview plus support handoff.

Key evidence:
1. `parent_billing_page` renders explicit unavailable and delegated-action copy.
2. Direct page tests prove there is no fake `Pay Now` or `Manage Plan` self-service path.

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

Exit criteria status:
- Met for honesty.
- Not upgraded to true self-service billing.

### WS4: Gold-Path Test Coverage

Severity: P1
Current status: Closed for the priority audited pages

Resolution:
- Direct page coverage was added or verified for the priority gold-path pages named in the audit.

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

Verification evidence:
1. Priority page batch passed: 16 passed, 0 failed.
2. Direct page tests exist for all seven priority audited routes.

Exit criteria status:
- Met for the priority audited gold-path pages.

## Non-Blocking But Required Workstreams

### WS5: AI Coach Degradation UX

Severity: P2
Current status: Partial

Primary evidence:
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`
- `apps/empire_flutter/app/lib/modules/habits/habits_page.dart`

Problem:
- AI runtime degradation remains a secondary UX quality item rather than a gold blocker.

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
Current status: Closed

Primary evidence:
- `apps/empire_flutter/app/lib/router/app_router.dart`

Resolution:
- The audited alias routes were converted into redirects through canonical normalization.

Tasks:
1. Pick canonical routes.
2. Convert aliases into redirects or remove them.
3. Update dashboard cards, docs, tests, and telemetry labels.

Verification evidence:
1. Router redirect regressions were updated and passed.

Exit criteria status:
- Met for the audited aliases.

### WS7: Direct Firestore Coupling Reduction

Severity: P2
Current status: Closed for the audited AI overlay path

Primary evidence:
- `apps/empire_flutter/app/lib/runtime/global_ai_assistant_overlay.dart`
- `apps/empire_flutter/app/lib/domain/repositories.dart`

Resolution:
- The audited AI overlay session-occurrence lookup logic was consolidated behind shared helper boundaries with injectable Firestore access.

Tasks:
1. Route runtime overlay reads through injected services or repositories.
2. Prefer constructor-injected Firestore or `FirestoreService` boundaries in gold-path surfaces.
3. Keep fail-closed behavior when providers are absent.

Verification evidence:
1. The audited overlay path no longer duplicates direct lookup logic.

Exit criteria status:
- Met for the audited overlay path.

### WS8: Stale Copy and i18n Drift

Severity: P3
Current status: Partial

Primary evidence:
- `apps/empire_flutter/app/lib/i18n/workflow_surface_i18n.dart`
- `apps/empire_flutter/app/lib/i18n/site_dashboard_i18n.dart`

Problem:
- Some stale copy cleanup remains, but the highest-risk placeholder copy on audited gold paths has already been removed or reframed.

Tasks:
1. Remove or rewrite stale unavailable strings once the real product behavior is finalized.
2. Keep `en`, `zh-CN`, and `zh-TW` aligned.
3. Re-run locale confidence gates after each copy update.

Verification:
1. Grep for legacy placeholder copy under `apps/empire_flutter/app/lib/modules` and `apps/empire_flutter/app/lib/i18n`.
2. Focused localization tests where affected.

## Recommended Execution Order

Completed in this pass:
1. WS1 Site Dashboard Truthfulness
2. WS2 Educator Learner Support Completion
3. WS3 Parent Billing Honesty as view-only behavior
4. WS4 Gold-Path Test Coverage for priority audited pages
5. WS6 Route Canonicalization
6. WS7 Direct Firestore Coupling Reduction for the audited overlay path

Remaining recommended order:
1. WS5 AI Coach Degradation UX
2. WS8 Stale Copy and i18n Drift
3. Native distribution proof for iOS and Android release pipelines

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

Additional release evidence now required for gold:

```bash
cd /Users/simonluke/dev/scholesa
./scripts/apple_release_local.sh verify_local_release
./scripts/android_release_local.sh verify_local_release
```

And one successful distribution proof for each native platform through the supported path.

## Gold Release Gate For These Findings

Do not mark the Flutter app gold-ready until all of the following are true:

1. Site dashboard contains no knowingly disconnected primary KPI card.
2. Educator learner support flow includes a real action path.
3. Parent billing either supports real completion or is explicitly reframed as view-only with a real support path.
4. Gold-path page coverage remains in place for the audited routes.
5. Alias-route drift stays contained enough that route analytics and operator instructions stay canonical.
6. iOS distribution is proven through the supported TestFlight path.
7. Android distribution is proven through the supported Google Play path.

Until then, “builds” is not the same as “release complete.”