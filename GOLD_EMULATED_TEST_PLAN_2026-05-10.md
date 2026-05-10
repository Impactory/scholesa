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

## Failure Handling

| Failure type | Action |
| --- | --- |
| Wrong-role or wrong-site read/write allowed | Fix rules or callable auth before UI work. Add denial test. |
| Missing `siteId` on site-scoped write | Fix write path or canonical seed shape, then rerun rules and evidence-chain emulator. |
| Proof writes growth directly | Move growth update behind rubric/checkpoint review. Add emulator assertion. |
| AI support writes mastery or hides disclosure | Block release. Preserve AI support as support only and record disclosure/proof. |
| Parent sees educator-only support notes | Block release. Replace raw data access with parent-safe projection. |
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