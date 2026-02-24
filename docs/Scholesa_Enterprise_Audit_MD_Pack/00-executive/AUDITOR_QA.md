# Auditor / Buyer Q&A (Pre-Answered)

## Where is student data stored?
See PRIVACY/DATA_MAP.md and INFRA/DATA_STORES.md.

## How do you prevent cross-school data leaks?
See SECURITY/TENANT_ISOLATION.md + EVIDENCE/tenant-isolation-test.json.

## How do you control AI data exposure?
See AI/AI_DATA_BOUNDARIES.md + AI/LOGGING_SPEC.md + redaction policy.

## How do you delete/export data?
See PRIVACY/EXPORT_DELETE_RUNBOOK.md and PRIVACY/RETENTION_DELETION.md.

## How do you respond to incidents?
See OPS/INCIDENT_RESPONSE_PLAN.md and OPS/POSTMORTEM_TEMPLATE.md.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/00-executive/AUDITOR_QA.md`
<!-- TELEMETRY_WIRING:END -->
