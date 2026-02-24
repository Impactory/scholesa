# 42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md
Physical site check-in / check-out (front desk reality)

This complements AttendanceRecord with operational arrival/dismissal controls.

**Design language lock** applies.

---

## 1) Requirements
- capture arrival timestamp (check-in)
- capture dismissal timestamp (check-out)
- support late pickup alerts
- support QR front desk workflow (admin-only)
- support educator “session open” flow to see who is present in building

---

## 2) Core flows
### Front desk (admin/site role)
- “Open site day”
- check-in learners (search, scan QR, quick select)
- check-out learners (validate authorized pickup)
- late pickup warning triggers

### Educator
- sees check-in status when taking attendance
- can mark “present in class” separate from “checked-in at site”

---

## 3) Offline behavior
- check-in/out must work offline
- sync is idempotent, last-write-wins with audit

---

## 4) Relationship to AttendanceRecord
AttendanceRecord remains the “class presence” record.
CheckInOut is the “facility presence” record.

---

## 5) Telemetry
- site.checkin
- site.checkout
- site.late_pickup.flagged

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `42_PHYSICAL_SITE_CHECKIN_CHECKOUT_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
