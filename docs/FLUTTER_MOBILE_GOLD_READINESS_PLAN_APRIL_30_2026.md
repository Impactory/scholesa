# Flutter/Mobile Gold Readiness Plan - April 30, 2026

## Current Verdict

**Flutter/mobile is not blanket gold-ready yet.** The focused Flutter/mobile release bundle has passed across the validated learner, educator, guardian, site, offline, report/export, permission, analyzer, and source-contract slices. The April 30 route-level evidence blockers are now closed, the current-worktree full Flutter test/analyzer gate now passes, the local web/functions/root test gates are clean, and the new non-deploying `./scripts/deploy.sh release-gate` passes from the current worktree. The broader Flutter app remains beta until an approved live or no-traffic deploy rehearsal is clean.

Do not promote Flutter/mobile to gold-ready because a widget renders or a focused test passes. Gold requires end-to-end evidence capture, verification, interpretation, portfolio/report communication, site scoping, offline behavior, and role-safe outputs.

## What Is Already Proven

| Area | Status | Proof |
| --- | --- | --- |
| MiloOS learner support journey | Focused gold-candidate slice passed | `BosLearnerLoopInsightsCard` parses opened, used, explain-back, and pending support journey gaps. |
| MiloOS educator visibility | Focused gold-candidate slice passed | `EducatorLearnerSupportsPage` renders per-learner support provenance and pending explain-back debt from same-site `interactionEvents`. |
| MiloOS site health | Focused gold-candidate slice passed | `SiteDashboardPage` renders same-site support health from `interactionEvents`. |
| MiloOS truth boundary | Passed for focused slice | Support events are framed as support/provenance and follow-up debt, not capability mastery. |
| Guardian portfolio/passport workflows | Passed | `parent_surfaces_workflow_test.dart` proves linked guardian schedule, portfolio, reviewed artifacts, passport export/copy, provenance-gated downloads, and billing unavailable state. |
| Flutter route proof matrix | Passed as classification artifact | `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` maps current Flutter routes, dashboard cards, persistence/service paths, proof files, and remaining blockers. |
| Offline evidence-chain gate | Passed | Focused offline/growth tests prove queued rubric/checkpoint paths preserve server-owned interpretation and block direct capability growth writes. |
| Mobile classroom ergonomics | Passed | Phone-width learner mission submission, educator quick evidence capture, educator support debt, site support health, and dashboard overflow tests pass after responsive fixes. |
| Role permission and site-boundary review | Passed | Flutter boundary tests and Firestore rules integration prove role/site scoping, linked guardian summaries, raw support-event denial, and missing-site support-event exclusion. |
| Focused Flutter/mobile release bundle | Passed | Combined mobile test bundle, full Flutter analyzer, source contract, Firestore rules integration, and diff hygiene passed on 2026-04-30. Current-worktree full `flutter test` now passes 1075 tests and full `flutter analyze` reports no issues. |
| Flutter `/learner/miloos` parity | Passed | Flutter now registers and routes `/learner/miloos` to a learner support/provenance page; the web workflow loader uses the `bosGetLearnerLoopInsights` callable boundary. `test/web-route-parity.test.ts` and `test/workflow-security-contract.test.ts` pass. |
| Local release gate expansion | Passed locally | Root `npm test` passes 524 tests, `npm run build` passes, `npm run typecheck -- --pretty false` passes, `npm run lint` passes, Functions build and Gen 2 verification pass, 37 non-emulator Functions suites pass 184 tests, and `npm run test:integration:evidence-chain` passes 3 emulator-backed tests. |
| Non-deploying release script gate | Passed locally | `./scripts/deploy.sh release-gate` runs root typecheck/lint/Jest, Firestore rules and evidence-chain integration inside one Firestore emulator session, Functions build/verify and split tests, full Flutter analyze/test, and diff hygiene without deploying. |
| Full deploy fail-fast ordering | Hardened | `deploy_all` now runs `ensure_flutter_gate` before live Functions, rules, web, or compliance deploys, so mobile regressions stop the full deploy before any live deploy action. |
| Direct parent growth timeline route proof | Passed | `parent_growth_timeline_page_test.dart` proves `/parent/growth-timeline` renders linked learner growth, educator provenance, and evidence linkage while excluding unlinked learner growth. |
| Mobile HQ authoring persistence | Passed | `hq_authoring_persistence_test.dart` proves mobile HQ creates active-site capability records and canonical `rubricTemplates` records while excluding other-site authoring data. |
| Peer-feedback persistence and role safety | Passed | `peer_feedback_page_test.dart` proves same-site peer submissions only and canonical peer feedback writes; Firestore rules now deny cross-site, missing-site, and wrong-author peer feedback access. |
| Partner deliverable evidence output trust | Passed | `partner_deliverables_page_test.dart`, `partner_contracting_workflow_test.dart`, and Firestore rules prove partner deliverables carry `partnerId`, `siteId`, contract, submitter, and evidence URL provenance, while partners cannot accept their own deliverables. |
| Learner credential evidence provenance | Passed | `learner_credentials_page_test.dart` proves credentials show issuer, source evidence, portfolio, proof bundle, growth, and rubric links while excluding other-site credentials; Firestore rules require educator-issued credentials to carry evidence provenance. |
| Parent active report-share revocation | Passed | `parent_consent_page_test.dart` proves linked guardians see same-site active evidence-bearing report shares for their learner, exclude unrelated, other-site, and revoked shares, revoke an active share through the server-owned `revokeReportShareRequest` callable without deleting the lifecycle record, and keep the share visible/active when revocation fails. |
| Learner today classroom evidence actions | Passed | `learner_today_page_test.dart` proves `/learner/today` renders the current evidence loop, habit action, and active mission progress at 390px classroom width without layout overflow. |
| Learner checkpoint same-site capture | Passed | `checkpoint_submission_page_test.dart` proves `/learner/checkpoints` renders only same-site checkpoint prompts at 390px classroom width and captures learner responses into active-site `checkpointHistory`; `sync_coordinator_test.dart` pins eligible offline checkpoint replay to `processCheckpointMasteryUpdate` instead of direct mastery writes. |
| Learner reflection portfolio provenance | Passed | `reflection_journal_page_test.dart` proves `/learner/reflections` reads only active-site `learnerReflections` and renders mission, session, and portfolio provenance at 390px classroom width without presenting reflection capture as mastery. |
| Learner proof assembly small-screen and offline replay | Passed | `proof_assembly_page_test.dart` proves `/learner/proof-assembly` captures Explain-It-Back, Oral Check, and Mini Rebuild into same-site proof bundles at 390px classroom width; `sync_coordinator_test.dart` proves queued proof bundle create/update replay writes `proofOfLearningBundles` without local mastery writes. |
| Learner portfolio created-item provenance | Passed | `learner_portfolio_honesty_test.dart` proves the live educator mission-review flow creates reviewed portfolio items with site, learner, evidence record, capability, mission attempt, proof bundle, proof status, AI disclosure, verification prompt, and educator-review provenance, then renders that reviewed artifact in `/learner/portfolio`. |
| Analyzer | Passed for current mobile slice | `flutter analyze` is clean after the MiloOS mobile parity changes. |

