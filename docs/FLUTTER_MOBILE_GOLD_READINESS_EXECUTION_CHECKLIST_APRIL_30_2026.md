# Flutter/Mobile Gold Readiness Execution Checklist - April 30, 2026

Current verdict: **the focused Flutter/mobile release bundle passed, and the Cloud Run web no-traffic rehearsal is now complete; this is still not a blanket platform gold-ready certification**.

Latest release-gate status: `./scripts/deploy.sh release-gate` passes from the current worktree without deploying. Emulator-backed rules and evidence-chain tests run inside one Firestore emulator session, and `./scripts/deploy.sh all` now runs the Flutter gate before any live deploy action. On 2026-05-03, the approved no-traffic Cloud Run web rehearsal also passed with `CLOUD_RUN_NO_TRAFFIC=1 IMAGE_TAG=rehearsal-20260503-081143 ./scripts/deploy.sh web` against project `studio-3328096157-e3f79`: primary web created ready no-traffic revision `scholesa-web-00040-qpw`, Flutter web created ready no-traffic revision `empire-web-00072-fw6`, and traffic remained pinned to the prior serving revisions.

## Milestone 0 - Scope And Truth Boundary

- [x] Record that focused MiloOS mobile parity passed.
- [x] Record that full Flutter/mobile is not gold-ready yet.
- [x] Preserve support/provenance as support debt, not capability mastery.
- [x] Name the first blocking workflow: guardian/report workflow instability.

Done when:

- The plan states the exact scoped pass and the remaining beta surface.
- No document implies full Flutter/mobile gold readiness from the MiloOS slice alone.

## Milestone 1 - Guardian And Report Workflow Stabilization

- [x] Run `parent_surfaces_workflow_test.dart` alone and capture all current failures.
- [x] Fix Firebase app/test harness setup for live learner/educator review paths without replacing the workflow with fake artifacts.
- [x] Fix parent portfolio summary download expectations without weakening provenance checks.
- [x] Fix parent portfolio clipboard fallback expectations without weakening provenance checks.
- [x] Fix child passport export/copy expectations without weakening provenance checks.
- [x] Confirm reviewed artifacts and passport claims are created through live learner and educator workflow paths.
- [x] Confirm no raw `interactionEvents` parent read path is introduced.

Completed 2026-04-30: the broad parent surface workflow suite passes. The fix keeps the live learner submission -> educator review -> reviewed portfolio/passport path intact, preserves report provenance enforcement, recognizes verification criteria as a valid verification signal, and strengthens test seed data with production-shaped evidence/proof/rubric/reviewer provenance instead of weakening export assertions.

Proof command:

```bash
cd apps/empire_flutter/app && flutter test test/parent_surfaces_workflow_test.dart
```

## Milestone 2 - Current Flutter Route Proof Matrix

- [x] Inventory current Flutter route registry and role dashboards.
- [x] Mark evidence-chain mobile routes by role: learner, educator, guardian, site, HQ.
- [x] Classify each as aligned and reusable, reusable with modification, partial, fake/stubbed, misaligned, or missing entirely.
- [x] Link each route to persistence/service paths and test files.
- [x] Identify routes that still depend on placeholders, seed-only data, or fake actions.
- [x] Update or replace stale March route matrix claims with April 30 status.

Completed 2026-04-30: `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` now classifies current Flutter route registry and role-dashboard surfaces by evidence function, persistence/service path, proof file, and blocker. The matrix records that several core paths are aligned, while offline replay, small-screen classroom ergonomics, direct parent growth timeline proof, mobile HQ authoring depth, peer feedback, partner deliverable evidence trust, and learner credential provenance required targeted follow-up before any blanket gold claim.

Proof artifact:

- `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`

## Milestone 3 - Offline Evidence Chain Gate

- [x] Run focused offline/growth ownership tests.
- [x] Confirm offline rubric replay goes through `applyRubricToEvidence`.
- [x] Confirm offline checkpoint replay goes through `processCheckpointMasteryUpdate` when eligible.
- [x] Confirm direct mobile writes to `capabilityMastery` and `capabilityGrowthEvents` fail closed.
- [x] Confirm offline support/MiloOS events remain support/provenance only.
- [x] Confirm report delivery audit/share-request retries are durable and do not export misleading reports.

Completed 2026-04-30: the focused offline evidence-chain suite passed as a bundle with 46 tests. The focused analyzer also passed on the growth engine, Firestore service, sync coordinator, mission service, and related offline tests. This proves the current offline gate keeps growth interpretation server-owned, blocks direct queued capability growth writes, and keeps support/provenance separate from mastery.

Proof commands:

```bash
cd apps/empire_flutter/app && flutter test test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart
cd apps/empire_flutter/app && flutter analyze lib/modules/missions/mission_service.dart lib/services/capability_growth_engine.dart lib/services/firestore_service.dart lib/offline/sync_coordinator.dart test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart
```

## Milestone 4 - Mobile Classroom Ergonomics

- [x] Add or identify focused small-screen tests for learner evidence submission.
- [x] Add or identify focused small-screen tests for educator live evidence capture.
- [x] Add or identify focused small-screen tests for educator learner supports and MiloOS debt.
- [x] Add or identify focused small-screen tests for site support health.
- [x] Verify loading, empty, success, and error states do not overflow or hide primary actions.
- [x] Verify teacher live-class actions are fast and do not require cleanup after class.

