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

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `19_AUDIT_AND_FIX_PLAYBOOK.md`
<!-- TELEMETRY_WIRING:END -->
