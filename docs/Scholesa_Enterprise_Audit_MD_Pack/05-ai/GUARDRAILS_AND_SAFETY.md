# Guardrails & Safety

Tests must cover:
- prompt injection attempts
- data exfil attempts
- unsafe content
- self-harm / violence content handling (K–12 safe defaults)
- policy refusal behavior
- safe alternatives / teacher escalation

Evidence:
- ai-guardrails-report.json
- logs showing blocked outcomes

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/05-ai/GUARDRAILS_AND_SAFETY.md`
<!-- TELEMETRY_WIRING:END -->
