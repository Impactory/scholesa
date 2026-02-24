# Secrets & Keys

## Secret storage
- Google Secret Manager only
- No secrets in Git history
- Rotation schedule documented

## Encryption
- At-rest: managed by GCP (document)
- In-transit: TLS
- Optional: CMEK for higher assurance (document if enabled)

Evidence:
- secret-inventory export (redacted)
- rotation record

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/03-security/SECRETS_AND_KEYS.md`
<!-- TELEMETRY_WIRING:END -->
