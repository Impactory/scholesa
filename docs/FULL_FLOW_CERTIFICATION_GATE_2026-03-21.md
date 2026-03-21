# Full-Flow Certification Gate

Last updated: 2026-03-21
Purpose: define the minimum bar for calling a route, workflow, or cluster fully honest, full-flow verified, or gold-ready.

This gate is stricter than route rendering, stale-data honesty, or single-action persistence proof.

## 1. Classification Levels

Use only one of these labels for a route or workflow:

1. `Misleading or unsafe`
   - The surface hides failure, fakes completion, implies live state without proof, or makes capability claims without evidence provenance.
2. `Operationally honest`
   - The surface no longer lies about loading, empty, unavailable, stale, or blocked state, but full mutation/reload/scope depth is still partial.
3. `Full-flow partial`
   - The surface proves meaningful read and write behavior, but at least one critical gate below is still under-proven.
4. `Full-flow verified`
   - All required gates below are proven for the intended workflow scope.
5. `Gold-ready`
   - Full-flow verified with real release-grade evidence on the supported production surface.

## 2. Mandatory Full-Flow Gates

A route or workflow is not `Full-flow verified` unless every applicable gate passes.

### Gate A: State Truth

The UI must distinguish all applicable states:

1. loading
2. empty
3. unavailable/error
4. stale after prior success
5. partial data
6. saved or completed outcome

Fail if any of these states collapse into the same copy or behavior when they mean different operational truth.

### Gate B: Real Mutation

If the route exposes a primary action, it must:

1. submit the intended mutation to the real backend or a faithful test double
2. handle validation failures explicitly
3. surface authorization/scope failures explicitly
4. avoid local-only fake completion

Fail if a dialog closes, toast appears, or UI toggles without authoritative persistence proof.

### Gate C: Authoritative Reload

After a successful mutation, the route must prove one of:

1. explicit re-fetch from the source of truth
2. trusted subscription update from the source of truth
3. a documented equivalent authoritative refresh path

Fail if the screen only echoes optimistic local state and never proves the persisted backend result.

### Gate D: Recovery

When read or write fails, the user must have an honest recovery path:

1. retry
2. refresh
3. safe continue with clearly marked stale data
4. bounded support-handoff with next-step expectation

Fail if the user is stranded in a dead end or forced to infer what to do next.

### Gate E: Scope And Permission Correctness

The route must prove role and scope correctness where applicable:

1. site scope
2. learner scope
3. partner scope
4. HQ versus non-HQ permissions
5. feature-flag or environment gating

Fail if the UI suggests an action is available when policy or scope should block it, or if the route silently shows cross-scope data.

### Gate F: Accessibility And Discoverability

Warnings, blocked states, recovery actions, and mutation outcomes must be discoverable for assistive-tech and keyboard users.

Fail if the route is only visually honest.

### Gate G: Telemetry And Auditability

Critical decisions and high-risk operator actions must emit auditable telemetry or audit records when the product depends on post-hoc traceability.

Fail if a consequential action changes state but leaves no reliable audit or telemetry trail where one is expected.

### Gate H: Educational Truth

For capability-first workflows, the route must not imply:

1. mastery
2. growth
3. proof-of-learning
4. portfolio readiness
5. Passport/report claims

unless those claims are backed by visible persisted evidence lineage.

Fail if the route makes learner claims from UI inference, attendance, XP, completion, or disconnected summaries.

### Gate I: AI Transparency

If AI affects the workflow, the route must prove:

1. AI use is disclosed
2. disclosure persists where relevant
3. human verification intent is visible where required
4. generated content is not misrepresented as verified learner proof

Fail if AI output can pass through the workflow as if it were authenticated learner evidence.

## 3. Automatic Fail Conditions

Any one of these blocks `Full-flow verified` status:

1. fake empty state caused by exception-to-empty conversion
2. fake success toast with no authoritative persistence proof
3. stale state presented as if current/live
4. action availability without permission or scope proof
5. optimistic UI with no reload or subscription confirmation
6. missing retry or recovery path on an operator-critical failure
7. capability or growth claim without evidence provenance
8. AI-assisted artifact or decision without disclosure path
9. inaccessible warning, retry, or blocked-state control
10. manual cleanup outside the product required for the normal workflow to be trusted

## 4. Minimum Evidence Required Per Route Audit

At minimum, record:

1. read-path proof
2. primary mutation proof if the route mutates
3. post-mutation reload proof
4. failure-path proof
5. recovery-path proof
6. scope/permission proof where relevant
7. evidence provenance proof where educational claims are involved
8. AI disclosure proof where AI is involved

If a route does not support one of these categories, record the reason explicitly rather than implying it passed.

## 5. Support-Handoff Rule

Support-handoff flows can still be honest, but only if:

1. the UI clearly states it is not self-service
2. the handoff persists a real request or contact action
3. the next step and expected owner are visible

They do not qualify as self-service full-flow proof unless the full in-product completion path exists.

## 6. Gold-Ready Exit Rule

Do not label a route, workflow, or release `gold-ready` unless:

1. all applicable full-flow gates pass
2. production-relevant release surface is verified end to end
3. no critical learner, educator, site, partner, or HQ workflow remains stubbed, disconnected, or dependent on manual cleanup

For Scholesa specifically, gold also requires educational truth, not only software truth.

## 7. Required Audit Output Format

For every future route or workflow review, record these five lines:

1. Classification: `Misleading or unsafe` | `Operationally honest` | `Full-flow partial` | `Full-flow verified` | `Gold-ready`
2. Proven gates: list the gates that passed
3. Missing gates: list the gates still under-proven
4. Blocking risk: the single most serious reason it is not at the next class
5. Next proof task: the smallest concrete proof needed next