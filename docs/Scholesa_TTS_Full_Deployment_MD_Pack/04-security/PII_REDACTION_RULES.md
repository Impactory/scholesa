# PII Redaction Rules (Voice)

## When to apply
- Before speaking any content that may contain identifiers
- Always for K–5 unless teacher explicitly requests read-aloud of student submission and policy allows

## Redact patterns
- Names (if available via roster lists) -> [NAME]
- Emails -> [EMAIL]
- Phone numbers -> [PHONE]
- Addresses -> [ADDRESS]
- Internal IDs (siteId, learnerId, submissionId) -> [ID]

## Logging
Never store redacted text or original text in logs.
Store only:
- redactionApplied: boolean
- redactionCount: number
- lengths

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/04-security/PII_REDACTION_RULES.md`
<!-- TELEMETRY_WIRING:END -->
