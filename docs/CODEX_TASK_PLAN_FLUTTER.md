# Codex Task Plan — Flutter Platform Completion

## Title
Flutter app completion: telemetry, provisioning, messaging, CMS, marketplace/billing, partner contracting, AI drafts, offline extensions

## Current status (Jan 7, 2026)
- Telemetry wired for auth/logout, attendance, mission attempts, CMS landing view, messaging send, order paid (client trigger), contracting, AI drafts, notification requests.
- Admin provisioning UI for learner/parent/guardian links in dashboards; audit writes in place; entitlements used to gate cards.
- Messaging threads/messages UI with rate limits, attachment upload path, external notification enqueue + scheduled processor; offline drafts still pending.
- Marketplace: client checkout card creates paid orders + grants entitlements + refreshes role claims; **server-authoritative billing still required**.
- Lead capture on landing page writes to Firestore; cms page render done; telemetry lead submitted enabled.
- Contracting UI (org/contract/deliverable/payout) with evidence upload, rules, telemetry/audit; QA pending.
- AI drafts request/review UI with telemetry/audit; rules added; QA pending.
- Tests: flutter analyze/test passing after recent changes; rules tests pass (emulator warning noted).

## Next work items (ordered)
1) Make billing server-authoritative: move checkout/payment + entitlement grant behind Cloud Run/Firebase function; client only raises intents; validate signature/idempotency per docs/13 + docs/15; add rule coverage.
2) Offline + telemetry glue: queue only permitted drafts (e.g., messaging drafts if allowed), ensure contracting/AI events stay PII-safe; refresh entitlements post-fulfillment.
3) Messaging/notifications hardening: server-side processor throttling (added) needs delivery hook/audit; consider offline drafts if allowed; add rule tests if needed.
4) QA + audit: run docs/09, update docs/19/20 evidence, sync docs/10 traceability for new REQs.
5) Marketplace listing/checkout polish + entitlement gating UX.

## Scope
- Roles impacted: learner, educator, parent, site, hq, partner, billing admin, marketing operator
- Collections touched: users, learnerProfiles, parentProfiles, guardianLinks, attendanceRecords, missionAttempts, portfolioItems, credentials, telemetryEvents, cmsPages, leads, marketplaceListings, orders, fulfillments, entitlements, messageThreads, messages, notifications, partnerOrgs, partnerContracts, partnerDeliverables, payouts
- Endpoints touched: callable logTelemetryEvent (client emit), API checkout/fulfillment hooks (client-initiated intents), messaging send pipeline triggers, CMS lead capture endpoint (optional), partner contracting approval endpoints
- Offline required: yes — attendance/mission/portfolio already; extend to safe drafts (messaging drafts, leads) where permitted by policy

## Docs to follow
01, 02, 02A, 05, 06, 08, 09, 12, 13, 14, 15, 16, 17, 18

## Plan
1) Telemetry wiring: emit canonical events on attendance, mission attempt, messaging send, CMS page view, order paid (from API callbacks surfaced to client), ensure no PII in metadata.
2) Admin provisioning UI: site/hq-only creation of learner/parent profiles + guardianLinks with siteId enforcement, audit hooks, validation.
3) Messaging slice: in-app threads/messages UI with participant validation; request notification sends via API; surface rate-limit/audit cues.
4) Marketing CMS slice: public `/p/{slug}` renderer, lead capture form, publish-state handling, telemetry cms.page.viewed.
5) Marketplace + billing: listing catalog/detail, checkout intent via Dart API, post-payment fulfillment view, entitlement gating banners.
6) Partner contracting: partner dashboard for contracts/deliverables/payout status; HQ approvals; evidence uploads; telemetry for contract/deliverable/payout.
7) AI drafts UX: request draft (API), review/approve/reject states; never auto-send.
8) Offline extensions: queue allowable drafts (messaging, leads) and sync inspector updates; keep billing writes online-only.
9) QA/build: flutter analyze/test/build web; update QA_RUNBOOK, audits, traceability with evidence.

## Implementation checklist
- [ ] UI complete (no placeholder stubs)
- [ ] API complete (authz, validation, idempotency) — client will call server endpoints where required
- [ ] Firestore rules updated + tested (client-side assumptions align)
- [ ] Offline behavior covered (if applicable)
- [ ] Telemetry events emitted (docs/18)
- [ ] Tests added

## Verification
### Automated
- flutter analyze
- flutter test
- flutter build web --release
 - npm test -- --runInBand --testPathPattern=rules.test.ts (with emulators set)

### Manual QA
- Attendance online/offline submit with telemetry
- Mission attempt submit with reflection/artifacts offline -> sync
- Admin provisioning flow (learner/parent/link) site-scoped
- Messaging thread creation/send; notification request; rate-limit feedback
- CMS page render + lead capture
- Marketplace listing browse -> checkout intent -> fulfillment view (call completeCheckoutWebhook/completeCheckout; set WEBHOOK_SECRET)
- Refresh entitlements after fulfillment (dashboard button)
- Partner contract approval + deliverable upload + payout status
- AI draft request -> approve/reject
- Offline queue inspector shows pending/failed/resolved

## Traceability updates
- Update `TRACEABILITY_MATRIX.md` for new REQs covering telemetry, provisioning UI, messaging, CMS, marketplace/billing, partner contracting, AI drafts, offline extensions, analytics consumption.
