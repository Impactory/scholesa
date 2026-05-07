# Scholesa Repo Stability And Security Refactor Plan - May 2026

Status: **plan only - no runtime refactor implemented in this artifact**.

This plan is the staged path to make the Scholesa repository more stable, more secure, and easier to maintain without breaking the capability-first evidence chain. It is intentionally incremental. No phase should be merged unless the validation gates for that phase pass and the changed surface has a clear rollback path.

## Current Baseline

| Area | Current observation | Refactor implication |
| --- | --- | --- |
| Active owned code surface | Roughly 824 owned TS/JS/Dart source files across `app`, `src`, `functions/src`, `scripts`, `services/scholesa-compliance/src`, Flutter `lib/test`, and E2E `test`. | Refactor must be phased by surface; a big-bang cleanup is too risky. |
| Root TypeScript | `tsconfig.json` is strict, but excludes `functions`, `apps`, `scripts`, `test`, and `dataconnect`. | Root typecheck does not prove all executable code is type-safe. Add per-surface gates before tightening. |
| Root ESLint | `eslint.config.mjs` ignores `apps`, generated output, docs, and disables `@typescript-eslint/no-explicit-any`. | Tightening must be ratcheted by directory, not switched globally in one step. |
| Functions TypeScript | `functions/tsconfig.json` is strict and has `noImplicitReturns`, but `noUnusedLocals` is false. | Good base; add unused-local cleanup after extracting duplicated test helpers. |
| Flutter analysis | `apps/empire_flutter/app/analysis_options.yaml` uses basic `flutter_lints`; parent `apps/empire_flutter/analysis_options.yaml` is much stricter. | Migrate the app toward stricter analyzer rules in batches. |
| Firestore rules | `isSiteScopedRead` and `isSiteScopedWrite` allow data with no `siteId` by default. | This is a future hardening target; require explicit server-owned exceptions before enforcing site scope. |
| Storage rules | `portfolioMedia/{learnerId}/{fileName}` allows read by any authenticated user. | Tighten to owner, linked guardian, educator/site/HQ with proven relationship/claim. |
| Placeholder posture | Browser Firebase config fails closed outside server/build/E2E harness. | Preserve this. Any config refactor must keep real browser runtime fail-closed. |
| AI posture | Internal-only AI gates exist and MiloOS support must not write mastery directly. | Preserve AI disclosure/provenance and no-external-provider gates in every refactor. |
| Duplicate scan | Some repeated names are expected (`WorkflowPage`, generated Data Connect symbols, Playwright `Page`); others are consolidation targets (`parseArgs`, script `main`, test Firestore mocks, renderer `toIso/asString/formatDate`). | Classify duplicates before renaming. Do not mechanically deduplicate by symbol name alone. |

## Non-Negotiable Refactor Rules

1. Do not change behavior and structure in the same PR unless the behavior change is explicitly tested.
2. Do not rename or move Firestore fields, Storage paths, Cloud Function names, route URLs, or public env vars without a migration and compatibility window.
3. Do not touch generated code under `src/dataconnect-generated`, `src/dataconnect-admin-generated`, or generated Functions output.
4. Do not delete a duplicate until it is classified as harmful duplication, not just same-name repetition.
5. Preserve locale-first routing under `app/[locale]` and thin `WorkflowRoutePage` route pages.
6. Preserve evidence-chain truth: no completion, attendance, AI support, XP, or engagement signal may become capability mastery.
7. Preserve four-layer authorization for protected workflows: Firebase Auth claims, Firestore/Storage rules, web route metadata, and Flutter role gates.
8. Every phase must include a before/after validation command set and a rollback note.
9. Security hardening must fail closed. If compatibility requires a temporary allowlist, document owner, expiry, and test coverage.
10. Native-channel app-store release work remains separate from this repo refactor unless explicitly scoped.

## Phase 0 - Freeze And Evidence Baseline

Goal: make every later refactor measurable and reversible.

Actions:

- Record `git rev-parse --short HEAD`, `git status --short`, and `git diff --check` before each PR.
- Create a refactor tracking issue or checklist with one row per phase in this document.
- Tag current known unrelated worktree changes so they are not accidentally reverted.
- Record current Cloud Run/Firebase live state separately from refactor work; deployment evidence belongs in Gold readiness docs, not in refactor PRs.

Validation:

```bash
git rev-parse --short HEAD
git status --short
git diff --check
```

Stop conditions:

- Unexplained modified files exist.
- The phase would touch live services without explicit operator authorization.
- The phase mixes unrelated route, schema, and security changes.

## Phase 1 - Canonical Inventory And Ownership Map

