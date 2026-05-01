# MiloOS Gold Readiness Plan - April 30, 2026

## Status

**Current verdict: MiloOS web plus focused Flutter/mobile role-parity gate passed; broader Scholesa remains beta-ready, not platform gold-ready.**

MiloOS is stronger across the support-provenance loop: learner support, explain-back, educator visibility, guardian provenance, Admin-School support health, canonical synthetic states, permissions, browser proof, focused accessibility, and focused Flutter/mobile role-parity checks now have validation. This is a scoped MiloOS gold-candidate signoff, not a blanket Scholesa platform gold claim.

## Product Truth Boundary

MiloOS is learner support and verification provenance. It is not a mastery engine.

- `ai_help_opened`, `ai_help_used`, `ai_coach_response`, and `explain_it_back_submitted` are support/provenance events.
- MiloOS support events must not write `capabilityMastery`.
- MiloOS support events must not write `capabilityGrowthEvents`.
- Explain-back status can identify verification debt, but it cannot become mastery by itself.
- Educator rubric application or checkpoint mastery processing remains the growth interpretation path.
- Families and site leaders must see support provenance as support health, not learner capability claims.

## Current Verified Surface

| Surface | Current proof | Gold state |
| --- | --- | --- |
| Learner web `/learner/miloos` | Browser E2E proves support request, transcript, pending explain-back, returned pending explain-back completion, refreshed counters, phone-width usability, keyboard-only support completion, focus preservation, traceable support-turn events, and no `capabilityMastery` write. | Web gold-candidate gate passed. |
| Educator web `/educator/learners` | Browser E2E proves same-site MiloOS support provenance and pending follow-up debt, including cross-role and phone-width paths. | Web gold-candidate gate passed for support visibility and follow-up debt. |
| Guardian web `/parent/summary` | Browser E2E proves linked guardian sees same-site support provenance and non-mastery language, including after learner explain-back completion. | Web gold-candidate gate passed for support provenance. |
| Admin-School web `/site/dashboard` | Browser E2E proves site-wide same-site support health aggregation, including after cross-role support completion and on phone-width viewport. | Web gold-candidate gate passed for support health visibility. |
| Accessibility | Focused Axe WCAG 2.2 AA checks pass on protected MiloOS support regions, reduced-motion/hydration warnings are cleaned up, and keyboard-only support completion is verified. | Scoped web gold-candidate gate passed. |
| Firestore rules | Educator and site-admin same-site `interactionEvents` reads are tested; other-site/missing-site denied; linked and unlinked parent raw-event reads and queries are denied. | Scoped web gold-candidate gate passed. |
| Functions/emulator | `genAiCoach` -> `submitExplainBack` -> `bosGetLearnerLoopInsights` path is emulator-tested and no mastery write is asserted. | Scoped web gold-candidate gate passed. |
| Flutter/mobile learner | `BosLearnerLoopInsightsCard` parses opened/used/explain-back/pending support journey gaps. | Focused mobile parity gate passed for learner support provenance. |
| Flutter/mobile educator | `EducatorLearnerSupportsPage` renders per-learner MiloOS support provenance and pending explain-back debt from site-scoped `interactionEvents`. | Focused mobile parity gate passed for educator support follow-up. |
| Flutter/mobile Admin-School | `SiteDashboardPage` renders same-site MiloOS support health and pending explain-back debt from `interactionEvents`. | Focused mobile parity gate passed for site support health. |

## Gold Gates

1. **Support Loop Integrity**: learner can open MiloOS, get a readable transcript, submit explain-back, and see updated support status without support-only mastery or growth writes.
2. **Cross-Role Provenance Visibility**: educator, guardian, and site surfaces show scoped support provenance and pending debt without capability claims.
3. **Permissions And Site Boundary**: learner, educator, site, and parent reads are role/site scoped; parents do not read raw `interactionEvents`.
4. **Accessibility And Classroom Use**: protected web surfaces pass focused WCAG checks, keyboard flow, phone-width layout, and no text-overlap checks.
5. **Observability And Audit Trail**: support opened/used/response/explain-back records have durable IDs and trace fields so operators can inspect stuck pending debt.
6. **Seeded Data And UAT Repeatability**: canonical synthetic states cover no-support, pending, current, cross-site denial, and missing-site denial without support-only mastery/growth writes.
7. **Release Gate Bundle**: web, Functions, rules, emulator, browser, synthetic-data, and focused Flutter/mobile commands are reproducible from the repo.

## Flutter/Mobile Scope

Flutter/mobile is now included in the scoped MiloOS support-provenance gate. The validated slice is intentionally narrow:

- learner-loop support journey display through `BosLearnerLoopInsightsCard`;
- educator per-learner MiloOS support provenance and pending explain-back debt;
- Admin-School same-site MiloOS support health aggregation;
- analyzer-clean Dart implementation.

This does not make the full Flutter app gold-ready. Broader Flutter workflows remain beta unless separately validated; the later Flutter/mobile release bundle now covers guardian portfolio/export paths, full Flutter tests/analyzer, root tests, Functions/rules gates, and the non-deploying `./scripts/deploy.sh release-gate`. MiloOS still remains a focused support-provenance gold-candidate slice rather than a blanket mobile or platform gold claim.

## Gold Stop Conditions

Do not call MiloOS gold-ready if any of these are true:

- Any MiloOS support event writes mastery or growth directly.
- Guardian, educator, or site surfaces imply support equals capability.
- Educator, site, or parent can read cross-site support events.
- Browser E2E relies only on isolated fake screens instead of protected routes.
- Focused accessibility passes but full route has unresolved critical keyboard or mobile blockers.
- Operators cannot reproduce the validation sequence from a clean checkout.
- Flutter/mobile parity checks are stale or broadened beyond the tested MiloOS support-provenance slice.

## Final MiloOS Gold-Candidate Signoff

- Support evidence created: `ai_help_opened`, `ai_help_used`, `ai_coach_response`, and `explain_it_back_submitted` records in `interactionEvents`, joined by `aiHelpOpenedEventId` and trace metadata.
- Observers: learners see their support loop and pending checks; educators see same-site support provenance and pending follow-up debt; guardians see linked learner support provenance through server-owned summaries; site leaders see site-scoped support health.
- Authenticity verification: learners submit explain-back evidence tied to the opened support turn; pending explain-back remains verification debt until completed.
- Support is not mastery: MiloOS support events do not write `capabilityMastery` or `capabilityGrowthEvents`; rubric application and checkpoint mastery processing remain the growth paths.
- Educator action: pending explain-back debt appears in educator support provenance surfaces so educators can follow up without treating support usage as capability evidence.
- Guardian interpretation: guardian surfaces show support provenance and explain-back status without exposing raw `interactionEvents` or making mastery claims.
- Site interpretation: site leaders see aggregate support opened/used/explain-back/pending counts for implementation health and stuck-debt discovery.
- Remaining beta scope: broader Scholesa and broader Flutter workflows remain beta outside the focused MiloOS support-provenance parity gate.

Final web gate commands passed 2026-04-30: typecheck, lint, focused web/source tests, focused Functions honesty tests, Functions build, Firestore rules integration, evidence-chain emulator integration, MiloOS browser/WCAG/mobile/keyboard E2E suite, synthetic-data dry-run, and `git diff --check`. On 2026-05-01, the non-deploying `./scripts/deploy.sh release-gate` also passed from the current worktree, including root tests, combined Firestore emulator release tests, Functions gates, full Flutter analyze/test, and diff hygiene.

Final focused Flutter/mobile gate passed 2026-04-30:

```bash
cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart
cd apps/empire_flutter/app && flutter analyze
```
