# 23_TEACHER_SUPPORT_INSIGHTS_SPEC.md

Insights must be actionable in a live classroom.

## UX
- Class heatmap: top check-ins + classwide suggestions
- Learner snapshot: habit loop + supports + “try this today”
- Intervention logger: strategy + outcome + short note

## Collections
- sessionInsights/{sessionOccurrenceId}
- learnerInsights/{learnerId}
- supportInterventions/{id}
- configs/supportStrategies

## Offline
- show last-known insights offline
- log interventions offline and sync later

## Telemetry
- insight.viewed
- support.applied
- support.outcome.logged

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `23_TEACHER_SUPPORT_INSIGHTS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