Goal: know what the repo owns before changing it.

Actions:

- Create a machine-readable source inventory for owned surfaces:
  - `app/**`
  - `src/**` excluding generated Data Connect output
  - `functions/src/**` excluding generated output
  - `scripts/**`
  - `services/scholesa-compliance/src/**`
  - `apps/empire_flutter/app/lib/**`
  - `apps/empire_flutter/app/test/**`
  - `test/e2e/**`
- Classify each directory as runtime, test, generated, ops script, docs, or release artifact.
- Add a short owner/purpose map for high-risk surfaces:
  - auth and profile loading
  - Firestore collection access
  - evidence/proof/rubric/growth services
  - MiloOS and AI support
  - report/passport/share consent
  - Cloud Run deploy scripts
  - Flutter offline/evidence modules

Validation:

```bash
find app src functions/src scripts services/scholesa-compliance/src apps/empire_flutter/app/lib apps/empire_flutter/app/test test -type f \
  \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.dart' \)
```

Deliverable:

- `docs/REPO_SURFACE_OWNERSHIP_MAP_MAY_2026.md` or an equivalent generated report.

## Phase 2 - Validation Gate Ratchet

Goal: make refactors safer before making broad code changes.

Actions:

- Split validation into named gates by surface:
  - web: `npm run typecheck`, `npm run lint`, focused Jest
  - functions: `npm --prefix functions run build`, Functions unit tests
  - rules: Firestore rules emulator tests
  - workflows: no-mock workflow audit
  - AI: internal-only policy gates
  - secrets: tracked secret scan
  - Flutter: `flutter analyze` and test gate from the app directory
  - Cloud Run: non-deploying release-gate only unless live action is authorized
- Add a lightweight `npm run refactor:baseline` script that runs only non-mutating local gates.
- Add a separate `npm run refactor:full` script for expensive local gates.
- Do not add live Firebase or Cloud Run mutation to either script.

Validation:

```bash
npm run typecheck
npm run lint
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
npm run ai:internal-only:all
npm run qa:secret-scan
npm run qa:workflow:no-mock
npm --prefix functions run build
```

Stop conditions:

- A proposed ratchet creates hundreds of failures without a scoped migration plan.
- A gate requires secrets or live mutation by default.

## Phase 3 - Duplicate Classification Before Deduplication

Goal: remove harmful duplication without breaking intentional patterns.

Duplicate classes:

| Class | Example | Decision |
| --- | --- | --- |
| Intentional architecture | Repeated thin `WorkflowPage` route wrappers. | Keep. These preserve App Router route clarity. |
| Generated duplication | Data Connect generated symbols. | Ignore; never manually edit. |
| Test harness duplication | Repeated Firestore mock classes/helpers across `functions/src/workflowOps.*.test.ts`. | Consolidate into a shared Functions test harness after preserving test behavior. |
| Script boilerplate | Repeated `main`, `parseArgs`, env resolution, JSON output. | Consolidate into small script utilities only where it removes real risk. |
| Renderer utilities | Repeated `toIso`, `asString`, `formatDate` across workflow renderers. | Extract to `src/features/workflows/utils` after adding renderer tests. |
| Form handlers | Repeated `handleSubmit` names in unrelated components. | Usually keep; same local name is not a defect. |

Actions:

- Build a duplicate-symbol report that excludes generated files and test-local names unless explicitly requested.
- Create an allowlist for intentional duplicate names.
- Convert only repeated logic, not just repeated symbol names.
- Start with test harness consolidation because it reduces future refactor cost with low user-facing blast radius.

Validation:

```bash
npm --prefix functions run test -- --runInBand src/workflowOps.readPaths.test.ts src/workflowOps.hqLists.test.ts
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
```

Stop conditions:

- A rename crosses public route/API/function boundaries.
- Deduplication makes tests less realistic or hides Firestore behavior.

## Phase 4 - Firestore Rules Hardening

Goal: move from permissive fallback scoping to explicit least privilege.

Actions:

- Inventory every collection allowed by `firestore.rules` and classify it as site-scoped, user-owned, server-owned, public-authenticated, or HQ-global.
- Replace `isSiteScopedRead(data) => true when siteId missing` with explicit helper variants:
  - `isSiteScopedReadRequired(data)` for site-scoped production collections
  - `isGlobalReadAllowed(data)` for HQ/global framework collections
  - `isServerOwnedReadAllowed(data)` for server lifecycle docs
- Add emulator denial tests for missing `siteId` on collections that must be site-scoped.
- Add parent boundary tests for reports, portfolio, evidence, reflections, AI logs, and learner support state.
- Keep global capability framework collections readable only where product requires it, and document why.

