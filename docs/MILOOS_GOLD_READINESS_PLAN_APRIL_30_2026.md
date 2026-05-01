# MiloOS Gold Readiness Plan - April 30, 2026

## Status

**Current verdict: web MiloOS gold-candidate gate passed; broader Scholesa remains beta-ready, not platform gold-ready.**

MiloOS web is materially stronger: learner support, explain-back, educator visibility, guardian provenance, and Admin-School support health now have real persistence paths, role-scoped visibility, protected-route browser proof, focused accessibility coverage, canonical synthetic states, and release-bundle proof. This is a scoped web MiloOS gold-candidate signoff, not a blanket Scholesa or Flutter gold claim.

MiloOS can be called gold-ready only when the support loop is verified end to end across real services, role surfaces, permissions, observability, mobile classroom constraints, and release operations without presenting support activity as capability mastery.

## Product Truth Boundary

MiloOS is learner support and verification provenance. It is not a mastery engine.

Gold readiness requires these boundaries to stay true everywhere:

- `ai_help_opened`, `ai_help_used`, `ai_coach_response`, and `explain_it_back_submitted` are support/provenance events.
- MiloOS support events must not write `capabilityMastery`.
- MiloOS support events must not write `capabilityGrowthEvents`.
- Explain-back status can identify verification debt, but it cannot become mastery by itself.
- Educator rubric application or checkpoint mastery processing remains the growth interpretation path.
- Families and site leaders must see support provenance as support health, not learner capability claims.

## Current Verified Surface

| Surface | Current proof | Gold state |
| --- | --- | --- |
| Learner `/learner/miloos` | Browser E2E proves support request, transcript, pending explain-back, returned pending explain-back completion, refreshed counters, phone-width usability, keyboard-only support completion, focus preservation, traceable support-turn events, and no `capabilityMastery` write. | Web gold-candidate gate passed. |
| Educator `/educator/learners` | Browser E2E proves same-site MiloOS support provenance and pending follow-up debt, including cross-role and phone-width paths. | Web gold-candidate gate passed for support visibility and follow-up debt. |
| Guardian `/parent/summary` | Browser E2E proves linked guardian sees same-site support provenance and non-mastery language, including after learner explain-back completion. | Web gold-candidate gate passed for support provenance. |
| Admin-School `/site/dashboard` | Browser E2E proves site-wide same-site support health aggregation, including after cross-role support completion and on phone-width viewport. | Web gold-candidate gate passed for support health visibility. |
| Accessibility | Focused Axe WCAG 2.2 AA checks pass on protected MiloOS support regions, PageTransition reduced-motion/hydration warnings are cleaned up, and keyboard-only support completion is verified. | Scoped web gold-candidate gate passed. |
| Firestore rules | Educator and site-admin same-site `interactionEvents` reads are tested; other-site/missing-site denied; linked and unlinked parent raw-event reads and queries are denied. | Scoped web gold-candidate gate passed. |
| Functions/emulator | `genAiCoach` -> `submitExplainBack` -> `bosGetLearnerLoopInsights` path is emulator-tested and no mastery write is asserted. | Scoped web gold-candidate gate passed. |
| Flutter | Learner-loop cards show support gaps. | Explicitly beta and out of current web-only gold-candidate scope. |

## Gold Definition

MiloOS is gold-ready only when all gates below pass.

### Gate 1 - Support Loop Integrity

The learner can open MiloOS, ask for help, receive a readable transcript, submit an explain-back, and see updated support status.

Required proof:

- Real callable/emulator path uses `genAiCoach`, `submitExplainBack`, and `bosGetLearnerLoopInsights`.
- Browser learner path passes on desktop and mobile viewport.
- Audio failure fallback still leaves transcript and explain-back available.
- No support action writes mastery or growth docs.

### Gate 2 - Cross-Role Provenance Visibility

The same support journey must appear correctly for educator, guardian, and Admin-School roles.

Required proof:

- Educator sees pending explain-back debt for same-site learners only.
- Guardian sees linked learner support provenance only through the parent bundle/callable, not raw event reads.
- Site admin sees aggregate support health for same-site learners only.
- HQ/network visibility is either implemented with explicit rules and UI or explicitly excluded from gold scope.

### Gate 3 - Permissions And Site Boundary

MiloOS events must not leak across sites or roles.

Required proof:

- Learner can read only their own learner-loop insight path.
- Educator can read only same-site `interactionEvents`.
- Site admin can read only same-site `interactionEvents`.
- Parent cannot read raw `interactionEvents` directly.
- Parent can receive only linked learner support summaries through callable output.
- Missing `siteId` events are denied to educator/site reads.

