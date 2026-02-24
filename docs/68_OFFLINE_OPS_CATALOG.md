# 68_OFFLINE_OPS_CATALOG.md
Offline Operations Catalog (what must work without internet)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
Enumerate exactly which actions are offline-capable and how they sync, so implementation is unambiguous.

## Offline guarantees (P0 for physical schools)
- attendance taking
- check-in/out and pickup verification capture
- incident submission (optional offline)
- mission attempt drafting (recommended)
- message send (optional offline)

## Canonical op envelope
See `57_OFFLINE_STORAGE_SYNC_ENGINE.md`.

---

## Op types (must be implemented)
### 1) attendance.record
Payload:
- siteId, occurrenceId, learnerId, status, note?, recordedAtClient, recordedBy

Server:
- validate educator/admin membership
- upsert attendance record idempotently
- return server timestamp
- AuditLog: `attendance.recorded`

Conflict:
- deterministic policy (latest server timestamp wins, or explicit override)

### 2) presence.checkin
Payload:
- siteId, learnerId, actorId, method, atClient, location?

Server:
- validate role + site membership
- create presence record
- notify for late check-in (if configured)

### 3) presence.checkout
Payload:
- siteId, learnerId, actorId, pickupPersonId?, atClient, note?

Server:
- verify pickup authorization OR accept as “pending verification”
- create checkout record
- notify on late pickup if thresholds exceeded

### 4) incident.submit (optional offline)
Payload:
- siteId, learnerId?, severity, summary, details, atClient, attachments?

Server:
- create incident on sync; notify site admin
- AuditLog: `incident.submitted`

### 5) message.send (optional offline)
Payload:
- threadId/participants, body, atClient
Server:
- send when online; UI shows pending state

### 6) attempt.saveDraft
Payload:
- siteId, missionId, snapshotId, learnerId, reflection, artifactRefs?, atClient
Server:
- upsert draft attempt; no submit unless explicit op

---

## Required UI affordances
- Global “Sync status” indicator (pending ops count)
- Per-screen banners if offline
- Retry UI for failed ops

---

## QA scripts (must execute)
- Airplane mode attendance + sync
- Airplane mode check-in/out + sync
- Duplicate replay idempotency per op type

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `68_OFFLINE_OPS_CATALOG.md`
<!-- TELEMETRY_WIRING:END -->