Validation:

```bash
npm run test:integration:rules
npm run test:integration:evidence-chain
```

Stop conditions:

- Existing canonical synthetic flows fail because required `siteId` fields are missing. Fix data shape first, then harden rules.
- Guardian or learner access is blocked without a replacement parent-safe projection.

## Phase 5 - Storage Rules Hardening

Goal: prevent broad authenticated access to learner media.

Actions:

- Tighten `portfolioMedia/{learnerId}/{fileName}` read from any authenticated user to one of:
  - learner owner
  - linked guardian
  - educator/site/HQ with same-site relationship
  - explicit report/share consent token mediated by server state
- Add file type and size tests for media upload paths.
- Add denial tests for unrelated authenticated users.
- Confirm partner deliverables remain outside the Gold claim unless partner scope is included and permission-safe.

Validation:

```bash
npx --yes firebase-tools emulators:exec --only storage "npm test -- --runTestsByPath <storage-rules-test>"
```

Implementation note:

- If Storage emulator tests do not exist yet, create them before tightening production rules.

Stop conditions:

- Any media path becomes public or role-only without learner/site relationship checks.

## Phase 6 - Auth, Claims, And Route Metadata Unification

Goal: make authorization consistent across web routes, Firestore rules, and Flutter gates.

Actions:

- Build a route-to-role matrix from `src/lib/routing/workflowRoutes.ts` and `app/[locale]/(protected)/**`.
- Compare route metadata roles with Firestore rule roles and Flutter role gates.
- Normalize role names (`site`, `siteLead`, `admin`, `hq`, `educator`, `parent`, `learner`, `partner`) into one canonical mapping module.
- Add source-contract tests that fail if protected routes lack role metadata.
- Ensure client code never treats profile role as stronger than server authorization.

Validation:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
npm run qa:firebase-role-e2e
```

Stop conditions:

- A route becomes accessible to broader roles without a product/security decision.
- Parent routes expose raw educator-only evidence or support flags.

## Phase 7 - Runtime Config And Secret Boundary Cleanup

Goal: centralize config parsing and prevent secret drift.

Actions:

- Create one server config module for required non-public env vars and one client config module for `NEXT_PUBLIC_*` values.
- Preserve current browser fail-closed behavior for missing Firebase client env vars.
- Remove hard-coded fallback passwords from live-capable scripts or require an explicit `--allow-demo-defaults` flag.
- Keep `.secrets/**` local-only and ensure secret setup scripts never print secret values.
- Expand `scripts/secret_scan.py` beyond OpenAI/service-account/OAuth patterns to include generic private keys, Stripe keys, Firebase tokens, GitHub tokens, Anthropic keys, and Google API keys.
- Keep docs/report allowlists narrow; do not allow secrets in docs by default unless the docs contain redacted examples only.

Validation:

```bash
npm run qa:secret-scan
npm run ai:internal-only:all
npm run typecheck
```

Stop conditions:

- A production path can boot with demo credentials.
- A live-capable script can mutate Firebase using default test credentials without an explicit apply flag and project confirmation.

## Phase 8 - API And Cloud Functions Contract Hardening

Goal: make all server entrypoints validate inputs, roles, site scope, and evidence provenance.

Actions:

- Inventory every `app/api/**/route.ts` and exported Functions callable/HTTP handler.
- Require Zod or equivalent structured validation at each request boundary.
- Require explicit actor context: uid, role, active site, and audit reason for privileged writes.
- Ensure all evidence-chain writes include provenance: actor, site, learner, evidence type, source artifact/proof, timestamps, and verification status.
- Keep MiloOS writes limited to support/provenance/explain-back records; never direct mastery/growth updates.
- Add idempotency keys for live mutation endpoints where retries are plausible.

Validation:

```bash
npm --prefix functions run build
npm --prefix functions run test -- --runInBand
npm test -- --runTestsByPath src/__tests__/evidence-chain-components.test.ts
```

Stop conditions:

- An endpoint writes learner growth without evidence/proof/rubric linkage.
- A callable trusts client-provided role/site without server-side verification.

## Phase 9 - Evidence Chain Service Boundary

Goal: separate evidence capture, verification, interpretation, and communication logic so claims stay truthful.

Actions:

- Define service modules around the four evidence functions:
  - capture: observations, artifacts, reflections, checkpoints
  - verify: proof-of-learning, educator signoff, AI disclosure/explain-back
  - interpret: rubric/capability mapping, growth update candidate generation
  - communicate: portfolio/passport/guardian/admin outputs with provenance
- Move shared evidence normalization into one module used by web and Functions where practical.
- Add tests that prove completion/attendance/support signals do not become mastery.
- Make capability growth updates server-owned and traceable to evidence/proof/rubric inputs.

Validation:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts
npm run test:integration:evidence-chain
```

