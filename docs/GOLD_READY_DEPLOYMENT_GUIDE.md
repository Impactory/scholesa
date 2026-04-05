# GOLD_READY_DEPLOYMENT_GUIDE.md

**Last verified: 2026-04-05**
**Branch: main**
**Purpose:** Living reference for every platform surface, current blocker inventory, and exact steps to reach Gold across Next.js web, Flutter web/native, Firebase Functions, and the compliance operator. Use this file as the single source of truth when resuming work from any machine.

---

## Platform Overview

Scholesa is a **capability-first evidence platform** for K-9 learning studios. Every deployment decision is subordinate to one test: does this surface correctly capture, verify, interpret, or communicate evidence of learner capability?

### Surfaces and Deploy Targets

| Surface | Target | Dockerfile | Deploy Command |
|---------|--------|-----------|----------------|
| Next.js web (primary) | Google Cloud Run | `Dockerfile` | `./scripts/deploy.sh primary-web` |
| Flutter WASM web | Google Cloud Run | `Dockerfile.flutter` | `./scripts/deploy.sh flutter-web` |
| Firebase Functions v2 | Firebase | (built-in) | `firebase deploy --only functions` |
| Compliance operator | Google Cloud Run | `Dockerfile.compliance` | `./scripts/deploy.sh compliance-operator` |
| Flutter iOS | TestFlight | `scripts/apple_release_ci.sh` | `./scripts/deploy.sh flutter-ios` |
| Flutter Android | Google Play | `scripts/android_release_ci.sh` | `./scripts/deploy.sh flutter-android` |
| Flutter macOS | Direct | — | `./scripts/deploy.sh flutter-macos` |

Firebase project: `studio-3328096157-e3f79` (all surfaces use same project).

---

## Current State (2026-04-05)

### Verdict: Beta ready. Not gold ready.

| Check | Status | Detail |
|-------|--------|--------|
| Web TypeScript | **PASS** | `npm run typecheck` — clean |
| Web lint | **FAIL** | 27 errors in `functions/src/index.ts`, `functions/src/voiceSystem.ts`, `app/layout.tsx`, `src/components/*` |
| Web Jest | **FAIL** | 13 failures in 5 suites — evidence chain schema, models, route parity, legacy branding guard |
| Functions build | **FAIL** | 7 TS errors in `functions/src/index.ts` — blocks Firebase Functions deploy |
| Flutter analyze | Unknown — run `flutter analyze` from `apps/empire_flutter/app/` |
| Flutter tests | **FAIL (7)** | 814 pass / 7 fail — **must run from `apps/empire_flutter/app/`** |
| CI/CD | Present | `.github/workflows/ci.yml` — runs full suite on push to main |
| Git state | **REBASE IN PROGRESS** | Must `git rebase --continue` before pushing |

---

## Immediate Blockers (Must Fix Before Any Deploy)

### 1. Git Rebase In Progress

```bash
# Verify state
git status

# Complete the rebase (all conflicts are resolved — just needs continuation)
git rebase --continue

# Push to remote
git push origin main
```

### 2. Functions TypeScript Errors — `functions/src/index.ts`

7 errors blocking `firebase deploy --only functions`:

```
Line 2956, 2985: Cannot redeclare block-scoped variable 'capabilityId'
  → Wrap both switch-case blocks in { } to create block scope

Line 2986: '??' and '||' operations cannot be mixed without parentheses
  → Add parentheses: (a ?? b) || c

Line 8061, 8406: Type '"siteLead"' / '"admin"' not assignable to type 'Role'
  → The Role union type does not include 'siteLead' or 'admin'
  → Check src/types/schema.ts for Role definition and add missing roles
    OR change 'siteLead' → 'site' and 'admin' → 'hq' if those are the correct roles
```

Fix command:
```bash
npm --prefix functions run build  # must exit 0 before deploy
```

### 3. Web Jest Failures (13 tests, 5 suites)

| Suite | Failure Type |
|-------|-------------|
| `evidence-chain.test.ts` | Schema contracts — `progressionDescriptors`, `RubricTemplate`, `RubricTemplateCriterion` types missing or misnamed |
| `evidence-chain-components.test.ts` | `EvidenceRecord.sessionOccurrenceId` field missing or renamed |
| `models.test.ts` | Site scoping, pillar encoding, accountability cycle fields |
| `assistant-legacy-branding-guard.test.ts` | Legacy assistant branding string found in active code paths |
| `web-route-parity.test.ts` | Flutter route registry diverged from web route definitions |

Fix command:
```bash
npm test  # must exit 0 before deploy
```

### 4. Web Lint Errors (27 errors)

Files with errors: `functions/src/index.ts`, `functions/src/voiceSystem.ts`, `functions/src/workflowOps.ts`, `app/layout.tsx`, `src/components/*`, `scripts/import_synthetic_data.js`

