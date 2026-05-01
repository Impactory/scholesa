# Flutter/Mobile Gold Readiness Execution Checklist - April 30, 2026

Current verdict: **focused MiloOS Flutter/mobile support-provenance gate passed; full Flutter/mobile app remains beta-ready, not gold-ready**.

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

- [ ] Inventory current Flutter route registry and role dashboards.
- [ ] Mark evidence-chain mobile routes by role: learner, educator, guardian, site, HQ.
- [ ] Classify each as aligned and reusable, reusable with modification, partial, fake/stubbed, misaligned, or missing entirely.
- [ ] Link each route to persistence/service paths and test files.
- [ ] Identify routes that still depend on placeholders, seed-only data, or fake actions.
- [ ] Update or replace stale March route matrix claims with April 30 status.

Proof artifact:

- `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`

## Milestone 3 - Offline Evidence Chain Gate

- [ ] Run focused offline/growth ownership tests.
- [ ] Confirm offline rubric replay goes through `applyRubricToEvidence`.
- [ ] Confirm offline checkpoint replay goes through `processCheckpointMasteryUpdate` when eligible.
- [ ] Confirm direct mobile writes to `capabilityMastery` and `capabilityGrowthEvents` fail closed.
- [ ] Confirm offline support/MiloOS events remain support/provenance only.
- [ ] Confirm report delivery audit/share-request retries are durable and do not export misleading reports.

Proof commands:

```bash
cd apps/empire_flutter/app && flutter test test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart
cd apps/empire_flutter/app && flutter analyze lib/modules/missions/mission_service.dart lib/services/capability_growth_engine.dart lib/services/firestore_service.dart lib/offline/sync_coordinator.dart test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart
```

## Milestone 4 - Mobile Classroom Ergonomics

- [ ] Add or identify focused small-screen tests for learner evidence submission.
- [ ] Add or identify focused small-screen tests for educator live evidence capture.
- [ ] Add or identify focused small-screen tests for educator learner supports and MiloOS debt.
- [ ] Add or identify focused small-screen tests for site support health.
- [ ] Verify loading, empty, success, and error states do not overflow or hide primary actions.
- [ ] Verify teacher live-class actions are fast and do not require cleanup after class.

Proof command placeholder:

```bash
cd apps/empire_flutter/app && flutter test <mobile-classroom-focused-tests>
```

## Milestone 5 - Role Permission And Site Boundary Review

- [ ] Confirm mobile learner surfaces only request learner-owned evidence/provenance.
- [ ] Confirm mobile educator surfaces query same-site learner/evidence/support data only.
- [ ] Confirm mobile site surfaces query same-site aggregates only.
- [ ] Confirm mobile parent/guardian surfaces receive linked learner summaries and do not introduce raw support-event reads.
- [ ] Confirm missing `siteId` support/evidence records do not become visible through mobile service fallbacks.

Proof expectation:

- Existing Firestore rules integration remains the source of truth for enforcement.
- Flutter service/widget tests must not assume cross-site data is readable.

## Milestone 6 - Full Flutter/Mobile Release Bundle

- [ ] Run MiloOS focused mobile parity tests.
- [ ] Run parent/guardian workflow tests.
- [ ] Run offline evidence chain tests.
- [ ] Run route proof matrix/source contract tests once added.
- [ ] Run full `flutter analyze`.
- [ ] Run `git diff --check`.
- [ ] Update `AUDIT_TODO_APRIL_2026.md` with exact command output and honest verdict only after all gates pass.

Current minimum bundle:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart test/parent_surfaces_workflow_test.dart
cd apps/empire_flutter/app && flutter analyze
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
