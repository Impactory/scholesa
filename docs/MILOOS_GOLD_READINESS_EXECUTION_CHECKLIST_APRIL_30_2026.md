# MiloOS Gold Readiness Execution Checklist - April 30, 2026

## How To Use This Checklist

Work from top to bottom. Do not mark a milestone complete because UI exists. Mark it complete only when the listed proof commands pass and `AUDIT_TODO_APRIL_2026.md` is updated.

Current verdict: **MiloOS web plus focused Flutter/mobile support-provenance gate passed; broader Scholesa remains beta-ready, not platform gold-ready**.

## Milestone 0 - Preserve The Truth Boundary

- [x] Confirm every changed MiloOS surface says support/provenance, not mastery.
- [x] Confirm no support event writes `capabilityMastery`.
- [x] Confirm no support event writes `capabilityGrowthEvents`.
- [x] Confirm explain-back status is verification debt only.
- [x] Confirm `applyRubricToEvidence` and `processCheckpointMasteryUpdate` remain the growth paths.

Completed 2026-04-30: source contracts, Functions honesty tests, browser E2Es, and evidence-chain emulator tests verify MiloOS support remains provenance and verification debt only. Growth remains through rubric/checkpoint paths.

Proof commands:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts
npm --prefix functions test -- aiHelpWording.test.ts bosRuntimeHonesty.test.ts
```

## Milestone 1 - Clean Browser Warning Baseline

- [x] Fix PageTransition reduced-motion/hydration warnings seen during protected MiloOS Playwright runs.
- [x] Re-run focused MiloOS browser tests and verify no release-critical console warning remains.
- [x] Keep reduced-motion behavior accessible.
- [x] Do not disable animations globally just to silence tests unless product accepts that behavior.

Completed 2026-04-30: `PageTransition` now renders stable plain markup until mount and whenever the browser prefers reduced motion, using native `matchMedia` instead of Framer's reduced-motion hook. This removes the protected-route hydration mismatch and reduced-motion console warning without disabling animations for users who have not requested reduced motion.

Candidate files:

- `src/components/layout/PageTransition.tsx`
- `test/e2e/accessibility.e2e.spec.ts`
- `test/e2e/miloos-accessibility.e2e.spec.ts`

Proof commands:

```bash
npx playwright test --config playwright.config.ts test/e2e/miloos-accessibility.e2e.spec.ts
npx playwright test --config playwright.config.ts test/e2e/miloos-learner-loop.e2e.spec.ts test/e2e/miloos-educator-support-provenance.e2e.spec.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts test/e2e/miloos-site-support-health.e2e.spec.ts
```

## Milestone 2 - Parent Raw-Event Denial

- [x] Add Firestore rules tests proving linked parents cannot read raw `interactionEvents`.
- [x] Add Firestore rules tests proving unlinked parents cannot read raw `interactionEvents`.
- [x] Keep parent support provenance available only through `getParentDashboardBundle` or approved server bundle output.
- [x] Confirm guardian browser test still passes.

Completed 2026-04-30: Firestore rules integration now proves both linked and unlinked parents cannot read raw MiloOS `interactionEvents` documents or same-site queries. The evidence-chain emulator still proves `getParentDashboardBundle` returns linked learner `miloosSupportSummary`, and the guardian browser proof still passes.

Candidate files:

- `firestore.rules`
- `test/firestore-rules.test.js`
- `functions/src/evidenceChainEmulator.test.ts`

Proof commands:

```bash
npm run test:integration:rules
npm run test:integration:evidence-chain
npx playwright test --config playwright.config.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts
```

## Milestone 3 - Cross-Role Golden Path Browser Test

- [x] Create `test/e2e/miloos-cross-role-golden-path.e2e.spec.ts`.
- [x] Start from a clean E2E state.
- [x] Sign in learner and request MiloOS help.
- [x] Assert transcript appears.
- [x] Assert pending explain-back appears for learner.
- [x] Sign in educator and assert pending explain-back debt appears for same-site learner.
- [x] Sign in learner and submit explain-back.
- [x] Sign in guardian and assert support provenance updates.
- [x] Sign in site admin and assert aggregate support health updates.
- [x] Assert `capabilityMastery` remains empty for the support-only journey.

Completed 2026-04-30: the cross-role browser proof now drives learner help, educator pending-debt visibility, returned learner explain-back completion, guardian support provenance, and site support health in one clean E2E journey. The implementation also added persisted pending support interaction metadata so a learner can return to `/learner/miloos` and complete a prior pending explain-back instead of losing the recovery path after navigation.

Proof command:

```bash
npx playwright test --config playwright.config.ts test/e2e/miloos-cross-role-golden-path.e2e.spec.ts
```

## Milestone 4 - Mobile Classroom Proof

- [x] Add phone-width Playwright coverage for `/en/learner/miloos`.
- [x] Assert prompt input, transcript, explain-back input, and counters do not overlap.
- [x] Add phone-width Playwright coverage for `/en/educator/learners`.
- [x] Assert educator can scan pending MiloOS follow-up debt without horizontal overflow.
- [x] Add phone-width Playwright coverage for `/en/site/dashboard` support health.
- [x] Assert support count tiles remain readable.

Completed 2026-04-30: `test/e2e/miloos-mobile-classroom.e2e.spec.ts` now proves the learner MiloOS support loop, educator pending follow-up card, and site support health tiles remain usable on a 390px phone viewport without horizontal overflow.

Suggested command:

```bash
npx playwright test --config playwright.config.ts test/e2e/miloos-mobile-classroom.e2e.spec.ts
```

## Milestone 5 - Keyboard And Focus Proof

- [x] Tab to the MiloOS question input.
- [x] Submit a question without mouse input.
- [x] Tab to transcript/explain-back area.
- [x] Submit explain-back without mouse input.
- [x] Verify focus is not lost after submit.
- [x] Verify screen-reader names for submit controls are clear.

Completed 2026-04-30: `test/e2e/miloos-keyboard.e2e.spec.ts` now proves a learner can complete the MiloOS support loop with keyboard-only Tab/Enter flow. `AICoachScreen` now moves focus to the explain-back input after a response and to the live status message after explain-back submission.

Candidate files:

- `src/components/sdt/AICoachScreen.tsx`
- `src/components/sdt/AICoachPopup.tsx`
- `test/e2e/miloos-keyboard.e2e.spec.ts`

Proof command:

```bash
npx playwright test --config playwright.config.ts test/e2e/miloos-keyboard.e2e.spec.ts
```

## Milestone 6 - Observability And Traceability

- [x] Confirm `ai_help_opened` has learner, site, interaction, and timestamp fields.
- [x] Confirm `ai_help_used` links to the support turn.
- [x] Confirm `ai_coach_response` links to the support turn.
- [x] Confirm `explain_it_back_submitted` links to the support turn.
- [x] Confirm pending explain-back is derivable from persisted events.
- [x] Confirm telemetry does not emit mastery-like signals for support-only journeys.
- [x] Add an operator-readable way to locate stuck pending explain-back debt.

Completed 2026-04-30: `ai_help_opened` now self-stamps `traceId` and `payload.aiHelpOpenedEventId`; `ai_coach_response` now links to the same opened support turn. The emulator-backed evidence-chain test asserts opened/used/response/explain-back linkage, timestamps, pending explain-back derivation, and no support-only mastery writes. Site implementation health remains the operator-readable surface for stuck pending explain-back debt.

Candidate files:

- `functions/src/index.ts`
- `functions/src/bosRuntime.ts`
- `src/lib/miloos/learnerLoopInsights.ts`
- `src/lib/telemetry/telemetryService.ts`
- `src/features/workflows/renderers/SiteImplementationHealthRenderer.tsx`

Proof commands:

```bash
npm --prefix functions test -- aiHelpWording.test.ts bosRuntimeHonesty.test.ts
npm run test:integration:evidence-chain
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
```

## Milestone 7 - Canonical Synthetic States

- [x] Add canonical seed data for no-support learner.
- [x] Add canonical seed data for pending explain-back learner.
- [x] Add canonical seed data for support-current learner.
- [x] Add canonical seed data for cross-site event denial.
- [x] Add canonical seed data for missing-site event denial.
- [x] Document which seed mode supports MiloOS demos/UAT.
- [x] Prove Flutter/mobile support surfaces consume the canonical importer output.
- [x] Prove web support surfaces consume canonical importer-derived MiloOS events.

Completed 2026-04-30: `scripts/import_synthetic_data.js` now always adds `syntheticMiloOSGoldStates/latest` with five canonical learner states for MiloOS demos, UAT, rules tests, and regression checks. The states are available in `starter`, `full`, and `all` seed modes; `test/synthetic_miloos_gold_states.test.js` proves they do not seed support-only `capabilityMastery` or `capabilityGrowthEvents` writes.

Completed 2026-05-01: `synthetic_miloos_gold_states_mobile_test.dart` now loads the actual `buildImportBundle({ mode: 'starter' })` output from `scripts/import_synthetic_data.js`, hydrates Flutter fake Firestore with the canonical `syntheticMiloOSGoldStates/latest` users, enrollments, sessions, and `interactionEvents`, and proves educator support provenance plus site support health consume those records without local mastery or growth writes. The synthetic educator and site-lead users now carry `activeSiteId` so current mobile AppState/site-context consumers can use the pack directly.

Completed 2026-05-01: web MiloOS Playwright proofs now derive support events through `test/e2e/miloos-synthetic-gold-fixture.ts`, which calls the same `buildImportBundle({ mode: 'starter' })` synthetic importer and maps the canonical `syntheticMiloOSGoldStates/latest` support turns into the existing browser E2E users. Educator, guardian, site, WCAG, and phone-width classroom proofs now consume importer-derived pending, current, cross-site, and missing-site states instead of local ad hoc support arrays.

Updated 2026-05-01: the web browser E2E harness now also stores the mapped `syntheticMiloOSGoldStates/latest` manifest via `seedSyntheticMiloOSGoldStates`, including the importer source counts for 5 learner states and 13 interaction events, so current web tests can assert the canonical state record is present alongside the importer-derived support events. This closes the event-only fixture gap between web and Flutter fake Firestore.

Completed 2026-05-01: learner-facing web and Flutter support summaries now expose MiloOS coach responses as support provenance alongside opened, used, explained, and pending counts. This keeps learner usability consistent with site support-health reporting while preserving the boundary that coach responses are not capability mastery or growth.

Candidate files:

- `firestore_seed.ts`
- `scripts/import_synthetic_data.js`
- existing synthetic data fixture packs under `docs/` or `scripts/`

Proof commands:

```bash
npm run seed:synthetic-data:dry-run
npm run test:integration:rules
npm run test:integration:evidence-chain
cd apps/empire_flutter/app && flutter test test/synthetic_miloos_gold_states_mobile_test.dart
npx playwright test test/e2e/miloos-educator-support-provenance.e2e.spec.ts test/e2e/miloos-site-support-health.e2e.spec.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts test/e2e/miloos-mobile-classroom.e2e.spec.ts test/e2e/miloos-accessibility.e2e.spec.ts
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart
```

## Milestone 8 - Flutter Scope Decision

- [x] Decide whether gold scope includes Flutter MiloOS role parity.
- [x] Add focused Flutter learner support provenance test coverage through `BosLearnerLoopInsightsCard`.
- [x] Add Flutter educator per-learner support provenance and pending explain-back debt from site-scoped `interactionEvents`.
- [x] Add Flutter Admin-School site support health aggregation from same-site `interactionEvents`.
- [x] Document that the focused Flutter/mobile MiloOS support-provenance gate passed while broader Flutter workflows remain beta.

Completed 2026-04-30: Flutter MiloOS role parity is now in scope for the focused support-provenance gate. Learner-loop support cards, educator learner-support provenance, and site support health are tested with fake Firestore and analyzer-clean Dart. This does not certify unrelated Flutter parent portfolio/export workflows or the whole Flutter app as gold-ready.

Updated 2026-05-01: the Flutter support-provenance gate now also consumes canonical MiloOS synthetic importer output through `synthetic_miloos_gold_states_mobile_test.dart`; this prevents the mobile tests from drifting into ad hoc `site-1` seed data while the JS synthetic pack evolves.

Proof commands:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart test/synthetic_miloos_gold_states_mobile_test.dart
cd apps/empire_flutter/app && flutter analyze
```

