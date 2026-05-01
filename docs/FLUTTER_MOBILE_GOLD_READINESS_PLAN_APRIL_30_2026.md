# Flutter/Mobile Gold Readiness Plan - April 30, 2026

## Current Verdict

**Flutter/mobile is not gold-ready yet.** The focused MiloOS support-provenance mobile gate has passed, but the broader Flutter app remains beta until the full evidence chain is verified across learner, educator, guardian, site, offline, report/export, and release operations.

Do not promote Flutter/mobile to gold-ready because a widget renders or a focused test passes. Gold requires end-to-end evidence capture, verification, interpretation, portfolio/report communication, site scoping, offline behavior, and role-safe outputs.

## What Is Already Proven

| Area | Status | Proof |
| --- | --- | --- |
| MiloOS learner support journey | Focused gold-candidate slice passed | `BosLearnerLoopInsightsCard` parses opened, used, explain-back, and pending support journey gaps. |
| MiloOS educator visibility | Focused gold-candidate slice passed | `EducatorLearnerSupportsPage` renders per-learner support provenance and pending explain-back debt from same-site `interactionEvents`. |
| MiloOS site health | Focused gold-candidate slice passed | `SiteDashboardPage` renders same-site support health from `interactionEvents`. |
| MiloOS truth boundary | Passed for focused slice | Support events are framed as support/provenance and follow-up debt, not capability mastery. |
| Guardian portfolio/passport workflows | Passed | `parent_surfaces_workflow_test.dart` proves linked guardian schedule, portfolio, reviewed artifacts, passport export/copy, provenance-gated downloads, and billing unavailable state. |
| Analyzer | Passed for current mobile slice | `flutter analyze` is clean after the MiloOS mobile parity changes. |

Focused proof commands that passed:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart
cd apps/empire_flutter/app && flutter analyze
```

## Known Blockers Before Full Flutter/Mobile Gold

1. **Route matrix needs current classification**: older route proof matrices exist, but the plan needs a current April 30 classification of direct, partial, fake/stubbed, and missing mobile evidence-chain surfaces.
2. **Offline evidence ops need a full gate**: prior offline/growth boundary tests exist, but mobile gold needs one current bundle proving offline queue behavior for evidence capture, proof, rubric/checkpoint replay, and failed server-owned writes.
3. **Mobile classroom ergonomics need current proof**: learner/educator small-screen evidence capture and live support flows need a focused Flutter viewport gate.
4. **End-to-end mobile release gate is not bundled**: focused tests have passed in slices, but there is no single documented Flutter/mobile gold command bundle that operators can run and interpret.

## Plan Of Attack

### Phase 1 - Stabilize Guardian And Report Workflows

Status: completed 2026-04-30.

Primary role: guardian.

Evidence-chain step: communicate evidence through trustworthy portfolio, passport, and family report outputs.

Actions:

- Fix `parent_surfaces_workflow_test.dart` failures without weakening assertions.
- Keep Firebase/test harness setup honest; do not bypass live learner/educator workflow proof with fake artifacts.
- Confirm parent portfolio and child passport reports carry evidence, proof, rubric, reviewer, AI disclosure, and capability provenance when available.
- Confirm missing provenance fails closed instead of exporting a misleading family artifact.

Exit proof:

```bash
cd apps/empire_flutter/app && flutter test test/parent_surfaces_workflow_test.dart
```

### Phase 2 - Build A Current Flutter Route Proof Matrix

Primary roles: learner, educator, guardian, site, HQ.

Evidence-chain step: classify every mobile route by evidence function and readiness.

Actions:

- Refresh the Flutter route matrix from current app routes and tests.
- Classify each route as aligned and reusable, reusable with modification, partial, fake/stubbed, misaligned, or missing entirely.
- Separate evidence-chain routes from operational routes.
- Mark exact proof files and missing test gaps per route.

Exit proof:

- A current route matrix document lists each mobile evidence-chain route, owner role, persistence path, test file, and blocker.

### Phase 3 - Prove Offline Evidence Chain Behavior

Primary roles: learner and educator.

Evidence-chain step: capture, verify, and interpret evidence safely when connectivity is unreliable.

Actions:

- Run and update offline queue tests for evidence capture, proof-of-learning, rubric application, checkpoint replay, and report-share/delivery audit retry.
- Confirm support events remain support/provenance and do not become offline mastery writes.
- Confirm direct `capabilityMastery` and `capabilityGrowthEvents` writes fail closed from mobile/offline paths.

Exit proof:

```bash
cd apps/empire_flutter/app && flutter test test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart
cd apps/empire_flutter/app && flutter analyze lib/modules/missions/mission_service.dart lib/services/capability_growth_engine.dart lib/services/firestore_service.dart lib/offline/sync_coordinator.dart test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart
```

### Phase 4 - Prove Mobile Classroom Ergonomics

Primary roles: learner and educator.

Evidence-chain step: live capture and support during class.

Actions:

- Add focused small-screen Flutter widget/golden-style checks for learner evidence submission, educator live evidence capture, educator supports, and site dashboard support health.
- Verify touch targets, text wrapping, loading/empty/error states, and no horizontal overflow.
- Confirm teacher live actions can be completed quickly and do not require after-class cleanup.

Exit proof:

- Focused mobile viewport tests cover the critical learner/educator classroom surfaces.

### Phase 5 - Bundle Full Flutter/Mobile Gold Gate

Primary role: operators.

Evidence-chain step: release trust and repeatability.

Actions:

- Create a single Flutter/mobile release gate command list.
- Include focused role workflow tests, parent/guardian workflows, offline evidence tests, route proof matrix tests, analyzer, and diff hygiene.
- Update `AUDIT_TODO_APRIL_2026.md` only after all commands pass.

Exit proof:

```bash
cd apps/empire_flutter/app && flutter test \
  test/bos_insights_cards_test.dart \
  test/educator_learner_supports_page_test.dart \
  test/site_dashboard_page_test.dart \
  test/parent_surfaces_workflow_test.dart
cd apps/empire_flutter/app && flutter analyze
cd /Users/impactory/Documents/GitHub/scholesa && git diff --check
```

The final bundle will expand as phases 2-4 promote more focused tests into the required gate.

## Gold Stop Conditions

Do not call Flutter/mobile gold-ready if any of these are true:

- `parent_surfaces_workflow_test.dart` fails.
- Any mobile workflow writes or implies capability mastery from support, completion, attendance, XP, or report export alone.
- Offline queue can directly write `capabilityMastery` or `capabilityGrowthEvents` without the server-owned interpretation path.
- Guardian exports/share actions can succeed without evidence provenance when provenance is required.
- A route proof matrix item is marked fake/stubbed, partial, or missing for a core evidence-chain workflow.
- Analyzer or diff hygiene fails.
- The final command bundle cannot be reproduced from a clean checkout.

## Next Slice

The next highest-risk break is **the missing current Flutter route proof matrix**. Build `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` from the current route registry, role dashboards, persistence paths, and tests before expanding the final mobile release gate.
