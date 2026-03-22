# Compliance Report

## Status Summary
- Deferred items logged in DEFERMENT_LOG.md, but the locale-first web track is active and validated for routing, protected access, and tri-locale entry coverage.
- Schema parity: Flutter models/repos implemented for core LMS (users, sessions, occurrences, enrollments, attendance, missions, attempts, portfolios, accountability, audit logs); active web routing and dashboard entry coverage is validated, while broader web data-access layers remain deferred and there is no implemented `src/repositories/` layer in the current repo.
- Role routing (web): implemented with tests (✅).
- Dashboards (web): protected role entry, redirects, and generic workflow-shell mounting are validated in the browser harness; that harness runs with `NEXT_PUBLIC_E2E_TEST_MODE=1`, so it proves route composition and role gating rather than live production data backends. Flutter dashboards (learner/educator/parent/site/partner/hq) are styled and live (✅ for Flutter UI, data wiring partial).
- Offline: Flutter connectivity banner + persistent queue with dedup + auto-flush (✅ in app); web offline queue remains partially deferred.
- Invariants: docId/pillarCodes/accountability dates enforced in services (🟡 extend to all repos).
- Audit logs: privileged writes for attempts/attendance/portfolio items (🟡 extend to others).
- Tests: Playwright role-routing and locale-entry workflow suite is green on web, but it runs against the explicit fake E2E backend rather than Firestore or callables; focused Flutter localization/workflow suites are green (🟡 broader coverage still expandable).
- Build/PWA/Cloud Run (web): production build and browser-harness route validation executed; broader live web backend and deployment validation remains open. Flutter builds locally via `flutter run`/`flutter build` pending CI.

## Evidence (current)
- Web workflow-route harness (fake backend mode): test/e2e/workflow-routes.e2e.spec.ts
- Web i18n key audit: scripts/vibe_i18n_keys.js
- Web routing test: src/__tests__/routing.test.ts
- Invariants test: src/__tests__/invariants.test.ts
- Models test: src/__tests__/models.test.ts
- Audit helper test: src/__tests__/audit_log.test.ts
- Web offline queue (paused stack): src/offline/offlineQueue.ts
- Web dashboards: app/[locale]/(protected)/*
- Flutter offline: apps/empire_flutter/app/lib/features/offline/* (banner, queue, service)
- Flutter dashboards/auth/theme: apps/empire_flutter/app/lib/features/* and app/lib/app.dart

## Blockers / Next
- Formally defer or implement the missing web data-access layer for domains previously described as pending web repos (Skill, SkillMastery, MissionPlan, Portfolio, Credential); there is no current `src/repositories/` implementation to complete incrementally.
- Add more unit roundtrips (web) and Flutter widget/unit tests.
- Execute QA runbook and attach evidence for broader non-routing web surfaces.
- Run remaining broad web/unit/build gates and add sustained `flutter test`/`flutter build` pipeline coverage.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `COMPLIANCE_REPORT.md`
<!-- TELEMETRY_WIRING:END -->
