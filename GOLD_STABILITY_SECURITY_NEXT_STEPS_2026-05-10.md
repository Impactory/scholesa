# Gold Stability And Security Next Steps - 2026-05-10

Status: Not gold-ready.

This is a stability and security execution plan, not a gold certification. Scholesa should only be called gold-ready after every primary workflow is verified end to end with real or canonical synthetic evidence, correct role gates, emulator-backed security tests, native-channel proof, and live deployment proof.

Active bottom-up gap-closure process: `docs/BLANKET_GOLD_BOTTOM_UP_GAP_CLOSURE_PLAN_MAY_10_2026.md`. Use that plan to move from current validated slices into the next implementation pass; it keeps MiloOS typed/spoken modeling, security hardening, refactor discipline, native proof, live canary, and documentation gates in one ordered queue.

## Current Baseline

Recent validated items:

- Focused MiloOS hover and voice suite passed: `flutter test test/ai_coach_widget_regression_test.dart test/global_ai_assistant_overlay_regression_test.dart test/web_speech_test.dart test/ui_golden_test.dart`.
- Focused Flutter analyzer passed for touched MiloOS files.
- Root Flutter web shell contract passed: `npx jest src/__tests__/flutter-web-signout-availability.test.ts --runInBand`.
- Firestore rules emulator passed 119/119.
- Evidence-chain emulator passed 3/3 with non-blocking internal AI fallback and Jest open-handle warnings.
- Analytics emulator passed 17/17 after aligning telemetry metric assertions to the fail-closed nullable contract.
- Non-deploying release gate passed after the latest MiloOS hover/voice changes; the Flutter gate inside it passed with `+1092: All tests passed!`.
- Cloud Run `empire-web` deploy through `./scripts/deploy.sh flutter-web` succeeded for the latest MiloOS hover/voice pass. Revision `empire-web-00087-g7d` is the latest ready revision and serves 100 percent traffic; the old `empire-web-00074-rvc` `gold-rehearsal` tag remains at 0 percent.
- Live probes passed after deploy: `https://scholesa.com` returned 200, `https://scholesa.com/videos/proof-flow.mp4` returned 200 as `video/mp4`, and the direct Cloud Run origin returned 200.
- Logout hardening pass completed: Firebase sign-out and local session clear no longer wait behind a stuck Google/provider sign-out call.
- MiloOS voice tuning pass completed: web speech now uses a slightly slower, lower-pitch voice profile and prefers natural/neural browser voices before generic fallbacks.
- Cloud Run `empire-web` deploy through `./scripts/deploy.sh flutter-web` succeeded for the logout/voice hardening pass. Cloud Build `a0c6a065-058d-46c8-9904-5f6780e3095c` built image tag `20260510-123327`; revision `empire-web-00088-ln2` is latest ready and serves 100 percent traffic.
- Final non-deploying release gate passed after the logout/voice hardening pass; the Flutter gate inside it passed with `+1093: All tests passed!`.
- Flutter web deploy after the theme/load/login/CTA pass succeeded. Revision `empire-web-00089-wfs` serves 100 percent traffic, and live HTTP probes passed for `https://scholesa.com` and `/videos/proof-flow.mp4`.
- Repo hygiene follow-up removed generated Flutter golden failure artifacts and `.firebase/logs/vsce-debug.log` from the working tree, ignored future generated outputs, and added a `deploy.sh` guard for dirty generated artifact paths.
- Educator proof verification and rubric application now hide raw backend/index errors from user-facing surfaces and show friendly recovery guidance; focused analyzer and widget regressions passed for those touched flows.
- Admin-HQ capability framework and rubric template setup now hide raw backend/index errors from user-facing load/save/delete surfaces and show friendly recovery guidance; focused analyzer and HQ authoring widget regressions passed for those touched flows.
- Learner mission loading now shows a friendly retry state instead of raw backend/index errors or a misleading empty mission state; focused analyzer and mission page widget regressions passed for the touched flow.
- Parent growth timeline and shared family progress loading now hide raw backend/index errors from user-facing reporting surfaces and show friendly recovery guidance; focused analyzer and parent reporting regressions passed for the touched flows.
- Educator mission planning now hides raw backend/index errors from initial load and stale-refresh banners while preserving the last successful plan list; focused analyzer and mission-plan widget regressions passed for the touched flow.
- Shared educator schedule, session list, and learner roster loading now hide raw backend/index errors while preserving stale live-class data where available; focused analyzer and educator service/learner roster regressions passed for the touched flows.
- Shared Flutter empty, loading, error, fatal-error, and startup-recovery states now use Scholesa theme/color-scheme tokens instead of ad hoc Material greys/reds/oranges; focused analyzer and shared UI theme regressions passed for the touched primitives.
- Site and HQ stale-data banners, status indicators, identity-resolution actions, and integration-health recovery states now use Scholesa semantic color-scheme tokens for warning/success/error states while preserving provider brand colors; focused analyzer and Site/HQ widget regressions passed for the touched role surfaces.
- MiloOS Flutter typed prompts now send explicit `inputModality: typed` while spoken/web-speech/upload prompts remain `voice`, so backend typed-input intelligence is not accidentally bypassed by the stricter spoken/unknown confidence guard; focused Flutter analyzer/tests and backend voice-system regressions passed for the touched contract.
- First Firestore/Storage security hardening slice completed: shared Firestore site-scope helpers now fail closed on missing `siteId`, core portfolio/Passport/proof provenance collections require site scope, `portfolioMedia/{learnerId}/{fileName}` no longer allows reads by any authenticated user, and the rules gate now runs Firestore plus Storage emulator tests. `npm run test:integration:rules` passed 133/133.
- Server-owned mastery/growth boundary slice completed: direct client writes to `capabilityMastery`, `capabilityGrowthEvents`, `processDomainMastery`, and `processDomainGrowthEvents` are denied by Firestore rules while Functions remain the owner of rubric/checkpoint growth writes. `npm run test:integration:rules` passed 135/135, and `npm --prefix functions run test -- --runInBand src/evidenceChainCallables.test.ts` passed 23/23.
- AI audit site-scope boundary slice completed: `aiInteractionLogs` and `aiCoachInteractions` now require site-scoped reads/writes, learner or same-site educator ownership on create, and outcome-only updates for web AI interaction logs; native `AICoachInteractionModel` and `FirestoreService.logAICoachInteraction` now carry `siteId`. `npm run test:integration:rules` passed 139/139, focused Flutter model tests passed, and focused Flutter analyzer passed.
- Proof bundle lifecycle hardening slice completed: learner/client writes to `proofOfLearningBundles` can only assemble `missing`, `partial`, or `pending_review` proof and cannot set `educatorVerifierId` or `verifiedAt`; educator verification remains callable/Admin SDK-owned. `npm run test:integration:rules` passed 141/141, and `npm --prefix functions run test -- --runInBand src/evidenceChainCallables.test.ts` passed 23/23.
- Report audit boundary slice completed: `auditLogs` now denies client-created `report.delivery_recorded`, `report.delivery_blocked`, and `learnerReport` audit rows so Passport/report delivery state remains callable/Admin SDK-owned; site operational audit writes remain allowed only with site scope. `npm run test:integration:rules` passed 144/144, focused report Functions tests passed 27/27, and focused web report helper tests passed 16/16.
- Native proof bundle site-scope and review slice completed: Flutter `ProofOfLearningBundleModel`, learner proof assembly, service creation, and offline proof replay now carry `siteId`; educator proof verification and revision requests now route through the `verifyProofOfLearning` callable instead of direct client proof/portfolio writes. Focused Flutter analyzer passed, focused Flutter proof tests passed 74/74, source-contract Jest passed, `npm run test:integration:rules` passed 144/144, and `npm run qa:secret-scan` passed.
- Report share provenance slice completed: web share helpers and the `createReportShareRequest` callable now require non-empty, complete evidence provenance before an active report-share lifecycle record can be created, so contradictory metadata cannot convert a weak Passport/report into an active share. Focused web report tests passed 25/25, focused Functions report tests passed 28/28, Functions build passed, source-contract Jest passed 345/345, `npm run test:integration:rules` passed 144/144, and `npm run qa:secret-scan` passed.
- Report share revocation slice completed: revoking explicit report-share consent now also revokes linked active report-share lifecycle records and records the cascade count in the consent revocation audit. Focused Functions report tests passed 29/29, Functions build passed, and `git diff --check` passed.
- Report share media consent slice completed: `reportShareMedia/{learnerId}/{shareRequestId}/{fileName}` is now server-owned for writes and readable only while the Firestore `reportShareRequests/{shareRequestId}` lifecycle record is active, unexpired, linked to the learner, and visible to the learner, linked guardian, share creator, same-site staff, or HQ. Focused Storage rules tests passed 11/11 with revoked, expired, missing, wrong-learner, wrong-site, unauthenticated, and client-upload denials.

