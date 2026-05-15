# Repo-Wide Refactor And Security Execution Plan - May 15 2026

Status: execution plan with May 15 baseline evidence and first refactor ratchet implemented.

This plan extends `docs/REPO_STABILITY_SECURITY_REFACTOR_PLAN_MAY_2026.md`. It is not a mandate for a big rewrite. The repo is too broad and too close to live operation for a sweeping refactor. The correct path is a ratcheted sequence of small, reversible phases that strengthen security, evidence provenance, and maintainability without changing product truth.

## Success Criteria

Scholesa is refactor-ready when all of these are true:

1. Every runtime surface has an owner, validation gate, rollback note, and route/data boundary map.
2. Security hardening fails closed for site scope, role permission, evidence access, AI egress, and secret handling.
3. Refactors do not rename or move Firestore fields, Storage paths, Cloud Function names, public URLs, or env vars without compatibility plans.
4. Capability claims remain evidence-backed and never derive from completion, attendance, engagement, XP, or AI support alone.
5. Web, Flutter, Functions, Firebase rules, compliance, scripts, and native release tooling each have a targeted gate before the broad release gate runs.

## Phase 0 - Baseline Already Captured On May 15

| Gate | Result |
| --- | --- |
| Root typecheck | PASS |
| Root lint | PASS |
| Next build | PASS |
| Public Flutter route tests | PASS, `7/7` |
| Secret scan | PASS |
| AI internal-only gates | PASS |
| Kubernetes manifest render | PASS |
| Workflow no-mock audit | PASS |
| COPPA guard tests | PASS |
| Firestore and Storage rules emulator tests | PASS, 238 tests |
| Compliance scan | PASS |
| High-severity npm audit | PASS, with low-severity transitive advisories remaining |
| Live role-account UAT | PASS, 8 canonical accounts and 16 route proofs against `https://scholesa.com` |
| Full web/security blanket-gold gate | PASS, proof log `audit-pack/reports/blanket-gold-live-may15.log` |
| Refactor baseline gate | PASS, `npm run refactor:baseline` on May 15 |
| Refactor full gate | PASS, `npm run refactor:full` on May 15, proof log `audit-pack/reports/refactor-full-may15.log` |

Rollback rule: if a later refactor causes any Phase 0 gate to fail, stop and either fix the exact regression or revert that phase only.

## Phase 1 - Ownership And Surface Map

Goal: make the repo navigable before moving code.

| Surface | Primary paths | Required map output |
| --- | --- | --- |
| Next public and protected web | `app/`, `src/features`, `src/lib/routing`, `locales/` | Route owner, role gate, visible terminology, i18n namespace, evidence-chain step. |
| Flutter web and native app | `apps/empire_flutter/app/lib`, `apps/empire_flutter/app/test` | Route owner, small-screen mode, offline behavior, persistence path, role gate. |
| Firebase Functions | `functions/src` | Callable owner, auth requirement, site scope, audit event, emulator/unit test. |
| Firestore and Storage rules | `firestore.rules`, `storage.rules`, `test/*rules*.js` | Collection classification: site-scoped, user-owned, server-owned, public metadata, or explicit admin-only. |
| Compliance operator | `services/scholesa-compliance/src` | Check owner, evidence path, deployment target, unauthenticated edge behavior. |
| Release scripts | `scripts/`, `.github/workflows/` | Mutating versus non-mutating classification, required credentials, redaction policy. |
| Shared/generated packages | `packages/`, generated Data Connect paths | Generated exclusions and shared package owners. |

Deliverable: update or generate a current ownership map from `docs/REPO_MAP.md` and `docs/ROUTE_MODULE_MATRIX.md`. Do not move files during this phase.

Validation:

```bash
git status --short
npm run typecheck -- --pretty false
npm run lint
```

## Phase 2 - Validation Ratchet

Goal: split the giant release burden into reusable local gates.

Add or confirm two explicit scripts:

| Script | Purpose | Must not do |
| --- | --- | --- |
| `refactor:baseline` | Typecheck, lint, workflow no-mock, secret scan, AI internal-only, compliance scan. Implemented in `package.json`. | Deploy, seed live data, mutate Firebase, upload native builds. |
| `refactor:full` | Baseline plus rules emulator tests, Functions build/tests, focused Flutter tests, Next build. Implemented in `package.json`. | Shift Cloud Run traffic or use store credentials. |

May 15 result: `npm run refactor:baseline` passed and `npm run refactor:full` passed. The full gate proof is stored at `audit-pack/reports/refactor-full-may15.log` and includes Firestore/Storage rules emulator tests, Functions build/tests, Flutter CI tests, and a Next production build.

Acceptance gates:

