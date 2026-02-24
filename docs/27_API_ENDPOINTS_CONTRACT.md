# 27_API_ENDPOINTS_CONTRACT.md

This is the **production API contract** for the Empire Dart API deployed on Cloud Run.

> The API MUST enforce Firebase auth, role checks, site scoping, idempotency, and audit logs.

---

## A) Conventions

### Base URL
- `https://<cloud-run-service>/api`

### Auth
Protected endpoints require:
- `Authorization: Bearer <Firebase ID token>`

API must:
- verify token
- load `users/{uid}` to determine role and site scope

### Required headers
- `Idempotency-Key` for retryable writes (offline + mobile + classroom)

### Standard error format
```json
{
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "Human readable message",
    "details": { "hint": "optional" }
  }
}
```

### Audit logs
For privileged ops, API writes AuditLog:
- actorId, actorRole, action, entityType, entityId, siteId, details

---

## B) Public endpoints

### GET /health
Returns 200 OK when healthy.

### POST /billing/webhook
Public (Stripe), signature verified.
Must be idempotent (replays safe).

(Optionally)
### POST /telemetry
If routing telemetry through API instead of direct Firestore.

---

## C) Auth/bootstrap

### GET /me
Protected.
Returns:
- uid, role, siteIds, activeSiteId
- optionally entitlements summary for active site

### POST /sites/active
Protected.
Body: { "activeSiteId": "<id>" }
Rules:
- user must belong to siteId
- update user.activeSiteId

---

## D) Admin provisioning (site/hq only)

### POST /admin/users
Creates user record (and optionally invite workflow).
Body: { email, role, siteIds, displayName? }

### POST /admin/guardian-links
Body: { parentId, learnerId, siteId, relationship?, isPrimary? }
Must be idempotent (no duplicates).

### POST /admin/learner-profile
Must include admin-only intake:
- metadata.kyleParrot = { kyleAnswer, parrotAnswer }

### POST /admin/parent-profile

All provisioning endpoints:
- enforce site scope
- write AuditLog

---

## E) Sessions + class operations

### POST /sessions
Create session template.

### POST /session-occurrences
Create occurrence (for date/time).

### POST /enrollments
Enroll learner in session.

### POST /attendance/batch
Purpose: classroom speed + offline retries.
Body:
- siteId, sessionOccurrenceId
- records: [{ learnerId, status, note? }]

Rules:
- deterministic ID server-side: `${sessionOccurrenceId}_${learnerId}`
- recordedBy = auth uid
- idempotent upserts safe to retry

---

## F) Missions

### POST /mission-plans
Educator sets mission plan for occurrence.

### POST /mission-attempts
Learner creates/updates attempt.
Rules:
- learnerId derived from auth uid
- learner cannot set reviewedBy/reviewNotes

### POST /mission-attempts/{id}/submit
Learner submits attempt; emits telemetry.

### POST /mission-attempts/{id}/review
Educator reviews; reviewedBy derived from auth uid; audited.

---

## G) Messaging

### POST /threads
Creates thread.
Rules:
- participants must share site OR have valid guardian/learner relationship
- prevent random educator outreach by parents

### POST /threads/{id}/messages
Send message.
Rules:
- rate limit
- relationship + site scope enforced

---

## H) Billing (Stripe)

### POST /billing/checkout-session
Protected.
Body:
- planId, ownerType, ownerId, successUrl, cancelUrl
Rules:
- validate owner scope
Returns: { checkoutUrl }

### POST /billing/webhook
Verifies signature, idempotent events:
- writes Subscription/Invoice/EntitlementGrants
- writes AuditLog for billing updates

---

## I) Marketplace

### POST /listings
Create listing draft/submitted.

### POST /listings/{id}/submit
Submit for HQ review.

### POST /listings/{id}/approve
HQ only. Sets approvedBy/approvedAt and can publish.

### POST /orders
Creates order intent; prefer API-only flow.
Paid state should come from webhook.

---

## J) Contracting + payouts

### POST /contracts
Partner creates draft; HQ can also create.

### POST /contracts/{id}/approve
HQ only.

### POST /deliverables
Partner submits deliverable evidence.

### POST /deliverables/{id}/accept
HQ only.

### POST /payouts/{id}/approve
HQ finance only.

---

## K) Intelligence + popups

### GET /configs/support-strategies
Returns configs/supportStrategies.

### GET /configs/popup-rules
Returns configs/popupRules.

### POST /signals/recompute
HQ/site admin/scheduled job.
Computes learnerSignals.

### POST /insights/generate-session
Generates sessionInsights + updates learnerInsights (optional).

### POST /support-interventions
Educator logs a strategy + outcome.
Must support idempotency for offline retries.

---

## Non-negotiables
- No endpoint returns teacher intelligence to parents.
- All retryable writes are idempotent.
- Privileged actions write AuditLog.
- Stripe webhooks are signature-verified and replay-safe.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `27_API_ENDPOINTS_CONTRACT.md`
<!-- TELEMETRY_WIRING:END -->
