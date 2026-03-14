# REQ-114 Prototype Proof: Federated Learning Workstream Started

Date: 2026-03-14
Status: Partial prototype slice implemented

## Scope proved

REQ-114 is still not a shipped federated-learning capability, but the repo now contains a real prototype workstream slice instead of governance docs only.

Implemented prototype scope:

- bounded federated-learning experiment configuration helpers
- HQ callables to list and upsert prototype experiments
- feature-flag integration for site-scoped experiment gating
- bounded prototype update-summary ingestion with privacy guardrails
- audit-log coverage for experiment upserts and accepted prototype update summaries
- schema definitions for experiment and update-summary records

Not claimed by this proof:

- on-device training runtime
- aggregation service
- model updates applied to production systems
- pilot approval or privacy sign-off completion
- cross-site or global model rollout

## Implementation files

- functions/src/federatedLearningPrototype.ts
- functions/src/federatedLearningPrototype.test.ts
- functions/src/workflowOps.ts
- functions/src/index.ts
- schema.ts

## Validation

Passed on 2026-03-14:

1. Root typecheck
   - command: `npm run typecheck`
2. Functions build
   - command: `cd functions && npm run build`
3. Focused helper test
   - command: `cd functions && npm test -- federatedLearningPrototype.test.ts`

## Evidence summary

- Prototype experiments are now first-class backend records instead of draft-only concepts.
- Each experiment carries runtime target, aggregate threshold, bounded raw-update size, allowed-site cohort, and prototype upload enablement.
- Upserting an experiment also writes a site-scoped feature flag so the existing governance surface can gate cohorts.
- Prototype update ingestion rejects raw content fields such as prompts, transcripts, raw updates, and artifact bodies.
- Accepted summaries are limited to metadata such as payload size, vector length, sample count, digest, and trace identifier.
- Audit logs record both experiment changes and accepted prototype updates.

## Remaining gap to full REQ-114

REQ-114 remains partial until all of the following exist and are approved:

- approved privacy review and sign-off checklist
- device runtime implementation
- aggregation threshold execution path
- pilot evidence and rollback proof
- tests beyond helper validation for real prototype flows