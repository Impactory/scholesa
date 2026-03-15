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
- bounded runtime-vector payload resolution for site devices, including site-scoped callable package resolution, device-side activation reporting on package load, and norm-capped merged runtime vectors staged inside aggregation artifacts and candidate packages
- bounded runtime-delivery lifecycle control, including expiry windows, explicit revocation reasons, fallback reporting, and device-side invalidation of stale runtime payloads
- HQ runtime-delivery lifecycle visibility, including recent delivery history with expiry and revocation detail per experiment
- HQ per-site rollout-health visibility for the latest runtime delivery, including resolved, staged, fallback, and pending site counts plus site-by-site drill-in detail
- HQ runtime-activation history visibility for the latest package, including status counts and per-site activation or fallback evidence drill-in
- HQ rollout-alert highlighting on experiment cards when fallback or pending site statuses exist for a live latest runtime delivery, while terminal deliveries stay visible as lifecycle history without surfacing as current alerts
- HQ alert-first ordering of experiment cards so live fallback and pending rollout issues surface ahead of healthy prototype experiments without prioritizing terminal deliveries as active incidents
- HQ persisted rollout-alert triage records so fallback and pending delivery issues can be acknowledged with notes instead of remaining permanently raw operator alerts
- HQ rollout-alert history visibility across runtime deliveries, plus a bounded rollout-audit feed covering delivery, activation, and alert-triage state changes per experiment
- HQ rollout-audit filtering by package and site directly in the operator UI, acknowledgement-change history for alert triage, and bounded escalation-state tracking for unresolved rollout issues
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

Additional focused validation passed on 2026-03-15:

1. Functions build
   - command: `cd functions && npm run build`
2. Focused helper test
   - command: `cd functions && npm test -- federatedLearningPrototype.test.ts`
3. Focused Flutter prototype workflow test
   - command: `cd apps/empire_flutter/app && flutter test test/federated_learning_prototype_workflow_test.dart`

## Evidence summary

