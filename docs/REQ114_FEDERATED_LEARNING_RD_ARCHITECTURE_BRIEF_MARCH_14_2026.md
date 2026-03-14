# REQ-114 Draft R and D Architecture Brief: Federated Learning Data Moat

Date: 2026-03-14
Status: Draft for approval

## Purpose

REQ-114 cannot be implemented honestly from the current repo because no approved federated-learning architecture, privacy review, or runtime plan exists.

This document defines the minimum R and D brief required before any implementation work should be authorized.

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

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ114_FEDERATED_LEARNING_RD_ARCHITECTURE_BRIEF_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->