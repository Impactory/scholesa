# Component Inventory (No Phantom Boxes)

For each component, fill ALL fields or audit fails.

## Web App (Firebase Hosting)
- Repo path:
- Build command:
- Hosting site:
- Rewrite config:
- Owner:
- SLO:
- Dashboards:
- Runbook:

## scholesa-api (Cloud Run)
- Service name:
- Region:
- Service account:
- IAM policy export:
- Secrets:
- SLO:
- Alerts:
- Runbook:
- Tests:

## scholesa-ai (Cloud Run)
- Service name:
- Model providers:
- Policy store:
- Tool registry:
- Safety evaluation suite:
- Logs:
- Tests:

## Firestore
- Database:
- Rules file:
- Indexes:
- Backup/restore:
- Access model:

## Artifact Storage (GCS)
- Bucket(s):
- CMEK?:
- Retention:
- Access controls:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/01-architecture/COMPONENT_INVENTORY.md`
<!-- TELEMETRY_WIRING:END -->
