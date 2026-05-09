# GOLD_READY_DEPLOYMENT_GUIDE.md

**Last verified: 2026-05-09**
**Branch: main**
**Purpose:** Living reference for every platform surface, current blocker inventory, and exact steps to reach Gold across Next.js web, Flutter web/native, Firebase Functions, and the compliance operator. Use this file as the single source of truth when resuming work from any machine.

---

## Platform Overview

Scholesa is a **capability-first evidence platform** for K-12 schools and learning studios. Every deployment decision is subordinate to one test: does this surface correctly capture, verify, interpret, or communicate evidence of learner capability?

### Surfaces and Deploy Targets

| Surface | Target | Dockerfile | Deploy Command |
|---------|--------|-----------|----------------|
| Next.js web (primary) | Google Cloud Run | `Dockerfile` | `./scripts/deploy.sh primary-web` |
| Flutter WASM web | Google Cloud Run | `Dockerfile.flutter` | `./scripts/deploy.sh flutter-web` |
| Firebase Functions v2 | Firebase | (built-in) | `firebase deploy --only functions` |
| Compliance operator | Google Cloud Run | `Dockerfile.compliance` | `./scripts/deploy.sh compliance-operator` |
| Flutter iOS | TestFlight | `scripts/apple_release_ci.sh`, `.github/workflows/apple-release.yml` | `./scripts/deploy.sh flutter-ios` |
| Flutter Android | Google Play | `scripts/android_release_ci.sh`, `.github/workflows/android-release.yml` | `./scripts/deploy.sh flutter-android` |
| Flutter macOS | Developer ID notarization | `scripts/macos_release_ci.sh`, `.github/workflows/macos-release.yml` | `./scripts/deploy.sh flutter-macos` |

Firebase project: `studio-3328096157-e3f79` (all surfaces use same project).

---

## Current State (2026-05-09)

### Verdict: Web/Cloud Run Gold GO. Native-channel distribution not Gold yet.

The current authoritative packet is `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md`, with the operator checklist in `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md`. This guide is the quick deployment reference for that packet.

| Check | Status | Detail |
|-------|--------|--------|
| Web/Cloud Run scope | **GO** | Release owner accepted traffic-pinning proof as the final release-control substitute; production traffic remains pinned while the no-traffic rehearsal evidence is recorded. |
| Web TypeScript | **PASS** | `npm run typecheck` passes. |
| Web lint | **PASS** | `npm run lint` passes. |
| Web Jest | **PASS** | May 9 refresh passed full Jest at 40 suites / 597 tests; focused Gold source-contract runs pass at 192 tests. |
| Production web build | **PASS** | `npm run build` passed in the final evidence packet. |
| Functions / evidence-chain callables | **PASS for included packet** | MiloOS and evidence-chain callable proofs are recorded in the final signoff packet; May 9 `npm --prefix functions run build` passes. Deploy only through the gated release scripts. |
| Flutter tests | **PASS** | Native build proofs pass the full Flutter gate with `1087` tests. |
| Native local builds | **PASS** | macOS, iOS no-codesign, and Android local release builds are proven. |
| Native distribution | **BLOCKED EXTERNALLY** | TestFlight, Google Play internal, and macOS Developer ID notarization are automated and fail closed, but live proof requires external signing/store credentials. |
| Git state | **NO REBASE BLOCKER OBSERVED** | Use `git status --short --untracked-files=all` before release work; do not assume historical April rebase notes are current. |

---

## Immediate Blockers

### Native-channel distribution credentials and live proof

Native-channel Gold cannot be claimed until all three channels are proven with live distribution evidence:

1. iOS TestFlight upload with App Store Connect verification.
2. Android Google Play internal-track upload with Play Console verification.
3. macOS Developer ID signing, notarization, stapling, and `spctl` assessment.

Current local readiness command:

```bash
./scripts/native_distribution_proof.sh verify
```

Expected current result until external assets are installed: fail closed with missing App Store Connect env, Apple Distribution identity, iOS provisioning profile, Google Play env, Android `key.properties`, and Developer ID Application identity.

Once release credentials are installed, use one guarded proof path:

