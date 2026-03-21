# Full Honesty Audit

Last updated: 2026-03-21
Status: Beta ready, not gold ready
Scope: Flutter app enabled routes, current runtime behavior, current test evidence, and release readiness

## Verdict

- Not gold ready.
- Still beta ready for a controlled audience.
- Core learner, educator, parent, messaging, and site operations paths are no longer obviously fake.
- Gold is still blocked by unproven native distribution and by remaining depth gaps in mutation, failure-path, and operator-governance proof.

## Honesty Standard Tightened

The audit standard is now stricter than simple visible rendering or stale-data honesty.

The reusable certification checklist for future route and workflow reviews lives in `docs/FULL_FLOW_CERTIFICATION_GATE_2026-03-21.md`.
The running worksheet for concrete route classifications lives in `docs/FULL_FLOW_GATE_WORKSHEET_2026-03-21.md`.

Terminology:

- Honest degraded mode: the route keeps prior verified data visible, declares that refresh is failing, exposes the failure detail when it matters, and offers a real recovery path.
- Route-direct proof: the route itself has focused test evidence for the page behavior being claimed.
- Full-flow proof: the route or workflow proves live read, live mutation where applicable, source-of-truth reload, honest failure handling, correct role and scope enforcement, and no fake completion.
- Gold-ready proof: full-flow proof plus release-grade evidence that the path works end to end on the real supported surface, not only in a harness.

Rules:

1. Stale data does not count as end-to-end success. It only counts as honest degraded behavior.
2. A direct route test does not by itself count as full-flow verification.
3. A save action is not proven unless the post-mutation state is re-read from the authoritative source and rendered truthfully.
4. A route is not honest if a control exists but the user cannot tell whether it persisted, failed, was blocked by permissions, or stayed local-only.
5. Empty state, unavailable state, stale state, partial data, and post-save state must be distinguishable in both copy and behavior.
6. Accessibility is part of honesty. If assistive-tech users cannot discover the warning, retry, scope, or blocked action, the route is not fully honest.
7. Capability-first flows must not imply learner growth, mastery, proof, or readiness unless evidence provenance is visible and the claim is actually derived from persisted evidence.
8. AI-assisted flows must disclose AI involvement and must not present generated output as verified learner proof.

Full-flow proof minimum for an auditable route:

1. Read path: current scoped data loads from the real backing source or a faithful test double and renders the correct state.
2. Mutation path: the primary action persists the intended change.
3. Re-query path: the UI reflects the persisted result after reload or equivalent authoritative refresh.
4. Failure path: the route shows an explicit, truthful failure state without collapsing into fake empty or fake success.
5. Recovery path: the user can retry, refresh, or otherwise recover from the failure in-surface.
6. Scope path: role, site, learner, or partner boundaries are enforced and visible where relevant.
7. Accessibility path: controls, warnings, and outcomes are reachable and announced appropriately.
8. Telemetry path: critical operator or learner actions emit auditable telemetry where the product depends on that trace.
9. Pedagogy path: any capability, evidence, portfolio, rubric, passport, or proof-of-learning claim is tied to real persisted evidence, not UI inference.

Because of this stricter standard, references below to direct proof or honest stale behavior should be read as partial confidence unless the mutation, reload, and scope paths are also directly proven.

### Confidence classes used below

- Operationally honest: the route no longer lies about loading, emptiness, failure, or stale state, but full-flow mutation and scope depth may still be partial.
- Full-flow partial: important read and some write paths are proven, but at least one of authoritative reload, scope enforcement, recovery depth, telemetry, or evidence provenance is still under-proven.
- Gold-ready: reserved for routes or workflows with full-flow proof plus release-grade verification. No broad route cluster below should be read as gold-ready unless stated explicitly.

## A. Release Matrix Updated

### Route inventory

- Enabled route registry currently exposes 52 page surfaces across learner, educator, parent, site, partner, HQ, and cross-role flows.
- Canonical aliases remain active for:
  - `/educator/review-queue` -> `/educator/missions/review`
  - `/site/scheduling` -> `/site/sessions`
  - `/hq/cms` -> `/hq/curriculum`

