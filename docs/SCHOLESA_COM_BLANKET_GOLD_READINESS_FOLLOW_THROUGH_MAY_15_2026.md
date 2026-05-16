# Scholesa.com Blanket Gold Readiness Follow-Through - May 15 2026

Status: current live evidence record and blocker table after the May 15 learner-onboarding/MiloOS follow-through deploy.

Verdict: `scholesa.com` public web is live, attractive, aligned with the updated capability evidence language, and passing live role-account UAT after the learner first-login setup and MiloOS voice/i18n update. Complete blanket Gold across all requested web and native surfaces is still not claimable because macOS Developer ID notarization readiness is blocked by keychain access. iOS and Android local release builds pass after the latest source changes; iOS TestFlight build visibility remains proven for the previously uploaded build.

## Scope

Included in this May 15 packet:

- Public `scholesa.com` Flutter front door: `/welcome`, `/login`.
- Public Next pages proxied through `scholesa.com`: `/en`, `/en/summer-camp-2026`.
- Email login routing behavior already proven in the prior live pass.
- Full live role-account UAT across the canonical `@scholesa.test` accounts.
- Full web/security blanket-gold gate log at `audit-pack/reports/blanket-gold-live-may15.log`.
- Learner first-login step-through setup with MiloOS read-aloud controls and i18n strings.
- MiloOS friendly voice persona, locale-aware TTS setup, and privacy-safe voice/onboarding failure telemetry.
- Security and compliance gates listed below.
- iOS TestFlight visibility check for the current Flutter build.

Not included as complete until rerun after release-owner keychain repair:

- macOS Developer ID signing, notarization, stapling, and Gatekeeper proof.
- Guarded aggregate native proof after macOS unblocks.

## Live Deployment Evidence

| Service | Evidence |
| --- | --- |
| Primary Next web | `scholesa-web-00076-qq5` serving 100 percent traffic after Cloud Build `4483be81-5357-4ba8-9db0-7ac217ab4bc9`. |
| Primary Next image | `gcr.io/studio-3328096157-e3f79/scholesa:20260515-learner-onboarding-miloos-r2`. |
| Flutter web | `empire-web-00103-h5c` serving 100 percent traffic after Cloud Build `f350685f-f278-46d2-a581-bd1ce18ea545`. |
| Public domain split | Flutter owns `/welcome`, `/login`, and app shell routes; Flutter nginx proxies locale public Next routes such as `/en` and `/en/summer-camp-2026`. |
| Deploy proof | `audit-pack/reports/deploy-web-learner-onboarding-miloos-may15.log`. |

## Learner Onboarding And MiloOS Follow-Through

| Item | Result | Proof |
| --- | --- | --- |
| First-login learner setup | PASS | The old long setup sheet is now a five-step flow: reading comfort, confidence, interests/goals, weekly rhythm, and helpful tools. Incomplete Learners remain gated until setup is saved. |
| Classroom mobile behavior | PASS | The setup sheet is height-constrained, scrollable, and verified at phone width so Learners see one step at a time without compact action overflow. |
| Spoken MiloOS guidance | PASS | Each setup step has a MiloOS read-aloud path, a replay button, warm voice settings, locale-aware TTS configuration, and Web Speech/FlutterTTS fallback logging. |
| MiloOS persona | PASS | The AI Coach prompt now asks MiloOS to sound like a friendly, warm woman coach, calm and non-robotic, while preserving safety and evidence-scaffold rules. |
| i18n | PASS | Learner setup strings were added for English source, Simplified Chinese, and Traditional Chinese through `LearnerSurfaceI18n`. TTS language selection follows the active/platform locale. |
| Warning/error logging | PASS for changed surfaces | Learner setup load/save failures, onboarding gate failures, setup speech failures, and AI Coach voice API/FlutterTTS/Web Speech/init failures now emit privacy-safe logs/telemetry without learner content. |

Proof logs:

- `audit-pack/reports/flutter-focused-learner-miloos-may15.log`
- `audit-pack/reports/flutter-learner-setup-persistence-may15.log`
- `audit-pack/reports/live-role-account-uat-learner-onboarding-miloos-may15.log`

