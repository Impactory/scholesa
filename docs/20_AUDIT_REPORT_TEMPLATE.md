# 20_AUDIT_REPORT_TEMPLATE.md

## Metadata
- Date:
- Commit:
- Environment:

## Summary
- Total findings:
- P0:
- P1:
- Release PASS/FAIL:

## Evidence
- Build logs:
- Screenshots:
- Emulator logs:

## Findings
### P0
- AUD-001:

### P1
- AUD-002:

## Sign-off
- Auditor:
- Notes:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `20_AUDIT_REPORT_TEMPLATE.md`
<!-- TELEMETRY_WIRING:END -->
