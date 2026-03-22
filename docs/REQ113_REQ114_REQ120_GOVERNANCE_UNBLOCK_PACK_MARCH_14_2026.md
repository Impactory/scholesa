# Governance Unblock Pack for REQ-113, REQ-114, and REQ-120

Date: 2026-03-14

## Purpose

This pack converts the remaining open requirements into explicit governance decisions with named approval tracks, entry criteria, and exit gates.

It is intended to replace vague "blocked" or "planned" status with an approval-ready record that Product, Compliance, Security, and Release can act on.

Canonical supporting evidence already present in the repo:

- `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md`
- `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- `docs/REQ113_REQ114_REQ120_BLOCKER_STATUS_MARCH_14_2026.md`
- `docs/TRACEABILITY_MATRIX.md`

Draft decision artifacts created from this pack:

- `docs/REQ120_CLEVER_CLASSLINK_INTEGRATION_CHARTER_DRAFT_MARCH_14_2026.md`
- `docs/REQ120_CLEVER_INTERNAL_API_CONTRACT_DRAFT_MARCH_14_2026.md`
- `docs/REQ113_INTERNAL_TELEMETRY_REPLACEMENT_PROPOSAL_MARCH_14_2026.md`
- `docs/REQ114_FEDERATED_LEARNING_RD_ARCHITECTURE_BRIEF_MARCH_14_2026.md`
- `docs/REQ114_FEDERATED_LEARNING_PRIVACY_REVIEW_FORM_MARCH_14_2026.md`
- `docs/REQ114_FEDERATED_LEARNING_EXPERIMENT_SIGNOFF_CHECKLIST_MARCH_14_2026.md`

## Current Decision Summary

| Requirement | Current state | Why it is not green today | Decision needed |
| --- | --- | --- | --- |
| REQ-113 | resolved by replacement | Vendor analytics capture conflicts with current compliance posture, and the active execution plan now treats internal telemetry plus warehouse-friendly export as the satisfied contract | Approve a vendor analytics exception only if leadership wants to override the current internal-first contract |
| REQ-114 | deferred | A bounded prototype exists, but there is still no approved production architecture, privacy review, or pilot sign-off for release-grade claims | Approve an R and D charter and production guardrails before moving beyond prototype status |
| REQ-120 | deferred | Clever/ClassLink remain planned-only with no approved delivery charter | Approve an integration charter with scopes, data handling, and rollout gates |

## REQ-113: PostHog and Segment Capture

### Existing repo policy

- `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md` states vendor analytics paths such as PostHog or Segment must not be introduced to satisfy the requirement.
- `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md` directs the team to treat vendor capture as not approved and use the internal telemetry pipeline plus warehouse-friendly export only.

### Governance question

Choose exactly one:

1. Keep the vendor-ban posture and replace REQ-113 with an internal-export requirement.
2. Approve a narrow compliance exception for one or both vendors.

Current honest state:

- The active execution plan already follows option 1.
- REQ-113 is therefore satisfied under the internal telemetry contract.
- This section remains relevant only if leadership wants to reopen vendor analytics as an exception path.

### Required approvers

- Product owner
- Compliance owner
- Security owner
- Release owner

### If exception is requested, minimum entry criteria

- Data Processing Agreement review completed.
- Student-data classification completed for every event family proposed for export.
- Written confirmation that no raw learner prompts, transcripts, PII, or cross-site joins leave the internal telemetry boundary.
- Retention, deletion, and tenant-isolation controls documented.
- Vendor domains added to an approved egress list with security review.

### Exit gates if exception is approved

- Approved vendor scope list exists.
- Event allowlist exists and is mapped to `docs/18_ANALYTICS_TELEMETRY_SPEC.md`.
- Security review signed.
- Compliance review signed.
- Targeted tests and audit jobs added.
- Traceability row updated with code and proof docs.

### Decision record

- Decision: APPROVE EXCEPTION / REPLACE REQUIREMENT / HOLD
- Owner:
- Date:
- Reference ticket:
- Notes:

## REQ-114: Federated Learning Data Moat

### Existing repo policy

- `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md` states unimplemented features such as federated learning must remain planned or deferred until code and tests exist.
- `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md` states the item must stay partial until architecture, privacy review, runtime code, and broader tests are all real and approved.

Current honest state:

- A bounded federated-learning prototype now exists in the repo.
- That prototype is not yet enough to claim shipped federated-learning delivery, production rollout, or privacy-approved pilot readiness.
- Governance is still required before the requirement can move beyond deferred or prototype status.

### Governance question

Should Scholesa fund a real federated-learning R and D track, or should the requirement be reworded to a non-federated internal analytics moat?

### Required approvers

- Product owner
- Privacy/compliance owner
- Security owner
- Data/ML owner
- Release owner

### Minimum entry criteria for an R and D charter

- Privacy impact assessment completed.
- On-device runtime target defined: web, Flutter mobile, or both.
- Gradient/update format defined and reviewed for re-identification risk.
- Consent posture defined for minors and school-admin contracts.
- Rollback and disable strategy defined.

### Exit gates before implementation can be claimed

- Approved architecture doc.
- Approved privacy review.
- Approved data retention and deletion policy.
- Prototype runtime and aggregation code merged.
- Test harness for device and server aggregation flows exists.
- Traceability row updated with code and proof docs.

### Decision record

- Decision: FUND R AND D / REWORD REQUIREMENT / HOLD
- Owner:
- Date:
- Reference ticket:
- Notes:

## REQ-120: Clever and ClassLink Integrations

### Existing repo policy

- `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md` states Clever and ClassLink should remain deferred unless a full integration charter is approved.
- Existing shipped integration coverage already includes CSV SIS import, Google Classroom, LTI 1.3, grade passback, and enterprise SSO.

### Governance question

Which integration, if any, should be funded first, and what exact scope is approved?

### Required approvers

- Product owner
- Partnerships/business owner
- Compliance owner
- Security owner
- Release owner

### Minimum integration charter fields

- Provider: Clever / ClassLink / both
- Supported flows: roster sync, SSO, provisioning, grade sync, or launch only
- Tenant onboarding and credential ownership model
- Site-scoping and district-scoping rules
- Data contract and retention limits
- Failure handling and retry policy
- Support ownership and rollback plan

### Exit gates before implementation can be claimed

- Approved integration charter exists.
- Provider auth and webhook or sync contract documented.
- Canonical schema additions approved.
- Security and compliance review signed.
- Web/backend/mobile surfaces identified.
- Tests and failure-path evidence added.
- Traceability row updated with code and proof docs.

### Decision record

- Decision: FUND CLEVER / FUND CLASSLINK / FUND BOTH / HOLD
- Owner:
- Date:
- Reference ticket:
- Notes:

## Consolidated Sign-off

- Product approval:
- Compliance approval:
- Security approval:
- Release approval:
- Final disposition date:

## Recommended immediate action

1. Keep REQ-113 on the internal telemetry export posture unless leadership explicitly wants a vendor exception.
2. Keep REQ-114 in R and D until a privacy-reviewed architecture exists.
3. Approve one integration charter for REQ-120 rather than authorizing Clever and ClassLink together by default.