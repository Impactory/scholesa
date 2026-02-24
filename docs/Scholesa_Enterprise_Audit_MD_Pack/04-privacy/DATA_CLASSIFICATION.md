# Data Classification

Classes:
1) Student PII
2) Education record data (grades, submissions)
3) Teacher/admin identity data
4) Learning artifacts (portfolio)
5) Telemetry/events
6) AI interaction logs (prompts/responses/tool calls)

For each:
- Storage location
- Encryption
- Access roles
- Retention period
- Export method
- Deletion method

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/04-privacy/DATA_CLASSIFICATION.md`
<!-- TELEMETRY_WIRING:END -->
