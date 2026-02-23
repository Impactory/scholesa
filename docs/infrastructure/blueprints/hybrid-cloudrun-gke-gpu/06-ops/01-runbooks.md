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
