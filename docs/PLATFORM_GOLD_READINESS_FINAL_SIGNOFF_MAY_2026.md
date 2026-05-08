# Platform Gold Readiness Final Signoff - May 2026

Verdict: **NO-GO for blanket platform gold**.

This signoff records the current evidence packet without converting bounded proof into a platform-wide gold claim. Scholesa has strong gold-candidate slices across the capability evidence chain, site ops proof, local operator release safety, Cloud Run no-traffic deploy rehearsal, live synthetic dashboard readiness, pilot-account role access, six-role web browser cutover, educator quick-capture persistence, MiloOS learner callable proof, read-only Cloud Run release state, traffic-pinning proof, and post-pinning smoke. Production traffic was not promoted, so blanket GO still requires either an explicit promotion or an explicit release-owner decision that the recorded traffic-pinning proof is the final release control.

Forward plan: `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md` is the required step-by-step runbook for converting this NO-GO packet into a GO packet.

## Evidence Recorded

| Area | Evidence | Result |
| --- | --- | --- |
| Evidence chain browser proof | `npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts` | Passed |
| Site ops browser proof | `npx playwright test test/e2e/workflow-routes.e2e.spec.ts --grep "site ops workflow"` | Passed |
| Source contracts | `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts` | Passed, 343 tests |
| Local operator release safety | `bash ./scripts/operator_release_proof.sh` | Passed |
| Read-only Cloud Run release state | `bash ./scripts/cloud_run_release_state_probe.sh` | Passed |
| Full release reproducibility gate | `./scripts/deploy.sh release-gate`; latest local log `/tmp/scholesa-release-gate-20260508-001144.log` | Passed; release gate stayed non-deploying, full Flutter gate passed `1087` tests, diff hygiene passed, and the gate ended with `Release reproducibility gate passed` |
| Production web build | `npm run build` | Passed; Next.js production build compiled successfully and included `/[locale]/educator/proof-review`, `/[locale]/educator/verification`, public entrypoints, and protected workflow routes |
| AI internal-only policy | `npm run ai:internal-only:all` | Passed |
| Synthetic data dry-run | `npm run seed:synthetic-data:dry-run` | Passed; dry-run import `synthetic-import-2026-05-08T00-04-56-329Z`, mode `all`, packs `starter` and `full`, no Firestore writes |
| MiloOS typed input intelligence | `npm --prefix functions run test -- --runInBand src/voiceSystem.test.ts` | Passed, 19 tests; typed learner questions receive evidence/prototype guidance while voice/unknown student input keeps strict confidence guardrails |
| MiloOS source and browser proof | Focused Jest for MiloOS support/provenance plus `npx playwright test --config playwright.config.ts` across the MiloOS E2E specs | Passed; 5 focused source suites / 15 tests and 13 browser tests across learner, educator, guardian, site, mobile, keyboard, accessibility, and cross-role provenance |
| Logo source/render proof | `src/__tests__/navigation-signout-availability.test.ts`, `src/__tests__/skills-first-honesty-entrypoints.test.ts`, and Playwright image inspection on `/en`, `/en/login`, `/en/register`, and protected learner navigation | Passed; rendered images load through `/logo/scholesa-logo-192.png` with nonzero natural dimensions on public entrypoints and authenticated navigation |
| Theme icon-only source/browser proof | `src/__tests__/navigation-signout-availability.test.ts` and `npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts` | Passed locally; public entrypoints and protected navigation render system, light, and dark controls as accessible icon-only buttons with no visible `System`, `Light`, or `Dark` text in the switch |
| Theme rehearsal-mode browser proof | `PLAYWRIGHT_BASE_URL=http://127.0.0.1:3010 npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts --grep "public entrypoints"` | Passed against a separately started local server; this proves the same external-base-url path operators must use against the no-traffic `gold-rehearsal` Cloud Run URL without Playwright starting a local web server |
| Fail-closed Firebase placeholder proof | Local browser boot without Firebase client env vars on port 3000 | Passed; browser runtime refused demo placeholders with `Missing required Firebase client env vars. Refusing to initialize the client SDK with demo placeholders.` |
| Live synthetic data import | `FIREBASE_PROJECT_ID=studio-3328096157-e3f79 node scripts/import_synthetic_data.js --mode starter --apply --batch-size 400` | Passed; merge-only gcloud OAuth import wrote canonical starter docs plus dashboard readiness state |
| Learner dashboard Firestore indexes | `firebase deploy --only firestore:indexes --project studio-3328096157-e3f79` and exact `gcloud firestore indexes composite list` check | Passed; `capabilityGrowthEvents`, `portfolioItems`, and `missionAttempts` dashboard indexes READY |
| MiloOS learner-loop backend contract | `cd functions && npm test -- --runTestsByPath src/bosRuntimeHonesty.test.ts src/bosRuntime.test.ts`, `npm run build`, `firebase deploy --only functions:bosGetLearnerLoopInsights` | Passed; callable returns support/opened/explain-back verification fields consumed by web |
| MiloOS learner callable browser proof | `gold-rehearsal` `/en/learner/miloos?verify=00045-retag` as `learner@scholesa.dev`; `firebase deploy --only functions:genAiCoach,functions:submitExplainBack,functions:logTelemetryEvent`; `gcloud run services add-iam-policy-binding genaicoach --member=allUsers --role=roles/run.invoker`; live preflight curl; browser ask | Passed; floating MiloOS button resolves `Open MiloOS` / `Ask for help`, logo link renders, preflight returns 204 with rehearsal origin, and browser ask returns a MiloOS response transcript, spoken-response state, next steps, and explain-back prompt |
| Learner dashboard live smoke | `gold-rehearsal` `/en/learner/today` as `test-learner-001` / `pilot-site-001` | Passed; capability assessments, growth events, active mission, and MiloOS support snapshot render from live data |
| Pilot-account role browser sweep | `gold-rehearsal` form login using `learner@scholesa.dev`, `educator@scholesa.dev`, `parent@scholesa.dev`, `site@scholesa.dev`, `hq@scholesa.dev`, `partner@scholesa.dev` | Passed for the web cutover slice; learner `/en/learner/today`, educator `/en/educator/today`, guardian `/en/parent/summary`, site `/en/site/dashboard`, site `/en/site/evidence-health`, HQ `/en/hq/sites`, and partner `/en/partner/listings` rendered without index or permission errors |
| Educator quick-capture live persistence | Browser save on `gold-rehearsal` `/en/educator/today`, followed by Firestore REST readback of `evidenceRecords` for `pilot-site-001` | Passed; live record `rGNkJv1pn5SX37o8NMC0` persisted with `status: captured`, `capabilityId: null`, and `capabilityMapped: false` for the non-portfolio observation path |
| Role-cutover Firestore index contracts | `firestore.indexes.json`, `firebase deploy --only firestore:indexes --project studio-3328096157-e3f79`, and exact `gcloud firestore indexes composite list` check | Passed; `sessionOccurrences`, `enrollments`, `evidenceRecords`, and `users` role-cutover indexes are READY, including `evidenceRecords(siteId ASC, createdAt ASC)` for site evidence-health |
| Proof/verification Firestore indexes | May 8 read-only `node scripts/proof_verification_index_readiness.js` after reauth | Passed; `portfolioItems(siteId, verificationStatus, createdAt)`, `portfolioItems(siteId, createdAt)`, `proofOfLearningBundles(siteId, verificationStatus, createdAt)`, `proofOfLearningBundles(verificationStatus, createdAt)`, `proofOfLearningBundles(learnerId, createdAt)`, and `proofOfLearningBundles(learnerId, updatedAt)` all READY (`READY=6`, `MISSING=0`) |
| Synthetic role-readiness dry-run | `node scripts/import_synthetic_data.js --mode starter --dry-run` | Passed locally; manifest includes 6 pilot role users, 1 pilot site, 1 session, 1 occurrence, 1 guardian link, and 1 attendance record for cutover dashboard readiness |
| Current-worktree no-traffic deploy rehearsal | `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh web`, `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh compliance-operator`, `GCP_PROJECT_ID=studio-3328096157-e3f79 CLOUD_RUN_NO_TRAFFIC=1 IMAGE_TAG=gold-rehearsal-20260507-miloos-root-locale-fix bash ./scripts/deploy.sh primary-web`, and manual `gcloud run services update-traffic --update-tags gold-rehearsal=scholesa-web-00045-pm9` before the script hardening | Passed; web MiloOS/root-locale fix deployed as rehearsal revision `scholesa-web-00045-pm9` with 0% production traffic, and `gold-rehearsal` tag points to that revision |
| Tagged rehearsal smoke | `gold-rehearsal` Cloud Run tag URLs | Primary web `/` 200, primary web `/en/login` 200, Flutter root 200, compliance unauthenticated endpoints 403 |
| Traffic-pinning proof | `EXPECTED_WEB_REHEARSAL_REVISION=scholesa-web-00045-pm9 EXPECTED_WEB_TRAFFIC_REVISION=scholesa-web-00038-fvt EXPECTED_FLUTTER_REHEARSAL_REVISION=empire-web-00073-9wk EXPECTED_FLUTTER_TRAFFIC_REVISION=empire-web-00071-6mx EXPECTED_COMPLIANCE_REHEARSAL_REVISION=scholesa-compliance-00038-dt7 EXPECTED_COMPLIANCE_TRAFFIC_REVISION=scholesa-compliance-00037-bvx bash ./scripts/cloud_run_release_state_probe.sh` | Passed; production traffic remains pinned to the previous serving revisions while rehearsal tags point to the newer candidate revisions, and unauthenticated compliance edge endpoints return 403 |
| Post-pinning smoke | Curl smoke of production and `gold-rehearsal` URLs for primary web, Flutter web, and compliance | Passed; web prod/root/login 200, web rehearsal/root/login 200, Flutter prod/rehearsal root 200, compliance prod/rehearsal root/health/status 403 |
| Native-channel release scope | Explicitly deferred from this blanket platform packet | Deferred |
| Current local validation | `node --check scripts/import_synthetic_data.js`, `git diff --check`, focused Jest, full `npm test`, `npm run typecheck`, `npm run lint`, and Cloud Build `npm run build` | Passed; full Jest: 39 suites / 545 tests |

