# 22_LEARNER_INTELLIGENCE_PERSONALIZATION_SPEC.md

The platform should learn what supports learners best, without labeling or diagnosing.

## Core stance
No fixed “learning style” labels. Track:
- habits (commitment/evidence/reflection consistency)
- engagement (attendance/submissions)
- supports that worked (teacher logged outcomes)

## Collections
- learnerSignals/{learnerId}
- learnerSupportProfiles/{learnerId}
- configs/supportStrategies

## Outputs
Learner:
- 3 commitment suggestions max
- better reminder timing (opt-in)
- positive coaching tips

Educator:
- who to check in with first today
- “try this support” cards with explainable reasons

## Computation
Phase 1: rules-based signals from platform usage + interventions
Phase 2: AI drafts wording only (human approval)

## Explainability
Every suggestion must show:
- why (signals)
- time window
- confidence

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `22_LEARNER_INTELLIGENCE_PERSONALIZATION_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
