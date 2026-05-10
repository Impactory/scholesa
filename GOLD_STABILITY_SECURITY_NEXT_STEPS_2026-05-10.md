# Gold Stability And Security Next Steps - 2026-05-10

Status: Not gold-ready.

This is a stability and security execution plan, not a gold certification. Scholesa should only be called gold-ready after every primary workflow is verified end to end with real or canonical synthetic evidence, correct role gates, emulator-backed security tests, native-channel proof, and live deployment proof.

## Current Baseline

Recent validated items:

- Focused MiloOS hover and voice suite passed: `flutter test test/ai_coach_widget_regression_test.dart test/global_ai_assistant_overlay_regression_test.dart test/web_speech_test.dart test/ui_golden_test.dart`.
- Focused Flutter analyzer passed for touched MiloOS files.
- Root Flutter web shell contract passed: `npx jest src/__tests__/flutter-web-signout-availability.test.ts --runInBand`.
- Earlier non-deploying release gate passed after restoring `RUN_EMULATOR_TESTS=1` in the release-gate emulator command.
- Earlier Cloud Run `empire-web` deploy through `./scripts/deploy.sh flutter-web` succeeded and routed `empire-web-00084-6wg` to 100 percent traffic.

Current release blockers and risks:

- Full Flutter deploy gate must be rerun after the MiloOS copy/golden updates before another deploy can be considered clean.
- Native distribution remains blocked until TestFlight, Google Play internal testing, and macOS signing/notarization proof exist.
- Cloud Run project identity must stay explicit: live Flutter site currently matches `studio-3328096157-e3f79` / `empire-web`; project number `430675339898` maps to `scholesa-prod`, which does not host the serving `empire-web` service.
- Firestore and Storage hardening are still required before gold: missing `siteId` fallback and broad authenticated learner-media reads are not acceptable gold posture.
- Passport/report output remains partial until every claim can be traced to evidence, proof, rubric, growth event, portfolio item, and consent boundary.
- Parent/guardian, partner, and admin interpretation layers must not ship claims without provenance.

## Gold Stability Principles

1. Evidence-chain truth beats UI completeness.
2. No mastery claim without evidence provenance.
3. No role route without four-layer authorization proof.
4. No deploy without the non-deploying gate and focused regression for touched surfaces.
5. No native gold without external distribution proof.
6. No AI gold without internal-only provider gates, learner disclosure, explain-back, and auditable trace.
7. No report gold without family-safe, permission-safe claim provenance.

## Phase 0 - Stabilize The Current Release Gate

Goal: make the repo releasable again before broad feature work.

Actions:

- Rerun the focused MiloOS suite after every hover, speech, or assistant change.
- Rerun full Flutter tests because `./scripts/deploy.sh flutter-web` runs the full Flutter gate before deploying.
- Rerun `./scripts/deploy.sh release-gate` after emulator suites pass.
- Keep `git diff --check` clean.
- Update gold/test-plan docs whenever a blocker changes state.

Validation:

```bash
cd apps/empire_flutter/app
flutter analyze --no-fatal-infos
flutter test --reporter compact

cd ../../..
./scripts/deploy.sh release-gate
git diff --check
```

Stop conditions:

- Any Flutter test failure.
- Any emulator denial test failure.
- Any source-contract test that permits duplicate floating chrome, missing sign-out, or fake workflow data.

## Phase 1 - Lock Workflow Stability

Goal: every route renders, persists, fails safely, and preserves the evidence chain.

Actions:

- Treat every route in `ALL_WORKFLOW_PATHS` as a release surface.
- Add a route bug coverage row for every learner, educator, parent, site, partner, HQ, and common route.
- Verify loading, empty, success, error, mobile, and unauthorized states.
- Verify no resilience error card appears during the role golden paths.
- Verify every write uses `siteId` or an explicit global/server-owned exception.

Validation:

```bash
npm test
npm run test:e2e:web
npm run qa:workflow:no-mock
npm run test:integration:rules
```

## Phase 2 - Harden Security Boundaries

