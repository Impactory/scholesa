# 46_IDENTITY_MATCHING_RESOLUTION_SPEC.md
Identity matching + resolution (Classroom/GitHub/duplicates)

This is the hidden reliability layer. Without it, integrations become a support nightmare.

---

## 1) Problems to solve
- student has multiple emails (school vs personal)
- renamed Google accounts mid-year
- duplicate Scholesa users created during provisioning
- GitHub usernames differ from school identity

---

## 2) Principles
- automated matching is a suggestion, not an irreversible action
- admins confirm and audit every manual match
- do not allow educators or parents to re-map identity links

---

## 3) Admin UI: Identity Resolution Center
Shows:
- “Unmatched external users” (from Classroom roster/GitHub events)
- suggested matches with confidence reasons:
  - email exact match
  - name + DOB match (if available; avoid storing more PII than necessary)
  - manual selection

Actions:
- link external user → Scholesa user
- merge duplicate Scholesa users (HQ/admin only)
- mark as “ignore” (external user not part of school)

---

## 4) Audit + safety
Every mapping change writes AuditLog:
- previous mapping
- new mapping
- who approved
- timestamp

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `46_IDENTITY_MATCHING_RESOLUTION_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