### Verification inventory

- Focused page, workflow, regression, placeholder-action, and honesty test coverage now backs nearly the full enabled Flutter route surface.
- That route-direct coverage is stronger than the current full-flow certification depth.
- No broad flow cluster below should be read as universally full-flow certified merely because it has strong route-direct coverage.
- Fresh verification in this pass:
  - partner contracting workflow proof pass: 6 passed, 0 failed
  - attendance honesty proof pass: 5 passed, 0 failed
  - operator accessibility follow-up proof pass: 29 passed, 0 failed
  - site ops recovery proof pass: 6 passed, 0 failed
  - site identity honesty proof pass: 2 passed, 0 failed
  - site incidents honesty proof pass: 4 passed, 0 failed
  - site integrations health proof pass: 4 passed, 0 failed
  - HQ feature flags proof pass: 22 passed, 0 failed
  - HQ user-admin audit-log proof pass: 12 passed, 0 failed
  - partner listings, integrations, and deliverables proof pass: 12 passed, 0 failed
  - partner integrations proof pass: 4 passed, 0 failed
  - educator learner supports and partner deliverables proof pass: 12 passed, 0 failed
  - educator mission plans proof pass: 6 passed, 0 failed
  - provisioning, site sessions, and learner today proof pass: 7 passed, 0 failed
  - site provisioning route proof pass: 24 passed, 0 failed
  - site sessions route proof pass: 9 passed, 0 failed
  - educator sessions and partner contracts proof pass: 5 passed, 0 failed
  - remaining-route proof pass: 7 passed, 0 failed
  - learner and parent alias-route proof pass: 9 passed, 0 failed
  - `flutter analyze`: passed
  - next admin-cluster failure-path pass: 4 passed, 0 failed
- Existing broad audit baseline still current in this code cycle:
  - 247 passed, 0 failed
  - Route-proof status is tracked in `docs/FLUTTER_ROUTE_PROOF_MATRIX_2026-03-19.md`

### Flow-by-flow honesty matrix

