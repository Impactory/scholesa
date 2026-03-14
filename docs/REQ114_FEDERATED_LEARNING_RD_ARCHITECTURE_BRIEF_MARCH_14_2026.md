# REQ-114 Draft R and D Architecture Brief: Federated Learning Data Moat

Date: 2026-03-14
Status: Draft for approval

## Purpose

REQ-114 cannot be implemented honestly from the current repo because no approved federated-learning architecture, privacy review, or runtime plan exists.

This document defines the minimum R and D brief required before any implementation work should be authorized.

Companion review artifacts:
- `docs/REQ114_FEDERATED_LEARNING_PRIVACY_REVIEW_FORM_MARCH_14_2026.md`
- `docs/REQ114_FEDERATED_LEARNING_EXPERIMENT_SIGNOFF_CHECKLIST_MARCH_14_2026.md`

## 1) Objective

Investigate whether Scholesa can support privacy-preserving on-device learning signals that improve internal models without exporting raw learner content, raw prompts, or direct identifiers.

This is an R and D objective, not a production claim.

## 2) Non-negotiables

- No raw learner prompts, transcripts, message bodies, or evidence artifacts leave the tenant boundary as part of federated-learning experiments.
- No cross-site training joins without explicit privacy approval.
- No always-on background training on minor devices.
- Every experiment must be site-gated, feature-flagged, and remotely disableable.
- Federated learning cannot bypass COPPA, school consent, or audit requirements.

## 3) Candidate architecture

### Client runtime

Possible runtimes to evaluate:
- Flutter mobile only
- web PWA only
- hybrid, after separate privacy review

Client responsibilities:
- derive narrow feature vectors or updates from already-approved local signals
- apply privacy guards before upload
- respect battery, network, and consent constraints
- emit only experiment-safe telemetry summaries

### Coordination service

Server responsibilities:
- enroll only approved sites or cohorts
- distribute signed experiment configuration
- receive bounded client updates
- validate schema, size, and tenant scope
- aggregate updates only when privacy thresholds are met

### Aggregation layer

Minimum design constraints:
- k-anonymity style threshold before aggregate acceptance
- per-site isolation by default
- no single-client update ever applied directly to a global model
- retention policy on raw update blobs shorter than aggregate outputs

## 4) Privacy and compliance gates

Required before prototype approval:

1. Privacy impact assessment completed.
2. Re-identification risk review completed for gradient or update payloads.
3. School-consent posture defined for experimental cohorts.
4. Parent-notice language reviewed where legally required.
5. Security review completed for transport, storage, and rollback.

Required before pilot approval:

1. Device kill switch verified.
2. Data retention and deletion path verified.
3. Audit logs recorded for experiment enrollment and configuration changes.
4. Experiment limited to approved sites only.

## 5) Proposed experiment phases

### Phase 0: paper architecture

Deliverables:
- approved architecture diagram
- threat model
- privacy review
- experiment metric definition

### Phase 1: offline simulation

Deliverables:
- replay-safe synthetic or de-identified simulation harness
- aggregation threshold tests
- drift and rollback analysis

### Phase 2: controlled device pilot

Deliverables:
- feature-flagged client prototype
- site-limited rollout
- audit trail for enrollment and disablement
- explicit success and harm metrics

### Phase 3: production decision

Only after pilot review:
- decide ship, continue R and D, or cancel

## 6) Success metrics

The pilot should define measurable outcomes before any code is merged beyond prototype scope:

- improvement in approved internal model quality metric
- no privacy incidents
- no unacceptable battery or performance regressions
- no unexplained cross-site contamination
- clear rollback time objective

## 7) Failure and rollback plan

- server-side experiment disable switch
- client-side feature flag expiry
- deletion path for uploaded experimental updates
- incident playbook for privacy regression or drift anomaly

## 8) Approval block

- Product approval:
- Privacy/compliance approval:
- Security approval:
- Data/ML approval:
- Release approval:
- Experiment owner:
- Approved runtime target:
- Target site cohort:
- Decision date:

## 9) Traceability rule

REQ-114 must remain deferred until all of the following exist:
- approved R and D brief
- approved privacy review
- prototype code
- tests
- proof doc tied to actual implementation

## 10) Threat model draft

### Protected assets

- learner-derived local feature vectors
- uploaded client update blobs
- aggregation configuration
- experiment enrollment lists
- model checkpoints and derived evaluation outputs

### Trust boundaries

1. learner device runtime
2. transport from device to Scholesa backend
3. aggregation service and staging storage
4. evaluation and rollout decision surfaces

### Primary threats

| Threat | Description | Required mitigation before pilot |
| --- | --- | --- |
| update inversion | attacker or operator reconstructs sensitive learner signals from uploaded updates | keep updates bounded, aggregated only above threshold, and never expose raw per-client updates to product operators |
| membership inference | attacker infers whether a learner participated in training | site-limited cohorts, minimum cohort thresholds, no external reporting at individual level |
| cross-site contamination | updates from one site affect another without approval | site isolation by default and explicit policy for any broader aggregation |
| malicious client poisoning | compromised client uploads adversarial or malformed updates | signed config, schema validation, bounded update size, anomaly rejection, rollout kill switch |
| operator overreach | internal users inspect raw experimental data beyond approved purpose | narrow admin access, audit logs, short retention, documented review roles |
| battery or bandwidth harm | experimental runtime degrades learner devices | charge/network gating, runtime budget, remote disablement, pilot-only rollout |
| consent mismatch | experimental participation exceeds approved school or parent consent posture | experiment enrollment bound to approved sites and consent records before activation |

### Security controls required before prototype merge

- signed experiment configuration
- per-site feature flags
- bounded payload schemas
- server-side validation and rejection metrics
- audit logging for experiment enrollment and configuration changes
- storage retention policy for raw update blobs

## 11) Privacy impact checklist draft

Use this checklist before moving REQ-114 out of deferred status.

### Data classification

- [ ] Document every field in the client update payload.
- [ ] Confirm no direct identifiers are present.
- [ ] Confirm no raw prompts, transcripts, free-text reflections, or artifact content are present.
- [ ] Confirm no hidden identifiers can be reconstructed from payload combinations.

### Legal and consent posture

- [ ] Identify whether school consent is sufficient or parent notice is additionally required.
- [ ] Confirm experiment participation is limited to approved sites.
- [ ] Confirm opt-out or disable rules are documented.

### Storage and retention

- [ ] Define where raw update blobs are stored.
- [ ] Define retention limit for raw blobs.
- [ ] Define retention limit for aggregates and checkpoints.
- [ ] Define deletion process for experiment shutdown.

### Access control

- [ ] List every role allowed to view experiment configuration.
- [ ] List every role allowed to inspect raw update metrics.
- [ ] Confirm no educator or parent surface exposes experimental raw data.

### Transport and device safety

- [ ] Require secure transport for all update uploads.
- [ ] Define device-side budget for battery, CPU, and network.
- [ ] Define offline, low-battery, and metered-network behavior.

### Evaluation and reporting

- [ ] Define aggregate-only reporting thresholds.
- [ ] Confirm no per-learner model quality reporting leaves the experiment boundary.
- [ ] Confirm rollback trigger thresholds are documented.

### Approval block

- Privacy reviewer:
- Security reviewer:
- Product reviewer:
- Date:
- Result: APPROVED / HOLD

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ114_FEDERATED_LEARNING_RD_ARCHITECTURE_BRIEF_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->