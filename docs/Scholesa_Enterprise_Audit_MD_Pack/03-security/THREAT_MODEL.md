# Threat Model (Summary)

Include:
- Assets: student PII, education records, portfolio artifacts, auth tokens, AI logs
- Threats: cross-tenant leak, account takeover, prompt injection, data exfil, supply chain compromise
- Controls: auth claims, Firestore rules, tool scoping, redaction, scanning, monitoring
- Residual risk + roadmap

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/03-security/THREAT_MODEL.md`
<!-- TELEMETRY_WIRING:END -->
