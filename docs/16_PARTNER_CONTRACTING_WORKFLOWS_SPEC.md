# 16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md

Partner contracting governs scope, deliverables, and payouts.

## Objects
- PartnerContract
- PartnerDeliverable
- Payout

## Workflow
Contract: draft → submitted → negotiation → approved → active → completed/terminated
Deliverable: planned → in_progress → submitted → accepted/rejected
Payout: pending → approved → paid/failed

## Governance
- HQ approves contracts
- HQ accepts deliverables (or delegates with explicit policy)
- HQ finance approves payouts
- audit logs on approvals

## MVP screens
- contract list/detail
- deliverable submit + accept/reject
- payout approval dashboard

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
