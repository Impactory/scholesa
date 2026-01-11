# Compliance Report

## Status Summary
- Deferred items logged in DEFERMENT_LOG.md (web stack paused: REQ-001–036, 039–040, 043, 045).
- Schema parity: Flutter models/repos implemented for core LMS (users, sessions, occurrences, enrollments, attendance, missions, attempts, portfolios, accountability, audit logs); web stack still paused.
- Role routing (web): implemented with tests (✅).
- Dashboards (web) paused; Flutter dashboards (learner/educator/parent/site/partner/hq) styled and live (✅ for Flutter UI, data wiring partial).
- Offline: Flutter connectivity banner + persistent queue with dedup + auto-flush (✅ in app); web offline queue remains paused.
- Invariants: docId/pillarCodes/accountability dates enforced in services (🟡 extend to all repos).
- Audit logs: privileged writes for attempts/attendance/portfolio items (🟡 extend to others).
- Tests: routing/invariants/models/audit helper present (web); Flutter tests not added yet (🟡 overall).
- Build/PWA/Cloud Run (web): not validated (🔴 until run). Flutter builds locally via `flutter run`/`flutter build` pending CI.

## Evidence (current)
- Web routing test: src/__tests__/routing.test.ts
- Invariants test: src/__tests__/invariants.test.ts
- Models test: src/__tests__/models.test.ts
- Audit helper test: src/__tests__/audit_log.test.ts
- Web offline queue (paused stack): src/offline/offlineQueue.ts
- Web dashboards: app/[locale]/(protected)/*
- Flutter offline: apps/empire_flutter/app/lib/features/offline/* (banner, queue, service)
- Flutter dashboards/auth/theme: apps/empire_flutter/app/lib/features/* and app/lib/app.dart

## Blockers / Next
- Complete pending web repos (Skill, SkillMastery, MissionPlan, Portfolio, Credential) or formally defer.
- Add more unit roundtrips (web) and Flutter widget/unit tests.
- Execute QA runbook (web paused; Flutter flows) and attach evidence.
- Run `npm test`, `npm run build` (web) if re-enabled; add `flutter test`/`flutter build` pipeline.