## Live Browser Proof

| URL | Result | Proof notes |
| --- | --- | --- |
| `https://scholesa.com/en` | PASS | Returned `200`, final URL remained `/en`, body included `The Proof Engine for Real Capability Growth`, body included `Growth Reports`, and no localized app links matched `/en/login`, `/en/learner`, `/en/educator`, `/en/site`, `/en/hq`, or `/en/partner`. |
| `https://scholesa.com/en/summer-camp-2026` | PASS | Returned `200`, final URL remained `/en/summer-camp-2026`, body included Summer Camp and learner language. |
| `https://scholesa.com/welcome` | PASS | Returned `200` from Flutter public app. |
| `https://scholesa.com/login` | PASS | Returned `200` from Flutter public app. |

Screenshot artifacts created under `audit-pack/reports/screenshots/`:

- `live-scholesa-next-en-marketing-parity.png`
- `live-scholesa-summer-camp-2026-parity.png`
- `live-scholesa-flutter-welcome-parity.png`
- `live-scholesa-flutter-login-parity.png`

## Live Role-Account UAT Evidence

Artifact: `audit-pack/reports/live-role-account-uat-certification.json`.

| Account group | Result | Notes |
| --- | --- | --- |
| HQ/admin | PASS | `admin@scholesa.test` certified `/hq/sites` and `/hq/user-admin` through the live Flutter shell. |
| Educator | PASS | `educator@scholesa.test` certified `/educator/today` and the Flutter Proof Review equivalent for Evidence Review. |
| Learner cohorts | PASS | `discoverer@scholesa.test`, `builder@scholesa.test`, `explorer@scholesa.test`, and `innovator@scholesa.test` authenticated and rendered their learner workflow surfaces. Current live Learner accounts route through onboarding where setup is incomplete. |
| Family | PASS | `family@scholesa.test` certified `/parent/summary` and the Flutter Growth Timeline equivalent for Growth Report proof. |
| Mentor/partner | PASS | `mentor@scholesa.test` certified `/partner/listings` and `/partner/deliverables`; attempted Educator Evidence Review resolves to partner-scoped deliverable proof. |

Summary: 8 canonical accounts certified, 16 route proofs certified, product chain recorded as `capability -> mission -> session -> checkpoint -> evidence -> reflection -> capability review -> portfolio -> badge -> showcase -> growth report`.

## Local And Security Gate Evidence

| Gate | Result | Gold relevance |
| --- | --- | --- |
| `./scripts/deploy.sh web` after learner/MiloOS update | PASS | Next and Flutter web deployed to `scholesa-web-00076-qq5` and `empire-web-00103-h5c`; proof log `audit-pack/reports/deploy-web-learner-onboarding-miloos-may15.log`. |
| `npm run test:uat:live-role-accounts` after learner/MiloOS deploy | PASS | 8 canonical `@scholesa.test` accounts and 16 route proofs passed against live `https://scholesa.com`; proof log `audit-pack/reports/live-role-account-uat-learner-onboarding-miloos-may15.log`. |
| Focused learner/MiloOS Flutter tests | PASS | `learner_today_page_test.dart`, `ai_coach_widget_regression_test.dart`, and `learner_onboarding_gate_test.dart` passed; proof log `audit-pack/reports/flutter-focused-learner-miloos-may15.log`. |
| Learner setup persistence regression | PASS | The broader tri-locale learner setup persistence test now walks the new step-through flow and passed; proof log `audit-pack/reports/flutter-learner-setup-persistence-may15.log`. |
| `npm run test:uat:blanket-gold` with live `scholesa.com` env | PASS | Full web/security gate passed with live role-account UAT. Proof log: `audit-pack/reports/blanket-gold-live-may15.log`. |
| `npm run refactor:baseline` | PASS | Non-mutating refactor/security ratchet passed after adding the May 15 scripts. |
| `npm run refactor:full` | PASS | Non-deploying refactor full gate passed; proof log: `audit-pack/reports/refactor-full-may15.log`. |
| `npm run typecheck -- --pretty false` | PASS | Web TypeScript safety. |
| `npm run lint` | PASS | Web/static code quality. |
| `npm run build` | PASS | Next production build. |
| `flutter test test/public_entry_routes_test.dart` | PASS | Public Flutter route/login/Summer Camp regression. |
| `npm run qa:secret-scan` | PASS | No tracked secret patterns. |
| `npm run ai:internal-only:all` | PASS | AI dependency/import/domain/egress boundary. |
| `npm run qa:k8s:manifests` | PASS | Kubernetes manifest structure and security posture render. |
| `npm run qa:workflow:no-mock` | PASS | No mock workflow findings in strict audit. |
| `npm run qa:coppa:guards` | PASS | Minor-safety guard regression suite. |
| `npm run test:integration:rules` | PASS | Firestore and Storage rules passed 239 emulator tests, including report-share request/consent boundary coverage. |
| `npm run compliance:scan` | PASS | Compliance repo-structure scan passed. |
| `npm audit --audit-level=high` | PASS with low advisories | No high or critical advisories; 9 low transitive advisories remain. |

