# Data Map

Document where data lives:
- Firebase Auth: identity records
- Firestore: learning records, progress, mission attempts
- Cloud Storage: artifacts/uploads
- Cloud Logging: operational logs (ensure redaction)
- BigQuery: analytics (if used)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/04-privacy/DATA_MAP.md`
<!-- TELEMETRY_WIRING:END -->
