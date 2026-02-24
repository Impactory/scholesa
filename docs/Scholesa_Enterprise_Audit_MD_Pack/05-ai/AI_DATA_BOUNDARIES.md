# AI Data Boundaries

Define:
- What data may enter AI context
- What is forbidden (PII, credentials, other tenants)
- How retrieval works (siteId-scoped)
- How student artifacts are referenced (IDs not full dumps unless required)

Include:
- boundary tests
- redaction tests

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/05-ai/AI_DATA_BOUNDARIES.md`
<!-- TELEMETRY_WIRING:END -->
