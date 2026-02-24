# 74_CODEX_EXECUTION_VIBE_RUN_TO_DONE.md
Codex “Run-to-Done” Vibe Instructions (finish the app to running state)

Generated: 2026-01-09

**Intent:** These instructions are written so Codex (or another coding agent) can complete the platform to a stable **running state** with minimal ambiguity.

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app.

---

## Inputs (must read first)
Codex must load and follow these docs in order:
1) `73_COMPLETE_DOC_SET_TO_RUN.md`
2) `52_RUNNABLE_REPO_BOOTSTRAP.md`
3) `56_FLUTTER_APP_WIRING_ROUTER.md`
4) `02A_SCHEMA_V3.ts`
5) `47_ROLE_DASHBOARD_CARD_REGISTRY.md`
6) `49_ROUTE_FLIP_TRACKER.md`
7) `65_MODULE_DEFINITION_OF_DONE.md`
8) `66_API_ENDPOINTS_FULL_CATALOG.md`
9) `67_FIRESTORE_RULES_TEST_MATRIX.md`
10) `68_OFFLINE_OPS_CATALOG.md`
11) `59_DEPLOYMENT_CLOUD_RUN_COMMANDS.md`
12) `51_IMPLEMENTATION_AUDIT_GO_LIVE.md`

---

## Hard rules (Codex must obey)
1) Do not change design language or theming.
2) Do not create duplicate routes or parallel pages (single canonical router).
3) Do not trust client role or siteId—server authorizes everything.
4) Firestore rules are default-deny; never loosen to “make it work.”
5) Every privileged write generates AuditLog entries.
6) No placeholder “coming soon” on enabled routes.
7) Route flips only after Module DoD passes.

---

## Work plan (execute exactly)
### Step 1 — Make the Flutter app compile & boot cleanly
- Implement `AppConfig` (single source for env config).
- Implement a safe startup bootstrap: init Firebase → call `/v1/me` → store AppState → render dashboard.
- Implement global error screen with retry.
- Confirm `flutter run -d chrome` has no red console errors.

Deliverable proof:
- `flutter analyze` clean
- `flutter test` passes (at least basic)
- can log in using a test account

### Step 2 — Implement router + role gate + dashboard cards
- Use one central router file.
- Implement RoleGate for protected routes.
- Implement `kKnownRoutes` and ensure disabled routes cannot be navigated.
- Use `47_ROLE_DASHBOARD_CARD_REGISTRY.md` to render cards.

Deliverable proof:
- each role dashboard renders correct cards
- card opens enabled routes and blocks disabled routes

### Step 3 — Implement Firestore rules + indexes + emulator tests
- Implement rules per matrix in `67`.
- Implement indexes for the queries you actually run.
- Add emulator test harness and tests for:
  - cross-site deny
  - admin-only provisioning deny
  - parent boundary deny
  - client-write deny for server collections

Deliverable proof:
- `firebase emulators:exec` (or equivalent) runs tests successfully.

### Step 4 — Implement API services to full required scope for “running state”
Codex must implement the API endpoints required by the two chosen real workflows:
- Provisioning flow (site admin + guardian link)
- Attendance flow (offline ops supported)

Implementation requirements:
- verify Firebase ID tokens
- resolve role + site scope server-side
- idempotency keys for writes
- audit logs for privileged actions
- `/healthz` always returns 200 in staging

Deliverable proof:
- local API + Flutter works end-to-end
- staging API deployed and reachable

### Step 5 — Offline ops engine (attendance + check-in/out scaffold)
- Implement offline queue storage using one persistence solution.
- Implement `/v1/sync/batch`.
- Implement at minimum: `attendance.record` op type end-to-end.
- Show sync status indicator.

Deliverable proof:
- airplane mode attendance capture → later sync success
- idempotent replay produces no duplicates

### Step 6 — Seed staging data + verify end-to-end
- Use `60_SEED_DATA_STAGING_PILOT.md`.
- Create 6 role accounts and one pilot site with one session + occurrence.
- Verify parent sees safe summary view (no teacher-only content).

Deliverable proof:
- staging smoke test recorded (login + workflow)

### Step 7 — Deploy to Cloud Run
- Use `59_DEPLOYMENT_CLOUD_RUN_COMMANDS.md`.
- Deploy web container and API container.
- Verify `/healthz`.
- Run the audit doc `51` and attach evidence.

Deliverable proof:
- Cloud Run URLs and logs
- CI build success (if enabled)

---

## Definition of Done (stop only when true)
- Flutter web runs locally with login and dashboards per role.
- Staging web runs on Cloud Run.
- API running on Cloud Run with `/healthz`.
- Firestore rules tests passing.
- At least two real workflows implemented end-to-end with real storage, not mocks.
- Route flips recorded in `49_ROUTE_FLIP_TRACKER.md`.
- Evidence recorded in `51_IMPLEMENTATION_AUDIT_GO_LIVE.md`.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `74_CODEX_EXECUTION_VIBE_RUN_TO_DONE.md`
<!-- TELEMETRY_WIRING:END -->