Stop conditions:

- UI surfaces claim learner capability without source evidence provenance.
- A refactor hides uncertainty or missing evidence behind positive dashboard language.

## Phase 10 - Workflow Renderer Stabilization

Goal: reduce renderer complexity without changing route behavior.

Actions:

- Keep route pages thin and keep `WorkflowRoutePage` delegation.
- Extract repeated renderer helpers only after tests pin current output.
- Split large renderer files by workflow boundary if they mix data loading, mutation, and presentation.
- Replace ad hoc date/string parsing with shared utilities where repeated.
- Keep empty/loading/error states explicit and role-aware.

Validation:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
npx playwright test test/e2e/workflow-routes.e2e.spec.ts
```

Stop conditions:

- A renderer loses provenance text, empty-state honesty, or role-specific CTA behavior.

## Phase 11 - Flutter Stability Refactor

Goal: make the Flutter app safer without bundling native-channel release work.

Actions:

- Adopt stricter analyzer rules into `apps/empire_flutter/app/analysis_options.yaml` in batches.
- Start with low-risk rules: `prefer_single_quotes`, `avoid_print`, `unawaited_futures` review, `avoid_dynamic_calls`, and null-safety warnings.
- Preserve existing offline/evidence flows and router role gates.
- Keep platform icon sync stable; do not mix macOS/iOS/Android signing changes into app logic refactors.
- Add Flutter tests for role gates, evidence capture offline queue, and MiloOS support disclosure where missing.

Validation:

```bash
cd apps/empire_flutter/app
flutter analyze --no-fatal-infos
flutter test
```

Stop conditions:

- A refactor changes native signing, notarization, app-store, or provisioning files unless that phase explicitly scopes native release.

## Phase 12 - Ops Script And Release Safety Cleanup

Goal: reduce script duplication while preserving live-mutation brakes.

Actions:

- Extract shared script helpers for argument parsing, required env checks, JSON output, and project confirmation.
- Require `--apply` plus explicit project ID for all scripts that mutate Firebase or Cloud resources.
- Require dry-run default for seed/repair/reconcile scripts.
- Keep `deploy.sh release-gate` non-deploying.
- Add shellcheck-style linting where practical, but do not block on all historical shell warnings at once.
- Record live deployment state separately from code refactor docs.

Validation:

```bash
npm run seed:synthetic-data:dry-run
./scripts/deploy.sh release-gate
bash ./scripts/operator_release_proof.sh
bash ./scripts/cloud_run_release_state_probe.sh
```

Stop conditions:

- A cleanup makes a live script easier to run accidentally.
- No-traffic and rollback guards are weakened.

## Phase 13 - Dependency And Supply Chain Hardening

Goal: reduce dependency risk without churn-driven upgrades.

Actions:

- Generate a dependency ownership report for root, Functions, compliance service, and Flutter pub packages.
- Remove unused dependencies only after import scans and tests pass.
- Pin or document critical runtime versions: Node 24, Next 16, Firebase Admin/Functions, Flutter stable.
- Add dependency drift/audit gates that fail on high-confidence vulnerable runtime dependencies.
- Keep generated Data Connect packages under their generated ownership path.

Validation:

```bash
npm run qa:dependency-drift
npm run typecheck
npm --prefix functions run build
```

Stop conditions:

- A dependency upgrade changes auth, Firestore, Cloud Functions, Next routing, or Flutter build behavior without dedicated regression proof.

## Phase 14 - Observability, Audit, And Privacy Review

Goal: make security-relevant actions visible without leaking student data.

Actions:

- Inventory privileged actions that must create audit logs: role changes, site membership changes, evidence verification, report sharing, consent changes, rubric publication, synthetic data apply, deployment operator actions.
- Ensure telemetry excludes PII and learner free text unless explicitly designed and consented.
- Add privacy boundary tests for guardian and partner views.
- Ensure MiloOS logs prompts/suggestions/learner changes/explain-back verification without exposing unrelated learner data.

Validation:

```bash
npm run qa:vibe-telemetry:audit
npm run qa:vibe-telemetry:blockers
npm run qa:firebase-role-e2e
```

Stop conditions:

- Logs include tokens, secrets, private learner free text, or unrelated learner data.

## Phase 15 - Final Hardening And Release Qualification

Goal: prove the refactored repo is at least as correct as the pre-refactor baseline.

Actions:

- Re-run all non-mutating gates.
- Re-run focused browser proof for evidence chain, workflow routes, MiloOS, mobile classroom, guardian/passport, and site ops.
- Re-run synthetic-data dry-run and compare manifest shape against source contracts.
- Re-run secret, AI, no-mock, dependency, and telemetry gates.
- Update release docs only with evidence that actually passed.

Validation:

```bash
npm run typecheck
npm run lint
npm test
npm run ai:internal-only:all
npm run qa:secret-scan
npm run qa:workflow:no-mock
npm run seed:synthetic-data:dry-run
npm --prefix functions run build
npm --prefix functions run test -- --runInBand
./scripts/deploy.sh release-gate
```

Optional browser validation:

```bash
npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts
npx playwright test test/e2e/workflow-routes.e2e.spec.ts
npx playwright test test/e2e/miloos-cross-role-golden-path.e2e.spec.ts
```

Stop conditions:

- Any evidence-chain workflow regresses.
- Any role boundary becomes broader.
- Any placeholder, mock, or synthetic-only path enters production workflow code.

## Recommended PR Sequence

1. Inventory and validation scripts only. No runtime behavior changes.
2. Duplicate-symbol report and allowlist. No runtime behavior changes.
3. Functions test harness consolidation. Tests only.
4. Workflow renderer utility extraction. Web source only with focused tests.
5. Config and secret scan ratchet. No runtime fallback broadening.
6. Firestore rules site-scope tests. Tests before rule tightening.
7. Firestore rules site-scope tightening. Rules plus emulator proof.
8. Storage rules tests. Tests before rule tightening.
9. Storage portfolio media read tightening. Rules plus emulator proof.
10. Route-role metadata source contracts. Tests before role normalization.
11. Role mapping normalization. Web/Functions/Flutter gates.
12. API/callable request validation. Endpoint-by-endpoint.
13. Evidence service boundary extraction. Small vertical slices.
14. Flutter analyzer ratchet batch 1. Dart only.
15. Ops script helper extraction. Dry-run and no-traffic guards pinned.
16. Dependency cleanup. One package family at a time.
17. Full non-mutating release qualification.

## Security Acceptance Criteria

The refactor is successful only when all of these are true:

- No production browser path can initialize with placeholder Firebase client config.
- No external AI provider dependency, import, domain, or egress path is introduced.
- No learner media is readable by unrelated authenticated users.
- No site-scoped collection silently allows missing `siteId` unless explicitly classified as HQ-global or server-owned.
- No client path writes capability mastery or growth directly.
- No parent/guardian route exposes unrelated learner data or educator-only internal notes.
- No live-capable script mutates Firebase/Cloud resources without explicit apply/project confirmation.
- No generated code is manually edited.
- No duplicate logic remains in high-risk test harnesses or workflow renderer utilities without an explicit allowlist entry.
- All release and refactor validation gates pass from the current worktree.

## Evidence-Chain Acceptance Criteria

The refactor must preserve or improve every link in the evidence chain:

1. Admin-HQ setup still defines capability frameworks, rubrics, checkpoints, and progression descriptors.
2. Educator live session workflow still supports under-10-second evidence capture.
3. Learner artifact/reflection/checkpoint/proof flows still persist real evidence.
4. Proof-of-learning still verifies authenticity and AI disclosure where relevant.
5. Rubric/capability mapping remains connected to growth candidate logic.
6. Capability growth remains evidence-derived, not completion-derived.
7. Portfolio items remain linked to artifacts/evidence/proof.
8. Passport/report/guardian outputs keep provenance and honest empty states.
9. Site/Admin dashboards communicate implementation health and evidence coverage without fake confidence.
10. Ops scripts and synthetic data support repeatable demo/UAT/regression flows without live-mutation surprises.

## First Implementation Slice

Start with the lowest-risk, highest-leverage slice:

1. Add a duplicate-symbol inventory script that excludes generated files and classifies duplicates by allowlist.
2. Add a `refactor:baseline` non-mutating gate script.
3. Extract repeated Functions Firestore test mocks into a shared test helper.
4. Run the affected Functions tests, root source contracts, `npm run typecheck`, `npm run lint`, and `git diff --check`.

This makes later refactors safer without changing product behavior or security rules first.

## Complete Execution Matrix

| Workstream | First PR | Main files/surfaces | Must not change | Required gate before merge |
| --- | --- | --- | --- | --- |
| Inventory | Add source ownership report and duplicate report. | `docs`, future `scripts/refactor_*`. | Runtime code, rules, deploy scripts. | `git diff --check`, docs diagnostics. |
| Baseline gates | Add `refactor:baseline` and `refactor:full` local scripts. | `package.json`, possible helper script. | Live deploy behavior, default mutation behavior. | `npm run refactor:baseline` once created. |
| Duplicate allowlist | Add generated duplicate report plus explicit allowlist. | `scripts`, `docs`. | Source renames. | Duplicate report exits clean with allowlisted intentional duplicates. |
| Functions test harness | Extract repeated Firestore mocks from `workflowOps.*.test.ts`. | `functions/src/**.test.ts`, new test helper. | Production Functions handlers. | Affected Functions tests plus `npm --prefix functions run build`. |
| Renderer helpers | Extract repeated renderer `toIso`, `asString`, `formatDate`. | `src/features/workflows/renderers`, utility module. | Route metadata, URL structure, Firestore writes. | Source contracts plus workflow route E2E. |
| Rules test expansion | Add denial tests for missing site scope and parent boundaries. | `jest.rules.config.js`, rules tests. | `firestore.rules` behavior at first. | Rules emulator tests fail for missing protections before rules tighten. |
| Firestore hardening | Enforce explicit site/global/server-owned helpers. | `firestore.rules`, rules tests. | Canonical synthetic data shape unless migrated first. | Firestore rules and evidence-chain emulator tests. |
| Storage hardening | Add storage tests, then tighten portfolio media reads. | `storage.rules`, storage tests. | Upload path names and file compatibility. | Storage emulator tests and role denial proof. |
| Role metadata | Generate protected route-role matrix. | `workflowRoutes.ts`, protected route tests, Flutter gates. | Public URLs, locale routing. | Route source contracts and role E2E audit. |
| Config/secrets | Centralize env parsing and ratchet secret scan. | config modules, `scripts/secret_scan.py`. | Browser fail-closed behavior. | Secret scan, AI internal-only, typecheck. |
| API validation | Add request schemas endpoint by endpoint. | `app/api/**`, Functions callables. | Response contracts unless versioned. | Endpoint tests and Functions build. |
| Evidence services | Extract capture/verify/interpret/communicate boundaries. | `src/lib`, `functions/src`, feature modules. | Mastery semantics and provenance fields. | Evidence-chain source and emulator tests. |
| Flutter analyzer | Ratchet analyzer rules in small batches. | `apps/empire_flutter/app/analysis_options.yaml`, Dart code. | Native signing/provisioning. | `flutter analyze`, `flutter test`. |
| Ops scripts | Extract dry-run/apply/project confirmation helpers. | `scripts/**`. | No-traffic, rollback, release-gate safety. | Synthetic dry-run, operator release proof. |
| Dependency hardening | Remove unused deps and pin critical updates by family. | package manifests, lockfiles, pubspecs. | Multiple major runtime families at once. | Dependency drift, build, typecheck. |
| Final qualification | Run full local non-mutating proof. | All touched surfaces. | GO/Gold claims without release evidence. | Full validation ladder below. |

## No-Break Change Protocol

Every implementation PR should follow this sequence:

1. Baseline: capture `git status --short`, `git diff --check`, and the relevant passing test command before editing.
2. Characterize: add or identify tests that describe current behavior before moving code.
3. Move only: if a PR extracts or renames code, avoid behavior changes in the same PR.
4. Wire through one call site first when possible, then expand mechanically after tests pass.
5. Keep compatibility shims for public exports, Cloud Function names, URLs, Firestore fields, and Storage paths until all callers are migrated.
6. Add denial tests before security tightening, then make the tightening pass.
7. Run the smallest focused gate first, then the broader gate.
8. Record any intentionally deferred cleanup in the plan or tracking issue, not as vague TODOs in production code.
9. Do not update Gold/readiness claims unless evidence was produced in that same worktree.
10. Roll back by reverting the PR; avoid migrations that cannot be rolled back independently.

## Duplicate Function And Variable Control Specification

The goal is not zero repeated words. The goal is zero unowned duplicate logic in security-critical or evidence-critical paths.

### Duplicate Categories

| Category | Policy | Examples |
| --- | --- | --- |
| Public API duplicate | Forbidden unless versioned and documented. | Duplicate route handlers, callable names, exported service functions with same responsibility. |
| Local component handler duplicate | Allowed. | `handleSubmit`, `onSave`, `formatLabel` inside unrelated components. |
| Generated duplicate | Ignored. | Data Connect generated JS/TS/DTS output. |
| Test harness duplicate | Consolidate when repeated in three or more files. | Firestore mocks, callable auth fixtures, E2E harness window types. |
| Script boilerplate duplicate | Consolidate when it controls live mutation, secrets, or project selection. | `parseArgs`, `main`, project/env confirmation. |
| Renderer utility duplicate | Consolidate when identical formatting/parsing appears in three or more workflow renderers. | `toIso`, `asString`, `formatDate`. |
| Security logic duplicate | Forbidden unless one source delegates to the canonical source. | role checks, site checks, consent checks, AI provider checks. |

### Duplicate Report Requirements

Create a script that emits JSON with:

- symbol name
- kind: function, const arrow function, type, interface, class, Dart class/function
- file list
- generated/test/runtime classification
- allowlist status
- recommended action: keep, extract, rename, delete, investigate

The script must exclude:

- `node_modules/**`
- `.next/**`
- `functions/lib/**`
- `build/**`
- Data Connect generated directories
- generated Dart/Flutter files

The allowlist should be explicit and reviewed. A proposed shape:

```json
{
  "allowedDuplicateSymbols": [
    {
      "name": "WorkflowPage",
      "reason": "Intentional thin Next.js route wrapper pattern",
      "scope": "app/[locale]/**/page.tsx"
    }
  ]
}
```

### Duplicate Exit Criteria

- No duplicate security helpers for role, site, consent, AI provider, or Firebase config decisions.
- No duplicate live-mutation script confirmation logic.
- No repeated Firestore mock implementation across more than one Functions test helper.
- No repeated renderer date/string helpers across more than one workflow utility module.
- Every allowed duplicate has a documented reason.

## Security Hardening Matrix

| Security domain | Current risk to remove | Required end state | Proof |
| --- | --- | --- | --- |
| Identity and roles | Role names and gates are spread across rules, web metadata, scripts, and Flutter. | One canonical role mapping with source-contract checks across surfaces. | Route-role matrix, role E2E audit, rules tests. |
| Site isolation | Some Firestore helpers allow missing `siteId`. | Site-scoped collections require site scope; explicit exceptions for HQ-global/server-owned docs. | Emulator allow/deny matrix. |
| Parent/guardian privacy | Parent-safe boundaries depend on collection-specific logic. | Parents see only linked learner projections and consent-safe evidence. | Parent denial tests and guardian E2E. |
| Portfolio media | Any authenticated user can currently read portfolio media. | Owner/linked guardian/same-site educator/site/HQ or explicit consent only. | Storage emulator denial tests. |
| API validation | Request validation is not guaranteed uniformly. | Zod or structured validation at every API/callable boundary. | Endpoint inventory and tests. |
| Secrets | Secret scan catches important but limited patterns. | Expanded tracked-file scan and no client-build secrets. | `npm run qa:secret-scan`, CI check. |
| AI boundary | MiloOS must remain internal support. | No external provider dependencies/imports/domains/egress; no direct mastery writes. | `npm run ai:internal-only:all`, MiloOS tests. |
| Synthetic data | Live-capable scripts can be risky if defaults are accepted silently. | Dry-run default, explicit `--apply`, explicit project confirmation. | Synthetic dry-run/apply tests and script proof. |
| Cloud Run release safety | Live deploy commands can create revisions/tags. | No-traffic and promotion commands remain separate; release-gate stays non-deploying. | Operator release proof and state probe. |
| Telemetry/privacy | Telemetry may drift into PII if not enforced. | No tokens, secrets, unrelated learner data, or raw private text in logs. | Telemetry audits and privacy tests. |
| Dependencies | Broad upgrades can alter runtime auth/routing/build behavior. | Dependency changes grouped by package family with regression proof. | Dependency drift and build gates. |
| Flutter offline/security | App analyzer is not as strict as parent config. | Analyzer ratchet and role/offline tests. | Flutter analyze/test. |

## Full Validation Ladder

Run these in order as refactor scope expands:

1. Formatting and diff hygiene:

```bash
git diff --check
```

2. Web static gates:

```bash
npm run typecheck
npm run lint
```

3. Focused source contracts:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
```

