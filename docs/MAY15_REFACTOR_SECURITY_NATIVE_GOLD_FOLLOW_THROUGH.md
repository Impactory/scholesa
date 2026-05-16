# May 15 Refactor, Security, Native UX, And Blanket Gold Follow-Through

Status: active May 15 control packet, updated after the learner-onboarding/MiloOS follow-through deploy and iOS/Android local build verification.

Current verdict: `scholesa.com` public web is live, serving the updated Flutter plus Next public split, and passing live canonical role-account UAT after the learner first-login setup and MiloOS voice/i18n update. Complete blanket Gold across web, iOS, macOS, and distribution proof is still blocked until macOS Developer ID keychain access is restored and notarization proof is rerun. Do not describe the whole platform as fully blanket Gold until the native blocker table is closed.

## Packet Files

| File | Purpose |
| --- | --- |
| `docs/REPO_WIDE_REFACTOR_SECURITY_EXECUTION_PLAN_MAY_15_2026.md` | Repo-wide refactor and security execution plan. |
| `docs/NATIVE_SMALL_SCREEN_UX_RETHINK_PHASE2_MAY_15_2026.md` | Phase 2 native app small-screen UX plan. |
| `docs/SCHOLESA_COM_BLANKET_GOLD_READINESS_FOLLOW_THROUGH_MAY_15_2026.md` | Current `scholesa.com` live readiness evidence, blocker table, and next gates. |

## Current Live Web State

| Surface | Status | Evidence |
| --- | --- | --- |
| Flutter public front door | Live | `https://scholesa.com/welcome` and `https://scholesa.com/login` returned `200`; Flutter public route regression passed `7/7`. |
| Next public locale route | Live | `https://scholesa.com/en` returned `200`, showed `The Proof Engine for Real Capability Growth`, showed `Growth Reports`, and had no localized app links such as `/en/login`. |
| Summer Camp page | Live | `https://scholesa.com/en/summer-camp-2026` returned `200` and showed Summer Camp learner language. |
| Primary Next Cloud Run | Live | Cloud Build `4483be81-5357-4ba8-9db0-7ac217ab4bc9`; image `gcr.io/studio-3328096157-e3f79/scholesa:20260515-learner-onboarding-miloos-r2`; revision `scholesa-web-00076-qq5`; 100 percent traffic. |
| Flutter Cloud Run | Live | Cloud Build `f350685f-f278-46d2-a581-bd1ce18ea545`; image `gcr.io/studio-3328096157-e3f79/empire-web:20260515-learner-onboarding-miloos-r2`; revision `empire-web-00103-h5c`; 100 percent traffic. |
| Learner first-login setup | Live | Five-step guided setup is deployed with MiloOS read-aloud controls, i18n strings, and mobile-width regression coverage. |
| MiloOS voice/persona | Live | MiloOS uses a warmer, friendly woman coach prompt, locale-aware TTS configuration, and privacy-safe voice failure telemetry. |

## Current Validation Evidence