| Flow cluster | Discoverable | Understandable | Completable | Persists correctly | Recovers from errors | Mobile | Fake/stubbed/ambiguous | Audit call |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Auth, routing, shared-device sign-out | Yes | Yes | Yes | Yes | Mostly yes | Yes | Welcome and login are now directly proven; no obvious fake path remains in the public/auth shells | Operationally honest, full-flow breadth still partial |
| Learner missions and habits | Yes | Yes | Yes | Yes | Yes, degraded AI mode is now explicit | Yes | No obvious fake primary action | Operationally honest, capability-claim depth still partial |
| Learner onboarding and credentials | Yes | Mostly yes | Yes | Yes | Mostly yes | Yes | Some secondary storage failures still degrade plainly rather than gracefully | Operationally honest, full-flow partial |
| Learner portfolio and today | Yes | Mostly yes | Mostly yes | Partly proven | Mostly yes on audited mission/habit failure and stale-data states, partial on deeper onboarding/AI paths | Yes | Today now fails honestly under direct test; deeper secondary paths still rely on broader coverage | Operationally honest, evidence/provenance depth partial |
| Educator learners and follow-up requests | Yes | Yes | Yes | Yes | Mostly yes | Yes | No obvious fake action in audited path | Operationally honest, broader write/reload depth partial |
| Educator attendance | Yes | Yes | Yes | Mostly yes | Yes on audited attendance list and roster first-load/stale-refresh paths; recovery controls are now labeled and stale-state messaging is assistive-tech visible; real Firestore-backed roster coupling now proves active enrolled learners become the live class roster, and direct route proof now covers attendance save success, explicit save failure, reload of saved attendance from Firestore when the roster is reopened, and truthful offline queueing without Firestore writes before sync resumes | Yes | No obvious fake primary action | Operationally honest, broader educator workflow coupling still partial |
| Educator sessions, mission plans, integrations, learner supports, today | Yes | Mostly yes | Likely | Partly proven | Mostly yes across the audited sessions, mission-plans, today, learner-supports, and integrations failure states; learner-support first-load outage and stale saved-plan refresh truth are now directly proven and remaining depth is narrower assignment breadth | Yes | No obvious fake primary action remains in the audited paths | Operationally honest, full-flow partial across the cluster |
| Parent summary, billing, schedule, portfolio, child view | Yes | Yes | Mostly yes | Support-request persistence is real where used | Mostly yes | Yes | Billing is honest summary only, not self-service | Operationally honest, support-handoff and provenance depth partial |
| Site dashboard, billing, consent, pickup auth, ops, audit, provisioning, sessions | Yes | Yes | Mostly yes | Mostly yes | Mostly yes on audited provisioning, sessions, and site-ops runtime rollout failure/stale-data paths, with direct refresh and retry recovery now proven; `/site/provisioning` now also has direct learner/parent/link/cohort create proof, learner/parent edit persistence proof, active-site guardian-link deletion proof, explicit create/edit/delete failure proof, direct create/edit/delete telemetry proof, authoritative reload proof on audited mutation paths, and direct route-gating proof, while downstream coupling remains partial, and `/site/sessions` now has direct create persistence, authoritative reload, explicit create-failure proof, and direct route-gating proof | Yes | No obvious fake primary action remains in the audited paths | Operationally honest, deeper site mutation flows still partial |
| Site identity and incident/admin support surfaces | Yes | Mostly yes | Partly | Partly | Mostly yes on the audited identity, incidents, and integrations-health failure path; identity, incidents, and integrations health now keep visible refresh-failure detail with accessible stale-state announcement, but the wider cluster is still partial | Yes | Less misleading than before, still not comprehensively proven | Operationally honest, full-flow partial and not gold |
| Partner contracts and deliverables | Yes | Mostly yes | Mostly yes | Mostly yes | Mostly yes on the audited contracts/launches plus deliverables first-load and stale-refresh failure paths, including preserved stale contracts and launches on refresh failure; stale-state warnings now announce accessibly, but deeper mutation depth is still partial | Yes | No obvious fake primary action in audited path | Operationally honest, broader mutation depth partial |
| Partner listings and payouts | Yes | Mostly yes | Partly | Partly | Mostly yes on the audited payouts path plus listings first-load and stale-refresh failure paths, partial on the wider cluster | Yes | Listings create-and-persist path is now directly proven and no longer degrades outages into fake empty state; broader partner depth is still partial | Operationally honest, full-flow partial and not gold |
| HQ sites, role switcher, exports, analytics | Yes | Yes | Yes | Yes | Mostly yes | Yes | No obvious fake primary path in audited route tests | Operationally honest, broader operator workflow depth partial |
| HQ billing, approvals, audit, safety, integrations health, feature flags, user admin | Yes | Mostly yes | Partly | Partly | Mostly yes on the audited billing, approvals, audit, feature-flags, and user-admin audit-log failure and stale-data paths; feature flags now also have direct HQ-only route gating, HQ-bounded delivery context in governance dialogs, rollout-alert triage success/failure proof, alert-history and rollout-audit rendering of saved triage/control/escalation state, rollout-control and rollout-escalation validation, save-and-reload, and backend-failure proof, plus explicit route copy that rollout status is not learner evidence, mastery, Passport, or AI-use disclosure truth | Yes | `/hq/feature-flags` is now route-level full-flow verified; the remaining gap is wider federated-learning workflow certification rather than route truthfulness | Operationally honest at the cluster level; `/hq/feature-flags` itself is full-flow verified, and the cluster is not gold |
| Cross-role messages, notifications, profile, settings | Yes | Yes | Yes | Yes | Mostly yes | Yes | No obvious fake primary action | Operationally honest, deeper cross-role action breadth partial |

## B. Gold Blockers

### 1. Native distribution is still unproven end to end

Current truth:

- iOS release automation is hardened, but there is still no verified successful TestFlight upload in this environment.
- Android release automation is hardened, but there is still no verified successful Google Play upload in this environment.

