# 11_CODEX_TASK_TEMPLATE.md

Use this template for every Codex task.

## Title
(verb phrase)

## Scope
- Roles impacted:
- Collections touched:
- Endpoints touched:
- Offline required: yes/no

## Docs to follow
(list doc IDs, always include 01,02,02A,05,06,08,09,26,27 as relevant)

## Plan
1)
2)
3)

## Implementation checklist
- [ ] UI complete (no placeholder stubs)
- [ ] API complete (authz, validation, idempotency)
- [ ] Firestore rules updated + tested
- [ ] Offline behavior covered (if applicable)
- [ ] Telemetry events emitted (docs/18)
- [ ] Tests added

## Verification
### Automated
- commands run + results

### Manual QA
- steps + screenshots/logs

## Traceability updates
- rows added/updated in `docs/10`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `11_CODEX_TASK_TEMPLATE.md`
<!-- TELEMETRY_WIRING:END -->
