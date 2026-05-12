# Gold Emulated Test Plan - 2026-05-10

Status: Local emulator and release-gate execution completed for the 2026-05-10 stability pass. Live Cloud Run canary and native distribution proof remain outside this emulator plan.

This plan defines the emulator-backed and local deterministic tests that must pass before Scholesa can move toward gold. Emulator tests are not a substitute for live canary or native distribution proof, but they are the required safety net for Firestore rules, evidence-chain callables, analytics contracts, and role/site isolation.

## Execution Rules

- Run Firestore emulator suites sequentially because they share the emulator port.
- Do not run live-mutating scripts unless the command explicitly says live and the operator has approved it.
- Use canonical synthetic data or test fixtures that match production model shapes.
- Record exact command, result, and blocker in this file.
- If a test fails because the test expected stale wording or UI, update the test only when the product change is intentional and evidence-safe.
- If a test fails because authorization, persistence, provenance, or security is wrong, fix the implementation first.

## Required Local And Emulator Gates

| Order | Gate | Command | What it proves | Gold meaning |
| --- | --- | --- | --- | --- |
| 1 | Diff hygiene | `git diff --check` | No whitespace/conflict-marker issues. | Required before any release gate. |
| 2 | Root typecheck | `npm run typecheck -- --pretty false` | TypeScript route/backend contracts compile. | Required, but root excludes Flutter/functions internals. |
| 3 | Root lint | `npm run lint` | Web and scripts lint under current config. | Required. |
| 4 | Root Jest | `npm test` | Web source contracts, workflow wiring, i18n, policies. | Required. |
| 5 | Firestore rules emulator | `npm run test:integration:rules` | Firestore allow/deny cases and site/role boundaries. | Required security gate. |
| 6 | Evidence-chain emulator | `npm run test:integration:evidence-chain` | Canonical evidence chain through emulator-backed Functions test. | Required evidence gate. |
| 7 | Analytics emulator | `npm run test:integration:analytics` | Telemetry/event contracts under emulator. | Required observability gate. |
| 8 | Functions build/tests | `npm --prefix functions run build && npm --prefix functions run test -- --runInBand` | Functions TypeScript build and callable/unit behavior. | Required backend gate. |
| 9 | AI internal-only | `npm run ai:internal-only:all` | No external AI provider dependency/import/domain/egress. | Required AI security gate. |
| 10 | Secret scan | `npm run qa:secret-scan` | No tracked secret patterns. | Required security gate. |
| 11 | Workflow no-mock audit | `npm run qa:workflow:no-mock` | Workflows do not rely on fake/mock production behavior. | Required truth gate. |
| 12 | Web E2E | `npm run test:e2e:web` | Browser workflows, route access, accessibility-tagged specs. | Required UI/workflow gate; uses E2E backend where configured. |
| 13 | Flutter analyzer | `cd apps/empire_flutter/app && flutter analyze --no-fatal-infos` | Flutter code health. | Required native/web channel gate. |
| 14 | Flutter full tests | `cd apps/empire_flutter/app && flutter test --reporter compact` | Flutter widget, service, route, source, and golden tests. | Required before Flutter deploy. |
| 15 | Release gate | `./scripts/deploy.sh release-gate` | Non-deploying reproducibility gate: typecheck, lint, Jest, emulator tests, Functions build/tests, Flutter gate, diff hygiene. | Required final local gate. |

## Emulator Suites To Run Now

Run these in order:

```bash
npm run test:integration:rules
npm run test:integration:evidence-chain
npm run test:integration:analytics
```

Then run the full gate:

```bash
./scripts/deploy.sh release-gate
```

## Workflow Coverage Map For Emulator Tests

