# 66_API_ENDPOINTS_FULL_CATALOG.md
Full API Endpoints Catalog (No Minimums)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
Define the **complete server API surface** required to implement Scholesa end-to-end:
multi-role + provisioning, physical ops, learning engine, billing/marketplace/contracting,
messaging/notifications, analytics/telemetry, exports/retention, integrations (Classroom + GitHub), jobs + webhooks.

## Global conventions (strict)
- Base path: `/v1`
- Auth: Firebase ID token (`Authorization: Bearer <token>`)
- Every request: server verifies token + resolves role/site/entitlements
- Every write: supports idempotency (`Idempotency-Key`), returns server timestamps, writes AuditLog for privileged actions

## Response shapes (recommended)
- Lists: `{ "items": [...], "nextPageToken": "..." }`
- Errors: stable codes (PERMISSION_DENIED, NOT_FOUND, FAILED_PRECONDITION, INVALID_ARGUMENT)

---

# 0) Health
- GET `/healthz` → `{ "ok": true, "version": "...", "buildTag": "..." }`

---

# 1) Session + identity bootstrap
- GET `/v1/me`
- POST `/v1/site/switch`

---

# 2) Users + sites + provisioning (HQ + site admin)
Users:
- GET `/v1/users`
- GET `/v1/users/:id`
- POST `/v1/users`
- PATCH `/v1/users/:id`
- POST `/v1/users/:id/reset-password` (optional)

Sites:
- GET `/v1/sites`
- GET `/v1/sites/my`
- POST `/v1/sites`
- PATCH `/v1/sites/:id`
- POST `/v1/sites/:id/admins`

Profiles + guardian links (admin-only):
- GET `/v1/sites/:siteId/learners`
- POST `/v1/sites/:siteId/learners`
- PATCH `/v1/learners/:learnerId/profile`
- GET `/v1/sites/:siteId/parents`
- POST `/v1/sites/:siteId/parents`
- PATCH `/v1/parents/:parentId/profile`
- POST `/v1/guardian-links`
- DELETE `/v1/guardian-links/:id`
- GET `/v1/guardian-links?siteId=...`
- GET `/v1/my/children` (parent safe)

Identity resolution center:
- GET `/v1/identity/unmatched`
- POST `/v1/identity/link`
- POST `/v1/identity/unlink`
- POST `/v1/identity/merge-users` (HQ only)

---

# 3) Scheduling core: rooms, sessions, occurrences, enrollments
Rooms:
- GET `/v1/sites/:siteId/rooms`
- POST `/v1/sites/:siteId/rooms`
- PATCH `/v1/rooms/:id`
- DELETE `/v1/rooms/:id`

Sessions:
- GET `/v1/sites/:siteId/sessions`
- POST `/v1/sites/:siteId/sessions`
- PATCH `/v1/sessions/:id`
- DELETE `/v1/sessions/:id`

Occurrences:
- GET `/v1/sites/:siteId/occurrences?date=YYYY-MM-DD&educatorId=...`
- POST `/v1/sessions/:sessionId/occurrences/generate`
- PATCH `/v1/occurrences/:id`

Enrollments:
- GET `/v1/sessions/:sessionId/enrollments`
- POST `/v1/enrollments`
- PATCH `/v1/enrollments/:id`
- DELETE `/v1/enrollments/:id`

---

# 4) Attendance (offline-capable)
- GET `/v1/occurrences/today`
- GET `/v1/occurrences/:id/roster`
- GET `/v1/occurrences/:id/attendance`
- POST `/v1/occurrences/:id/attendance` (batch upsert)
- PATCH `/v1/attendance/:id`
- POST `/v1/sync/batch`

---

# 5) Physical ops: check-in/out, pickup auth, incidents, consent
Pickup authorization:
- GET `/v1/sites/:siteId/pickup-authorizations?learnerId=...`
- POST `/v1/pickup-authorizations`
- PATCH `/v1/pickup-authorizations/:id`
- DELETE `/v1/pickup-authorizations/:id`

Presence:
- GET `/v1/sites/:siteId/presence?date=YYYY-MM-DD`
- POST `/v1/presence/checkin`
- POST `/v1/presence/checkout`
- POST `/v1/presence/verify-pickup`
- POST `/v1/sync/batch`

Consent:
- GET `/v1/learners/:learnerId/consent`
- PATCH `/v1/learners/:learnerId/consent` (site admin only)

Incidents:
- GET `/v1/sites/:siteId/incidents`
- POST `/v1/incidents`
- GET `/v1/incidents/:id`
- PATCH `/v1/incidents/:id`
- POST `/v1/incidents/:id/escalate`

---

# 6) Curriculum + learning engine
Pillars/skills:
- GET `/v1/pillars`
- GET `/v1/skills?pillarCode=...`

Missions:
- GET `/v1/missions?siteId=...&publisherType=...&published=true`
- POST `/v1/missions`
- PATCH `/v1/missions/:id`
- POST `/v1/missions/:id/publish`
- POST `/v1/missions/:id/unpublish`

Snapshots (immutability):
- POST `/v1/missions/:id/snapshot`
- GET `/v1/mission-snapshots/:id`

Mission plans:
- GET `/v1/occurrences/:id/mission-plan`
- POST `/v1/occurrences/:id/mission-plan`
- PATCH `/v1/mission-plans/:id`

Attempts:
- GET `/v1/learners/:learnerId/attempts`
- POST `/v1/attempts`
- PATCH `/v1/attempts/:id`
- POST `/v1/attempts/:id/submit`
- POST `/v1/attempts/:id/review`
- GET `/v1/review-queue?siteId=...&status=submitted`

Skill mastery:
- GET `/v1/learners/:learnerId/skill-mastery`
- POST `/v1/skill-mastery/upsert`