| Gate | Result | Notes |
| --- | --- | --- |
| `npm run typecheck -- --pretty false` | PASS | Root TypeScript passed. |
| `./scripts/deploy.sh web` after learner/MiloOS update | PASS | Next and Flutter web deployed; proof log `audit-pack/reports/deploy-web-learner-onboarding-miloos-may15.log`. |
| `npm run test:uat:live-role-accounts` after learner/MiloOS deploy | PASS | 8 canonical `@scholesa.test` accounts and 16 route proofs passed against live `https://scholesa.com`; proof log `audit-pack/reports/live-role-account-uat-learner-onboarding-miloos-may15.log`. |
| Focused learner/MiloOS Flutter tests | PASS | `learner_today_page_test.dart`, `ai_coach_widget_regression_test.dart`, and `learner_onboarding_gate_test.dart` passed; proof log `audit-pack/reports/flutter-focused-learner-miloos-may15.log`. |
| Learner setup persistence regression | PASS | The broader tri-locale setup persistence test walks the new setup flow and passed; proof log `audit-pack/reports/flutter-learner-setup-persistence-may15.log`. |
| `npm run lint` | PASS | ESLint passed. |
| `npm run build` | PASS | Next production build passed. |
| `flutter test test/public_entry_routes_test.dart` | PASS | `7/7` public Flutter tests passed. |
| `npm run qa:secret-scan` | PASS | No tracked secret patterns detected. |
| `npm run ai:internal-only:all` | PASS | AI dependency, import, domain, and egress gates passed. |
| `npm run qa:k8s:manifests` | PASS | Kubernetes manifests rendered and structural checks passed. |
| `npm run qa:workflow:no-mock` | PASS | 215 files scanned, 0 findings. |
| `npm run qa:coppa:guards` | PASS | COPPA regression suite passed. |
| `npm run test:integration:rules` | PASS | Firestore and Storage emulator rules passed 239 tests after report-share boundary hardening. |
| `npm run test:uat:live-role-accounts` via full gate | PASS | 8 canonical `@scholesa.test` accounts and 16 route proofs passed against live `https://scholesa.com`; artifact `audit-pack/reports/live-role-account-uat-certification.json`. |
| `npm run test:uat:blanket-gold` with live env | PASS | Full web/security gate passed; artifact `audit-pack/reports/blanket-gold-live-may15.log`. |
| `npm run refactor:baseline` | PASS | New non-mutating refactor ratchet passed: typecheck, lint, workflow no-mock, secret scan, AI internal-only, compliance scan. |
| `npm run refactor:full` | PASS | Non-deploying full refactor gate passed; proof log `audit-pack/reports/refactor-full-may15.log`. |
| `npm run compliance:scan` | PASS | Compliance repo-structure scan passed. |
| `npm audit --audit-level=high` | PASS with low findings | No high or critical audit findings; 9 low advisories remain in transitive Firebase/Google packages. |
| `npm run native:distribution:readiness` | BLOCKED | iOS and Android local distribution prerequisites pass; macOS Developer ID notarization is blocked by `errSecInternalComponent` keychain access. |
| `./scripts/deploy.sh flutter-ios` | PASS | Flutter gate passed and unsigned iOS release app built at `build/ios/iphoneos/Runner.app`; proof log `audit-pack/reports/flutter-ios-build-learner-onboarding-miloos-may15.log`. |
| `./scripts/deploy.sh flutter-android` | PASS | Flutter gate passed and Android release `app-release.aab` plus `app-release.apk` built; proof log `audit-pack/reports/flutter-android-build-learner-onboarding-miloos-may15.log`. |
| `./scripts/apple_release_local.sh verify_testflight_build` | PASS | TestFlight build `5` for `com.scholesa.app` is visible and `processing_state=VALID`. |

## Required Next Decisions

| Decision | Owner | Required before blanket Gold claim |
| --- | --- | --- |
| macOS Developer ID private-key access | Release owner on the Mac keychain | Approve or repair keychain access, rerun `npm run native:distribution:readiness`, then rerun macOS signing/notarization proof. |
| Native distribution proof packet | Release owner | Rerun guarded native proof after macOS unblocks. Do not call native blanket Gold without TestFlight, Play internal, and notarized macOS proof in one packet. |
| Refactor execution cadence | Engineering lead | Run the repo refactor plan as small PR-sized phases, never as an unbounded rewrite. |

## Refactor Follow-Through Completed This Pass

| Item | Result |
| --- | --- |
| Validation ratchet scripts | Added `refactor:baseline` and `refactor:full` to `package.json`. |
| Route ownership docs | Updated `docs/REPO_MAP.md` and `docs/ROUTE_MODULE_MATRIX.md` with the current `scholesa.com` Flutter/Next split and live UAT route equivalents. |
| Rules hardening proof | Added report-share request/consent emulator coverage for linked Family access, unrelated Family denial, missing-site denial, wrong-site denial, and server-owned writes. |
| Baseline proof | `npm run refactor:baseline` passed on May 15. |
| Full refactor proof | `npm run refactor:full` passed on May 15; log stored at `audit-pack/reports/refactor-full-may15.log`. |
| Learner onboarding/MiloOS UX slice | First-login setup is step-through, spoken by MiloOS, i18n-enabled, mobile-width tested, and live on `scholesa.com`. |
| Warning/error logging slice | Share/export failure telemetry remains in place; learner setup, onboarding gate, setup TTS, and AI Coach TTS failure paths now emit privacy-safe warning/error telemetry. |

## Operating Rule

Every follow-up refactor or UX change must preserve the Scholesa product chain:

`capability -> mission -> session -> checkpoint -> evidence -> reflection -> capability review -> portfolio -> badge -> showcase -> growth report`

Any change that weakens capability context, role permissions, site scoping, evidence provenance, minor safety, or auditability is a stop condition.