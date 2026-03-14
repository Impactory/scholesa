# REQ-113 Replacement Proposal: Internal Telemetry and Warehouse Export

Date: 2026-03-14
Status: Draft for approval

## Purpose

REQ-113 currently names PostHog and Segment, but the repo's active compliance posture forbids introducing vendor analytics SDKs or vendor event pipelines to satisfy the requirement.

This document proposes the exact wording needed to replace the vendor-specific requirement with an approved internal telemetry posture that matches the current platform direction.

## 1) Why replacement is needed

Current governing docs already say the vendor-specific requirement should not be implemented as written:

- `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md`
- `docs/18_ANALYTICS_TELEMETRY_SPEC.md`

Current policy summary:
- Keep telemetry on the internal Scholesa pipeline.
- Keep data COPPA-safe and site-scoped.
- Allow warehouse-friendly export only after privacy review.
- Do not introduce PostHog or Segment just to satisfy a feature row.

## 2) Proposed replacement requirement text

Replace:
- `PostHog and Segment capture`

With:
- `Internal telemetry capture with warehouse-friendly export adapters`

## 3) Proposed product-contract wording

Recommended canonical wording:

`Scholesa captures product telemetry through the internal event pipeline and may expose warehouse-friendly export adapters after privacy and compliance review. Vendor analytics SDKs are not required and are not the system of record.`

## 4) Proposed traceability wording

Recommended replacement row text for `docs/TRACEABILITY_MATRIX.md` once governance approves the wording change:

| Requirement | Implementation | Proof |
| --- | --- | --- |
| Internal telemetry capture with warehouse-friendly export adapters | `docs/18_ANALYTICS_TELEMETRY_SPEC.md`, `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`, internal telemetry emitters and aggregation jobs | Internal telemetry audit docs and validation gates |

## 5) Proposed wording updates in feature docs

### `feature sets 2025 March 12.md`

Replace:
- `PostHog/Segment capture`

With:
- `Internal telemetry capture with warehouse-friendly export posture`

### `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md`

Retain the blocker note, but add the approved replacement wording after governance sign-off.

## 6) Acceptance gates for the replacement requirement

The replacement requirement can only be marked green when:

1. Internal telemetry remains the source of truth.
2. Required March 12 event families are emitted.
3. No banned vendor SDKs or external analytics egress paths are introduced.
4. Export adapters, if added, pass privacy and compliance review.
5. Event payloads remain site-scoped, COPPA-safe, and free of raw prompts, transcripts, names, and emails.

## 7) Approval block

- Product approval:
- Compliance approval:
- Security approval:
- Release approval:
- Replacement wording approved: yes/no
- Traceability update approved: yes/no
- Decision date:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no change
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ113_INTERNAL_TELEMETRY_REPLACEMENT_PROPOSAL_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->