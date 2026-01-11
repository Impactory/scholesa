# 69_UI_SCREEN_INVENTORY.md
UI Screen Inventory (All roles, all modules)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
Provide an unambiguous list of screens that must exist for “fully implemented”.
Aligns to:
- `47_ROLE_DASHBOARD_CARD_REGISTRY.md`
- module specs (physical ops, learning, billing, integrations, marketplace, etc.)

---

# 1) Shared foundation
- /login
- /register (if enabled)
- /forgot-password (if enabled)
- /fatal-error (retry screen)
- /profile (self)
- /notifications
- /messages (threads list + detail)

# 2) Learner
- /learner/today
- /learner/missions
- /learner/attempt/:id
- /learner/portfolio
- /learner/credentials
- /learner/habits (pillar habits, streaks, nudges)
- /learner/settings

# 3) Educator
- /educator/today
- /educator/occurrence/:id/roster
- /educator/occurrence/:id/attendance (offline)
- /educator/mission-plans
- /educator/review-queue
- /educator/review/:attemptId
- /educator/learner-supports (AI insights for in-class supports; parent-safe boundary)
- /educator/incidents/new
- /educator/integrations

# 4) Parent (parent-safe)
- /parent/summary (weekly)
- /parent/child/:learnerId
- /parent/portfolio (safe)
- /parent/messages
- /parent/consent (view-only; admin workflow)
- /parent/billing (if parent payer)
- /parent/settings

# 5) Site admin
- /site/ops (today overview)
- /site/provisioning (create users, link guardians)
- /site/identity (resolve unmatched)
- /site/checkin (presence monitor)
- /site/pickup-auth
- /site/incidents (review/close/escalate)
- /site/consent (manage consent flags)
- /site/scheduling (rooms/sessions/occurrences)
- /site/billing
- /site/integrations-health
- /site/audit

# 6) Partner
- /partner/listings
- /partner/contracts
- /partner/deliverables
- /partner/payouts
- /partner/integrations

# 7) HQ
- /hq/user-admin
- /hq/approvals
- /hq/audit
- /hq/billing
- /hq/safety
- /hq/integrations-health
- /hq/analytics
- /hq/cms
- /hq/exports

---

## Screen DoD (applies to every enabled route)
- role gate
- data load + empty + error + retry
- consistent design language
- emits key telemetry events (bounded, no PII)