Common errors: `no-case-declarations`, `quotes`, `@typescript-eslint/no-require-imports`, unused variables.

Fix command:
```bash
npm run lint:fix  # auto-fixes 8 errors
npm run lint      # address remaining 19 manually
```

---

## Gold Certification Blockers

These must be resolved for Gold status. They are listed in priority order (evidence chain first).

### GOLD-1: Functions Build Must Be Clean

The `applyRubricToEvidence` callable is the most critical write in the system — it creates `capabilityGrowthEvents` and upserts `capabilityMastery`. It cannot deploy with TypeScript errors in the same file.

**Owner:** Fix the 7 errors in `functions/src/index.ts` (see Immediate Blockers section).

### GOLD-2: Evidence Chain Test Suite — All Green

The evidence chain schema contracts (`evidence-chain.test.ts`) define the platform contract. Failures here mean the deployed code does not match what the tests assert.

Missing or misaligned types to check in `src/types/schema.ts`:
- `Capability.progressionDescriptors`
- `ProgressionDescriptors` (four levels: Beginning/Developing/Proficient/Advanced)
- `RubricTemplate` and `RubricTemplateCriterion`
- `EvidenceRecord.sessionOccurrenceId`

### GOLD-3: Route Breadth — 52 Routes, 4 Full-Flow Verified

Current full-flow certified routes (all 9 gates proven):

| Route | Certified | File |
|-------|-----------|------|
| `/hq/feature-flags` | 2026-03-21 | `test/federated_learning_prototype_workflow_test.dart` |
| `/educator/attendance` | 2026-03-31 | `test/attendance_placeholder_actions_test.dart` |
| `/site/sessions` | 2026-03-31 | `test/site_sessions_page_test.dart` |
| `/site/provisioning` | 2026-03-31 | `test/provisioning_page_test.dart` |

**Gold requires:** All 52 routes certified or explicitly deferred with written rationale.

The 9 gates every route must prove:
- **A** State truth (empty, stale, failure states visible and honest)
- **B** Real mutation (primary write persists)
- **C** Authoritative reload (UI reflects persisted state after save)
- **D** Recovery (user can retry from failure in-surface)
- **E** Scope/permission (role and site boundaries enforced and visible)
- **F** Accessibility (controls/warnings reachable by assistive tech)
- **G** Telemetry (critical actions emit auditable trace)
- **H** Educational truth (no capability/mastery claim without evidence provenance)
- **I** AI transparency (no AI output presented as verified learner proof)

Reference: `docs/FULL_FLOW_CERTIFICATION_GATE_2026-03-21.md`, `docs/FULL_FLOW_GATE_WORKSHEET_2026-03-21.md`

### GOLD-4: HQ Capability Framework Editor (Missing)

Admin-HQ cannot define capabilities, rubrics, or progression descriptors from any UI. The `capabilities` collection must be seeded manually or via script. Without this, the evidence chain cannot be bootstrapped by a real school.

**What is needed:**
- `hq/curriculum` page must be upgraded from generic WorkflowRoutePage to a purpose-built capability editor
- Fields: `name`, `pillar`, `progressionDescriptors` (4 levels), `rubricTemplates`
- Write to `capabilities` Firestore collection (typed in `src/types/schema.ts`)
- Flutter: `lib/modules/hq_admin/capability_framework_page.dart` exists — verify it is wired to real Firestore writes

**Reference:** `src/components/evidence/EducatorEvidenceCapture.tsx` reads from `capabilities` — this is the downstream consumer. If HQ can't write, the educator can't read real capabilities.

### GOLD-5: Rubric Template Builder (Missing)

Educators apply rubrics but HQ cannot define rubric templates via UI. The `applyRubricToEvidence` callable creates `rubricApplications` with criterion scores — the criteria must come from a real `RubricTemplate`.

**What is needed:**
- Rubric template CRUD UI (HQ only)
- `RubricTemplate` and `RubricTemplateCriterion` types in `src/types/schema.ts` (tests failing on these)
- Write to Firestore, readable by `RubricReviewPanel.tsx`

### GOLD-6: Passport/Credential Wallet (Missing)

Learners have no dedicated Passport surface. `learner_credentials_page.dart` is display-only. The Passport is the portable output of the evidence chain — without it, the platform cannot communicate capability to external parties.

**What is needed:**
- Passport surface with: verified capability claims, evidence provenance per claim, mastery level labels, share/export path
- `ideationPassport.claims` already exists on `parent_portfolio_page.dart` (read path exists)
- Need: claim issuance trigger (from verified `capabilityMastery` records)

### GOLD-7: Flutter Offline Evidence Queue (Gap)

The offline queue (`lib/offline/offline_queue.dart`) has 10 OpTypes but evidence operations are **not reliably offline-safe**. The `CapabilityGrowthEngine` makes direct Firestore calls without offline queue integration.

