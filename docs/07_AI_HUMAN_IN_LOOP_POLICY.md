# 07_AI_HUMAN_IN_LOOP_POLICY.md

AI is allowed only as drafting assistance.

## Allowed
- draft teacher feedback wording (teacher approves)
- draft weekly parent summary wording (teacher/admin approves)
- suggest support strategies with “why” and confidence
- suggest learner commitments (learner chooses)

## Not allowed
- auto-grading
- diagnosing or sensitive inference
- auto-sending messages to parents
- auto-approving payouts/contracts/listings

## Storage requirements
Any AI-generated text stored with:
- status: DRAFT|APPROVED|REJECTED
- reviewedBy + reviewedAt
- linked signals used (“why”)
- AuditLog on approval

## UX requirement
Every AI suggestion must show:
- why (signals)
- confidence
- editable content before approve

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `07_AI_HUMAN_IN_LOOP_POLICY.md`
<!-- TELEMETRY_WIRING:END -->
