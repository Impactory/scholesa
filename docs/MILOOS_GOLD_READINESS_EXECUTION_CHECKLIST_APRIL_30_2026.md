# MiloOS Gold Readiness Execution Checklist - April 30, 2026

## How To Use This Checklist

Work from top to bottom. Do not mark a milestone complete because UI exists. Mark it complete only when the listed proof commands pass and `AUDIT_TODO_APRIL_2026.md` is updated.

Current verdict remains: **beta-ready, not gold-ready**.

## Milestone 0 - Preserve The Truth Boundary

- [ ] Confirm every changed MiloOS surface says support/provenance, not mastery.
- [ ] Confirm no support event writes `capabilityMastery`.
- [ ] Confirm no support event writes `capabilityGrowthEvents`.
- [ ] Confirm explain-back status is verification debt only.
- [ ] Confirm `applyRubricToEvidence` and `processCheckpointMasteryUpdate` remain the growth paths.

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

Completed 2026-04-30: `scripts/import_synthetic_data.js` now always adds `syntheticMiloOSGoldStates/latest` with five canonical learner states for MiloOS demos, UAT, rules tests, and regression checks. The states are available in `starter`, `full`, and `all` seed modes; `test/synthetic_miloos_gold_states.test.js` proves they do not seed support-only `capabilityMastery` or `capabilityGrowthEvents` writes.

Candidate files:

- `firestore_seed.ts`
- `scripts/import_synthetic_data.js`
- existing synthetic data fixture packs under `docs/` or `scripts/`

Proof commands:

```bash
npm run seed:synthetic-data:dry-run
npm run test:integration:rules
npm run test:integration:evidence-chain
```

## Milestone 8 - Flutter Scope Decision

- [ ] Decide whether gold scope includes Flutter MiloOS role parity.
- [ ] If yes, add Flutter learner support provenance tests beyond existing card coverage.
- [ ] If yes, add Flutter educator/guardian/site support provenance surfaces or explicitly planned equivalents.
- [ ] If no, document that web MiloOS is gold-candidate while Flutter MiloOS remains beta.

Proof commands if Flutter is in scope:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart
cd apps/empire_flutter/app && flutter analyze
```

## Milestone 9 - Gold Release Bundle

- [ ] Run typecheck.
- [ ] Run lint.
- [ ] Run focused web source/component tests.
- [ ] Run focused Functions tests.
- [ ] Run Functions build.
- [ ] Run Firestore rules integration.
- [ ] Run evidence-chain emulator integration.
- [ ] Run MiloOS browser E2E suite.
- [ ] Run MiloOS WCAG E2E suite.
- [ ] Run Flutter tests/analyzer if in scope.
- [ ] Run `git diff --check`.
- [ ] Update `AUDIT_TODO_APRIL_2026.md` with exact commands and verdict.

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
