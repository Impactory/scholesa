# Operations Runbooks (Minimum Set)

## RUNBOOK 1 — External Egress Blocked
Symptoms:
- SECURITY_EGRESS_BLOCKED events
Actions:
- Identify service + request traceId
- Locate code path attempting external call
- Remove dependency/call site and add test
Evidence update:
- vendor-egress-proof report must pass

## RUNBOOK 2 — Voice TTL Failure
Symptoms:
- voice objects not deleting
Actions:
- Verify bucket lifecycle policy
- Ensure no backup job includes voice buckets
Evidence update:
- voice-retention-ttl report

## RUNBOOK 3 — Tenant Isolation Alert
Symptoms:
- cross-tenant access attempt detected
Actions:
- revoke credentials, rotate keys
- verify Firestore rules
- run tenant isolation tests
Evidence:
- tenant-isolation report

## RUNBOOK 4 — Safety Escalation Regression
Symptoms:
- escalation fixtures failing
Actions:
- restore policy templates
- validate guardrails config
Evidence:
- safety-fixtures report

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/06-ops/01-runbooks.md`
<!-- TELEMETRY_WIRING:END -->
