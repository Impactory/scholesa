# 18_ANALYTICS_TELEMETRY_SPEC.md

Telemetry answers: “Is the Education 2.0 loop happening?”

Telemetry completeness note: mission-attempt activity events and core operational telemetry are wired, but capability-growth aggregation and Passport/report provenance consumption are not yet fully wired end to end. Do not read this spec alone as proof that learner growth claims are fully evidenced across reporting surfaces.

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
- voice.transcribe, voice.message, voice.tts

## March 12 feature-contract events

These events are required before the March 12 feature set can be called end to end:

- onboarding.started, onboarding.completed
- diagnostic.submitted
- learner.goal.updated
- fsrs.review.rated, fsrs.queue.snoozed, fsrs.queue.rescheduled
- interleaving.mode.changed
- worked_example.shown
- reflection.submitted
- accessibility.setting.changed
- class.created, class.join_code.created, roster.import.completed
- lesson.builder.saved
- assignment.published
- grading.feedback.applied
- live_session.started
- ai.guard.escalated
- mvl.required, mvl.completed
- autonomy_risk.detected
- sep.verify.prompted
- moderation.escalated
- integration.sync.started, integration.sync.completed
- auth.sso.login
- grade.passback.sent

## Privacy rules
- no PII in telemetry payloads (no names, emails, message bodies)
- include siteId, role, appVersion where possible
- include traceId, locale, and environment where possible
- no raw prompts, raw transcripts, audio bytes, or message bodies
- keep telemetry on the internal Scholesa pipeline; do not introduce vendor analytics SDKs that violate compliance posture

## Dashboards (minimum)
- weekly accountability adherence rate
- educator review turnaround (SLA)
- attendance trends
- intervention outcomes (“helped” rate)

## March 12 telemetry acceptance

For March 12 feature coverage, telemetry is not complete unless:

1. learner onboarding, diagnostic, reflection, accessibility, and FSRS actions emit structured events
2. educator authoring, roster import, assignment, and grading actions emit structured events
3. BOS or MIA guardrails emit escalation, verification, and autonomy-risk events
4. integration jobs emit start and completion events with outcomes
5. every new event remains COPPA-safe and site-scoped

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: partial (core telemetry events yes; broader capability-growth/reporting provenance still incomplete)
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `18_ANALYTICS_TELEMETRY_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
