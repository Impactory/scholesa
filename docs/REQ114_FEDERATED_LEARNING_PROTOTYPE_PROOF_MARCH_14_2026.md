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
- backend aggregation-run materialization once accepted summary windows cross the configured threshold
- Firestore rules for experiment and summary reads without exposing feature flags beyond HQ
- HQ visibility for the latest materialized aggregation run per experiment
- bounded merge-artifact records generated for each materialized aggregation run
- bounded candidate-model-package records staged from each generated merge artifact
- HQ candidate-package history drill-in with search, paging, latest-only filtering, promotion-state visibility, bounded HQ decision capture for sandbox-eval package approvals or holds, and a separate HQ promotion-history drill-in
- bounded candidate-promotion records for HQ sandbox-eval approvals linked to staged candidate packages
- bounded candidate-promotion revocation records for HQ rollback evidence tied to sandbox-eval package decisions
- bounded experiment privacy-review and sign-off checklist records for HQ approval readiness tracking
- bounded pilot-evidence records for HQ sandbox-eval, metrics-snapshot, and rollback-readiness tracking per staged candidate package
- bounded pilot-approval records for HQ sign-off on staged candidate packages once review, evidence, and eval prerequisites align
- bounded pilot-execution records for HQ launch, observation, and completion evidence on approved staged candidate packages within the allowed-site cohort
- bounded runtime-delivery manifest records for HQ assignment of observed pilot packages to approved sites, plus site-scoped resolver access to those manifests
- bounded runtime-activation evidence records for site-scoped acknowledgement of assigned runtime-delivery manifests, plus HQ read-only visibility into the latest site reports
- bounded runtime-vector payload resolution for site devices, including site-scoped callable package resolution, device-side activation reporting on package load, and real merged runtime vectors staged inside aggregation artifacts and candidate packages
- bounded runtime-delivery lifecycle control, including expiry windows, explicit revocation reasons, fallback reporting, and device-side invalidation of stale runtime payloads
- HQ runtime-delivery lifecycle visibility, including recent delivery history with expiry and revocation detail per experiment
- HQ per-site rollout-health visibility for the latest runtime delivery, including resolved, staged, fallback, and pending site counts plus site-by-site drill-in detail
- HQ runtime-activation history visibility for the latest package, including status counts and per-site activation or fallback evidence drill-in
- HQ rollout-alert highlighting on experiment cards when fallback or pending site statuses exist for the latest runtime delivery
- HQ alert-first ordering of experiment cards so fallback and pending rollout issues surface ahead of healthy prototype experiments
- HQ persisted rollout-alert triage records so fallback and pending delivery issues can be acknowledged with notes instead of remaining permanently raw operator alerts
- HQ visibility for recent aggregation-run history and artifact status per experiment

Not claimed by this proof:

- on-device training runtime
- true gradient or weight aggregation service
- model updates applied to production systems
- pilot rollout or delivery beyond bounded review, evidence, and approval records
- pilot rollout automation or device delivery beyond bounded execution evidence records
- generalized production model delivery beyond the bounded runtime-vector package path implemented here
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
- apps/empire_flutter/app/lib/services/federated_learning_runtime_activation_reporter.dart
- apps/empire_flutter/app/lib/services/federated_learning_runtime_adapter.dart
- apps/empire_flutter/app/lib/services/federated_learning_runtime_delivery_resolver.dart
- apps/empire_flutter/app/lib/services/federated_learning_runtime_package_resolver.dart
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
- Accepted summaries are now limited to bounded numeric runtime-vector sketches plus safe metadata such as payload size, vector length, sample count, digest, and trace identifier.
- Audit logs record both experiment changes and accepted prototype updates.
- The HQ feature-flags page now exposes a bounded experiment editor instead of leaving prototype configuration backend-only.
- Flutter repositories and rules expose read-only experiment/update-summary records while keeping writes behind server callables.
- Runtime BOS signals now feed a bounded event-window summarizer, which uploads bounded numeric runtime-vector sketches on mission/checkpoint/session triggers without sending raw learner content.
- When accepted summaries cumulatively hit the experiment threshold, the backend now materializes a bounded aggregation-run record, marks the source summaries as consumed, and merges the uploaded runtime-vector sketches into a weighted runtime payload instead of only emitting metadata.
- Each materialized run now also emits a bounded merge-artifact record that includes the merged runtime vector, model version, and payload digest alongside the aggregate metadata, while remaining an auditable bounded payload rather than a general model binary.
- Each generated merge artifact now also stages a bounded candidate-model-package payload record for downstream inspection and delivery, carrying the merged runtime vector for site-scoped resolution without claiming a generalized production rollout path.
- HQ can now inspect candidate-package history separately from aggregation runs, including package digests, linked artifacts, whether a package is still awaiting promotion, on hold, or approved for eval, and can write the bounded decision record directly from the package drill-in dialog.
- HQ can now inspect promotion decisions in a dedicated history dialog with status filtering, decision metadata, linked package/artifact context, and rationale search without claiming a production rollout console.
- HQ can now record bounded rollback evidence for sandbox-eval package decisions via promotion revocation records, and the same package/promotion history surfaces now show effective revoked state plus rollback rationale without claiming a deployed rollback executor.
- HQ can now record bounded experiment privacy-review and sign-off checklist status per prototype experiment, with approval gated on completed privacy review, completed sign-off checklist, and acknowledged rollout risk, without claiming a completed pilot approval workflow.
- HQ can now record bounded pilot evidence per staged candidate package, with ready-for-pilot state gated on completed sandbox evaluation, reviewed metrics snapshot, and verified rollback plan, without claiming a real pilot rollout or production delivery path.
- HQ can now record bounded pilot approval per staged candidate package, with approval gated on an approved experiment review record, ready-for-pilot evidence, and a non-revoked approved-for-eval promotion, without claiming a production rollout executor or live pilot delivery path.
- HQ can now record bounded pilot execution per staged candidate package, with launch, observation, and completion states gated on approved pilot approval, allowed-site cohort membership, and positive session and learner counts where required, without claiming a live rollout controller or on-device model-delivery path.
- HQ can now record bounded runtime-delivery manifests per staged candidate package, with assigned and active states gated on observed or completed pilot execution and target sites constrained to the experiment cohort, while site-scoped Flutter runtime code can resolve those manifests without claiming real weight delivery or model activation.
- Site-scoped Flutter runtime code can now report bounded runtime-activation evidence against assigned delivery manifests, with the backend enforcing site membership on the manifest target cohort and HQ surfaces showing the latest activation status per candidate package without claiming real payload loading or production model execution.
- Site-scoped Flutter runtime code can now resolve a bounded runtime package payload for the latest assigned or active delivery, automatically report activation evidence when that payload is loaded, and apply the merged runtime vector when encoding subsequent update sketches.
- HQ runtime-delivery records now carry bounded expiry and revocation metadata, the resolver returns explicit resolved-versus-expired-versus-revoked package state, and the device runtime reports fallback evidence while refusing to reuse stale payload vectors after expiry or revocation.
- The HQ feature-flags surface now exposes recent runtime-delivery history per experiment so operators can inspect delivery status, site spread, expiry windows, and revocation rationale without leaving the bounded prototype workflow.
- The HQ feature-flags surface now also derives per-site rollout health from runtime-delivery and activation records so operators can inspect which sites are resolved, pending, staged, or already in fallback for the latest bounded delivery.
- The HQ feature-flags surface now also exposes the underlying runtime-activation history for the latest package so operators can audit the actual site reports behind the rollout-health summary without leaving the bounded prototype workflow.
- The HQ feature-flags surface now also raises a bounded rollout alert directly on the experiment card whenever the latest delivery has fallback or pending site states, so operators can spot drift without opening the rollout dialogs first.
- The HQ feature-flags surface now also prioritizes those alerted experiments above healthy ones, so fallback and pending rollout issues rise to the top of the bounded operator queue.
- HQ can now persist rollout-alert triage records per runtime delivery, including fallback and pending counts, acknowledgement status, acknowledgement metadata, and operator notes, so reviewed rollout issues stop surfacing as permanently raw alerts while remaining bounded to the prototype operator workflow.
- Downstream promotion is still bounded to HQ-readable approval records targeting sandbox evaluation only; there is still no deployed model rollout, device delivery path, or production promotion executor in this repo.
- HQ can now inspect a short recent history of aggregation runs per experiment, including artifact generation status, instead of only a single latest-run summary.

## Remaining gap to full REQ-114

REQ-114 remains partial until all of the following exist and are approved:

- true on-device training beyond the bounded runtime-vector sketch path
- richer merge semantics than the current weighted runtime-vector averaging path
- production-grade rollout orchestration and long-lived model lifecycle management beyond the current bounded site-scoped expiry, revocation, and fallback path