## Operator Proof Summary

- `/site/ops` can create and resolve a site-scoped operator event with refresh persistence and `site_ops.event_resolved` audit proof.
- Local compliance runtime smoke verifies `/` 200, `/health` 200, and unauthenticated `/compliance/status` 401.
- Local operator release proof verifies the cutover guide, no-traffic guards, compliance auth posture, and rollback rule without deploying.
- Read-only Cloud Run release state probe verifies Cloud Run traffic has 100% serving revisions, optional exact revision expectations can be supplied for rehearsals/promotions, and unauthenticated compliance edge access returns 403.
- May 8 post-reauth read-only checks passed: proof/verification indexes are READY (`READY=6`, `MISSING=0`) and `bash ./scripts/cloud_run_release_state_probe.sh` passed with 100% serving revisions and unauthenticated compliance edge 403.
- May 7 operator containment note: an already-running local `./scripts/deploy.sh all` process was discovered, stopped with exit `143`, and its remote compliance Cloud Build `0346e4be-94f6-45c9-84d7-8d4cd17f872f` was cancelled before Cloud Run deployment; the follow-up read-only Cloud Run release state probe passed and no traffic movement was recorded.
- Current-worktree no-traffic rehearsal created fixed primary web revision `scholesa-web-00042-2jl`, Flutter web revision `empire-web-00073-9wk`, and compliance revision `scholesa-compliance-00038-dt7` while keeping traffic pinned to `scholesa-web-00038-fvt`, `empire-web-00071-6mx`, and `scholesa-compliance-00037-bvx`.
- Current quick-capture web fix was deployed as primary web revision `scholesa-web-00043-c7h`; `gold-rehearsal` now points to `scholesa-web-00043-c7h`, while production traffic remains 100% on `scholesa-web-00038-fvt`.
- Current MiloOS/root-locale web fix was deployed as primary web revision `scholesa-web-00045-pm9`; `gold-rehearsal` now points to `scholesa-web-00045-pm9`, while production traffic remains 100% on `scholesa-web-00038-fvt`.
- Traffic-pinning proof confirms `scholesa-web` production traffic remains 100% on `scholesa-web-00038-fvt`, `empire-web` remains 100% on `empire-web-00071-6mx`, and `scholesa-compliance` remains 100% on `scholesa-compliance-00037-bvx`; rehearsal tags point to `scholesa-web-00045-pm9`, `empire-web-00073-9wk`, and `scholesa-compliance-00038-dt7`.
- Canonical live synthetic data now includes `syntheticMiloOSGoldStates/latest`, `syntheticPlatformEvidenceChainGoldStates/latest`, and `syntheticDashboardReadinessStates/latest`.
- Learner dashboard proof for `test-learner-001` at `pilot-site-001` shows 3 capability assessments, 3 growth observations, verified MiloOS learner-loop signals, and one active mission backed by seeded evidence/proof/rubric/growth/portfolio records.
- Pilot role accounts are credential-valid for browser cutover. The coherent pilot set is `learner@scholesa.dev`, `educator@scholesa.dev`, `parent@scholesa.dev`, `site@scholesa.dev`, `hq@scholesa.dev`, and `partner@scholesa.dev` with `Test123!`.
- The live role sweep proves learner, educator, guardian, site, HQ, and partner web access on the rehearsal tag. Site implementation health shows `100/100 — Strong`, Evidence Coverage `100%`, Proof Adoption `100%`, Growth Velocity `3`, and MiloOS support health from live same-site synthetic data.
- Site evidence-health shows Learner Coverage `100%`, Total Evidence `2`, Capability Mapped `50%`, Rubric Applied `50%`, and educator capture rows from live `pilot-site-001` evidence.
- Educator quick observation save on `/en/educator/today` persisted a live non-portfolio observation without selecting a capability; Firestore readback confirmed the optional capability path stores no undefined fields.
- MiloOS learner browser proof on `/en/learner/miloos` shows the floating assistant label no longer leaks raw `aiCoach.*` keys, the Scholesa logo link renders in protected navigation, the `genAiCoach` preflight accepts the `gold-rehearsal` origin, and the authenticated learner receives a support response with transcript, next steps, and explain-back prompt.
- Current MiloOS typed input intelligence proof confirms typed learner questions can receive actionable evidence/prototype scaffolding without converting support into mastery, while voice and unknown student inputs continue to require strict confidence.
- Current logo render proof confirms `/en`, `/en/login`, `/en/register`, and protected learner navigation render the canonical PNG logo through Next image optimization with loaded natural dimensions.
- Current placeholder proof confirms real browser runtime fails closed without Firebase client env vars instead of initializing with demo placeholders; demo Firebase config remains limited to server/build/E2E harness mode.