```bash
npm run qa:secret-scan
npm run ai:internal-only:all
npm run qa:workflow:no-mock
npm run test:integration:rules
npm run compliance:scan
```

## Phase 3 - Security Boundary Hardening

Goal: reduce permission risk before cosmetic cleanup.

| Lane | Refactor action | Test requirement |
| --- | --- | --- |
| Site scope | Replace permissive missing-`siteId` helpers with explicit required/global/server-owned variants. | Emulator denial tests for missing `siteId` on site-scoped collections. |
| Family access | Keep Family views on projections or linked learner evidence, not broad raw records. | Linked and unrelated learner denial tests. |
| Evidence media | Tighten Storage reads to owner, linked Family, same-site Educator/site/HQ, or explicit share consent. | Storage emulator tests for unrelated authenticated denial. |
| AI egress | Keep external AI packages/domains blocked unless an approved internal gateway mediates access. | `npm run ai:internal-only:all`. |
| Secrets | Expand scanner patterns and keep local `.p8`, store, keychain, and service-account files out of Git. | `npm run qa:secret-scan` plus redacted native proof logs. |
| Auth claims | Align web route metadata, Flutter role gates, Functions auth checks, and rules role checks. | Source-contract route tests plus live role UAT. |

Stop condition: any change that broadens evidence access without a same-site, role, relationship, or explicit-share proof must be rejected.

## Phase 4 - Route And Workflow Refactor

Goal: eliminate route drift while preserving App Router clarity and Flutter parity.

Actions:

- Keep thin Next route wrappers where they clarify URL ownership.
- Compare `src/features/workflows/customRouteRenderers.tsx`, `src/lib/routing/workflowRoutes.ts`, and Flutter `app_router.dart` before touching route code.
- Mark legacy route namespaces separately from visible copy. For example, an internal route namespace can remain stable while user-facing UI says Family.
- Add source-contract tests whenever a route maps to a dedicated renderer.
- Keep public `scholesa.com` ownership clear: Flutter owns `/welcome`, `/login`, and app shell paths; Next owns locale public pages such as `/en` and `/en/summer-camp-2026` through the Flutter proxy.

Validation:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
cd apps/empire_flutter/app && flutter test test/public_entry_routes_test.dart
```

## Phase 5 - Data Access And Service Layer Cleanup

Goal: make reads and writes auditable by product chain step.

Work order:

1. Capability graph and framework reads.
2. Mission, session, checkpoint, and evidence capture writes.
3. Reflection, proof bundle, and capability review workflows.
4. Portfolio, badge, showcase, and Growth Report outputs.
5. MiloOS Coach support records, disclosure, and explain-back recovery.
6. Partner deliverables and externally visible outputs.

For each workstream, document:

- What evidence is created.
- Who can submit it.
- Who can observe it.
- How authenticity is verified.
- How learner growth updates over time.
- How Portfolio and Growth Report surfaces consume it.
- What the fallback says when evidence is missing.
- What an Educator can do in under 10 seconds during a live session.
- What happens on mobile.

## Phase 6 - Flutter And Native Code Organization

Goal: prepare for the Phase 2 small-screen UX redesign without mixing UX and data rewrites.

Actions:

- Separate route shells, screen state, persistence services, and widgets where a file currently owns too much.
- Keep offline replay and server-owned growth interpretation boundaries intact.
- Prefer small widget extraction only when it improves testability or responsive layout.
- Add 390px and 430px widget tests for any refactored mobile workflow.

Validation:

```bash
cd apps/empire_flutter/app
flutter analyze
flutter test
```

## Phase 7 - Release And Docs Hygiene

Goal: prevent stale Gold claims.

Actions:

- Add current status sections to dated release docs instead of overwriting historical signoffs.
- Keep native distribution proof separate from local native build proof.
- Keep `scholesa.com` public-web proof separate from app-store proof.
- Preserve screenshot and command evidence under `audit-pack/reports/` or dated `docs/*proof*` folders.

Exit criteria:

- No doc claims blanket Gold while a blocker exists.
- Every blocker has a command, owner, and evidence artifact path.

## First Three Refactor Slices

1. **Route truth slice**: regenerate route ownership map, add drift tests, and confirm Next/Flutter public route ownership.
2. **Rules hardening slice**: classify Firestore/Storage collections and add denial tests for missing site scope plus unrelated Family access.
3. **Native small-screen slice**: implement responsive shell and bottom-action patterns from the Phase 2 native UX plan, with focused Flutter tests before broad visual work.

May 15 progress: the route truth slice has refreshed `docs/REPO_MAP.md` and `docs/ROUTE_MODULE_MATRIX.md` with the current `scholesa.com` ownership split, refactor gates, and live route UAT equivalents. Next implementation slice should target rules hardening or native small-screen tests; do not start a repo-wide move/rename pass first.