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
