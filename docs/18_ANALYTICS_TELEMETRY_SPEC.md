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

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `18_ANALYTICS_TELEMETRY_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
