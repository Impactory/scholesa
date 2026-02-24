# 05_OFFLINE_FIRST_ISAR_SYNC_POLICY.md

Offline-first is mandatory because real classrooms have real connectivity problems.

## Must work offline
- AttendanceRecord marking
- MissionAttempt drafts and submissions (including evidence metadata)
- SupportIntervention logging
- Nudge state (popups shown/dismissed/completed)

---

## Local store approach (Isar)
Store:
- queue of pending writes
- minimal cached snapshots needed to run class
- sync error log for debugging

Queue item recommended fields:
- id, createdAt
- userId, siteId
- collectionPath, docId
- opType: upsert|delete
- payload
- retryCount, lastError
- status: queued|in_flight|failed|synced

---

## Sync rules
- sync triggers: login, app start, connectivity restore, manual “sync now”
- exponential backoff
- idempotency and deterministic IDs prevent duplicates
- show a calm “sync status” indicator

---

## Conflict strategy
- AttendanceRecord: deterministic ID; last-write-wins by updatedAt; prefer educator/admin write priority
- MissionAttempt: drafts merge; submitted is immutable except educator review fields
- SupportIntervention: append-only
- Nudge state: last-write-wins but enforce frequency caps via remote counters

---

## UX requirements
- offline banner
- “saved locally” confirmations
- manual “sync now”
- error inspector for failed items

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `05_OFFLINE_FIRST_ISAR_SYNC_POLICY.md`
<!-- TELEMETRY_WIRING:END -->