```bash
SCHOLESA_NATIVE_DISTRIBUTION_CONFIRM=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS \
  ./scripts/native_distribution_proof.sh execute-live
```

or run `.github/workflows/native-distribution-proof.yml` with `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS` after publishing the native GitHub secrets in `docs/GITHUB_ACTIONS_SECRETS.md`.

---

## Gold Certification State

These states are current as of May 9, 2026. Historical March/April audit files should not override this section; verify current state with the commands named below.

### GOLD-1: Web/Cloud Run Release Packet

Status: **GO for included scope**.

Evidence: `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md` records evidence-chain browser proof, site ops proof, source contracts, release safety, Cloud Run no-traffic rehearsals, role browser sweep, partner evidence-facing proof, proof-review routes, index readiness, current theme proof, and traffic-pinning proof.

### GOLD-2: Evidence Chain Tests and Source Contracts

Status: **PASS for current source-contract gate**.

Current focused gate:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand
```

### GOLD-3: Role and Route Proof

Status: **GO for included web/Cloud Run scope**.

The final signoff records learner, educator, guardian, site, HQ, and partner browser sweeps on the rehearsal tag, with partner evidence-facing deliverable persistence and readback. Native app-store release operations remain separate from route proof.

### GOLD-4: Capability, Rubric, Proof, Growth, Portfolio, Passport Chain

Status: **GO for included web/Cloud Run evidence packet**.

The packet records capability evidence chain proof, rubric/growth source contracts, proof-of-learning verification route proof, portfolio/report/passport output coverage, guardian interpretation coverage, and evidence provenance guardrails. Do not convert assignment completion, attendance, XP, or averages into mastery claims.

### GOLD-5: AI Transparency and Internal-Only Policy

Status: **PASS for included scope**.

Current gate:

```bash
npm run ai:internal-only:all
```

MiloOS support/provenance and explain-back proofs are recorded in the final signoff. AI support remains support, not verified learner proof.

### GOLD-6: Flutter Native Buildability

Status: **PASS as local build proof, not distribution proof**.

Recorded local proofs:
- macOS release app: `build/macos/Build/Products/Release/scholesa_app.app` at `137.0MB`.
- iOS no-codesign release app: `build/ios/iphoneos/Runner.app` at `76.3MB`.
- Android release AAB/APK: `56.6MB` AAB and `78.2MB` APK.

### GOLD-7: Native Distribution Readiness Tooling

Status: **PASS as fail-closed tooling**.

Available paths:
- Local preflight: `./scripts/native_distribution_readiness.sh`.
- Local live proof: `./scripts/native_distribution_proof.sh execute-live`.
- CI aggregate proof: `.github/workflows/native-distribution-proof.yml`.
- Secret helpers: `./scripts/set_apple_github_secrets.sh`, `./scripts/set_android_github_secrets.sh`.
- Local signing setup helpers: `./scripts/setup_apple_signing.sh`, `./scripts/setup_android_signing.sh`.

### GOLD-8: Native Distribution Proof

No verified TestFlight (iOS), Google Play internal (Android), or Developer ID notarized macOS distribution proof exists yet. Gold requires end-to-end native distribution proof, not just successful local builds.

**Local scripts exist:** `scripts/apple_release_local.sh`, `scripts/android_release_local.sh`, `scripts/macos_release_local.sh`, `scripts/native_distribution_readiness.sh`, and `scripts/native_distribution_proof.sh`.
**CI workflows exist:** `.github/workflows/apple-release.yml`, `.github/workflows/android-release.yml`, `.github/workflows/macos-release.yml`, and `.github/workflows/native-distribution-proof.yml`.
**What is needed:**
- Successful signed iOS upload to TestFlight through `./scripts/apple_release_local.sh upload_testflight` or `.github/workflows/native-distribution-proof.yml`.
- Successful signed Android App Bundle upload to Google Play internal testing through `./scripts/android_release_local.sh upload_internal` or `.github/workflows/native-distribution-proof.yml`.
- Successful macOS Developer ID signing, notarization, stapling, and `spctl` assessment through `./scripts/macos_release_local.sh sign_notarize_staple` or `.github/workflows/native-distribution-proof.yml`.
- Proof logs or workflow artifacts saved in `docs/native-distribution-proof-<timestamp>/` or attached to the GitHub Actions run, plus release-owner verification in App Store Connect, Google Play Console, and notarization output.

---

## Deployment Stages

### Stage 1 — Verify Current Gates (Pre-Deploy Gate)

```bash
# 1. Confirm there is no unexpected release-blocking git state
git status --short --untracked-files=all

