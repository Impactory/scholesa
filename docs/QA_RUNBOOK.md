# QA Runbook (run from repo root)

Quick link: one-page staging PITR drill checklist in STAGING_PITR_DRILL_CHECKLIST.md.

## Web stack (paused but retained)
- Env vars set (.env).
- Firebase emulators or test project.
- Start dev: `npm run dev`.

### LRN-01 Learner Mission Attempt + Reflection
1) Login as learner.
2) Navigate to /en/learner.
3) Click "Start Attempt" on a mission.
4) Toggle offline, click "Add Reflection"; go back online.
5) Confirm attempt/portfolio item written in Firestore.

### EDU-01 Educator Attendance
1) Login as educator (site scoped).
2) Go to /en/educator.
3) Pick today occurrence; mark Present/Late/Absent.
4) Verify attendanceRecords in Firestore.

### PAR-01 Parent Overview
1) Login as parent linked to a learner.
2) Go to /en/parent.
3) See child enrollments and recent attempts.

### SITE-01 Site Lead Session Create
1) Login as site lead.
2) /en/site -> enter title -> Create Session.
3) Confirm session doc exists.

### PART-01 Partner Minimal
1) Login partner.
2) /en/partner renders without errors.
3) Draft contract and submit deliverable; confirm Firestore partnerContracts/partnerDeliverables updated.

### HQ-01 Mission + KPI
1) Login HQ.
2) /en/hq -> create mission with pillar codes CSV.
3) Verify mission doc and KPI list rendered.

### OFF-EDU-01 Offline Attendance Queue
1) Educator go offline.
2) Mark attendance; ensure queued.
3) Go online; queue flushes; record in Firestore.

### OFF-LRN-01 Offline MissionAttempt Queue
1) Learner offline.
2) Start attempt; queue.
3) Online; record persists.

### OFF-LRN-02 Offline PortfolioItem Queue
1) Learner offline.
2) Add reflection; queue.
3) Online; portfolio item persists.

### BUILD-01 Web Build
- From repo root: `npm run build`.

### API-01 Cloud Run/Functions (if applicable)
- From repo root: `npm run build && docker build .` (or functions deploy dry-run).

## Flutter app (apps/empire_flutter/app)
- Ensure Flutter SDK installed; set `flutterfire configure` outputs present (firebase_options.dart, google-services.json, GoogleService-Info.plist).
- From `apps/empire_flutter/app`: `flutter pub get`, then `flutter run` (device/emulator) or `flutter build apk`.

### FL-AUTH-01 Auth + Role Routing
1) Launch app; register or login.
2) Confirm role selector shows cards with gradient/glass styling.
3) Select role; redirected to matching dashboard with pillar chips and site selector.

### FL-DASH-01 Dashboards UI Smoke
1) Verify learner/educator/parent/site/partner/hq dashboards render without error and show glass cards/list rows.
2) Confirm cards gated by entitlements (only roles with entitlements see marketplace/contracting/site admin cards).

### FL-OFFLINE-01 Offline Banner + Queue Flush
1) Go offline (Airplane mode); red banner appears.
2) Perform an action registered with OfflineQueue (e.g., attendance or mission attempt when wired); banner count increments.
3) Go online; banner hides and queued actions flush.

### FL-MSG-01 Messaging + Notifications
1) From dashboard messaging card, create thread with participants including self.
2) Send message online; observe rate-limit feedback if sending twice within 5s.
3) Toggle offline and send again; confirm queued in OfflineQueue and flushes when online (no external notification allowed offline).
4) Optional: attach file (notificationUploads path) and request external notification; ensure request enqueued in Firestore notificationRequests.

### FL-CNT-01 Partner Contracting
1) As partner, create org, draft contract, submit deliverable with upload; verify Firestore docs and telemetry.
2) As HQ, approve contract/deliverable/payout; ensure status updates and audit logs written.

### FL-AI-01 AI Drafts Flow
1) As any signed-in user, request AI draft with site/title/prompt; verify aiDrafts doc created.
2) As HQ/site/educator, approve/reject pending draft and add notes; verify status change and audit/telemetry.

### ANA-01 Telemetry Smoke Pass (Core + Non-core, Role-based)
1) Preconditions:
   Set `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_PROJECT_ID` for the target environment.
2) Execute role flows in this order:
   Learner: login, submit mission attempt, complete at least one popup flow.
   Educator: open sessions schedule, request substitute, apply and log learner support outcome.
   Site: complete check-in and check-out, flag one late pickup, create conflicting session to trigger conflict detection, assign substitute.
   HQ: create curriculum snapshot, apply rubric, share rubric parent summary, approve contract and payout.
   Partner/Commerce: submit lead, create/approve contract path, submit/accept deliverable, request/review AI draft, trigger checkout intent.
3) Run validator (full event set):
   `GOOGLE_APPLICATION_CREDENTIALS=... FIREBASE_PROJECT_ID=... node scripts/telemetry_smoke_check.js --mode=full --hours=2 --site=<siteId> --strict`
4) Pass criteria:
   `Result: PASS` from validator.
   No missing required events for core+extended+non-core.
   No schema/correlation/tenant/PII key errors.
5) Verify Firestore sample docs in `telemetryEvents` for newly created events:
   Required top-level fields: `event`, `userId`, `role`, `siteId`, `createdAt`.
   Required metadata fields: `requestId`, `traceId`, `redactionApplied`, `redactedPathCount`.
   For non-HQ telemetry, `siteId` must not be `unscoped`.
6) Fast command alias:
   `npm run qa:telemetry-smoke`

### FL-THEME-01 Visual Sweep
1) Check landing/login/register/role selector/dashboards use dark gradient + glass aesthetic with Manrope typography.

## Managed Firestore Operations (staging/prod)

### DB-IDX-01 Composite Index Rollout + Query Validation
1) Deploy indexes from repo root: `firebase deploy --only firestore:indexes`.
2) Wait for index build completion in Firebase Console → Firestore → Indexes.
3) Validate target query in app/functions path (`missionAttempts` filtered by `siteId` + `status`, ordered by `startedAt desc`).
4) Record p50/p95 latency and confirm no missing-index errors in logs.

### DB-BKP-01 Managed Backup + Restore Drill
1) In staging project, create identifiable drill docs (e.g., `backupDrill/{timestamp-*}`) across critical collections.
2) Trigger a managed backup (Firebase/GCP Backup service) and record backup ID + timestamp.
3) Mutate/delete drill docs to simulate incident.
4) Restore from backup into a restore target (preferred isolated project/database).
5) Verify restored docs match pre-incident values and relationships expected by app logic.
6) Document RTO (time to restore) and RPO (data loss window) observed.

### DB-PITR-01 Point-in-Time Recovery Drill (if enabled)
1) Confirm PITR is enabled for the target Firestore database.
2) Create a PITR marker doc, wait 2-3 minutes, then apply controlled mutation/delete.
3) Execute PITR restore to a timestamp immediately before mutation.
4) Verify marker/doc state restored correctly and application can read restored data.
5) Capture drill evidence: restore timestamp, completion time, validation queries, rollback decision.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `QA_RUNBOOK.md`
<!-- TELEMETRY_WIRING:END -->
