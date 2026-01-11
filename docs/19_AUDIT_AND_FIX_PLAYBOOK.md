# 19_AUDIT_AND_FIX_PLAYBOOK.md

Audits prevent regressions and security leaks.

## Severity
- P0: build broken, security leak, billing exploit, corruption risk
- P1: core workflow broken (provisioning, attendance, attempts, offline sync)
- P2: important but non-core broken
- P3: cosmetic

No release with P0/P1 open.

## Audit scope
- schema compliance (02A)
- rules enforcement (26)
- offline correctness (05)
- billing authority (13)
- approvals governance (15/16)
- telemetry validity (18)
- intelligence privacy boundary (24)
- API contract compliance (27)

## Required evidence
- build logs
- security denial proof
- offline sync proof
- audit report (`docs/20`)
