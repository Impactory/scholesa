# 17_MESSAGING_NOTIFICATIONS_SPEC.md

Messaging must be safe and relationship-scoped.

## Objects
- MessageThread
- Message
- Notification

## Relationship rules
- participants must share site OR be related through a learner link
- parents cannot message random educators outside the site
- rate limiting required (API)

## MVP
- thread list
- thread view
- send message
- in-app notifications

## Security
- deny message writes if relationship constraints fail
- audit log for system messages (optional but recommended)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `17_MESSAGING_NOTIFICATIONS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