Portfolios:
- GET `/v1/learners/:learnerId/portfolio`
- POST `/v1/portfolio-items`
- PATCH `/v1/portfolio-items/:id`
- DELETE `/v1/portfolio-items/:id`

Credentials:
- GET `/v1/learners/:learnerId/credentials`
- POST `/v1/credentials`
- DELETE `/v1/credentials/:id`

---

# 7) Accountability
- GET `/v1/accountability/cycles?scopeType=...&scopeId=...`
- POST `/v1/accountability/cycles`
- PATCH `/v1/accountability/cycles/:id`
- GET `/v1/accountability/kpis?cycleId=...`
- POST `/v1/accountability/kpis`
- PATCH `/v1/accountability/kpis/:id`
- GET `/v1/accountability/commitments?cycleId=...`
- POST `/v1/accountability/commitments`
- GET `/v1/accountability/reviews?cycleId=...`
- POST `/v1/accountability/reviews`

---

# 8) Messaging + notifications
Threads/messages:
- GET `/v1/threads`
- POST `/v1/threads`
- GET `/v1/threads/:id/messages`
- POST `/v1/threads/:id/messages`
- POST `/v1/threads/:id/archive`

Notifications:
- GET `/v1/notifications?status=unread`
- POST `/v1/notifications/:id/read`
- POST `/v1/notifications/mark-all-read`

---

# 9) Billing + entitlements (Stripe)
Plans:
- GET `/v1/billing/plans`
- POST `/v1/billing/plans` (HQ)
- PATCH `/v1/billing/plans/:id` (HQ)

Accounts:
- GET `/v1/billing/accounts/my`
- POST `/v1/billing/accounts` (HQ)
- PATCH `/v1/billing/accounts/:id` (HQ)

Subscriptions:
- POST `/v1/billing/checkout-session`
- POST `/v1/billing/subscription/cancel`
- GET `/v1/billing/subscription`

Invoices:
- GET `/v1/billing/invoices`
- GET `/v1/billing/invoices/:id`

Webhooks:
- POST `/webhooks/stripe`

Entitlements:
- GET `/v1/entitlements/my`
- POST `/v1/entitlements/grant` (HQ)
- POST `/v1/entitlements/revoke` (HQ)

---

# 10) Marketing CMS + leads
- GET `/v1/cms/pages?audience=...`
- GET `/v1/cms/pages/:slug`
- POST `/v1/cms/pages` (HQ)
- PATCH `/v1/cms/pages/:id` (HQ)
- POST `/v1/cms/pages/:id/publish` (HQ)
- POST `/v1/leads` (public)
- GET `/v1/leads` (HQ)

---

# 11) Marketplace
Partner org:
- GET `/v1/partner-orgs` (HQ)
- POST `/v1/partner-orgs` (HQ)
- PATCH `/v1/partner-orgs/:id` (HQ)

Listings:
- GET `/v1/marketplace/listings?published=true`
- POST `/v1/marketplace/listings`
- POST `/v1/marketplace/listings/:id/submit`
- POST `/v1/marketplace/listings/:id/approve` (HQ)
- POST `/v1/marketplace/listings/:id/reject` (HQ)
- POST `/v1/marketplace/listings/:id/publish` (HQ)
- PATCH `/v1/marketplace/listings/:id`

Orders/fulfillment:
- POST `/v1/marketplace/orders`
- GET `/v1/marketplace/orders/my`
- POST `/v1/marketplace/orders/:id/refund` (HQ)
- GET `/v1/marketplace/fulfillment?orderId=...`

---

# 12) Partner contracting + payouts
Contracts:
- GET `/v1/contracts`
- POST `/v1/contracts`
- POST `/v1/contracts/:id/submit`
- POST `/v1/contracts/:id/approve` (HQ)
- PATCH `/v1/contracts/:id`

Deliverables:
- GET `/v1/contracts/:id/deliverables`
- POST `/v1/deliverables`
- POST `/v1/deliverables/:id/submit`
- POST `/v1/deliverables/:id/accept` (HQ)
- POST `/v1/deliverables/:id/reject` (HQ)

Payouts:
- GET `/v1/payouts`
- POST `/v1/payouts/:id/approve` (HQ finance)
- POST `/webhooks/stripe-connect` (if used)

---

# 13) Analytics + telemetry
- POST `/v1/telemetry/events`
- GET `/v1/analytics/site-kpis?siteId=...`
- GET `/v1/analytics/hq-kpis`

---

# 14) Exports + retention + backups
Exports:
- POST `/v1/exports`
- GET `/v1/exports/:id/status`
- GET `/v1/exports/:id/download` (signed URL)

Retention:
- POST `/v1/retention/delete-request`
- POST `/v1/retention/execute` (scheduled job)

---

# 15) Integrations — Google Classroom
Per docs 28–32, 39:
- POST `/v1/integrations/classroom/connect`
- POST `/v1/integrations/classroom/callback`
- GET `/v1/integrations/classroom/status`
- POST `/v1/integrations/classroom/sync/roster`
- POST `/v1/integrations/classroom/sync/coursework` (phase 2)
- POST `/v1/integrations/classroom/push/grades` (phase 2)
- GET `/v1/integrations/classroom/jobs`

---

# 16) Integrations — GitHub
Per docs 40:
- POST `/v1/integrations/github/connect`
- GET `/v1/integrations/github/status`
- POST `/v1/integrations/github/link-repo`
- POST `/webhooks/github`
- GET `/v1/integrations/github/events`

---

# 17) Admin tooling
- GET `/v1/audit-logs?siteId=...`
- GET `/v1/system/feature-flags` (HQ)
- PATCH `/v1/system/feature-flags` (HQ)
