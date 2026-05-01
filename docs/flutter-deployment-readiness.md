# Flutter Deployment Readiness Report
**Date:** 2026-03-30
**Platform:** Scholesa Empire Flutter App
**Target:** Google Cloud Run (Flutter Web)
**Assessment:** Historical snapshot; superseded by the April 30 / May 1 Flutter-mobile and MiloOS release-gate records

> **Current status note - 2026-05-01**
>
> This report is preserved as a March 30 audit snapshot. It no longer represents the current Flutter/mobile or MiloOS release state.
>
> Current authoritative status lives in:
>
> - `docs/FLUTTER_MOBILE_GOLD_READINESS_PLAN_APRIL_30_2026.md`
> - `docs/FLUTTER_MOBILE_GOLD_READINESS_EXECUTION_CHECKLIST_APRIL_30_2026.md`
> - `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`
> - `docs/MILOOS_GOLD_READINESS_PLAN_APRIL_30_2026.md`
> - `docs/MILOOS_GOLD_READINESS_EXECUTION_CHECKLIST_APRIL_30_2026.md`
>
> The prior hard blockers for Cloud Run deployment path and end-to-end evidence-chain Flutter failures are closed in the current worktree: `scripts/deploy.sh` now includes Cloud Run deployment targets and the non-deploying `./scripts/deploy.sh release-gate`; the validated Flutter/mobile bundle now passes full app-scoped Flutter tests/analyzer, root tests, Firestore rules plus evidence-chain integration in one emulator session, Functions build/verify and split tests, production web build, and diff hygiene. The full Flutter/mobile app still must not be called blanket gold-ready until an approved live or `CLOUD_RUN_NO_TRAFFIC=1` deploy rehearsal passes from the current worktree.

---

## Ground Truth

The Flutter app is in a fundamentally different state than the web platform. Where the web is a generic scaffold wearing evidence chain labels, the Flutter app contains real implementation. The `capability_growth_engine.dart` writes actual Firestore documents. The models are real data contracts. The BOS/MIA integration calls real Cloud Functions. The offline queue uses Hive for real persistence. 760 tests pass.

This changes the question from "does the evidence chain exist" to "is it stable enough to deploy and trust in production."

Historical March 30 answer: **close, but not yet.** The sections below describe the four blockers as they existed at that audit date. For current release status, use the May 1 status note above.

---

## Readiness Scorecard

### Infrastructure

| Item | State | Verdict |
|------|-------|---------|
| Firebase project configured (Android, iOS, Web) | Real | Ready |
| `firebase_options.dart` generated for all platforms | Real | Ready |
| `flutter analyze` | 0 errors, 24 infos/warnings | Ready |
| Flutter web build script (`scripts/deploy.sh`) | Historical March 30 state: builds only, no Docker, no Cloud Run push. Current state: scripted Cloud Run targets and `release-gate` exist. | Historical blocker, closed in current worktree except approved deploy rehearsal |
| Dockerfile for Cloud Run | Historical March 30 state: did not exist. Current state: repo includes Cloud Run Dockerfiles for web surfaces. | Historical blocker, superseded |
| CI/CD pipeline | Historical March 30 state: not assessed in this report. Current state should be read from repo workflows and current release docs. | Historical blocker, superseded |
| Environment variable strategy (`--dart-define`) | Defined in `app_config.dart` | Ready |
| Emulator switching for dev/prod | Real | Ready |

### Test Suite (at audit date)

| Category | Pass | Fail | Verdict |
|----------|------|------|---------|
| Core logic (auth, router, services, offline) | Passing | 0 | Ready |
| Educator workflows | Passing | 3 | Needs fix |
| Learner workflows (non-golden) | Mostly passing | 1 critical | **Needs fix** |
| Parent workflows | Mostly passing | 2 critical | **Needs fix** |
| Federated learning prototype | — | ~19 | Isolated, not blocking |
| Dashboard CTA regression | — | 5 | Needs fix |
| Localization (zh-CN, zh-TW, dark theme) | — | 5 | Needs fix |
| HQ admin surface | — | 2 | Needs fix |
| Golden pixel diffs | — | 15 | Run `--update-goldens` |
| **Total** | **760** | **54** | |

### Evidence Chain (Flutter)