## Native Channel Evidence

| Channel | Result | Evidence |
| --- | --- | --- |
| iOS | PASS for local release build after latest changes; PASS for previous TestFlight visibility | `./scripts/deploy.sh flutter-ios` passed the Flutter gate and built `build/ios/iphoneos/Runner.app` with codesigning disabled. Proof log: `audit-pack/reports/flutter-ios-build-learner-onboarding-miloos-may15.log`. `./scripts/apple_release_local.sh verify_testflight_build` previously verified build `5` for `com.scholesa.app`; processing state `VALID`. |
| Android | PASS for local release build after latest changes | `./scripts/deploy.sh flutter-android` passed the Flutter gate and built `build/app/outputs/bundle/release/app-release.aab` plus `build/app/outputs/flutter-apk/app-release.apk`. Proof log: `audit-pack/reports/flutter-android-build-learner-onboarding-miloos-may15.log`. |
| macOS | BLOCKED | `npm run native:distribution:readiness` reported Developer ID notarization blocked by `errSecInternalComponent` during codesign probe. |
| Native aggregate | BLOCKED | Aggregate native-channel distribution is not Gold-ready until macOS keychain/signing/notarization proof passes again. |

## Blanket Gold Blockers

| Blocker | Current state | Required closure proof |
| --- | --- | --- |
| macOS Developer ID keychain access | Blocked by `errSecInternalComponent`. | Unlock/approve Developer ID private key access locally, rerun `npm run native:distribution:readiness`, then run macOS sign/notarize/staple proof. |
| Aggregate native proof | Blocked by macOS readiness. | Guarded native proof packet containing TestFlight, Play internal, and notarized macOS logs. |
| Whole-platform blanket Gold claim | Blocked only by native aggregate proof at this point. | Web/security gate and live role UAT are passing; close macOS/native proof before claiming all-surface blanket Gold. |

## Gold Readiness Rule

`scholesa.com` public web can be described as live and passing the May 15 full web/security blanket-gold gate with live role-account UAT. The whole Scholesa platform must not be described as complete blanket Gold across web and native until the native blocker table above is closed.

## Next Command Sequence

Run after the release owner repairs or approves macOS Developer ID private-key access:

```bash
npm run native:distribution:readiness
./scripts/macos_release_local.sh sign_notarize_staple
./scripts/apple_release_local.sh verify_testflight_build
```

Then run the full web/security/native proof bundle:

```bash
npm run test:uat:blanket-gold
npm run test:uat:live-role-accounts
SCHOLESA_NATIVE_DISTRIBUTION_CONFIRM=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS bash scripts/native_distribution_proof.sh execute-live
```

Stop if any command requires a secret or keychain password in the terminal output. The release owner must enter or approve those secrets locally; they must not be recorded in logs, docs, shell history, or proof artifacts.