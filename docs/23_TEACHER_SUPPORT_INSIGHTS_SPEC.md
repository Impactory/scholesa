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