Current release blockers and risks:

- The latest live Flutter web revision has cleared local gates and HTTP probes; role-based live canary remains required before broader public-site gold claims.
- Native distribution remains blocked until TestFlight, Google Play internal testing, and macOS signing/notarization proof exist; this slice only proves native proof bundle write shape/callable alignment locally.
- Cloud Run project identity must stay explicit: live Flutter site currently matches `studio-3328096157-e3f79` / `empire-web`; project number `430675339898` maps to `scholesa-prod`, which does not host the serving `empire-web` service.
- Firestore and Storage hardening is still gold-blocking beyond the validated rules/callable slices: broader collection-by-collection site-scope review, auth-claim parity, secret/compliance gates, and live role canary remain required.
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

## Active Bottom-Up Gap Queue

Use the May 10 bottom-up plan before starting the next fix pass. The current queue is:

1. Reconcile and preserve the current MiloOS typed/spoken request-modality proof.
2. Continue Firestore/Storage hardening beyond the first passing emulator slice: collection-by-collection site scope and auth-claim parity. Learner media/site-scope and report-share media consent slices are complete.
3. Prove callable/service boundaries for server-owned growth, mastery, proof verification/revision, AI audit, and report export. Mastery/growth client-write denial, AI audit site-scoping, proof bundle verification-status hardening, native proof site-scope/callable review alignment, report delivery audit spoofing denial, active report-share provenance consistency, explicit-consent revocation cascade, and report-share media consent access are complete; remaining report/share proof must cover live/operator verification.
4. Run MiloOS typed/spoken modeling through Flutter, backend, browser/mobile, telemetry, and explain-back proof.
5. Close the full HQ-to-Passport evidence chain with the same canonical evidence IDs across web, Flutter, Functions, and rules.
6. Finish all-role UI/theme, empty/error/stale, mobile, accessibility, and telemetry consistency.
7. Produce native-channel distribution proof for iOS, Android, and macOS.
8. Deploy only through `./scripts/deploy.sh`, run six-role live canary, and record rollback or traffic-pinning proof.

Stop after planning until the release owner explicitly starts the next implementation pass.

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
- Verify shared empty, loading, error, fatal-error, and recovery states render through Scholesa theme tokens in both light and dark themes across role surfaces.
- Verify role-local stale-data banners, status indicators, and action feedback use Scholesa semantic color-scheme tokens, with explicit exceptions only for recognizable provider/partner brand colors.
- Verify MiloOS client requests preserve the distinction between typed learner prompts and spoken/web-speech prompts across telemetry, backend policy, and explain-back flows.
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

- Firestore: continue replacing permissive missing-`siteId` behavior with explicit collection classes; the shared helper now fails closed and core portfolio/Passport/proof provenance collections are covered by emulator tests.
- Storage: continue learner-media hardening beyond the first `portfolioMedia` slice; owner, linked guardian claim, same-site staff metadata, HQ, missing metadata, other-site, and unauthenticated cases now have Storage emulator coverage.
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