# Infrastructure as Code Overview

Preferred:
- Terraform modules for Cloud Run, IAM, Secret Manager, Artifact Registry
- CI-applied Firebase rules and indexes

Minimum expectation:
- Every Cloud Run service is reproducible (config documented)
- IAM policy is exported and reviewed quarterly
- Secrets live only in Secret Manager (not repo)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/02-infrastructure/IAC_OVERVIEW.md`
<!-- TELEMETRY_WIRING:END -->