### Gate 4 - Accessibility And Mobile Classroom Use

MiloOS must be usable in classroom conditions.

Required proof:

- WCAG 2.2 AA automation passes for full MiloOS pages or documented scoped regions.
- Keyboard navigation covers prompt input, submit, transcript, explain-back input, and submit.
- Phone-width viewport is tested for learner and educator workflows.
- PageTransition reduced-motion/hydration warnings are resolved or isolated outside release-critical flows.
- No text overlap occurs in support cards, transcripts, or count tiles.

### Gate 5 - Observability And Audit Trail

Operators must be able to investigate support loops.

Required proof:

- Every support turn has durable event IDs and timestamps.
- Explain-back links to the original support interaction.
- Telemetry distinguishes opened, used, response, submitted, pending, and verified states.
- Logs do not expose sensitive learner content beyond approved audit fields.
- A site/operator can identify stuck pending explain-back debt.

### Gate 6 - Seeded Data And UAT Repeatability

Gold cannot depend on hand-made local state.

Required proof:

- Canonical synthetic data includes learners with no support, pending support, and explained-back support.
- Seeded data drives learner, educator, guardian, site, and any HQ scope used in gold signoff.
- Playwright tests can run from a clean reset.
- Emulator tests can run from a clean reset.

### Gate 7 - Release Gate Bundle

Gold signoff requires one command group or documented sequence that operators can run without manual interpretation.

Minimum sequence:

```bash
npm run typecheck -- --pretty false
npm run lint
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts src/__tests__/miloos-ai-coach-screen.test.tsx src/__tests__/miloos-learner-support-snapshot.test.tsx src/__tests__/educator-ai-audit-miloos-provenance.test.tsx
npm --prefix functions test -- aiHelpWording.test.ts bosRuntimeHonesty.test.ts
npm --prefix functions run build
npm run test:integration:evidence-chain
npm run test:integration:rules
npx playwright test --config playwright.config.ts test/e2e/miloos-learner-loop.e2e.spec.ts test/e2e/miloos-educator-support-provenance.e2e.spec.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts test/e2e/miloos-site-support-health.e2e.spec.ts test/e2e/miloos-accessibility.e2e.spec.ts
git diff --check
```

## Priority Workstreams

### 1. Remove App-Level Browser Warnings

Status: completed 2026-04-30 for the focused MiloOS protected-route baseline.

The focused MiloOS regions pass Axe, but Playwright still logs PageTransition reduced-motion/hydration warnings. Gold should not tolerate release-critical browser warnings on the same route family.

Target files:

- `src/components/layout/PageTransition.tsx`
- route layouts under `app/[locale]/`

Done when:

- Focused MiloOS Playwright runs are clean of PageTransition hydration warnings.
- Existing accessibility E2E still passes.

### 2. Add Parent Direct-Read Denial Tests

Status: completed 2026-04-30.

Parents should receive MiloOS support provenance through server-owned summaries, not raw event reads.

Target files:

- `firestore.rules`
- `test/firestore-rules.test.js`

Done when:

- Linked parent cannot read raw same-site `interactionEvents`.
- Unlinked parent cannot read raw `interactionEvents`.
- Parent bundle/callable still includes linked learner `miloosSupportSummary`.

### 3. Build One Cross-Role MiloOS Golden Path

Status: completed 2026-04-30.

Current browser tests prove each surface separately. Gold needs one narrative path from learner support to downstream visibility.

Target file:

- `test/e2e/miloos-cross-role-golden-path.e2e.spec.ts`

Flow:

1. Learner asks for help on `/en/learner/miloos`.
2. Learner sees transcript and pending explain-back.
3. Educator sees pending follow-up on `/en/educator/learners`.
4. Learner submits explain-back.
5. Guardian sees support provenance on `/en/parent/summary`.
6. Site admin sees support health on `/en/site/dashboard`.
7. Test asserts no `capabilityMastery` writes.

### 4. Prove Mobile Classroom Use

Status: completed 2026-04-30.

The teacher and learner flows need phone-width checks.

Target routes:

- `/en/learner/miloos`
- `/en/educator/learners`
- `/en/site/dashboard`

Done when:

- Phone viewport Playwright passes for transcript, explain-back, educator support card, and site support health.
- No overflow or overlapping text appears in support tiles.

### 5. Harden Observability

Status: completed 2026-04-30.