## Remaining NO-GO Conditions

- Production traffic promotion has not been executed.
- The release owner has not explicitly accepted traffic-pinning proof as the final release-control substitute for production promotion.
- The latest current-worktree proof verification queue and icon-only theme switch changes have not been rehearsed as a no-traffic Cloud Run web revision; that live rehearsal requires explicit operator authorization.
- The May 7 browser screenshot still shows visible `System`, `Light`, and `Dark` labels in the theme switch, so the currently viewed runtime bundle cannot be accepted as Gold evidence even though the source-level icon-only change exists locally.
- Final GO source-contract update has not been made because this artifact must remain NO-GO until the promotion-or-pinning decision boundary is closed.

## Steps Required To Convert This Signoff To GO

1. Complete every phase in `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md`.
2. Attach current-worktree no-traffic web, Flutter web, and compliance deploy evidence.
3. Verify proof-review queue loading and icon-only theme switch rendering on the rehearsed web revision, with fresh browser proof that no visible `System`, `Light`, or `Dark` label text remains inside the switch.
4. Resolve the tagged web rehearsal URL with `node scripts/cloud_run_rehearsal_urls.js`, then run `npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts` against the current worktree and repeat the public icon-only check against the rehearsed Cloud Run URL with `PLAYWRIGHT_BASE_URL="<scholesa-web REHEARSAL_URL>" npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts --grep "public entrypoints"`.
5. Re-check all release-critical Firestore indexes are READY immediately before the final release-control decision.
6. Either authorize production traffic promotion for the rehearsed revisions or explicitly accept the recorded traffic-pinning proof as the final release-control substitute.
7. If production traffic is promoted, re-run the post-promotion smoke across web, Flutter web, and compliance endpoints.
8. Re-run source-contract gates after the final signoff wording update.
9. Replace the NO-GO verdict with GO only for the included web/Cloud Run scope, preserving native-channel and partner deferrals unless separately proven.

## Explicit Deferrals

- Native-channel app-store release operations are deferred from this blanket platform packet. The validated mobile evidence-chain and Flutter web/Cloud Run slices remain gold-candidate evidence, but iOS, macOS, Android store distribution, signing, notarization, and app-store promotion are not included in this signoff.

## Boundary

This artifact supports a **gold-candidate** readiness packet for the proven slices above. It must not be used to describe Scholesa as blanket platform gold-ready until the remaining NO-GO conditions are closed with live operator evidence and any future native-channel inclusion is separately proven.