## Milestone 9 - Gold Release Bundle

- [x] Run typecheck.
- [x] Run lint.
- [x] Run focused web source/component tests.
- [x] Run focused Functions tests.
- [x] Run Functions build.
- [x] Run Firestore rules integration.
- [x] Run evidence-chain emulator integration.
- [x] Run MiloOS browser E2E suite.
- [x] Run MiloOS WCAG E2E suite.
- [x] Run Flutter tests/analyzer if in scope.
- [x] Run `git diff --check`.
- [x] Update `AUDIT_TODO_APRIL_2026.md` with exact commands and verdict.

Completed 2026-04-30: the web MiloOS gold-candidate release bundle passed, and the focused Flutter/mobile MiloOS support-provenance gate passed with learner-loop, educator, and site widget tests plus `flutter analyze`.

Minimum command bundle:

```bash
npm run typecheck -- --pretty false
npm run lint
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts src/__tests__/miloos-ai-coach-screen.test.tsx src/__tests__/miloos-learner-support-snapshot.test.tsx src/__tests__/educator-ai-audit-miloos-provenance.test.tsx
npm --prefix functions test -- aiHelpWording.test.ts bosRuntimeHonesty.test.ts
npm --prefix functions run build
npm run test:integration:rules
npm run test:integration:evidence-chain
npx playwright test --config playwright.config.ts test/e2e/miloos-learner-loop.e2e.spec.ts test/e2e/miloos-educator-support-provenance.e2e.spec.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts test/e2e/miloos-site-support-health.e2e.spec.ts test/e2e/miloos-accessibility.e2e.spec.ts
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart
cd apps/empire_flutter/app && flutter analyze
./scripts/deploy.sh release-gate
git diff --check
```

## Required Final Signoff Notes

When all milestones pass, the gold signoff must state:

- What support evidence MiloOS creates.
- Who can observe it.
- How authenticity is verified.
- Why support is not mastery.
- How educators act on pending explain-back debt.
- How guardians see support provenance.
- How site leaders see support health.
- What remains beta, especially Flutter if not included.

Final signoff is recorded in `docs/MILOOS_GOLD_READINESS_PLAN_APRIL_30_2026.md` and `AUDIT_TODO_APRIL_2026.md`.