| Evidence-chain step | Emulator or deterministic proof | Missing proof if failing |
| --- | --- | --- |
| Admin-HQ capability setup | Root Jest workflow/capability contracts, Firestore rules emulator for `capabilities`, web E2E HQ routes. | Capability definitions may render but not enforce site/global permissions or downstream mapping. |
| Session runtime | Firestore rules tests for sessions/occurrences, Flutter session/attendance tests, web E2E educator/site routes. | Educator live workflows can lose session occurrence lineage. |
| Educator observation | Evidence-chain emulator, Flutter educator evidence tests, rules denial tests. | Observations can be stranded, cross-site, or missing capability provenance. |
| Learner artifact/reflection/checkpoint | Flutter learner mission/checkpoint/portfolio tests, root Jest source contracts, web E2E learner routes. | Learner work may not become verified evidence or portfolio candidate. |
| Proof-of-learning | Evidence-chain emulator, proof review Flutter tests, Functions unit tests. | Proof can fail to hand off to rubric/growth or incorrectly write mastery. |
| Rubric/capability mapping | Functions tests, root workflow contracts, Flutter educator mission review tests. | Rubric outcomes can disconnect from capability growth. |
| Capability growth | Evidence-chain emulator, capability growth Function tests, learner timeline tests. | Growth claims can lack reviewed evidence lineage. |
| Portfolio linkage | Flutter learner/parent portfolio tests, web E2E report/passport surfaces. | Portfolio can show artifacts without proof/rubric/growth provenance. |
| Passport/reporting output | Parent callable tests, web E2E passport/report routes, analytics emulator. | Reports can overclaim or omit evidence provenance. |
| Guardian/school/partner interpretation | Rules tests, parent/partner E2E, site evidence-health tests. | External interpretation can be unsafe or misleading. |

## Run Ledger