| Step | Implementation | Test Coverage | Status |
|------|---------------|---------------|--------|
| Educator observation (ObservationModel) | Models + repositories exist | Limited | Partial |
| Evidence record capture | `captureEvidence()` in growth engine | Indirect | Real |
| Rubric application | `RubricApplicationModel` + `educator_mission_review_page` | Review page tests pass | Real |
| Capability growth event | `processRubricApplication()` writes to Firestore | Covered | **Real, working** |
| Mastery update | Inside growth engine, append-safe | Covered | **Real, working** |
| Portfolio enrichment | `_enrichPortfolioItem()` via direct Firestore | `_portfolioItemRepo` unused | Partial |
| Next steps generation | `_generateNextSteps()` writes `LearnerNextStepModel` | Covered | Real |
| Portfolio display of reviewed artifacts | End-to-end with educator review | **Failing** | **Broken** |
| Parent portfolio view of reviewed evidence | End-to-end workflow | **Failing** | **Broken** |
| Passport / credential claims (parent view) | End-to-end workflow | **Failing** | **Broken** |
| Offline queue coverage for evidence ops | Only 6 op types (none are evidence) | — | **Gap** |
| Proof-of-learning bundle | `ProofBundleModel` exists | Covered | Real |
| Checkpoint verification | `CheckpointModel`, `mvl_gate_widget` | Covered | Real |

---

## The Four Blockers (Historical March 30 Snapshot)

### Blocker 1 — No deployment path to Cloud Run (closed in current worktree)

`scripts/deploy.sh` runs `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run` and stops. No Docker build, no image tag, no `gcloud run deploy`, no staging step, no rollback plan.

Missing:
- A `Dockerfile` that copies Flutter web build into an nginx container
- Cloud Run service configuration (service name, region, memory, concurrency)
- `gcloud run deploy` wired into `scripts/deploy.sh`
- Environment-specific deploy targets (staging vs production)
- A health check endpoint

Note: `flutter_tts` and voice stack are not WASM-clean (noted in deploy.sh). WASM builds intentionally disabled. Cloud Run with JS build path is fine — known trade-off, not a blocker.

**Historical severity: Hard blocker. Current status: closed for local release-gate and scripted Cloud Run deploy path; live/no-traffic deploy rehearsal still required before blanket mobile gold.**

---

### Blocker 2 — End-to-end evidence chain tests failing (closed in current worktree)

Three failures that are not noise — they are the platform's core proof that the evidence chain works end to end:

**`learner_portfolio_honesty_test.dart`:**
> `learner portfolio renders reviewed artifacts created by the live educator mission review flow`

Confirms: educator reviews a mission → rubric applied → portfolio item updated → learner sees it. Failing.

**`parent_surfaces_workflow_test.dart`:**
> `portfolio page shows reviewed artifacts created through live learner and educator workflow for provisioning-linked families`
> `child passport shows reviewed claims created through live learner and educator workflow for provisioning-linked families`

Both failing. The parent cannot see verified portfolio evidence. The child passport shows no reviewed capability claims.

Root cause hypothesis: `learner_portfolio_page.dart` and `parent_portfolio_page.dart` are not querying `portfolioItems` filtered by enriched fields (`growthEventIds`, `capabilityIds`, `proofOfLearningStatus: verified`). They are likely still showing draft/published status without capability enrichment.

Also: `_portfolioItemRepo` field is unused in `capability_growth_engine.dart` — `_enrichPortfolioItem()` bypasses injected repo and calls Firestore directly, breaking mock injection in tests.

**Historical severity: Hard blocker for evidence chain. Current status: closed for the validated Flutter/mobile release bundle and MiloOS support-provenance slice.**

---

### Blocker 3 — Offline queue does not cover evidence operations (closed for validated evidence replay boundaries)

Current op types: `attendanceRecord`, `presenceCheckin`, `presenceCheckout`, `incidentSubmit`, `messageSend`, `attemptSaveDraft`.

Missing evidence chain ops:
- `observationCapture`
- `rubricApplication`
- `capabilityGrowthEvent`
- `checkpointVerification`

Hive infrastructure is sound. `SyncCoordinator` handles retry and deduplication. Gap is that evidence-critical operations were never registered as queueable op types.

**Historical severity: Medium. Current status: focused offline evidence-chain gates prove queued evidence/rubric/checkpoint behavior and block direct support-only or client-owned mastery/growth writes. Broader offline claims remain bounded by the current Flutter/mobile readiness plan.**

---

### Blocker 4 — No CI/CD pipeline (superseded by current release-gate path)

No `.github/workflows/`, no `Makefile`, no automated gate between commit and deployment. 54 failing tests reached main without automated catch. Golden images drifted without signal.

