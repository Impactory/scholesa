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