Completed 2026-04-30: the mobile classroom slice now runs learner mission evidence submission and educator quick evidence capture at phone width, plus educator support, site support health, and dashboard mobile overflow coverage. The pass fixed real phone-width overflows in learner mission cards/proof controls and educator live studio chips/dropdowns, while keeping evidence persistence paths intact.

Proof commands:

```bash
cd apps/empire_flutter/app && flutter test test/missions_page_test.dart test/educator_sessions_page_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart test/dashboard_cta_regression_test.dart
cd apps/empire_flutter/app && flutter analyze lib/modules/missions/missions_page.dart lib/modules/educator/educator_sessions_page.dart test/missions_page_test.dart test/educator_sessions_page_test.dart test/dashboard_cta_regression_test.dart
```

## Milestone 5 - Role Permission And Site Boundary Review

- [x] Confirm mobile learner surfaces only request learner-owned evidence/provenance.
- [x] Confirm mobile educator surfaces query same-site learner/evidence/support data only.
- [x] Confirm mobile site surfaces query same-site aggregates only.
- [x] Confirm mobile parent/guardian surfaces receive linked learner summaries and do not introduce raw support-event reads.
- [x] Confirm missing `siteId` support/evidence records do not become visible through mobile service fallbacks.

Completed 2026-04-30: the mobile boundary bundle passed with 50 Flutter tests, and Firestore rules integration now passes with 116 tests after peer-feedback site/author and partner deliverable ownership coverage were added. The pass covers learner-owned evidence routes, educator active-site learners/supports, site-scoped support health, linked guardian summaries, direct parent denial for raw `interactionEvents`, and explicit missing-site support-event exclusion in mobile support-health surfaces.

Proof expectation:

- Existing Firestore rules integration remains the source of truth for enforcement.
- Flutter service/widget tests must not assume cross-site data is readable.

Proof commands:

```bash
cd apps/empire_flutter/app && flutter test test/evidence_chain_routes_test.dart test/evidence_chain_firestore_service_test.dart test/educator_service_site_scope_test.dart test/educator_learner_supports_route_gate_test.dart test/site_dashboard_page_test.dart test/parent_surfaces_workflow_test.dart test/role_gate_honesty_test.dart
cd apps/empire_flutter/app && flutter analyze test/site_dashboard_page_test.dart test/educator_learner_supports_page_test.dart
npm run test:integration:rules
```

## Milestone 6 - Full Flutter/Mobile Release Bundle

- [x] Run MiloOS focused mobile parity tests.
- [x] Run parent/guardian workflow tests.
- [x] Run offline evidence chain tests.
- [x] Run route proof matrix/source contract tests once added.
- [x] Run full `flutter analyze`.
- [x] Run `git diff --check`.
- [x] Update `AUDIT_TODO_APRIL_2026.md` with exact command output and honest verdict only after all gates pass.

Completed 2026-04-30: the focused Flutter/mobile release bundle passed. The bundle combined MiloOS learner/educator/site support provenance, guardian portfolio/passport workflows, offline evidence-chain ownership, phone-width classroom evidence workflows, role/site-boundary checks, the route/source contract, Firestore rules integration, full Flutter analyzer, and diff hygiene. This is a release-bundle pass for the validated mobile slices, not a blanket full-app gold-ready claim while route-level partials remain.

Proof commands:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart test/parent_surfaces_workflow_test.dart test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart test/missions_page_test.dart test/educator_sessions_page_test.dart test/dashboard_cta_regression_test.dart test/evidence_chain_routes_test.dart test/educator_service_site_scope_test.dart test/educator_learner_supports_route_gate_test.dart test/role_gate_honesty_test.dart
cd apps/empire_flutter/app && flutter analyze
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
npm run test:integration:rules
cd /Users/impactory/Documents/GitHub/scholesa && git diff --check
```

## Milestone 7 - Final Signoff Notes

When the full mobile gate passes, the signoff must state:

- Which mobile roles are covered.
- Which evidence is captured, verified, interpreted, and communicated.
- Which workflows work offline and how queued operations replay.
- Which paths create capability growth and which paths only create support/provenance.
- How portfolio/passport/family outputs prove provenance.
- Which tests and commands passed.
- What remains beta.

No final signoff may describe Flutter/mobile as gold-ready while any milestone above is incomplete.

Current signoff boundary after Milestone 6 plus direct route proofs: the validated mobile release bundle covers learner evidence submission, educator evidence/support workflows, guardian portfolio/passport communication, guardian active report-share visibility and revocation from the parent consent surface, direct parent growth-timeline communication, mobile HQ capability/rubric authoring persistence, learner peer-feedback persistence and role-safety, partner deliverable evidence output trust, learner credential evidence provenance, Flutter `/learner/miloos` route parity with callable-backed web workflow loading, site support health, offline evidence replay ownership, role/site boundaries, source-contract wiring, and analyzer/diff hygiene. The current-worktree full Flutter gate now passes with 1075 tests and full app-scoped `flutter analyze` clean; root `npm test`, production `npm run build`, Firestore rules plus evidence-chain integration in one emulator session, Functions build/verify, split Functions tests, the non-deploying `./scripts/deploy.sh release-gate`, and the 2026-05-03 no-traffic Cloud Run web rehearsal also pass. Remaining beta scope is outside this validated release-bundle and deploy-rehearsal boundary; this record does not certify every platform workflow as blanket gold-ready.