Focused proof commands that passed:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart
cd apps/empire_flutter/app && flutter analyze
```

## Known Blockers Before Full Flutter/Mobile Gold

1. **Live deploy rehearsal remains before blanket gold**: the route-level evidence blockers from the April 30 matrix are closed, current-worktree local gates pass, and the non-deploying release script gate passes, but an approved live or `CLOUD_RUN_NO_TRAFFIC=1` deploy rehearsal still needs to pass cleanly.

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

Status: completed 2026-04-30.

Primary roles: learner, educator, guardian, site, HQ.

Evidence-chain step: classify every mobile route by evidence function and readiness.

Actions:

- Refresh the Flutter route matrix from current app routes and tests.
- Classify each route as aligned and reusable, reusable with modification, partial, fake/stubbed, misaligned, or missing entirely.
- Separate evidence-chain routes from operational routes.
- Mark exact proof files and missing test gaps per route.

Exit proof:

- `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` lists current mobile evidence-chain routes, owner roles, persistence paths, test files, classifications, and blockers.

### Phase 3 - Prove Offline Evidence Chain Behavior

Status: completed 2026-04-30.

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

Passed result: `flutter test` completed with 46 passing tests, and focused `flutter analyze` reported no issues.

### Phase 4 - Prove Mobile Classroom Ergonomics

Status: completed 2026-04-30.

Primary roles: learner and educator.

Evidence-chain step: live capture and support during class.

Actions:

- Add focused small-screen Flutter widget/golden-style checks for learner evidence submission, educator live evidence capture, educator supports, and site dashboard support health.
- Verify touch targets, text wrapping, loading/empty/error states, and no horizontal overflow.
- Confirm teacher live actions can be completed quickly and do not require after-class cleanup.

Exit proof:

- Focused mobile viewport tests cover learner mission evidence submission, educator quick evidence capture, educator support debt, site support health, and dashboard overflow behavior.

### Phase 5 - Prove Role Permission And Site Boundaries

Status: completed 2026-04-30.

Primary roles: learner, educator, guardian, site.

Evidence-chain step: protect evidence and support provenance at role/site boundaries.

Actions:

- Bundle Flutter route/service tests for learner-owned evidence, educator same-site data, site-scoped support health, and linked guardian summaries.
- Add explicit missing-site support-event coverage to mobile support-health tests.
- Run Firestore rules integration as the source of truth for direct collection access.

Exit proof:

- Focused Flutter boundary tests pass, missing-site support events are ignored by mobile surfaces, and Firestore rules integration denies cross-site and raw parent support-event reads.

### Phase 6 - Bundle Full Flutter/Mobile Gold Gate

Status: completed 2026-04-30 as a focused release-bundle gate for validated mobile slices. This does not erase route-level partials from the matrix.

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

Passed result: the expanded focused bundle ran 133 Flutter tests, full `flutter analyze` reported no issues, the source contract passed 187 Jest tests, Firestore rules integration now passes 118 tests after peer-feedback, partner deliverable, and credential provenance rule coverage, and `git diff --check` passed.

## Gold Stop Conditions

Do not call Flutter/mobile gold-ready if any of these are true:

- `parent_surfaces_workflow_test.dart` fails.
- Any mobile workflow writes or implies capability mastery from support, completion, attendance, XP, or report export alone.
- Offline queue can directly write `capabilityMastery` or `capabilityGrowthEvents` without the server-owned interpretation path.
- Guardian exports/share actions can succeed without evidence provenance when provenance is required.
- A route proof matrix item is marked fake/stubbed, partial, or missing for a core evidence-chain workflow.
- The approved live or no-traffic deploy rehearsal fails, has not been run, or cannot be reproduced from the current worktree.
- Analyzer or diff hygiene fails.
- The final command bundle cannot be reproduced from a clean checkout.

## Next Slice

The next highest-risk break is **approved deploy rehearsal reproducibility**. The latest failed `./scripts/deploy.sh all` stopped at Flutter tests; current-worktree full `flutter test` now passes 1075 tests, full app-scoped `flutter analyze` is clean, root `npm test` passes 524 tests, production `npm run build` passes, Firestore rules pass 118 tests, functions gates pass when emulator-backed tests use the required emulator wrapper, focused parent consent/report-share revocation tests pass, and `./scripts/deploy.sh release-gate` now passes without deploying. The full `all` target now runs the Flutter gate before any live deploy action. Run an approved live or `CLOUD_RUN_NO_TRAFFIC=1` deploy rehearsal before making any blanket mobile gold claim.