4. Security policy gates:

```bash
npm run qa:secret-scan
npm run ai:internal-only:all
npm run qa:workflow:no-mock
```

5. Functions gates:

```bash
npm --prefix functions run build
npm --prefix functions run test -- --runInBand
```

6. Rules and evidence emulator gates:

```bash
npm run test:integration:rules
npm run test:integration:evidence-chain
```

7. Synthetic data proof:

```bash
npm run seed:synthetic-data:dry-run
```

8. Flutter gates:

```bash
cd apps/empire_flutter/app
flutter analyze --no-fatal-infos
flutter test
```

9. Browser proof for touched workflows:

```bash
npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts
npx playwright test test/e2e/workflow-routes.e2e.spec.ts
npx playwright test test/e2e/miloos-cross-role-golden-path.e2e.spec.ts
```

10. Full non-mutating release qualification:

```bash
./scripts/deploy.sh release-gate
```

Do not run live Cloud Run, Firebase deploy, repair, seed apply, or traffic commands as part of routine refactor validation.

## Refactor Backlog By Surface

### Web App

- Consolidate workflow renderer utilities after source contracts pin behavior.
- Add protected-route metadata coverage tests for every `app/[locale]/(protected)` page.
- Centralize client-safe Firebase config and preserve browser fail-closed behavior.
- Ensure report, passport, guardian, and portfolio surfaces always show provenance and honest empty states.