Why this is a gold blocker:

- Gold readiness requires the release path itself to be proven, not just buildable.
- A clean local build is not equivalent to a working store release.

End-to-end solution:

1. Execute one full iOS release through the supported lane and capture the artifact, upload result, processing result, and installability evidence.
2. Execute one full Android internal-track release through the supported lane and capture upload, processing, rollout visibility, and installability evidence.
3. Add the evidence bundle to release docs so the next audit can treat store distribution as proven, not assumed.

## C. Beta-Safe But Not Gold

### 1. Breadth confidence is still below gold across the 52 enabled routes

Current truth:

- Coverage is now materially stronger on core paths.
- The app now has strong route-direct coverage, but that remains broader than its full-flow certification depth.
- Current route-proof matrix: 51 direct, 1 workflow/regression-only, 0 with no convincing route proof.
- That route-proof count should not be read as a count of fully certified end-to-end routes.

Risk concentration:

- wider federated-learning workflow certification beyond the now verified `/hq/feature-flags` route.
- wider downstream site workflow coupling beyond the now strengthened `/site/provisioning` and `/site/sessions` routes.
- partner listings edit depth remains thinner than create-and-persist proof.
- the root entry surface is still proven more by redirect behavior than by direct surface rendering.

End-to-end solution:

1. Keep the route-proof matrix from `kKnownRoutes` current and use it as a release contract.
2. Add direct tests first to enabled admin/operator routes that perform approvals, billing, identity resolution, or user administration.
3. For each added route test, prove one happy path and one failure path. Rendering-only tests do not count.

### 2. The audited operator empty-success bug class is fixed, but the wider admin surface is still only partly proven

Current truth:

- HQ approvals, site identity, partner payouts, HQ billing, HQ audit, and site incidents now render explicit failure states when loading fails.
- Those routes no longer pretend a backend outage means there is simply no work to do.
- The wider admin surface still has more partial-failure combinations than the direct test footprint covers.

### 3. Capability-first educational truth is still below gold in several workflow clusters

Current truth:

- The reopened audit removed many fake empty, fake success, and hidden-failure states.
- That does not yet prove that every learner-facing claim is backed by evidence provenance, rubric linkage, capability updates, portfolio visibility, passport consequences, and AI-use disclosure.
- Some route clusters are operationally honest but still short of pedagogical full-flow proof.

Why this is a gold blocker:

- Scholesa is not gold-ready if a workflow completes technically but still leaves learner growth claims, mastery claims, or evidence lineage under-proven.
- Capability-first correctness requires not only software truthfulness but educational truthfulness.

End-to-end solution:

1. For each capability-affecting workflow, prove what evidence is created, who can observe it, and how it updates learner growth over time.
2. Add direct proof that portfolio and passport/report surfaces consume the same underlying evidence rather than disconnected summary state.
3. Add explicit AI-use disclosure and verification-path proof where AI assistance affects the learner artifact or teacher decision surface.

Why this is beta-safe but not gold:

- The specific misleading behavior called out in the audit is now fixed.
- The remaining risk is breadth, not the same known lie surviving in those audited routes.

End-to-end solution:

1. Apply the same `error vs empty vs stale` pattern to the remaining operator-heavy HQ and site pages.
2. Add direct failure-path tests for the next admin cluster instead of only success/render tests.
3. Keep stale-data banners only where last-known-good data actually exists.

### 3. Some honest surfaces are still support-handoff products rather than self-service products

Current truth:

- Parent billing is honest, but it is still primarily a summary-and-support handoff.
- Some profile/settings/support flows defer to request submission rather than true in-product completion.

Why this is acceptable for beta:

- The UI is no longer pretending these flows are self-service when they are not.
- Persistence exists where support requests are submitted.

Why it is not gold:

- Gold needs product intent to be explicit. Either these are permanently support-led flows, or they need full self-service scope.

End-to-end solution:

