# REQ-114 Prototype Proof: Federated Learning Workstream Started

Date: 2026-03-14
Status: Partial prototype slice implemented

## Scope proved

REQ-114 is still not a shipped federated-learning capability, but the repo now contains a real prototype workstream slice instead of governance docs only.

Implemented prototype scope:

- bounded federated-learning experiment configuration helpers
- HQ callables to list and upsert prototype experiments
- site-scoped callable discovery for enrolled experiment assignments
- feature-flag integration for site-scoped experiment gating
- bounded prototype update-summary ingestion with privacy guardrails
- audit-log coverage for experiment upserts and accepted prototype update summaries
- schema definitions for experiment and update-summary records
- Flutter HQ management surface for experiment cohorts inside the existing feature-flags page
- Flutter domain models/repositories for experiment and summary records
- Flutter device-side uploader service that resolves active site context and submits bounded update summaries through the callable boundary
- Flutter runtime adapter that converts BOS event windows into bounded prototype summaries on real mission/session triggers
- Firestore rules for experiment and summary reads without exposing feature flags beyond HQ

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
- firestore.rules
- apps/empire_flutter/app/lib/domain/models.dart
- apps/empire_flutter/app/lib/domain/repositories.dart
- apps/empire_flutter/app/lib/modules/hq_admin/hq_feature_flags_page.dart
- apps/empire_flutter/app/lib/services/federated_learning_prototype_uploader.dart
- apps/empire_flutter/app/lib/services/federated_learning_runtime_adapter.dart
- apps/empire_flutter/app/lib/services/workflow_bridge_service.dart
- apps/empire_flutter/app/test/federated_learning_prototype_workflow_test.dart
- test/firestore-rules.test.js

## Validation

Passed on 2026-03-14:

1. Root typecheck
   - command: `npm run typecheck`
2. Functions build
   - command: `cd functions && npm run build`
3. Focused helper test
   - command: `cd functions && npm test -- federatedLearningPrototype.test.ts`
4. Focused Firestore rules test
   - command: `npm test -- --runInBand test/firestore-rules.test.js`
5. Focused Flutter prototype workflow test
   - command: `cd apps/empire_flutter/app && flutter test test/federated_learning_prototype_workflow_test.dart`

## Evidence summary

- Prototype experiments are now first-class backend records instead of draft-only concepts.
- Each experiment carries runtime target, aggregate threshold, bounded raw-update size, allowed-site cohort, and prototype upload enablement.
- Upserting an experiment also writes a site-scoped feature flag so the existing governance surface can gate cohorts.
- Site-admin devices now have a dedicated callable to discover only enrolled, enabled experiment assignments.
- Prototype update ingestion rejects raw content fields such as prompts, transcripts, raw updates, and artifact bodies.
- Accepted summaries are limited to metadata such as payload size, vector length, sample count, digest, and trace identifier.
- Audit logs record both experiment changes and accepted prototype updates.
- The HQ feature-flags page now exposes a bounded experiment editor instead of leaving prototype configuration backend-only.
- Flutter repositories and rules expose read-only experiment/update-summary records while keeping writes behind server callables.
- Runtime BOS signals now feed a bounded event-window summarizer, which uploads prototype summaries on mission/checkpoint/session triggers without sending raw learner content.

## Remaining gap to full REQ-114

REQ-114 remains partial until all of the following exist and are approved:

- approved privacy review and sign-off checklist
- device runtime beyond the bounded uploader abstraction
- aggregation threshold execution path
- pilot evidence and rollback proof
- rollout beyond the current BOS event-window prototype summarizer into a true on-device training/runtime path