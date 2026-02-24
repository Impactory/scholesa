# Data Retention Schedule (Default + Override)

Default retention is “as long as necessary for educational purposes,” with concrete defaults below.
Districts may require shorter schedules; Scholesa supports tenant-specific overrides where technically feasible.

## Defaults
- Active student records: retained during enrollment
- Inactive accounts: delete after 24 months inactivity
- AI interaction logs: retain 12 months (security + quality), shorter if district requires
- Operational logs: retain per security needs; redact/minimize
- Backups: rolling 30–90 days (configurable)

## Deletion verification
- Confirm Firestore docs removed
- Confirm artifact objects removed
- Record deletion completion report

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_Pack_PLUS/09-compliance/COPPA/DATA_RETENTION_SCHEDULE.md`
<!-- TELEMETRY_WIRING:END -->