- `ai_help_opened` self-stamps `traceId` and `payload.aiHelpOpenedEventId`.
- `ai_help_used`, `ai_coach_response`, and `explain_it_back_submitted` all link back to the opened support turn.
- Emulator-backed tests now prove persisted events can derive pending explain-back debt without writing mastery.
- Site implementation health exposes stuck pending explain-back debt for operators.

The event chain must be operator-debuggable.

Target files:

- `functions/src/index.ts`
- `functions/src/bosRuntime.ts`
- `src/lib/telemetry/telemetryService.ts`
- MiloOS support event readers

Done when:

- Support opened, used, response, explain-back submitted, and pending state have durable trace fields.
- Telemetry tests prove no mastery-like signal is emitted from support events.
- Site health can identify stuck pending explain-back debt.

### 6. Promote Canonical Synthetic MiloOS States

Status: completed 2026-04-30.

`scripts/import_synthetic_data.js` now adds `syntheticMiloOSGoldStates/latest` in every seed mode (`starter`, `full`, and `all`). The canonical pack includes learner IDs for no-support, pending explain-back, support-current, cross-site denial, and missing-site denial states. It writes only support/provenance `interactionEvents` and a manifest, not support-only mastery or growth documents.

The gold demo/UAT pack needs repeatable states.

Required synthetic states:

- Learner with no support yet.
- Learner with opened/used support and pending explain-back.
- Learner with support and explain-back current.
- Multi-site event that must not leak.
- Missing-site event that must not be readable by educator/site admin.

Verified with `npm run seed:synthetic-data:dry-run`, `npm run test:integration:rules`, `npm run test:integration:evidence-chain`, and `npm test -- --runTestsByPath test/synthetic_miloos_gold_states.test.js`.

### 7. Decide Flutter Scope

Status: completed 2026-04-30.

Flutter MiloOS role parity is not in the current MiloOS gold-candidate scope. The gold-candidate claim is web-only. Flutter remains beta for MiloOS until it has role-parity support provenance across learner, educator, guardian, and site surfaces plus focused Flutter tests/analyzer proof. Existing Flutter learner-loop/card and parent AI-disclosure coverage are useful, but not enough to certify MiloOS gold parity.

Flutter has learner-loop card coverage, but gold needs role parity or explicit web-only scope.

Done when one of these is true:

- Flutter learner, educator, guardian, and site surfaces render support provenance and pass focused widget/analyzer checks.
- Or the gold scope explicitly states MiloOS web is gold-candidate while Flutter MiloOS remains beta.

## Gold Stop Conditions

Do not call MiloOS gold-ready if any of these are true:

- Any MiloOS support event writes mastery or growth directly.
- Guardian or site surfaces imply support equals capability.
- Educator/site/parent can read cross-site support events.
- Browser E2E relies only on isolated fake screens instead of protected routes.
- Focused accessibility passes but full route has unresolved critical keyboard or mobile blockers.
- Operators cannot reproduce the validation sequence from a clean checkout.
- Flutter scope is unclear.

## Final Web MiloOS Gold-Candidate Signoff

- Support evidence created: `ai_help_opened`, `ai_help_used`, `ai_coach_response`, and `explain_it_back_submitted` records in `interactionEvents`, joined by `aiHelpOpenedEventId` and trace metadata.
- Observers: learners see their support loop and pending checks; educators see same-site support provenance and pending follow-up debt; guardians see linked learner support provenance through server-owned summaries; site leaders see site-scoped support health.
- Authenticity verification: learners must submit explain-back evidence tied to the opened support turn; pending explain-back remains verification debt until completed.
- Support is not mastery: MiloOS support events do not write `capabilityMastery` or `capabilityGrowthEvents`; rubric application and checkpoint mastery processing remain the growth paths.
- Educator action: pending explain-back debt appears in educator support provenance surfaces so educators can follow up without treating support usage as capability evidence.
- Guardian interpretation: guardian surfaces show support provenance and explain-back status without exposing raw `interactionEvents` or making mastery claims.
- Site interpretation: site leaders see aggregate support opened/used/explain-back/pending counts for implementation health and stuck-debt discovery.
- Remaining beta scope: Flutter MiloOS role parity remains beta and out of this web-only gold-candidate signoff.

Final gate commands passed 2026-04-30: typecheck, lint, focused web/source tests, focused Functions honesty tests, Functions build, Firestore rules integration, evidence-chain emulator integration, MiloOS browser/WCAG/mobile/keyboard E2E suite, synthetic-data dry-run, and `git diff --check`.