1. Make a product decision per support-handoff flow: keep as managed service or promote to self-service.
2. If keeping support-led, make the handoff SLA and next-step expectation visible.
3. If promoting to self-service, wire the missing CRUD/update path and audit it end to end.

## D. Polish-Only Issues

### 1. Secondary degraded states are uneven in quality

Current truth:

- Missions, habits, and attendance now fail honestly.
- Other secondary pages still vary between clear recovery guidance and generic blank/empty fallback messaging.

End-to-end solution:

1. Standardize degraded-state components across role surfaces.
2. Require title, reason, retry action, and safe continue action where possible.

### 2. Some route understanding still depends too much on internal vocabulary

Current truth:

- Most flows are understandable once opened.
- Several admin pages still assume operator familiarity with approvals, audits, and integrations without enough contextual explanation.

End-to-end solution:

1. Add one-sentence purpose text and consequence text on dense admin cards and sheets.
2. Keep this scoped to pages with operational decisions, not every screen.

## E. Invisible Technical Debt That Will Hurt Later

### 1. Catch-and-clear patterns are masking operational truth

Current truth:

- Some pages still treat exceptions as if there is simply no data.
- The audited approvals, identity resolution, and payouts routes were fixed in this pass, but the pattern still needs broader eradication.

Why this will hurt later:

- Operational dashboards become untrustworthy under partial outages.
- Support teams lose signal because failures do not surface clearly.

End-to-end solution:

1. Introduce a shared async-state model with `loading`, `data`, `empty`, `error`, and `stale`.
2. Ban exception-to-empty conversions in enabled operator surfaces.
3. Add lintable or reviewable guidance for this pattern.

### 2. Route enablement is ahead of route-proof discipline

Current truth:

- The router advertises a broad role surface.
- The proof system is still selective rather than exhaustive.

Why this will hurt later:

- Each new feature raises audit cost because proof debt compounds.
- Regressions will cluster in less-traveled admin routes.

End-to-end solution:

1. Treat `kKnownRoutes` as a release contract.
2. Require each enabled route to have either a direct route test or an explicit waiver recorded in the audit matrix.
3. Fail release readiness when enabled routes exceed the approved proof budget.

### 3. Admin surfaces still over-index on cloud-function success assumptions

Current truth:

- Multiple HQ/site pages are wired to real functions.
- The UI proof around partial failure and stale data is weaker than the success-path proof.

Why this will hurt later:

- Production incidents will present as ambiguity rather than explicit failure.
- Operators will trust stale or absent data.

End-to-end solution:

1. Add stale timestamps and last successful sync markers.
2. Add retry instrumentation and visible backend-failure toasts/banners.
3. Capture telemetry for load failure versus empty-data states so operations can distinguish demand from outage.

## Evidence of Verification

- Router inventory still exposes 52 enabled page surfaces.
- Focused test inventory now covers 49 audit-relevant files.
- `flutter analyze` passed on the current app state.
- Fresh next-cluster admin failure regressions passed: 4 tests, 0 failures.
- Fresh educator sessions and partner contracts proof pass: 5 tests, 0 failures.
- Fresh provisioning, site sessions, and learner today proof pass: 7 tests, 0 failures.
- Fresh remaining-route proof regressions passed: 7 tests, 0 failures.
- Current broad audit baseline for this code cycle remains 247 passed, 0 failed.

## Recommendation

- Recommendation: beta ready
- Gold readiness: blocked

Applied gate:

- This recommendation should now be interpreted through `docs/FULL_FLOW_CERTIFICATION_GATE_2026-03-21.md`, not through route presence or stale-state honesty alone.
- Route-by-route gate applications should now be recorded in `docs/FULL_FLOW_GATE_WORKSHEET_2026-03-21.md`.

## What Must Happen Before The Next Gold Claim

1. Prove one real iOS TestFlight release end to end.
2. Prove one real Android Play release end to end.
3. Upgrade the remaining proof gaps from route presence to route depth: start with educator mission-plans failure/mutation proof, then isolate the remaining learner and parent alias-route behaviors, then deepen HQ feature-flag governance proof.
