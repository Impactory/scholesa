# 44_SCHEDULING_CALENDAR_ROOMS_SPEC.md
Scheduling, calendar views, and room assignments

Physical sites need a usable calendar, not just sessionOccurrences.

---

## 1) Requirements
- calendar view (day/week)
- room assignment
- educator assignment + substitute support
- conflict detection (room double-booked, educator overlap)
- ICS export (optional)

---

## 2) Data model needs
- Rooms per site
- SessionOccurrence references roomId
- Substitute educator workflow (assigned for one occurrence)

---

## 3) UX flows
Admin:
- create rooms
- assign rooms to sessions/occurrences
- approve substitutes

Educator:
- see schedule and room
- request substitute for a date

---

## 4) Offline
- show cached schedule offline
- allow attendance even if schedule view is stale

---

## 5) Telemetry
- schedule.viewed
- room.conflict.detected
- substitute.requested
- substitute.assigned

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `44_SCHEDULING_CALENDAR_ROOMS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