| Time | Command | Result | Notes |
| --- | --- | --- | --- |
| 2026-05-10 | `flutter test test/ai_coach_widget_regression_test.dart test/global_ai_assistant_overlay_regression_test.dart test/web_speech_test.dart test/ui_golden_test.dart` | Passed | Validates bounded MiloOS hover, humanlike voice wording, web speech bridge, and refreshed AI Help goldens. |
| 2026-05-10 | `flutter analyze lib/runtime/ai_coach_widget.dart lib/runtime/global_ai_assistant_overlay.dart lib/runtime/web_speech_interop.dart test/ai_coach_widget_regression_test.dart test/global_ai_assistant_overlay_regression_test.dart test/ui_golden_test.dart` | Passed | No analyzer issues in touched MiloOS files. |
| 2026-05-10 | `npx jest src/__tests__/flutter-web-signout-availability.test.ts --runInBand` | Passed | Confirms Flutter web shell still exposes global assistant and keeps sign-out in bounded route/account chrome. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore rules emulator passed 119/119, including wrong-site, parent-boundary, partner ownership, portfolio/passport provenance, and default-deny cases. |
| 2026-05-10 | `npm run test:integration:evidence-chain` | Passed | Evidence-chain emulator passed 3/3. Non-blocking warnings remain for unavailable internal AI inference fallback and Jest open-handle cleanup. |
| 2026-05-10 | `npm run test:integration:analytics` | Failed, then passed | Initial failure was stale nullable telemetry metric expectations in the test. Updated assertions to the fail-closed `number | null` contract; final run passed 17/17. Firestore-only emulator still logs callable `functions/not-found` as non-blocking telemetry degradation. |
| 2026-05-10 | `./scripts/deploy.sh release-gate` | Passed | Non-deploying release gate passed after emulator fixes. Flutter gate passed with `+1092: All tests passed!`, then diff hygiene passed and the release reproducibility gate completed. |
| 2026-05-10 | `GCP_PROJECT_ID=studio-3328096157-e3f79 GCP_REGION=us-central1 CLOUD_RUN_FLUTTER_SERVICE=empire-web ./scripts/deploy.sh flutter-web` | Passed | Deploy gate reran Flutter tests (`+1092`), Cloud Build `d7d1dc42-dbdb-40f3-96df-3702ff72fe47` built image tag `20260510-121721`, and Cloud Run revision `empire-web-00087-g7d` now serves 100 percent traffic. |
| 2026-05-10 | `gcloud run services describe ...` and `curl -sSI` probes | Passed | Traffic table confirms `empire-web-00087-g7d` latest ready at 100 percent. `scholesa.com`, `/videos/proof-flow.mp4`, and direct Cloud Run origin returned 200. |
| 2026-05-10 | `flutter test test/auth_service_test.dart test/ai_coach_widget_regression_test.dart test/global_ai_assistant_overlay_regression_test.dart test/web_speech_test.dart` | Passed | Validates provider-hang logout regression, bounded MiloOS overlay, voice wording, and web speech bridge after the voice tuning pass. |
| 2026-05-10 | `flutter analyze lib/auth/auth_service.dart lib/runtime/ai_coach_widget.dart lib/runtime/web_speech_interop.dart test/auth_service_test.dart` | Passed | No analyzer issues in touched logout and MiloOS voice files. |
| 2026-05-10 | `GCP_PROJECT_ID=studio-3328096157-e3f79 GCP_REGION=us-central1 CLOUD_RUN_FLUTTER_SERVICE=empire-web ./scripts/deploy.sh flutter-web` | Passed | Deploy output capture was truncated by the terminal wrapper, but Cloud Build `a0c6a065-058d-46c8-9904-5f6780e3095c` succeeded for image tag `20260510-123327`; Cloud Run revision `empire-web-00088-ln2` serves 100 percent traffic. |
| 2026-05-10 | `gcloud run services describe ...` and `curl -sSI` probes | Passed | Traffic table confirms `empire-web-00088-ln2` latest ready at 100 percent. `scholesa.com`, `/videos/proof-flow.mp4`, and direct Cloud Run origin returned 200. |
| 2026-05-10 | `./scripts/deploy.sh release-gate` | Passed | Final non-deploying release gate passed after logout and voice hardening. Flutter gate passed with `+1093: All tests passed!`, then diff hygiene passed and the release reproducibility gate completed. |
| 2026-05-10 | `flutter test test/shared_state_theme_test.dart --reporter compact` | Passed | Validates shared Flutter empty/loading/error/fatal/recovery state use of Scholesa light/dark theme tokens. |
| 2026-05-10 | `flutter test test/site_dashboard_page_test.dart test/site_identity_page_test.dart test/hq_analytics_page_test.dart test/hq_integrations_health_page_test.dart --reporter compact` | Passed | Validates touched Site/HQ role surfaces after stale-data/status/action feedback moved to semantic theme tokens. |
| 2026-05-10 | `flutter analyze --no-pub --no-fatal-infos lib/modules/site/site_dashboard_page.dart lib/modules/site/site_identity_page.dart lib/modules/hq_admin/hq_analytics_page.dart lib/modules/hq_admin/hq_integrations_health_page.dart` | Passed | No analyzer issues in touched Site/HQ theming files. |
| 2026-05-10 | `flutter analyze --no-pub --no-fatal-infos lib/runtime/ai_coach_widget.dart lib/runtime/voice_runtime_service.dart test/voice_runtime_service_test.dart test/ai_coach_widget_regression_test.dart` | Passed | No analyzer issues in touched MiloOS typed/spoken modality files. |
| 2026-05-10 | `flutter test test/voice_runtime_service_test.dart test/ai_coach_widget_regression_test.dart --reporter compact` | Passed | 27 focused Flutter tests passed; typed client requests serialize `inputModality: typed`, manual typed sends are tracked as typed at the client boundary, and voice-only/spoken flows keep spoken-first behavior. |
| 2026-05-10 | `npm --prefix /Users/impactory/Documents/GitHub/scholesa/functions run test -- --runInBand src/voiceSystem.test.ts` | Passed | 19 backend voice-system tests passed; typed learner input stays useful without mastery claims while voice/unknown input keeps strict confidence guardrails. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 133/133 after the first security hardening slice. Coverage now includes fail-closed missing `siteId` helper behavior, core portfolio/Passport/proof provenance site scope, and `portfolioMedia` owner/linked-guardian-claim/same-site-staff-metadata/HQ access with other-site, missing-metadata, disallowed-type, and unauthenticated denials. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 135/135 after the server-owned mastery/growth boundary slice. Direct educator/client writes to capability and process-domain mastery/growth collections are denied while site-scoped read provenance remains available to learners, linked guardians, educators, and HQ. |
| 2026-05-10 | `npm --prefix functions run test -- --runInBand src/evidenceChainCallables.test.ts` | Passed | 23 callable contract tests passed, including rubric-owned capability/process growth writes and proof verification remaining authenticity-only without writing `capabilityMastery` or `capabilityGrowthEvents`. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 139/139 after the AI audit boundary slice. AI interaction logs and native AI coach interactions now require site-scoped access, deny wrong-site/missing-site records, require learner or same-site educator ownership on create, and restrict web AI log updates to `outcome`/`updatedAt`. |
| 2026-05-10 | `flutter test test/evidence_chain_models_test.dart test/evidence_chain_schema_alignment_test.dart --reporter compact` | Passed | 28 focused Flutter model/schema tests passed after adding `siteId` to native AI coach interaction records. |
| 2026-05-10 | `flutter analyze --no-pub --no-fatal-infos lib/services/firestore_service.dart lib/domain/models.dart test/evidence_chain_models_test.dart test/evidence_chain_schema_alignment_test.dart` | Passed | No analyzer issues in touched native AI audit model/service files. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 141/141 after proof bundle lifecycle hardening. Learner/client proof writes can assemble only `missing`, `partial`, or `pending_review` bundles and cannot self-set verified status, `educatorVerifierId`, or `verifiedAt`; direct educator client verification is denied. |
| 2026-05-10 | `npm --prefix functions run test -- --runInBand src/evidenceChainCallables.test.ts` | Passed | 23 callable contract tests passed after proof bundle lifecycle hardening; `verifyProofOfLearning` remains the server-owned authenticity boundary and still does not write `capabilityMastery` or `capabilityGrowthEvents` directly. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 144/144 after report audit boundary hardening. Clients cannot forge `report.delivery_recorded`, `report.delivery_blocked`, or `learnerReport` audit rows; same-site site admins can still create scoped operational audit logs, and missing/wrong-site operational audit writes are denied. |
| 2026-05-10 | `npm --prefix functions run test -- --runInBand src/reportDeliveryAudit.test.ts src/reportShareRequests.test.ts src/reportShareConsents.test.ts` | Passed | 27 focused Functions report tests passed for report delivery audit payloads, share-request policy/linkage, and consent lifecycle helpers. |
| 2026-05-10 | `npx jest src/__tests__/report-delivery-audit.test.ts --runInBand` | Passed | 16 focused web report helper tests passed for callable use, failed-contract audit metadata, share-request lifecycle metadata, and explicit-consent share helper behavior. |
| 2026-05-10 | `npx jest src/__tests__/report-delivery-audit.test.ts src/__tests__/report-share-export.test.ts --runInBand` | Passed | 25 focused web report/share tests passed after active share lifecycle creation began requiring complete evidence provenance metadata. |
| 2026-05-10 | `npm --prefix functions run test -- --runInBand src/reportShareRequests.test.ts src/reportShareConsents.test.ts src/reportDeliveryAudit.test.ts` | Passed | 28 focused Functions report tests passed after `createReportShareRequest` began rejecting contradictory or empty evidence provenance metadata. |
| 2026-05-10 | `npm --prefix functions run build` | Passed | Firebase Functions TypeScript build passed after callable report-share provenance validation was added. |
| 2026-05-10 | `npx jest src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand` | Passed | 345 source-contract tests passed after report-share provenance hardening and current gold-boundary assertions. |
| 2026-05-10 | `npm --prefix functions run test -- --runInBand src/reportShareRequests.test.ts src/reportShareConsents.test.ts src/reportDeliveryAudit.test.ts` | Passed | 29 focused Functions report tests passed after explicit consent revocation began cascading to linked active report-share lifecycle records. |
| 2026-05-10 | `npm --prefix functions run build` | Passed | Firebase Functions TypeScript build passed after consent revocation cascade changes. |
| 2026-05-11 | `npx --yes firebase-tools emulators:exec --only firestore,storage "npx jest --runInBand --config jest.rules.config.js test/storage-rules.test.js"` | Passed | 11 focused Storage rules tests passed after adding server-owned `reportShareMedia` access tied to active, unexpired Firestore report-share lifecycle records, with revoked/expired/missing/wrong-learner/wrong-site/unauth/client-upload denials. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 147/147 after report-share media consent access hardening. |
| 2026-05-11 | `npx jest src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/report-delivery-audit.test.ts src/__tests__/report-share-export.test.ts --runInBand` | Passed | 370 source-contract and web report tests passed after report-share media consent ledger updates. |
| 2026-05-11 | `npm run qa:secret-scan` | Passed | Secret scan passed after report-share media consent rules changes. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 151/151 after `missionAttempts` and `checkpointHistory` gained missing-site, wrong-site, same-site learner/educator, and update-denial coverage. |
| 2026-05-11 | `npx jest src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand` | Passed | 345 source-contract tests passed after mission/checkpoint site-scope hardening. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/services/firestore_service.dart` | Passed | Focused analyzer passed after the native `submitMissionAttempt` helper began requiring and writing `siteId`. |
| 2026-05-11 | `npm run qa:secret-scan` | Passed | Secret scan passed after mission/checkpoint Firestore rules hardening. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 157/157 after `skillEvidence`, `learnerReflections`, and `metacognitiveCalibrationRecords` gained missing-site, wrong-site, same-site learner/educator/linked-parent, and update-denial coverage. |
| 2026-05-11 | `npx jest src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand` | Passed | 345 source-contract tests passed after skill/reflection/calibration site-scope hardening. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/services/firestore_service.dart` | Passed | Focused analyzer remained green after the current native Firestore helper changes in the auth-parity worktree. |
| 2026-05-11 | `npm run qa:secret-scan` | Passed | Secret scan passed after skill/reflection/calibration Firestore rules hardening. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 159/159 after `habits` gained missing-site, wrong-site, same-site learner/educator, and update-denial coverage. |
| 2026-05-11 | `flutter test test/habits_page_test.dart test/learner_today_page_test.dart --reporter compact` | Passed | 6 focused Flutter habit/learner tests passed after native `HabitService` gained `siteId` context and test fixtures seeded matching site-scoped habits. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/main.dart lib/modules/habits/habit_service.dart test/habits_page_test.dart` | Passed | Focused analyzer passed for native habit site-scope changes. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 162/162 after `learnerGoals` and `learnerInterestProfiles` gained site-scope, linked-parent read, learner-owned write, query, and missing/wrong-site denial coverage. |
| 2026-05-11 | `npx jest src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand` | Passed | 345 focused source-contract tests stayed green after motivation and analytics readers switched learner-scoped evidence queries from legacy `userId` to `learnerId`. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 166/166 after `skillMastery` and `showcaseSubmissions` gained site-scope, same-site read/write, and missing/wrong-site denial coverage. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/domain/models.dart lib/domain/repositories.dart` | Passed | Focused native analyzer passed after `SkillMasteryModel`, `ShowcaseSubmissionModel`, and their repositories gained `siteId` parity. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 170/170 after `learnerProfiles`, `parentProfiles`, `guardianLinks`, and `educatorLearnerLinks` gained site-scope, identity-preservation, and missing/wrong-site denial coverage. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 175/175 after `studentAssents`, `itemResponses`, `learnerNextSteps`, `learnerSupportPlans`, and `learnerDifferentiationPlans` gained site-scope, identity-preservation, immutability, and missing/wrong-site denial coverage. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/domain/repositories.dart` | Passed | Focused native analyzer passed after `LearnerNextStepRepository.listByLearner` began requiring and filtering by `siteId`. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 178/178 after `missionPlans`, `portfolios`, and `rubricApplications` gained site-scope, identity-preservation, server-owned rubric write, and missing/wrong-site denial coverage. |
| 2026-05-11 | `npx jest src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand` | Passed | 345 focused source-contract tests stayed green after `rubricApplications` rules were aligned to the server-owned `applyRubricToEvidence` path. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 180/180 after `billingAccounts` and `payments` were restricted to owning-parent/HQ reads while remaining server-owned for writes. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 182/182 after `missionAssignments` and `skillAssessments` gained site-scope, same-site learner/linked-parent/educator read, identity-preservation, and missing/wrong-site denial coverage. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/modules/missions/mission_service.dart lib/services/firestore_service.dart` | Passed | Focused native analyzer passed after mission assignment and skill assessment read helpers gained `siteId` filtering where available. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 184/184 after server-owned `learnerProgress` and `activities` were restricted to same-site learner, linked-parent, or educator reads with missing/wrong-site denial coverage. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/main.dart lib/modules/parent/parent_service.dart` | Passed | Focused native analyzer passed after parent fallback reads gained `activeSiteId` context for activity filtering. |
| 2026-05-11 | `npm run typecheck` | Passed | Root TypeScript typecheck passed after progress/activity boundary changes. |
| 2026-05-11 | `cd functions && npm run build` | Passed | Functions TypeScript build passed after the parent learner-summary callable filtered activities by `siteId` when provided. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 185/185 after legacy `events` gained site-scoped read/write, `siteId` preservation, and missing/wrong-site denial coverage. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/modules/parent/parent_service.dart` | Passed | Focused native analyzer passed after parent fallback legacy event reads gained `siteId` filtering where available. |
| 2026-05-11 | `npm run typecheck` | Passed | Root TypeScript typecheck passed after legacy event query changes. |
| 2026-05-11 | `cd functions && npm run build` | Passed | Functions TypeScript build passed after parent summary legacy event queries gained `siteId` filtering where available. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 187/187 after legacy `accountabilityCycles` and `accountabilityKPIs` gained site-scoped read/write, `siteId` preservation, and missing/wrong-site denial coverage. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 191/191 after `mediaConsents`, `pickupAuthorizations`, `incidentReports`, and `siteCheckInOut` gained site-scope, identity-preservation, and missing/wrong-site denial coverage. |
| 2026-05-11 | `flutter analyze --no-pub --no-fatal-infos lib/modules/parent/parent_consent_service.dart` | Passed | Focused native analyzer passed after parent consent fallback media reads gained `siteId` filtering where available. |
| 2026-05-11 | `npm run typecheck` | Passed | Root TypeScript typecheck passed after safeguarding boundary changes. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 194/194 after server-owned `orchestrationStates`, `interventions`, and `mvlEpisodes` gained same-site learner/educator/HQ read boundaries and MVL identity-preserving evidence updates. |
| 2026-05-11 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator passed 197/197 after `recognitionBadges`, `badgeAchievements`, and `missionEnrollments` gained site-scope, learner/linked-parent/educator reads, immutable award behavior, and enrollment identity-preservation coverage. |
| 2026-05-10 | `flutter analyze --no-pub --no-fatal-infos lib/domain/models.dart lib/services/firestore_service.dart lib/modules/learner/proof_assembly_page.dart lib/modules/educator/proof_verification_page.dart test/evidence_chain_models_test.dart test/evidence_chain_schema_alignment_test.dart test/proof_assembly_page_test.dart test/proof_verification_page_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart test/evidence_chain_sync_coordinator_test.dart` | Passed | Focused analyzer passed after native proof bundles gained `siteId` and educator proof verification was routed through the callable wrapper. |
| 2026-05-10 | `flutter analyze --no-pub --no-fatal-infos lib/services/firestore_service.dart lib/modules/educator/proof_verification_page.dart test/proof_verification_page_test.dart test/evidence_chain_firestore_service_test.dart` | Passed | Focused analyzer passed after native educator proof revision requests moved from direct client writes to the server-owned proof callable wrapper. |
| 2026-05-10 | `flutter test test/evidence_chain_models_test.dart test/evidence_chain_schema_alignment_test.dart test/proof_assembly_page_test.dart test/proof_verification_page_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart test/evidence_chain_sync_coordinator_test.dart --reporter compact` | Passed | 74 focused Flutter tests passed for proof bundle model serialization, learner proof assembly, educator proof review/revision, service boundary assertions, and offline proof replay. |
| 2026-05-10 | `npx jest src/__tests__/evidence-chain-renderer-wiring.test.ts --runInBand` | Passed | Source-contract test passed after aligning native proof revision expectations with server-owned callable behavior and preserving the active not-blanket-gold truth boundary. |
| 2026-05-10 | `npm run test:integration:rules` | Passed | Firestore plus Storage rules emulator stayed green at 144/144 after native proof site-scope/callable alignment. |
| 2026-05-10 | `npm run qa:secret-scan` | Passed | Secret scan passed after native proof changes. |