**Current OpTypes (10):** attendanceRecord, presenceCheckin, presenceCheckout, incidentSubmit, messageSend, attemptSaveDraft, observationCapture, rubricApplication, capabilityGrowthEvent, checkpointVerification

**Gap:** `CapabilityGrowthEngine.processRubricApplication()` must route through the offline queue, not direct Firestore, when offline.

**Reference:** `apps/empire_flutter/app/lib/services/capability_growth_engine.dart`

### GOLD-8: Native Distribution Proof

No verified TestFlight (iOS) or Google Play (Android) upload exists. Gold requires end-to-end native distribution proof, not just a successful local build.

**Scripts exist:** `scripts/apple_release_ci.sh`, `scripts/android_release_ci.sh`
**What is needed:**
- Successful `flutter build ipa` + upload to TestFlight via Fastlane or `xcrun altool`
- Successful `flutter build appbundle` + upload to Google Play Internal Track
- Screenshot evidence saved in `docs/` as part of release validation

---

## Deployment Stages

### Stage 1 — Fix All Blockers (Pre-Deploy Gate)

```bash
# 1. Complete in-progress git rebase
git rebase --continue

# 2. Fix functions/src/index.ts TypeScript errors
npm --prefix functions run build   # must be clean

# 3. Fix web Jest failures
npm test                           # must be clean

# 4. Fix lint
npm run lint:fix && npm run lint   # reduce to 0 errors

# 5. Run full local gate
npm run flow:platform:gates

# 6. Flutter tests from correct directory
cd apps/empire_flutter/app && flutter test   # 814 pass required
```

### Stage 2 — Firebase Functions Deploy

```bash
firebase deploy --only functions
# This runs: npm --prefix functions run build → gen2 verify → deploy
```

Verify after deploy:
```bash
firebase functions:log --limit 20
# Confirm: applyRubricToEvidence, buildParentLearnerSummary are alive
```

