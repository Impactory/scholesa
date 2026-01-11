# 70_BACKGROUND_JOBS_WEBHOOKS.md
Background Jobs, Webhooks, and Scheduled Work

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
Make non-UI workflows explicit so implementation is complete:
sync jobs, webhook handlers, scheduled exports/retention, notifications fan-out.

---

# 1) Job runner model
Implement a job framework:
- job collection/state: queued/running/succeeded/failed
- retries with backoff
- idempotency
- job logs with lastError
- visibility: site admin and HQ dashboards

---

# 2) Google Classroom sync jobs
Per Classroom docs:
- roster sync (phase 1)
- course/coursework sync (phase 2)
- grade push (phase 2)

Requirements:
- idempotent operations
- rate limit + retry handling
- partial failures tracked
- repeated failures raise alerts

---

# 3) GitHub webhooks
- signature verification required
- idempotency by delivery id
- normalized event store (admin-only readable)
- identity mapping via identity center

---

# 4) Stripe webhooks
- signature verification required
- idempotency by event id
- update subscription/invoices/entitlements
- notify billing admins on failure

---

# 5) Notification fan-out
Events create Notification records:
- attendance recorded
- incident escalated
- invoice due
- integration job failed

Delivery:
- in-app first
- email/sms optional based on ParentProfile preferences

---

# 6) Exports + retention jobs
- server-side export generation
- signed URL downloads with TTL
- retention execution schedules (soft → hard delete)
- restore rehearsal in staging before go-live

---

# 7) Observability
- job failure metrics
- webhook failure alerts
- backlog size alerts