## Failure Handling

| Failure type | Action |
| --- | --- |
| Wrong-role or wrong-site read/write allowed | Fix rules or callable auth before UI work. Add denial test. |
| Missing `siteId` on site-scoped write | Fix write path or canonical seed shape, then rerun rules and evidence-chain emulator. |
| Learner or report media allows broad authenticated read | Require owner, linked guardian claim, same-site metadata, HQ, or active server-owned report-share lifecycle path; rerun Firestore plus Storage rules emulator. |
| Proof writes growth directly | Keep growth update behind rubric/checkpoint review. Rules now deny direct client mastery/growth writes and proof self-verification; native educator proof verification and revision requests now route through `verifyProofOfLearning`; continue callable proof for remaining report/share provenance paths. |
| AI support writes mastery or hides disclosure | Block release. Preserve AI support as support only and record disclosure/proof. AI audit records are now site-scoped; continue artifact-level AI disclosure linkage proof. |
| Parent sees educator-only support notes | Block release. Replace raw data access with parent-safe projection. |
| Report share lifecycle accepts contradictory provenance | Block release. Active report-share records now require evidence provenance to be required, expected, complete, and non-missing on both web helper and callable validation paths. |
| Consent revocation leaves linked report shares active | Block release. Explicit report-share consent revocation now cascades to linked active share lifecycle records and records the cascade count in the audit. |
| Flutter or web overlap/regression | Fix component root, add source/widget/browser test, rerun full channel gate. |
| Golden drift from intentional copy/UI change | Update goldens only after focused test proves the behavior is intended. |
| Role UI or recovery state uses ad hoc semantic colors | Move warning/success/error/neutral state to Scholesa `ColorScheme` or `ScholesaColors`; keep only explicit provider/partner brand-color exceptions. |
| MiloOS typed prompt is treated as unknown or voice | Add explicit `inputModality: typed` at the client request boundary and keep spoken/web-speech/upload sources as `voice`; rerun Flutter voice tests plus backend `voiceSystem.test.ts`. |

## Gold Emulator Exit Criteria

- Firestore rules emulator passes with wrong-role, wrong-site, and parent-boundary denial cases.
- Evidence-chain emulator passes with canonical synthetic data and no proof-to-mastery shortcut.
- Analytics emulator passes with redaction, trace IDs, site IDs, and required events.
- Full `./scripts/deploy.sh release-gate` passes after the final code/doc changes.
- Any emulator limitation, such as managed Firestore PITR, is documented as requiring a live staging drill.