### Stage 3 — Firestore Rules Deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
# Verify rules enforce RBAC + site-scoping before any web deploy
```

### Stage 4 — Next.js Primary Web Deploy

```bash
./scripts/deploy.sh primary-web
# or with traffic rehearsal first:
CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh primary-web
```

Required env vars: `GCP_PROJECT_ID`, `GCP_REGION`, `CLOUD_RUN_SERVICE`

Smoke test after deploy:
```bash
# Login → educator/attendance → create observation → verify persists
# Login → hq/feature-flags → toggle flag → verify reload
# Login → site/sessions → create session → verify reload
```

### Stage 5 — Flutter Web Deploy

```bash
./scripts/deploy.sh flutter-web
# or with rehearsal:
CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh flutter-web
```

Required env vars: `GCP_PROJECT_ID`, `GCP_REGION`, `CLOUD_RUN_FLUTTER_SERVICE`

Build command used internally: `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run`

> Note: No WASM build — `flutter_tts` is not WASM-clean.

Smoke test:
```bash
# Login as educator → educator/attendance → mark attendance → verify
# Login as learner → learner/portfolio → verify portfolio items load
# Login as parent → parent/portfolio → verify passport claims visible
```

### Stage 6 — Compliance Operator Deploy

```bash
./scripts/deploy.sh compliance-operator
```

Required env vars: `GCP_PROJECT_ID`, `GCP_REGION`, `CLOUD_RUN_COMPLIANCE_SERVICE`

### Stage 7 — Full Platform Smoke Test

```bash
# Run post-deploy smoke test
npm run compliance:gate            # Compliance checks
npm run qa:vibe-telemetry:blockers # Telemetry blockers
```

Manually verify the evidence chain end-to-end:
1. HQ creates/seeds a capability in the `capabilities` collection
2. Educator logs an observation via `/educator/evidence` → evidenceRecord written
3. Educator applies rubric via RubricReviewPanel → `applyRubricToEvidence` callable fires → `capabilityGrowthEvents` + `capabilityMastery` written
4. Learner views portfolio → portfolio items show linked evidence
5. Parent views child → sees passport claims with capability titles from `capabilities` collection

---

## Gold Certification Worksheet

Track progress here. Update as each item is resolved.

| Item | Status | Target Date | Owner |
|------|--------|-------------|-------|
| GOLD-0a: Git rebase complete | OPEN | — | — |
| GOLD-0b: Functions TS clean | OPEN | — | — |
| GOLD-0c: Web Jest clean | OPEN | — | — |
| GOLD-0d: Web lint clean | OPEN | — | — |
| GOLD-1: Functions deploy live | OPEN | — | — |
| GOLD-2: Evidence chain test suite green | OPEN | — | — |
| GOLD-3: All 52 routes full-flow certified | OPEN (4/52 done) | — | — |
| GOLD-4: HQ capability framework editor | OPEN | — | — |
| GOLD-5: Rubric template builder | OPEN | — | — |
| GOLD-6: Passport/credential wallet | OPEN | — | — |
| GOLD-7: Offline evidence queue coverage | OPEN | — | — |
| GOLD-8: Native distribution proof (iOS) | OPEN | — | — |
| GOLD-8: Native distribution proof (Android) | OPEN | — | — |

---

## Key Files Quick Reference

| File | Purpose |
|------|---------|
| `apps/empire_flutter/app/lib/services/capability_growth_engine.dart` | Most critical service — evidence chain engine |
| `apps/empire_flutter/app/lib/domain/models.dart` | 7586-line Flutter model file — all data contracts |
| `apps/empire_flutter/app/lib/domain/repositories.dart` | Firestore CRUD repositories |
| `apps/empire_flutter/app/lib/router/app_router.dart` | GoRouter — 52 routes, all role-gated |
| `apps/empire_flutter/app/lib/offline/offline_queue.dart` | Hive offline queue (10 OpTypes) |
| `apps/empire_flutter/app/lib/offline/sync_coordinator.dart` | Offline sync — exhaustive switch on all OpTypes |
| `apps/empire_flutter/app/lib/runtime/bos_service.dart` | BOS/MIA Cloud Functions wrapper |
| `src/types/schema.ts` | TypeScript canonical type definitions — do not diverge from Flutter models |
| `src/lib/routing/workflowRoutes.ts` | 58 web route definitions + role access |
| `src/components/evidence/EducatorEvidenceCapture.tsx` | Purpose-built educator evidence UI |
| `src/components/evidence/RubricReviewPanel.tsx` | Rubric scoring panel — calls `applyRubricToEvidence` |
| `src/lib/capabilities/useCapabilities.ts` | Hook: reads from `capabilities` collection |
| `functions/src/index.ts` | All Firebase callables (230KB+) — currently has TS errors |
| `functions/src/bosRuntime.ts` | BOS/MIA state machine |
| `firestore.rules` | RBAC Firestore security rules |
| `scripts/deploy.sh` | Full-stack deploy entry point |
| `Dockerfile` | Next.js web container |
| `Dockerfile.flutter` | Flutter web container |
| `Dockerfile.compliance` | Compliance operator container |
| `.github/workflows/ci.yml` | Full CI suite — must pass before merge |
| `docs/FULL_HONESTY_AUDIT_2026-03-19.md` | Route-by-route honesty classification |
| `docs/FULL_FLOW_CERTIFICATION_GATE_2026-03-21.md` | 9-gate certification definition |
| `docs/FULL_FLOW_GATE_WORKSHEET_2026-03-21.md` | Per-route gate worksheet |

---

## Schema Integrity Rules

These rules must never be broken:

1. **Do not write `capabilityTitles` to Firestore.** Titles were removed from `PortfolioItem` schema. Resolve from `capabilities` collection via `capabilityIds`. Reference: `src/types/schema.ts`.
2. **`capabilityGrowthEvents` is append-only.** Never update or delete. Only create.
3. **`proofOfLearningStatus`** has exactly 4 values: `not-available`, `missing`, `partial`, `verified`.
4. **Mastery levels** display as: Beginning / Developing / Proficient / Advanced (not "Level X/4").
5. **`applyRubricToEvidence`** must run in a Firestore batch — the rubricApplication, growthEvents, mastery upsert, and evidenceRecord link are all-or-nothing.
6. **AI output must never be presented as verified learner proof.** Any AI-generated content requires disclosure (Gate I).

---

## Environment Setup (Any Machine)

```bash
# Prerequisites: Node.js 24, Flutter stable, Firebase CLI, Java 21

# 1. Clone / pull
git clone https://github.com/Impactory/scholesa.git
cd scholesa

# 2. Install web deps
npm ci

# 3. Install functions deps
npm --prefix functions ci

# 4. Install Flutter deps
cd apps/empire_flutter/app && flutter pub get && cd ../../..

# 5. Copy env template
cp .env.example .env.local

# 6. Start local emulators
firebase emulators:start

# 7. Start web dev server
npm run dev

# Verify Flutter tests (MUST run from flutter app directory)
cd apps/empire_flutter/app && flutter test
```

---

## Release Policy

- **Big-bang only.** No canary or progressive rollouts.
- **Traffic rehearsal first:** `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh web` — validates Docker build and Cloud Run deploy without shifting traffic.
- **All CI checks must pass** before merge to main.
- **Do not deploy if evidence chain end-to-end tests are failing.** A broken portfolio display after educator review erodes trust more than no deploy.
- **Native distribution:** Do not declare iOS or Android gold without a verified TestFlight or Google Play Internal upload screenshot saved in `docs/`.