### Firebase Functions

- Extract repeated Firestore test harness utilities first.
- Add request schema validation to callables and HTTP handlers.
- Centralize actor/site context resolution.
- Keep evidence/growth updates server-owned and provenance-backed.
- Keep MiloOS support writes separate from capability mastery/growth writes.

### Firestore Rules

- Add collection classification before changing helpers.
- Add missing-`siteId` denial tests for production site-scoped collections.
- Add parent/guardian denial tests for raw evidence, AI logs, reflections, portfolio, and reports.
- Replace permissive fallback helpers with explicit site/global/server-owned helpers.

### Storage Rules

- Add emulator tests if absent.
- Tighten portfolio media reads to relationship/consent scope.
- Preserve file size/type protections.
- Keep partner deliverables permission-safe and outside blanket claims unless separately proven.

### Scripts And Ops

- Extract common CLI parsing and project confirmation.
- Make all mutation scripts dry-run by default.
- Require both `--apply` and explicit project ID for live mutation.
- Keep no-traffic deploy, promotion, and rollback as separate deliberate actions.

### Flutter

- Adopt stricter analyzer rules in batches.
- Add or reinforce role gate tests and offline evidence queue tests.
- Keep native signing/provisioning outside logic refactors.
- Ensure mobile classroom workflows preserve tap-minimal evidence capture.