Goal: make least privilege enforceable in rules, routes, native gates, and callables.

Actions:

- Firestore: replace permissive missing-`siteId` fallback with explicit collection classes.
- Storage: restrict learner media reads to owner, linked guardian, same-site educator/site/HQ, or server-mediated share consent.
- Auth: verify Firebase custom claims, Firestore rules, web route metadata, and Flutter role gates agree.
- Parent: serve parent-safe projections only; never expose raw educator notes or support flags.
- Partner: keep outputs permission-safe and evidence-backed; do not expose learner data without consent and provenance.
- AI: keep `npm run ai:internal-only:all` in the gate and verify disclosure audit trail.
- Secrets: run secret scan before deploy and extend patterns for Firebase tokens, OAuth secrets, Stripe keys, GitHub tokens, Google API keys, and private keys.

Validation:

```bash
npm run qa:secret-scan
npm run ai:internal-only:all
npm run test:integration:rules
npm run qa:firebase-role-e2e
npm run compliance:gate
```

## Phase 3 - Verify Evidence Chain End To End

Goal: prove the full chain, not just screens.

Required chain:

```text
Admin-HQ setup
-> session runtime
-> educator observation
-> learner artifact/reflection/checkpoint
-> proof-of-learning
-> rubric/capability mapping
-> capability growth update
-> portfolio linkage
-> Passport/reporting output
-> guardian/school/partner interpretation
```

Actions:

- Use canonical synthetic data that matches production shapes.
- For each chain step, verify create/read/update paths, provenance IDs, site scoping, audit logs, and downstream visibility.
- Fail the gate if Passport/report output cannot explain which evidence supports each claim.
- Fail the gate if any proof or AI support can directly write capability mastery.

Validation:

```bash
npm run test:integration:evidence-chain
npm run test:e2e:web
npm run qa:telemetry-smoke
```

## Phase 4 - Native Channel Proof

Goal: move from local compile proof to real distribution proof.

Actions:

- iOS: TestFlight internal build with sign-in, sign-out, evidence capture, MiloOS, offline queue, and media upload smoke.
- Android: Google Play internal testing build with the same role and evidence smoke.
- macOS: signed and notarized build with auth/session smoke and offline recovery.
- Device farm or real-device proof for mobile classroom width, camera/media permissions, microphone/STT/TTS, localization, and accessibility.

Validation:

```bash
npm run native:distribution:readiness
npm run native:distribution:proof
```

Stop condition:

- Local `flutter build` alone is not native gold proof.

## Phase 5 - Live Deployment And Canary Stability

Goal: verify the deployed artifact that users actually touch.

Actions:

- Deploy only through `./scripts/deploy.sh`.
- Use explicit project, region, and service variables.
- Probe direct Cloud Run URL and `https://scholesa.com`.
- Verify revision, image tag, 100 percent traffic target, cache headers, proof-flow video, no stale runtime assets, no protected data on public routes.
- Run role canary for learner, educator, parent, site, partner, and HQ.

Validation:

```bash
GCP_PROJECT_ID=studio-3328096157-e3f79 GCP_REGION=us-central1 CLOUD_RUN_FLUTTER_SERVICE=empire-web ./scripts/deploy.sh flutter-web
gcloud run services describe empire-web --project studio-3328096157-e3f79 --region us-central1 --format='value(status.url,status.traffic[0].revisionName,status.latestReadyRevisionName)'
curl -sSI https://scholesa.com
curl -sSI https://scholesa.com/videos/proof-flow.mp4
```

## Exit Criteria

Scholesa is still not gold-ready until all of these are true:

- Every primary role has a complete evidence-backed workflow with real persistence.
- Emulator rules tests deny wrong-role, wrong-site, missing-consent, and parent-boundary cases.
- Full release gate passes after the final code change.
- Flutter web is deployed through `./scripts/deploy.sh` and live canary passes.
- Native distribution proof exists for iOS, Android, and macOS.
- Passport/report claims are evidence-backed and family-safe.
- AI support is disclosed, verified, and auditable.