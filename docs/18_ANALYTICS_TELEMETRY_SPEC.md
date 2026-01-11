# 18_ANALYTICS_TELEMETRY_SPEC.md

Telemetry answers: “Is the Education 2.0 loop happening?”

## Required events
- auth.login, auth.logout
- attendance.recorded
- mission.attempt.submitted
- message.sent
- order.paid
- cms.page.viewed
- popup.shown, popup.dismissed, popup.completed, nudge.snoozed
- insight.viewed
- support.applied
- support.outcome.logged

## Privacy rules
- no PII in telemetry payloads (no names, emails, message bodies)
- include siteId, role, appVersion where possible

## Dashboards (minimum)
- weekly accountability adherence rate
- educator review turnaround (SLA)
- attendance trends
- intervention outcomes (“helped” rate)