# 2. Verify web source contracts and build hygiene
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand
npm run typecheck
npm run lint

# 3. Verify native distribution readiness boundary
./scripts/native_distribution_proof.sh verify

# 4. Optional full local release gate before a web/Cloud Run release packet
./scripts/deploy.sh release-gate

# 5. Flutter tests from correct directory when refreshing native build proof
cd apps/empire_flutter/app && flutter test
```

`./scripts/native_distribution_proof.sh verify` is expected to fail until external Apple/Google signing and store assets are installed. That failure is not a web/Cloud Run blocker; it is the native-channel Gold boundary.

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
| GOLD-0a: Git rebase complete | CLOSED for current packet; no rebase blocker observed in May 9 working state | 2026-05-09 | Release owner |
| GOLD-0b: Web TypeScript clean | CLOSED; `npm run typecheck` passes | 2026-05-09 | Release owner |
| GOLD-0c: Web Jest/source contracts clean | CLOSED for current source-contract gate; final packet records full Jest pass and focused gate passes | 2026-05-09 | Release owner |
| GOLD-0d: Web lint clean | CLOSED; `npm run lint` passes | 2026-05-09 | Release owner |
| GOLD-1: Included web/Cloud Run release packet | CLOSED / GO for included scope | 2026-05-09 | Release owner |
| GOLD-2: Evidence chain test suite green | CLOSED for included packet and current source-contract gate | 2026-05-09 | Release owner |
| GOLD-3: Role/route proof for included web scope | CLOSED for six-role web cutover and partner evidence-facing proof | 2026-05-09 | Release owner |
| GOLD-4: Capability/rubric/proof/growth/portfolio chain | CLOSED for included evidence packet | 2026-05-09 | Release owner |
| GOLD-5: AI transparency and internal-only policy | CLOSED for included packet | 2026-05-09 | Release owner |
| GOLD-6: Flutter native local build proof | CLOSED as build proof, not distribution proof | 2026-05-09 | Release owner |
| GOLD-7: Native distribution readiness tooling | CLOSED as fail-closed local and CI tooling | 2026-05-09 | Release owner |
| GOLD-8: Native distribution proof (iOS TestFlight) | OPEN — blocked by external App Store Connect, Apple Distribution, and provisioning assets | — | — |
| GOLD-8: Native distribution proof (Android Play internal) | OPEN — blocked by external Google Play and release signing assets | — | — |
| GOLD-8: Native distribution proof (macOS Developer ID notarization) | OPEN — blocked by external App Store Connect and Developer ID assets | — | — |

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
| `functions/src/index.ts` | Firebase callables, including evidence-chain and proof/growth operations |
| `functions/src/bosRuntime.ts` | BOS/MIA state machine |
| `firestore.rules` | RBAC Firestore security rules |
| `scripts/deploy.sh` | Full-stack deploy entry point |
| `Dockerfile` | Next.js web container |
| `Dockerfile.flutter` | Flutter web container |
| `Dockerfile.compliance` | Compliance operator container |
| `.github/workflows/ci.yml` | Full CI suite — must pass before merge |
| `.github/workflows/native-distribution-proof.yml` | Guarded aggregate native distribution proof workflow |
| `scripts/native_distribution_proof.sh` | Guarded local native live proof runner |
| `scripts/native_distribution_readiness.sh` | Aggregate fail-closed native release prerequisite check |
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
- **Native distribution:** Do not declare native-channel Gold without verified TestFlight, Google Play internal, and macOS Developer ID notarization proof captured through `./scripts/native_distribution_proof.sh execute-live` or `.github/workflows/native-distribution-proof.yml` and reviewed by the release owner.
