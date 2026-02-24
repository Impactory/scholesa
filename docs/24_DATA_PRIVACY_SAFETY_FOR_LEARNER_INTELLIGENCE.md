# 24_DATA_PRIVACY_SAFETY_FOR_LEARNER_INTELLIGENCE.md

## Principles
- minimal data
- explainable
- no diagnosis or sensitive inference
- AI draft-only with human approval

## Parent boundary (hard)
Parents must NOT read:
- learnerSupportProfiles
- learnerInsights
- sessionInsights

Parents see only parent-safe summaries.

## Implementation musts
- Firestore rules explicitly deny parent reads
- API role/site scope checks
- audit logs for intelligence generation and approvals

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `24_DATA_PRIVACY_SAFETY_FOR_LEARNER_INTELLIGENCE.md`
<!-- TELEMETRY_WIRING:END -->
