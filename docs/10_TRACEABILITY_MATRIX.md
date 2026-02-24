# 10_TRACEABILITY_MATRIX.md

Every requirement must map to implementation and evidence.

| REQ ID | Requirement | Docs | Code Paths | Tests | Evidence |
|---|---|---|---|---|---|
| REQ-AUTH-001 | Role routing after login | 01,06,09 | apps/... | flutter test ... | screenshots |
| REQ-ADM-001 | Admin-only guardian link | 02,06,26 | rules + api | rules tests | denial proof |
| REQ-OFF-001 | Attendance offline queue | 05,09 | apps/... | unit tests | offline proof |
| REQ-BILL-001 | Client cannot grant entitlements | 13,06,26 | rules + api | tests | denial proof |
| REQ-INT-001 | Parent blocked from insights | 24,06,26 | rules | emulator test | denial proof |
| REQ-API-001 | Protected endpoints require Firebase token | 27,06 | services/... | unit/integration | logs |

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `10_TRACEABILITY_MATRIX.md`
<!-- TELEMETRY_WIRING:END -->
