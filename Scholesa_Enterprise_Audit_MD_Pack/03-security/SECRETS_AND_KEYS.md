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
