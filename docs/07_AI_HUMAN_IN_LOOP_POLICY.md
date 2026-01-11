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