**Historical severity: Must have before production. Current status: the non-deploying `./scripts/deploy.sh release-gate` is the current local reproducibility gate; CI/CD breadth should be assessed against the current repo workflows and release docs, not this March 30 snapshot.**

---

## Deployment Readiness by Role

| Role | Flutter Readiness | Blocking Issue |
|------|-----------------|----------------|
| **Educator** | Evidence capture and BOS insights are real. Mission review exists. But end-to-end portfolio update from review is broken. | Blocker 2 |
| **Learner** | Today page, missions, habits are real. Portfolio UI exists but doesn't surface reviewed capability evidence correctly. | Blocker 2 |
| **Guardian/Parent** | Summary page works. Portfolio and passport views fail for verified evidence. | Blocker 2 |
| **Admin-HQ** | Sites, user admin, analytics, curriculum pages all exist. Test failures in federated learning (prototype) and integrations health (minor). | Defer federated learning |
| **Admin-School/Site** | Dashboard, sessions, check-in, incidents, provisioning all exist with real tests. CTA regressions minor. | Defer CTA regressions to RC2 |
| **Partner** | Listings, contracts, deliverables, payouts all exist. No test failures. | Ready |
| **Ops** | Offline queue, sync status, resilience wiring all real. Evidence ops not queued. | Blocker 3 |

---

## Prioritised Fix Order

| Priority | Work | Files |
|----------|------|-------|
| 1 | Fix evidence chain end-to-end (portfolio + passport display) | `learner_portfolio_page.dart`, `parent_portfolio_page.dart`, `parent_child_page.dart`, `capability_growth_engine.dart` |
| 2 | Refresh stale golden images | `flutter test --update-goldens test/ui_golden_test.dart` |
| 3a | Fix localization failures | `learner_today_page.dart`, `learner_portfolio_page.dart`, `site_incidents_page.dart` |
| 3b | Fix remaining test clusters | session menu, dashboard CTA, parent schedule, HQ admin |
| 4 | Build Dockerfile + complete deploy.sh + add CI | `Dockerfile`, `scripts/deploy.sh`, `.github/workflows/flutter.yml` |
| 5 | Add evidence op types to offline queue | `offline_queue.dart`, `capability_growth_engine.dart` |

---

## Deployment Gate Checklist

Before any build reaches production:

- [ ] `flutter analyze` — 0 errors
- [ ] 760+ tests pass, 0 failures in core evidence chain tests
- [ ] Golden images current — `--update-goldens` run committed
- [ ] Localization failures resolved
- [ ] Dockerfile present and Cloud Run deployment tested in staging
- [ ] CI workflow running on PR to main
- [ ] Offline queue covers evidence op types (or explicitly documented as not offline-safe for RC1)
- [ ] `_portfolioItemRepo` unused field fixed in `capability_growth_engine.dart`
- [ ] Federated learning tests excluded from CI gate (prototype)
- [ ] Release notes written against evidence chain

---

## What Is Not a Problem

- `capability_growth_engine.dart` is real — writes growth events, updates mastery, enriches portfolios, generates next steps
- Role-based access is real — `RoleGate` wraps every protected route, HQ impersonation works
- Firebase integration is complete — all four platforms configured, emulator switching works
- Offline persistence infrastructure is sound — Hive queue, sync coordinator, retry logic
- Models are complete — `ObservationModel`, `EvidenceRecordModel`, `RubricApplicationModel`, `CapabilityGrowthEventModel`, `CapabilityMasteryModel`, `ProofBundleModel` all exist and are wired into repositories

---

## Overall Verdict

| Area | Verdict |
|------|---------|
| Architecture | Solid |
| Evidence engine | Real, working |
| Evidence chain end-to-end (educator → learner portfolio → parent) | Historical March 30 finding; current Flutter/mobile readiness docs record the validated guardian/portfolio/passport and parent growth slices. |
| Test suite | Historical March 30 finding; current release-gate records full Flutter tests/analyzer and root gates passing from the current worktree. |
| Deployment infrastructure | Historical March 30 finding; current deploy script includes Cloud Run deploy paths and a non-deploying release gate. |
| CI/CD | Historical March 30 finding; assess current automation separately from this superseded report. |
| Offline evidence coverage | Historical March 30 finding; current Flutter/mobile readiness docs record the validated offline evidence-chain boundaries and remaining beta scope. |
| **Overall Flutter deployment readiness** | **Historical March 30 snapshot; superseded by current Flutter/mobile beta-ready / gold-candidate release-gate docs** |
