# 73_COMPLETE_DOC_SET_TO_RUN.md
Complete MD doc set required to finish Scholesa to a **running state** (compile → run → deploy)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).

---

## What “running state” means (Definition of Done)
The platform is considered **running** when ALL are true:

1) Local: `flutter run -d chrome` launches, login works, dashboard renders by role.
2) Staging: Web deployed to Cloud Run loads, login works, `/healthz` returns 200.
3) Firebase: Firestore/Storage rules compile and emulator rule tests pass.
4) Routing: dashboard cards open only enabled routes; disabled routes cannot be navigated.
5) Data: at least seeded accounts for each role exist (staging), and at least one end-to-end core workflow is real (not mocked).
6) Stability: no red console errors on the happy path; fatal errors show friendly retry screens.

---

## The MD files you need (grouped by purpose)

### A) Go-live / audit gate (required)
- `51_IMPLEMENTATION_AUDIT_GO_LIVE.md` (audit checklist with evidence links)
- `Scholesa_Go_Live_Readiness_Checklist.docx` (operational readiness)

### B) Runnable wiring set (required for compiling/running/deploying)
- `52_RUNNABLE_REPO_BOOTSTRAP.md` (repo + runnable definition)
- `53_ENVIRONMENT_CONFIG_SECRETS.md` (dev/stage/prod config discipline)
- `54_FIREBASE_SETUP_RULES_INDEXES.md` (rules/indexes/emulators)
- `55_CLOUD_RUN_API_SERVICE_SPEC.md` (service requirements and security model)
- `56_FLUTTER_APP_WIRING_ROUTER.md` (providers/router boundaries)
- `57_OFFLINE_STORAGE_SYNC_ENGINE.md` (offline engine pattern)
- `58_CI_CD_PIPELINE_GITHUB_ACTIONS.md` (repeatable builds)
- `59_DEPLOYMENT_CLOUD_RUN_COMMANDS.md` (CLI deploy)
- `60_SEED_DATA_STAGING_PILOT.md` (seed accounts + data)
- `61_OBSERVABILITY_ALERTING.md` (crash + server logs + alerts)
- `62_TEST_STRATEGY_AUTOMATION.md` (automated confidence)
- `63_MIGRATIONS_VERSIONING.md` (schema/content stability)

### C) Full implementation (no-minimums) set (required to avoid gaps and interpretation drift)
- `64_MASTER_IMPLEMENTATION_PLAN.md` (all phases, full scope)
- `65_MODULE_DEFINITION_OF_DONE.md` (route flip gating)
- `66_API_ENDPOINTS_FULL_CATALOG.md` (complete API surface)
- `67_FIRESTORE_RULES_TEST_MATRIX.md` (rules + tests mapping)
- `68_OFFLINE_OPS_CATALOG.md` (exact offline ops)
- `69_UI_SCREEN_INVENTORY.md` (all screens by role)
- `70_BACKGROUND_JOBS_WEBHOOKS.md` (jobs + webhooks)
- `71_SECURITY_PRIVACY_COMPLIANCE.md` (parent boundary + secrets + privacy)
- `72_RELEASE_CUTOVER_RUNBOOK.md` (staging → prod runbook)

### D) Dashboard + module delivery discipline (already in your doc set; required)
- `47_ROLE_DASHBOARD_CARD_REGISTRY.md` (what each role sees and where it navigates)
- `48_FEATURE_MODULE_BUILD_PLAYBOOK.md` (module build steps)
- `49_ROUTE_FLIP_TRACKER.md` (single truth of enabled routes)
- `50_PROVIDER_WIRING_PATTERNS.md` (how to wire providers safely)

### E) Schema source (required)
- `02A_SCHEMA_V3.ts` (canonical schema for all storage and DTOs)

### F) Integrations (only required if you enable these routes pre-launch)
Google Classroom:
- `28_GOOGLE_CLASSROOM_INTEGRATION_SPEC.md`
- `29_GOOGLE_CLASSROOM_SCHEMA_EXTENSIONS.md`
- `30_GOOGLE_CLASSROOM_OAUTH_SECURITY.md`
- `31_GOOGLE_CLASSROOM_SYNC_JOBS.md`
- `32_GOOGLE_CLASSROOM_QA_SCRIPT.md`
- `39_OAUTH_SCOPES_BUNDLES_CLASSROOM_ADDON.md`

GitHub:
- `40_GITHUB_APP_PERMISSIONS_MATRIX_AND_OAUTH_FALLBACK.md`

---

## Required build order to reach “running state” fastest (without cutting corners)
Follow this exact sequence:

1) **Repo + config discipline**
   - 52 → 53 → 56

2) **Firebase backbone**
   - 54 → 67 → 62

3) **API + auth bootstrap**
   - 66 (bootstrap endpoints first: `/healthz`, `/v1/me`, then provisioning)

4) **Dashboards + route flips**
   - 47 → 49 → 65

5) **Seed staging + verify end-to-end**
   - 60 → 61

6) **Deploy**
   - 59 → 58

7) **Audit for go-live confidence**
   - 51 + checklist docx
   - 72 for cutover discipline

---

## Minimum “real” workflows required for running state (choose 2)
You must implement at least two real end-to-end workflows (not mocked):

**Recommended for physical schools**
- Workflow 1: Site admin provisions learner + parent + links GuardianLink → parent sees child summary.
- Workflow 2: Educator takes attendance (offline allowed) → sync → parent sees safe summary (not raw teacher notes).

---

## Final “running state” proof bundle (what to capture)
- Screenshot/video: login → dashboard per role (6 roles)
- Screenshot/video: one core workflow end-to-end
- CI logs: web build + container build + deploy
- Emulator test output: rules tests pass
- Cloud Run URL + `/healthz` output

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `73_COMPLETE_DOC_SET_TO_RUN.md`
<!-- TELEMETRY_WIRING:END -->
