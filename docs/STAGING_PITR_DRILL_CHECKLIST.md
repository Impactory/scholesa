# Staging PITR Drill Checklist (One Page)

## Objective
Validate Firestore Point-in-Time Recovery (PITR) readiness in staging by proving data can be restored to a precise pre-incident timestamp within target RTO/RPO.

## Scope
- Environment: staging Firebase/GCP project only
- Datastore: Firestore (managed service, PITR enabled)
- Test data: isolated `pitrDrill/*` documents only
- Owner: Incident Commander (IC)
- Scribe: captures timestamps/evidence

## Preconditions (Go/No-Go)
- [ ] PITR enabled for staging Firestore database
- [ ] Restorer has required IAM permissions (Firestore Admin / Restore permissions)
- [ ] Change freeze window approved for drill duration
- [ ] Monitoring/log access available (Firebase + Cloud Logging)
- [ ] Rollback contact list confirmed

## Target SLOs
- RTO target: ___ minutes
- RPO target: ___ minutes

## Drill Steps
1) **Create marker dataset**
- [ ] Write marker docs in `pitrDrill/marker-*` with fields: `createdAt`, `runId`, `checksum`
- [ ] Record timestamp `T0_MARKER_CREATED` (UTC)

2) **Wait for recoverability window**
- [ ] Wait 2–5 minutes
- [ ] Record timestamp `T1_WINDOW_READY` (UTC)

3) **Inject controlled incident**
- [ ] Mutate/delete at least one marker doc
- [ ] Record timestamp `T2_INCIDENT` (UTC)

4) **Execute PITR restore**
- [ ] Select restore timestamp `T_RESTORE = T1_WINDOW_READY` (or immediately before `T2_INCIDENT`)
- [ ] Restore to isolated target (preferred) or approved staging restore target
- [ ] Record timestamp `T3_RESTORE_STARTED` (UTC)
- [ ] Record timestamp `T4_RESTORE_COMPLETED` (UTC)

5) **Validate restored state**
- [ ] Marker docs match pre-incident values/checksum
- [ ] No unexpected data corruption in adjacent critical collections
- [ ] App/API reads succeed against restored target for smoke queries

6) **Closeout**
- [ ] Compute and record:
  - `RTO = T4_RESTORE_COMPLETED - T2_INCIDENT`
  - `RPO = T2_INCIDENT - T_RESTORE`
- [ ] Capture lessons learned and action items
- [ ] Return environment to baseline

## Evidence Capture (Required)
- [ ] Screenshot/export: PITR enabled status
- [ ] Screenshot/export: restore job request (timestamp + target)
- [ ] Screenshot/export: restore completion state
- [ ] Query output showing marker docs before/after restore
- [ ] Cloud Logging entries for restore operation

## Pass/Fail Criteria
- **PASS** if all are true:
  - [ ] Restore completed successfully
  - [ ] Marker data restored accurately
  - [ ] RTO within target
  - [ ] RPO within target
- **FAIL** if any are true:
  - [ ] Restore fails/incomplete
  - [ ] Restored data mismatch
  - [ ] RTO or RPO breach

## Incident Notes Template
- Run ID: __________
- IC: __________
- Scribe: __________
- Start (UTC): __________
- End (UTC): __________
- Key blockers: __________
- Follow-ups (owner/date): __________

## Example Run (Filled)
- Run ID: PITR-STG-20260220-01
- IC: Alex Rivera
- Scribe: Jordan Lee
- Environment: staging
- RTO target: 30 minutes
- RPO target: 10 minutes

### Timeline (UTC)
- `T0_MARKER_CREATED`: 2026-02-20T14:05:10Z
- `T1_WINDOW_READY`: 2026-02-20T14:08:30Z
- `T2_INCIDENT`: 2026-02-20T14:10:05Z
- `T_RESTORE`: 2026-02-20T14:08:30Z
- `T3_RESTORE_STARTED`: 2026-02-20T14:12:00Z
- `T4_RESTORE_COMPLETED`: 2026-02-20T14:24:40Z

### Computed Outcomes
- `RTO = T4 - T2 = 14m 35s` ✅ within 30m target
- `RPO = T2 - T_RESTORE = 1m 35s` ✅ within 10m target

### Validation Results
- Marker docs: restored with matching `checksum` values ✅
- Smoke queries: app/API read checks passed ✅
- Unexpected corruption in adjacent collections: none observed ✅

### Evidence Pointers
- PITR enabled status: `evidence/pitr/PITR-STG-20260220-01-enabled.png`
- Restore request: `evidence/pitr/PITR-STG-20260220-01-request.png`
- Restore completion: `evidence/pitr/PITR-STG-20260220-01-complete.png`
- Query diff before/after: `evidence/pitr/PITR-STG-20260220-01-query-results.md`
- Cloud logs export: `evidence/pitr/PITR-STG-20260220-01-cloud-logs.json`

### Final Decision
- Drill status: **PASS**
- Follow-ups:
  - Add quarterly PITR schedule entry (Owner: SRE Lead, Due: 2026-03-01)
  - Automate marker checksum verification script (Owner: Platform Eng, Due: 2026-03-08)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `STAGING_PITR_DRILL_CHECKLIST.md`
<!-- TELEMETRY_WIRING:END -->
