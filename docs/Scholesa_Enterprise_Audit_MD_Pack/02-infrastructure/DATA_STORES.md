# Data Stores

## Firestore
- Collections grouped under /sites/{siteId}/... recommended.
- Security rules enforce siteId == auth claim.

## Cloud Storage
- Portfolio artifacts and uploads.
- Signed URL flows must validate siteId ownership.

## BigQuery (optional)
- Event warehouse with partitioning and siteId in every row.

## Secrets
- Secret Manager with least-privilege access by service account.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/02-infrastructure/DATA_STORES.md`
<!-- TELEMETRY_WIRING:END -->
