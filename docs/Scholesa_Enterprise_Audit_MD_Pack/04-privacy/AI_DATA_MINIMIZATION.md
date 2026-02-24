# AI Data Minimization

Principles:
- Send only necessary context to AI
- Redact direct identifiers where possible
- Avoid sending raw student PII to model providers unless required and disclosed
- Log boundaries: keep sensitive inputs in protected logs or hashed references

Evidence:
- AI prompt assembly spec
- Redaction rules + tests

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/04-privacy/AI_DATA_MINIMIZATION.md`
<!-- TELEMETRY_WIRING:END -->
