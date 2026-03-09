# Traceability Matrix

> Current status: Flutter and locale-first web tracks are active. Role-routing, protected-route, and tri-locale web coverage are validated through the non-emulator Playwright workflow suite and i18n key audit.

| Req ID | Requirement | Implementation Files | Verification | Status |
| --- | --- | --- | --- | --- |
| REQ-001 | Dart/Flutter models/repos for User | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ (Flutter models/repos; site scoping) |
| REQ-002 | Dart/Flutter models/repos for Site | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-003 | Dart/Flutter models/repos for Session | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-004 | Dart/Flutter models/repos for SessionOccurrence | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-005 | Dart/Flutter models/repos for Enrollment | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-006 | Dart/Flutter models/repos for AttendanceRecord | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ (deterministic docId helper) |
| REQ-007 | Dart/Flutter models/repos for Pillar | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-008 | Dart/Flutter models/repos for Skill | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-009 | Dart/Flutter models/repos for SkillMastery | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-010 | Dart/Flutter models/repos for Mission + invariant | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ (pillar codes captured) |
| REQ-011 | Dart/Flutter models/repos for MissionPlan | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-012 | Dart/Flutter models/repos for MissionAttempt | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-013 | Dart/Flutter models/repos for Portfolio | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-014 | Dart/Flutter models/repos for PortfolioItem | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-015 | Dart/Flutter models/repos for Credential | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-016 | Dart/Flutter models/repos for AccountabilityCycle + date invariant | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ (start/end captured) |
| REQ-017 | Dart/Flutter models/repos for AccountabilityKPI | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-018 | Dart/Flutter models/repos for AccountabilityCommitment | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-019 | Dart/Flutter models/repos for AccountabilityReview | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-020 | AuditLog model/repos + logging | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ (AuditLogRepository.log) |
| REQ-021 | Role routing map | apps/empire_flutter/app/lib/features/auth/role_routes.dart, app/lib/features/dashboards/role_selector_page.dart, app/[locale]/(protected)/*, middleware.ts | Manual: FL-ROUTE-01; Playwright: workflow-routes.e2e.spec.ts | ✅ (Flutter role map + guard; web locale-first protected routing validated in non-emulator browser E2E) |
| REQ-022 | Learner dashboard E2E slice | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart, offline/offline_actions.dart, offline/offline_dispatchers.dart | Manual: FL-LRN-01 | ✅ (Flutter mission + portfolio flows, offline-aware) |
| REQ-023 | Educator dashboard E2E slice | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart, offline/offline_actions.dart, offline/offline_dispatchers.dart | Manual: FL-EDU-01 | ✅ (Flutter attendance flow with deterministic IDs) |
| REQ-024 | Parent dashboard E2E slice | app/[locale]/(protected)/parent/page.tsx, src/repositories/userRepository.ts, test/e2e/workflow-routes.e2e.spec.ts | Playwright: parent workflow + parent route denial | ✅ (parent default routing, linked portfolio visibility, and denied site-route fallback validated) |
| REQ-025 | Site lead dashboard E2E slice | app/[locale]/(protected)/site/page.tsx, test/e2e/workflow-routes.e2e.spec.ts | Playwright: site workflow + site route denial | ✅ (site default routing, guardian-link provisioning flow, and denied partner-route fallback validated) |
| REQ-026 | Partner dashboard minimal flow | app/[locale]/(protected)/partner/page.tsx, test/e2e/workflow-routes.e2e.spec.ts | Playwright: partner workflow + partner route denial | ✅ (partner default routing, listing publish flow, and denied site-route fallback validated) |
| REQ-027 | HQ dashboard mission + KPI | app/[locale]/(protected)/hq/page.tsx, test/e2e/workflow-routes.e2e.spec.ts | Playwright: HQ workflow + unauthenticated denial | ✅ (HQ default routing, site activation flow, and unauthenticated denial validated) |
| REQ-028 | Offline queue AttendanceRecord | apps/empire_flutter/app/lib/features/offline/offline_queue.dart, offline/offline_dispatchers.dart | Manual: OFF-EDU-01 | ✅ (Flutter offline queue dispatches via AttendanceRepository + audit) |
| REQ-029 | Offline queue MissionAttempt | apps/empire_flutter/app/lib/features/offline/offline_queue.dart, offline/offline_dispatchers.dart | Manual: OFF-LRN-01 | ✅ (Flutter offline queue dispatches via MissionAttemptRepository + audit) |
| REQ-030 | Offline queue PortfolioItem/reflection | apps/empire_flutter/app/lib/features/offline/offline_queue.dart, offline/offline_dispatchers.dart | Manual: OFF-LRN-02 | ✅ (Flutter offline queue dispatches via PortfolioItemRepository + audit) |
| REQ-031 | Invariant enforcement | src/lib/invariants.ts | Unit: invariants.test.ts | ⚠️ Flutter client validation added; web invariants/tests still paused |
| REQ-032 | Audit logs on privileged writes | missionAttemptRepository.ts, attendanceRepository.ts, portfolioItemRepository.ts; apps/empire_flutter/app/lib/features/offline/offline_dispatchers.dart | Manual: AUDIT-FL-01 | ✅ (Flutter offline dispatchers write audit logs) |
| REQ-033 | Unit tests (models, routing, invariants) | src/__tests__/models.test.ts, routing.test.ts, invariants.test.ts | Unit: npm test | ⏸️ (web stack paused) |
| REQ-034 | Smoke/QA scripts | QA_RUNBOOK.md | Manual | ⏸️ (web stack paused) |
| REQ-035 | Flutter web build/PWA readiness | Web stack paused (Next.js/PWA disabled) | Manual: BUILD-01 | ⏸️ |
| REQ-036 | Cloud Run API build/health (if API) | Web stack paused (Next.js/PWA disabled) | Manual: API-01 | ⏸️ |
| REQ-037 | Final artifact bundle | SCHEMA_PORT_REPORT.md, COMPLIANCE_REPORT.md, QA_RUNBOOK.md, OFFLINE_VERIFICATION.md | Review | ✅ (docs refreshed for Flutter progress, offline verification, QA steps) |
| REQ-038 | Storage rules for portfolio media | storage.rules, firestore.rules, firebase.json | Jest: src/__tests__/rules.test.ts | ✅ |
| REQ-039 | Offline fallback page | public/offline.html, next.config.mjs | Manual: OFFLINE-UX-01 | ⏸️ (web stack paused) |
| REQ-040 | i18n coverage (en/zh-CN/zh-TW) for landing, auth, and protected route entry | locales/en.json, locales/zh-CN.json, locales/zh-TW.json, src/lib/i18n/config.ts, src/lib/i18n/messages.ts, test/e2e/workflow-routes.e2e.spec.ts, scripts/vibe_i18n_keys.js | Playwright: zh-CN landing/login + zh-TW redirect; Audit: vibe_i18n_keys.js | ✅ (tri-locale key consistency passes; locale-first runtime behavior validated end-to-end) |
| REQ-041 | Dependency baseline maintained | DEPENDENCY_BASELINE_SCHOLESA.md | Review: DEP-BASELINE-CHK | ✅ (updated with flutter + google_fonts) |
| REQ-042 | Firestore/Storage rules test harness | firestore.rules, storage.rules, src/__tests__/rules.test.ts | Jest: RULES-TEST-01 | ✅ |
| REQ-043 | CI checks (lint, type, test) | .github/workflows/ci.yml, package.json scripts | CI run: CI-01; local proof: npm run test:e2e:web, npm run build | 🟠 (web Playwright gate now runs without emulators; full CI evidence still pending) |
| REQ-044 | Route uniqueness audit (App Router) | app/[locale]/*, middleware.ts | Script: scaffold-routing.js | ✅ (audited: locale root + (auth) + (protected) dashboards only; no duplicate login/root pages) |
| REQ-045 | PWA cache strategy documented | next.config.mjs (runtimeCaching, offline fallback) | Review: PWA-STRAT-01 | ⏸️ (web stack paused) |
| REQ-046 | Flutter app setup (baseline) | scholesa_app/pubspec.yaml, scholesa_app/lib/main.dart, scholesa_app/lib/app.dart | Manual: FL-SETUP-01 | ✅ (baseline routing) |
| REQ-047 | Flutter Firebase config (Android/iOS) | apps/empire_flutter/app/lib/firebase_options.dart, app/android/app/google-services.json, app/ios/Runner/GoogleService-Info.plist | Manual: FL-FB-01 | ✅ (web+android+iOS configured; plist added) |
| REQ-048 | Flutter auth + role routing | apps/empire_flutter/app/lib/features/auth/*, app/lib/app.dart | Manual: FL-AUTH-01 | ✅ (Auth flows, role selector, entitlements + primary site persistence) |
| REQ-049 | Flutter dashboards (learner/educator/parent/site/hq) | apps/empire_flutter/app/lib/features/dashboards/* | Manual: FL-DASH-01 | ✅ (role cards, pillar chips, site selector, Firestore highlights, refreshed UI) |
| REQ-050 | Flutter offline/cache strategy | apps/empire_flutter/app/lib/features/offline/offline_service.dart, app/lib/features/offline/offline_banner.dart, app/lib/features/offline/offline_queue.dart, app/lib/app.dart | Manual: FL-OFFLINE-01 | ✅ (connectivity detection, persistent offline queue, auto flush on reconnect; register dispatchers per feature) |
| REQ-051 | Flutter slice 1 theme + landing shell | apps/empire_flutter/app/lib/app.dart, app/lib/theme.dart, app/lib/features/landing/landing_page.dart | ✅ (dark gradient/glass design applied) |
| REQ-052 | Canonical telemetry events emitted (docs/18) | apps/empire_flutter/app/lib/services/telemetry_service.dart, apps/empire_flutter/app/lib/domain/repositories.dart, apps/empire_flutter/app/lib/modules/checkin/checkin_page.dart, apps/empire_flutter/app/lib/modules/site/site_sessions_page.dart, apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart, apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart, functions/src/index.ts | Manual: ANA-01 | ✅ (docs/18 + docs/42/44/45 event coverage wired end-to-end, allowlisted, and hardened with site tagging + trace/request correlation + metadata PII redaction per audit-pack observability/privacy controls) |
| REQ-053 | Admin provisioning UI (learner/parent profiles + guardianLinks) | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart, app/lib/domain/repositories.dart | Manual: ADMIN-01 | 🟠 (UI added for site/hq; needs QA) |
| REQ-054 | Messaging threads + send + notification request | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart, app/lib/domain/models.dart, app/lib/domain/repositories.dart, app/lib/services/notification_service.dart, functions/src/index.ts | Manual: MSG-02 | 🟠 (threads/messages + telemetry + notification enqueue + scheduled processor; offline drafts enabled sans external send) |
| REQ-055 | Marketing CMS render + lead capture | apps/empire_flutter/app/lib/features/landing (extend), app/lib/features/cms/cms_page.dart, domain/models.dart, domain/repositories.dart | Manual: CMS-01 | ✅ (CMS page render + offline lead queue + telemetry) |
| REQ-056 | Marketplace browse + checkout intent + fulfillment view | apps/empire_flutter/app/lib/features/dashboards (marketplace UI), app/lib/services (api client), entitlement gating | Manual: MKT-02 | 🟠 (server intent flow preferred for HQ/Site; client fallback retained) |
| REQ-057 | Partner contracting dashboard + approvals | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart, app/lib/domain/models.dart, domain/repositories.dart, firestore.rules, storage.rules | Manual: CNT-03 | 🟠 (org/contract/deliverable/payout UI + approvals; evidence uploads + rules; QA pending) |
| REQ-058 | AI drafts request/review flows | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart, app/lib/domain/models.dart, domain/repositories.dart, functions/src/index.ts | Manual: AI-01 | 🟠 (request/review UI + telemetry + rules; QA pending) |
| REQ-059 | Offline extensions for new slices (allowed-only) | apps/empire_flutter/app/lib/features/offline/offline_queue.dart, offline_dispatchers.dart (extend) | Manual: OFF-EXT-01 | 🟠 (lead + attendance + mission + portfolio + credential + messaging drafts queued; billing stays online-only) |
| REQ-060 | Analytics dashboard consumption (telemetry-driven KPIs) | apps/empire_flutter/app/lib/features/dashboards/role_dashboards.dart (KPI cards), app/lib/features/analytics/analytics_dashboard_screen.dart | Manual: ANA-02 | 🟠 |
| REQ-061 | Dart/Flutter models/repos for IntegrationConnection (Google Classroom) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-062 | Dart/Flutter models/repos for ExternalCourseLink | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-063 | Dart/Flutter models/repos for ExternalUserLink | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-064 | Dart/Flutter models/repos for ExternalCourseworkLink | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-065 | Dart/Flutter models/repos for SyncJob + SyncCursor | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-066 | Dart/Flutter models/repos for GitHubConnection | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-067 | Dart/Flutter models/repos for ExternalRepoLink | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-068 | Dart/Flutter models/repos for ExternalPullRequestLink | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-069 | Dart/Flutter models/repos for GitHubWebhookDelivery | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-070 | Dart/Flutter models/repos for MediaConsent (safety) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-071 | Dart/Flutter models/repos for PickupAuthorization (safety) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-072 | Dart/Flutter models/repos for IncidentReport (safety) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-073 | Dart/Flutter models/repos for SiteCheckInOut (attendance/safety) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-074 | Dart/Flutter models/repos for Room (operations) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-075 | Dart/Flutter models/repos for MissionSnapshot (publish snapshot) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-076 | Dart/Flutter models/repos for Rubric + RubricApplication | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |
| REQ-077 | Dart/Flutter models/repos for ExternalIdentityLink (identity matching) | apps/empire_flutter/app/lib/domain/models.dart, domain/repositories.dart | Review | ✅ |

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `TRACEABILITY_MATRIX.md`
<!-- TELEMETRY_WIRING:END -->