- Prototype experiments are now first-class backend records instead of draft-only concepts.
- Each experiment carries runtime target, aggregate threshold, bounded raw-update size, allowed-site cohort, and prototype upload enablement.
- Upserting an experiment also writes a site-scoped feature flag so the existing governance surface can gate cohorts.
- Site-admin devices now have a dedicated callable to discover only enrolled, enabled experiment assignments.
- Prototype update ingestion rejects raw content fields such as prompts, transcripts, raw updates, and artifact bodies.
- Accepted summaries are now limited to bounded numeric runtime-vector payloads plus safe metadata such as payload size, vector length, sample count, digest, and trace identifier.
- Audit logs record both experiment changes and accepted prototype updates.
- The HQ feature-flags page now exposes a bounded experiment editor instead of leaving prototype configuration backend-only.
- Flutter repositories and rules expose read-only experiment/update-summary records while keeping writes behind server callables.
- Runtime BOS signals now feed a bounded warm-start local fine-tune step in the Flutter adapter, which uses the currently resolved runtime package as a local starting point, nudges a bounded runtime vector toward event-derived targets across a small epoch budget, and uploads the resulting bounded local model payload on mission/checkpoint/session triggers without sending raw learner content.
- When accepted summaries cumulatively hit the experiment threshold, the backend now materializes a bounded aggregation-run record, marks the source summaries as consumed, and merges the uploaded bounded local runtime vectors into a weighted runtime payload instead of only emitting metadata.
- Aggregation selection now also skips accepted summaries whose runtime target, schema version, optimizer strategy, vector length, or warm-start package/model lineage do not match the active batch, so prototype merge runs no longer average incompatible bounded local models together just because they arrived in the same threshold window.
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
- HQ can now inspect rollout-alert history across recent runtime deliveries and open a bounded rollout-audit feed that shows the underlying delivery, activation, and alert-triage state changes per experiment or per delivery without claiming a generalized production rollout control plane.
- That rollout-audit feed now also supports direct package and site filtering in the HQ UI, the alert-history surface now shows bounded triage-change history instead of only the latest triage snapshot per delivery, and operators can persist a bounded escalation record with owner, status, notes, and issue-age metadata for unresolved rollout issues on the active delivery.
- HQ can now inspect immutable escalation-history snapshots per runtime delivery, including due-versus-overdue cues for unresolved fallback or pending rollout issues, instead of only the latest escalation state.
- HQ can now also persist a bounded rollout-control record per runtime delivery with monitor-versus-restricted-versus-paused operator mode, owner, and reason, so delivery handling can be constrained without mutating the underlying runtime-delivery manifest record.
- Site-scoped runtime package resolution now also honors those bounded rollout-control records, so paused deliveries force fallback for all sites while restricted deliveries remain usable only for sites that already reported resolved activation on that delivery.
- Aggregation materialization now also applies a bounded norm-capped weighted runtime-vector merge strategy, so high-norm prototype updates are dampened instead of contributing with raw sample-count weight alone.
- Aggregation materialization now also persists merge transparency metadata, including the applied norm cap and effective total weight after norm damping, plus contributor-site lineage for each aggregated cohort, and the HQ experiment cards, aggregation-history, candidate-package history, and promotion-history surfaces render that metadata alongside the merge strategy so operators can audit bounded merge behavior and cohort provenance throughout triage, review, and promotion flows instead of treating it as hidden backend state.
- The HQ aggregation-history, candidate-package history, and promotion-history search surfaces now also index contributor-site lineage, so operators can filter bounded merge and promotion trails directly by site ID instead of scanning digests and record IDs by hand.
- The HQ aggregation-history surface now also renders trigger-summary and accepted-summary identifiers and supports direct filtering by summary ID, so bounded merge records can be traced back to the exact accepted update-summary windows that formed each aggregation run.
- Accepted summary IDs now persist through merge artifacts and candidate packages too, and HQ candidate-package plus promotion-history surfaces render and filter those summary IDs so downstream package review stays tied to the same bounded update window.
- The downstream merge-artifact and candidate-package records now also preserve the original trigger-summary identifier, and HQ candidate-package plus promotion-history surfaces render and filter that trigger ID alongside accepted-summary windows so package review can distinguish the event that materialized an aggregation from the full accepted cohort.
- HQ candidate-package and promotion-history drill-ins now also include a direct `Open aggregation run` action seeded to the exact `aggregationRunId`, so downstream review can jump back to the precise bounded merge record and accepted-summary cohort without manual history filtering.
- HQ aggregation-history, candidate-package history, and promotion-history drill-ins now also include direct accepted-summary drill-through backed by the persisted `summaryIds`, so operators can open the exact bounded update-summary records, site lineage, trace IDs, digests, and update norms that formed a reviewed aggregation or downstream package decision instead of relying on summary IDs as text alone.
- HQ aggregation-history, candidate-package history, and promotion-history surfaces now also include direct trigger-summary drill-through backed by the persisted `triggerSummaryId`, so operators can distinguish the single accepted summary that materialized an aggregation from the broader accepted cohort without manually cross-matching IDs.
- HQ aggregation-history, candidate-package history, and promotion-history search surfaces now also index persisted update-summary provenance metadata, including `traceId` and `payloadDigest`, so operators can pivot bounded merge and promotion trails by summary-level telemetry fingerprints without opening each drill-through dialog first.
- Candidate-promotion decision and revocation records now also snapshot `packageDigest` and `boundedDigest` at decision time, and HQ package plus promotion-history surfaces render and filter those immutable digests so downstream provenance does not depend on re-resolving current package state.
- Aggregation runs, merge artifacts, and staged candidate packages now also snapshot per-summary contribution details, including raw weight, norm-scale damping, effective weight, trace ID, payload digest, and site lineage, and HQ aggregation, package, promotion, and runtime-delivery drill-ins now expose a bounded contribution-details dialog so operators can audit exactly how each accepted summary influenced a merged runtime vector instead of only seeing aggregate norm-cap metadata.
- The HQ experiment card plus aggregation, package, promotion, and runtime-delivery history surfaces now also derive bounded damping rollups from those contribution-detail rows, showing how many summaries were scaled and how raw sample-count weight compares with effective post-cap weight before an operator opens the full contribution dialog.
- Site-scoped Flutter runtime uploads now also persist bounded local-training metadata on each accepted summary, including optimizer strategy, local epoch and step counts, training-window duration, and warm-start lineage back to the currently resolved bounded package and delivery record, and the HQ accepted-summary drill-through plus provenance search now expose that metadata so prototype update records are closer to auditable on-device fine-tuning checkpoints than plain runtime sketches.
- Those accepted-summary local-training fields now also roll up onto the HQ experiment card plus aggregation, package, promotion, and runtime-delivery history surfaces, so operators can inspect aggregate optimizer, epoch, step, window, and warm-start lineage without opening every summary drill-through.
- HQ runtime-delivery history now also supports provenance-aware filtering by delivery/package IDs, summary IDs, digests, site IDs, and summary-derived optimizer or warm-start metadata, so rollout operators can isolate the exact bounded manifest lineage they need without scanning an unfiltered delivery list.
- The HQ experiment card plus aggregation, package, promotion, and runtime-delivery package-linked surfaces now also expose bounded runtime-payload lineage for staged artifacts, including model version, runtime-vector length versus ceiling, aggregate payload bytes, average update norm, and runtime-vector digest, so prototype operators can inspect more than merge IDs and package digests when auditing a bounded model package.
- Runtime-delivery records now also snapshot the bounded package lineage that was assigned to sites, including `aggregationRunId`, `mergeArtifactId`, `packageDigest`, `boundedDigest`, `triggerSummaryId`, and `summaryIds`, and HQ delivery-history drill-ins now surface that linkage with a direct `Open aggregation run` jump so rollout operators can trace a distributed manifest back to the exact bounded merge record instead of treating delivery history as a terminal leaf.
- HQ runtime-delivery history now also backfills those bounded provenance fields from the linked candidate package when older delivery rows predate the newer snapshot fields, so trigger-summary, accepted-summary, and bounded-digest drill-ins remain visible across mixed historical data instead of only on freshly written manifests.
- Runtime-delivery upserts now also supersede older overlapping assigned or active deliveries for the same experiment/runtime target, so HQ delivery history reflects bounded package succession instead of leaving multiple live manifests competing by timestamp.
- Candidate-model-package rollout state now also retires packages whose latest runtime delivery was superseded or revoked, so HQ package history distinguishes still-distributed bounded payloads from terminal ones without claiming a broader promotion or archive system.
- Site-scoped runtime resolution now also returns explicit superseded terminal package state, including supersession metadata and device-side fallback reporting, so superseded deliveries no longer disappear as null resolution gaps when HQ advances a bounded manifest.
- Runtime rollout escalation updates now also auto-resolve when a delivery is already terminal or no longer has live fallback/pending sites, and rollout-control updates now auto-release terminal deliveries back to monitor, so stale operator interventions do not outlive revoked, superseded, or expired bounded manifests.
- Runtime rollout alert triage updates now also auto-settle to acknowledged when a delivery is terminal or no longer has any live fallback/pending sites, so stale active alerts cannot persist underneath an already healthy or terminal bounded rollout.
- Runtime rollout escalation updates now also refuse to persist a resolved current escalation while fallback or pending sites still exist, so live rollout issues reopen as active escalation state instead of hiding behind stale resolved records.
- Site-scoped runtime delivery listing now also filters expired, revoked, and superseded manifests before returning assignment history to device-side resolvers, so site assignment discovery stays aligned with the bounded runtime package lifecycle instead of exposing terminal manifests and relying on client-side cleanup.
- The HQ feature-flags surface now also suppresses current rollout-alert banners and alert-first severity ordering when the latest runtime delivery is already terminal, while keeping per-site rollout counts and lifecycle drill-in detail visible for superseded, revoked, or expired deliveries.
- The HQ feature-flags surface now also suppresses misleading `Runtime activation: pending` summaries for terminal latest deliveries with no site reports, replacing them with lifecycle-aware terminal activation copy so superseded, revoked, or expired deliveries stay visible as history instead of live activation work.
- The HQ feature-flags surface now also formats already-expired runtime deliveries as `expired` instead of `live until` in card and history lifecycle copy, so expired manifests read as terminal lifecycle state throughout the bounded operator UI.
- The HQ feature-flags surface now also includes revocation actor and reason inside revoked lifecycle copy, so revoked manifests retain bounded operator context in card and delivery-history views instead of collapsing to a bare timestamp.
- Downstream promotion is still bounded to HQ-readable approval records targeting sandbox evaluation only; there is still no deployed model rollout, device delivery path, or production promotion executor in this repo.
- HQ can now inspect a short recent history of aggregation runs per experiment, including artifact generation status, instead of only a single latest-run summary.

## Remaining gap to full REQ-114

REQ-114 remains partial until all of the following exist and are approved:

- production-grade on-device training beyond the current bounded warm-start local fine-tune path
- production-grade merge semantics beyond the current bounded compatibility-aware, norm-capped weighted runtime-vector averaging path
- richer production-grade aggregation observability beyond the current bounded merge-strategy, norm-cap, effective-weight, contributor-site lineage, and accepted-summary local-training transparency surfaced in prototype records and HQ history
- production-grade rollout orchestration and long-lived model lifecycle management beyond the current bounded site-scoped expiry, supersession, retirement, revocation, paused/restricted control, and fallback path