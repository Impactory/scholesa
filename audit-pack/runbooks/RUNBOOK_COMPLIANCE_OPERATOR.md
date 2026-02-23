# Scholesa COPPA Compliance Operator Runbook

## Purpose
Run and verify COPPA controls for internal AI-only policy, tenant isolation, retention, and log privacy.

## Service
- Cloud Run service: `scholesa-compliance`
- Health: `GET /healthz`
- Status: `GET /compliance/status`
- Trigger: `POST /compliance/run`
- Report fetch: `GET /compliance/report/:reportId`

## CI/Nightly Gates
- CI gate: `COMPLIANCE_INCLUDE_RC2=1 npm run compliance:gate`
- Nightly workflow: `.github/workflows/compliance-nightly.yml`
- Required artifacts: `audit-pack/reports/*.json`

## Core Evidence Artifacts
- `audit-pack/reports/repo-structure-scan.json`
- `audit-pack/reports/vendor-dependency-ban.json`
- `audit-pack/reports/vendor-domain-ban.json`
- `audit-pack/reports/vendor-secret-ban.json`
- `audit-pack/reports/vendor-egress-proof.json`
- `audit-pack/reports/tenant-isolation-invariants.json`
- `audit-pack/reports/voice-retention-controls.json`
- `audit-pack/reports/log-privacy-safety.json`
- `audit-pack/reports/student-data-training-ban.json`
- `audit-pack/reports/compliance-latest.json`
- `audit-pack/reports/compliance-dashboard.json`

## Blocker Policy
Release must be blocked when any of these are false:
- `ai:internal-only:all`
- `vibe:all`
- `audit:coppa:no-ads`
- All control checks in `services/scholesa-compliance/policies/controls.yaml`

## Remediation
1. Open `audit-pack/reports/compliance-latest.json`.
2. Resolve each entry in `failures`.
3. Follow runbooks:
   - `audit-pack/runbooks/RUNBOOK_VENDOR_BAN.md`
   - `audit-pack/runbooks/RUNBOOK_TENANT_ISOLATION.md`
   - `audit-pack/runbooks/RUNBOOK_VOICE_RETENTION.md`
   - `audit-pack/runbooks/RUNBOOK_NO_TRAINING.md`
4. Re-run: `npm run compliance:gate`.