### Compliance Service

- Preserve unauthenticated denial by default.
- Add request validation and audit context for operator endpoints.
- Keep compliance scan/report output free of secrets and learner PII.

### Shared Packages And Generated Code

- Do not manually edit generated Data Connect code.
- Keep shared package changes backward compatible until all consumers migrate.
- Add package-level tests before extracting cross-surface utilities.

## Required Tracking Artifacts

Create these before implementation begins:

1. `docs/REPO_SURFACE_OWNERSHIP_MAP_MAY_2026.md` - source ownership and risk classification.
2. `docs/REPO_DUPLICATE_SYMBOL_REPORT_MAY_2026.md` - duplicate report with allowlist decisions.
3. `docs/REPO_SECURITY_HARDENING_MATRIX_MAY_2026.md` - Firestore, Storage, API, AI, secrets, telemetry checklist.
4. `docs/REPO_REFACTOR_VALIDATION_LOG_MAY_2026.md` - command evidence for each phase.

These can be generated or hand-maintained, but they must not replace tests. They are navigation aids for the refactor program.

## First Ten Implementation Tickets

1. Add duplicate-symbol inventory script and allowlist file.
2. Add `refactor:baseline` script with non-mutating local gates.
3. Generate the source ownership map.
4. Extract Functions Firestore test harness helpers.
5. Add route-role metadata coverage test for protected web routes.
6. Add Firestore missing-`siteId` denial tests without changing rules yet.
7. Add Storage emulator tests for portfolio media read boundaries.
8. Expand secret scan patterns and tighten docs allowlists to redacted examples.
9. Extract workflow renderer date/string utilities with focused tests.
10. Add script mutation confirmation helper and migrate one low-risk dry-run/apply script.

## Final Definition Of Done For The Refactor Program

The repo-wide refactor is complete only when:

- The ownership map, duplicate report, security matrix, and validation log are current.
- Root, Functions, rules, Flutter, AI, secrets, no-mock, telemetry, dependency, synthetic dry-run, and focused E2E gates pass.
- Firestore and Storage rules have explicit least-privilege tests for site, role, guardian, and media boundaries.
- All live-capable scripts default to dry-run or require explicit apply/project confirmation.
- Duplicate security logic is removed or delegates to one canonical source.
- Intentional duplicate names are allowlisted with reasons.
- Generated code remains untouched.
- Evidence-chain workflows still pass capture, verify, interpret, and communicate proof.
- No Gold/readiness doc claims are broadened without current evidence.