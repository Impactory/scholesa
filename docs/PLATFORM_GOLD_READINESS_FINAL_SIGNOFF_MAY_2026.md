# Platform Gold Readiness Final Signoff - May 2026

Verdict: **NO-GO for blanket platform gold**.

This signoff records the current evidence packet without converting bounded proof into a platform-wide gold claim. Scholesa has strong gold-candidate slices across the capability evidence chain, site ops proof, local operator release safety, Cloud Run no-traffic deploy rehearsal, live synthetic dashboard readiness, pilot-account role access, six-role web browser cutover, educator quick-capture persistence, read-only Cloud Run release state, traffic-pinning proof, and post-pinning smoke. Production traffic was not promoted, so blanket GO still requires either an explicit promotion or an explicit release-owner decision that the recorded traffic-pinning proof is the final release control.

Forward plan: `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md` is the required step-by-step runbook for converting this NO-GO packet into a GO packet.

## Evidence Recorded

| Area | Evidence | Result |
| --- | --- | --- |
| Evidence chain browser proof | `npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts` | Passed |
| Site ops browser proof | `npx playwright test test/e2e/workflow-routes.e2e.spec.ts --grep "site ops workflow"` | Passed |
| Source contracts | `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts` | Passed, 343 tests |
| Local operator release safety | `bash ./scripts/operator_release_proof.sh` | Passed |
| Read-only Cloud Run release state | `bash ./scripts/cloud_run_release_state_probe.sh` | Passed |
| Full release reproducibility gate | `./scripts/deploy.sh release-gate` | Passed |
| AI internal-only policy | `npm run ai:internal-only:all` | Passed |
| Synthetic data dry-run | `npm run seed:synthetic-data:dry-run` | Passed |
| Live synthetic data import | `FIREBASE_PROJECT_ID=studio-3328096157-e3f79 node scripts/import_synthetic_data.js --mode starter --apply --batch-size 400` | Passed; merge-only gcloud OAuth import wrote canonical starter docs plus dashboard readiness state |
| Learner dashboard Firestore indexes | `firebase deploy --only firestore:indexes --project studio-3328096157-e3f79` and exact `gcloud firestore indexes composite list` check | Passed; `capabilityGrowthEvents`, `portfolioItems`, and `missionAttempts` dashboard indexes READY |
| MiloOS learner-loop backend contract | `cd functions && npm test -- --runTestsByPath src/bosRuntimeHonesty.test.ts src/bosRuntime.test.ts`, `npm run build`, `firebase deploy --only functions:bosGetLearnerLoopInsights` | Passed; callable returns support/opened/explain-back verification fields consumed by web |
| Learner dashboard live smoke | `gold-rehearsal` `/en/learner/today` as `test-learner-001` / `pilot-site-001` | Passed; capability assessments, growth events, active mission, and MiloOS support snapshot render from live data |
| Pilot-account role browser sweep | `gold-rehearsal` form login using `learner@scholesa.dev`, `educator@scholesa.dev`, `parent@scholesa.dev`, `site@scholesa.dev`, `hq@scholesa.dev`, `partner@scholesa.dev` | Passed for the web cutover slice; learner `/en/learner/today`, educator `/en/educator/today`, guardian `/en/parent/summary`, site `/en/site/dashboard`, site `/en/site/evidence-health`, HQ `/en/hq/sites`, and partner `/en/partner/listings` rendered without index or permission errors |
| Educator quick-capture live persistence | Browser save on `gold-rehearsal` `/en/educator/today`, followed by Firestore REST readback of `evidenceRecords` for `pilot-site-001` | Passed; live record `rGNkJv1pn5SX37o8NMC0` persisted with `status: captured`, `capabilityId: null`, and `capabilityMapped: false` for the non-portfolio observation path |
| Role-cutover Firestore index contracts | `firestore.indexes.json`, `firebase deploy --only firestore:indexes --project studio-3328096157-e3f79`, and exact `gcloud firestore indexes composite list` check | Passed; `sessionOccurrences`, `enrollments`, `evidenceRecords`, and `users` role-cutover indexes are READY, including `evidenceRecords(siteId ASC, createdAt ASC)` for site evidence-health |
| Synthetic role-readiness dry-run | `node scripts/import_synthetic_data.js --mode starter --dry-run` | Passed locally; manifest includes 6 pilot role users, 1 pilot site, 1 session, 1 occurrence, 1 guardian link, and 1 attendance record for cutover dashboard readiness |
| Current-worktree no-traffic deploy rehearsal | `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh web`, `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh compliance-operator`, and `GCP_PROJECT_ID=studio-3328096157-e3f79 CLOUD_RUN_NO_TRAFFIC=1 IMAGE_TAG=gold-rehearsal-20260507-quick-capture-fix bash ./scripts/deploy.sh primary-web` | Passed; web quick-capture fix deployed as rehearsal revision `scholesa-web-00043-c7h` with 0% production traffic, and `gold-rehearsal` tag retargeted to that revision |
| Tagged rehearsal smoke | `gold-rehearsal` Cloud Run tag URLs | Primary web `/` 200, primary web `/en/login` 200, Flutter root 200, compliance unauthenticated endpoints 403 |
| Traffic-pinning proof | `EXPECTED_WEB_REHEARSAL_REVISION=scholesa-web-00043-c7h EXPECTED_WEB_TRAFFIC_REVISION=scholesa-web-00038-fvt EXPECTED_FLUTTER_REHEARSAL_REVISION=empire-web-00073-9wk EXPECTED_FLUTTER_TRAFFIC_REVISION=empire-web-00071-6mx EXPECTED_COMPLIANCE_REHEARSAL_REVISION=scholesa-compliance-00038-dt7 EXPECTED_COMPLIANCE_TRAFFIC_REVISION=scholesa-compliance-00037-bvx bash ./scripts/cloud_run_release_state_probe.sh` | Passed; production traffic remains pinned to the previous serving revisions while rehearsal tags point to the newer candidate revisions, and unauthenticated compliance edge endpoints return 403 |
| Post-pinning smoke | Curl smoke of production and `gold-rehearsal` URLs for primary web, Flutter web, and compliance | Passed; web prod/root/login 200, web rehearsal/root/login 200, Flutter prod/rehearsal root 200, compliance prod/rehearsal root/health/status 403 |
| Native-channel release scope | Explicitly deferred from this blanket platform packet | Deferred |
| Current local validation | `node --check scripts/import_synthetic_data.js`, `git diff --check`, focused Jest, full `npm test`, `npm run typecheck`, `npm run lint`, and Cloud Build `npm run build` | Passed; full Jest: 39 suites / 545 tests |

## Operator Proof Summary

- `/site/ops` can create and resolve a site-scoped operator event with refresh persistence and `site_ops.event_resolved` audit proof.
- Local compliance runtime smoke verifies `/` 200, `/health` 200, and unauthenticated `/compliance/status` 401.
- Local operator release proof verifies the cutover guide, no-traffic guards, compliance auth posture, and rollback rule without deploying.
- Read-only Cloud Run release state probe verifies Cloud Run traffic has 100% serving revisions, optional exact revision expectations can be supplied for rehearsals/promotions, and unauthenticated compliance edge access returns 403.
- Current-worktree no-traffic rehearsal created fixed primary web revision `scholesa-web-00042-2jl`, Flutter web revision `empire-web-00073-9wk`, and compliance revision `scholesa-compliance-00038-dt7` while keeping traffic pinned to `scholesa-web-00038-fvt`, `empire-web-00071-6mx`, and `scholesa-compliance-00037-bvx`.
- Current quick-capture web fix was deployed as primary web revision `scholesa-web-00043-c7h`; `gold-rehearsal` now points to `scholesa-web-00043-c7h`, while production traffic remains 100% on `scholesa-web-00038-fvt`.
- Traffic-pinning proof confirms `scholesa-web` production traffic remains 100% on `scholesa-web-00038-fvt`, `empire-web` remains 100% on `empire-web-00071-6mx`, and `scholesa-compliance` remains 100% on `scholesa-compliance-00037-bvx`; rehearsal tags point to `scholesa-web-00043-c7h`, `empire-web-00073-9wk`, and `scholesa-compliance-00038-dt7`.
- Canonical live synthetic data now includes `syntheticMiloOSGoldStates/latest`, `syntheticPlatformEvidenceChainGoldStates/latest`, and `syntheticDashboardReadinessStates/latest`.
- Learner dashboard proof for `test-learner-001` at `pilot-site-001` shows 3 capability assessments, 3 growth observations, verified MiloOS learner-loop signals, and one active mission backed by seeded evidence/proof/rubric/growth/portfolio records.
- Pilot role accounts are credential-valid for browser cutover. The coherent pilot set is `learner@scholesa.dev`, `educator@scholesa.dev`, `parent@scholesa.dev`, `site@scholesa.dev`, `hq@scholesa.dev`, and `partner@scholesa.dev` with `Test123!`.
- The live role sweep proves learner, educator, guardian, site, HQ, and partner web access on the rehearsal tag. Site implementation health shows `100/100 — Strong`, Evidence Coverage `100%`, Proof Adoption `100%`, Growth Velocity `3`, and MiloOS support health from live same-site synthetic data.
- Site evidence-health shows Learner Coverage `100%`, Total Evidence `2`, Capability Mapped `50%`, Rubric Applied `50%`, and educator capture rows from live `pilot-site-001` evidence.
- Educator quick observation save on `/en/educator/today` persisted a live non-portfolio observation without selecting a capability; Firestore readback confirmed the optional capability path stores no undefined fields.

## Remaining NO-GO Conditions

- Production traffic promotion has not been executed.
- The release owner has not explicitly accepted traffic-pinning proof as the final release-control substitute for production promotion.
- Final GO source-contract update has not been made because this artifact must remain NO-GO until the promotion-or-pinning decision boundary is closed.

## Steps Required To Convert This Signoff To GO

1. Complete every phase in `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md`.
2. Attach current-worktree no-traffic web, Flutter web, and compliance deploy evidence.
3. Either authorize production traffic promotion for the rehearsed revisions or explicitly accept the recorded traffic-pinning proof as the final release-control substitute.
4. If production traffic is promoted, re-run the post-promotion smoke across web, Flutter web, and compliance endpoints.
5. Re-run source-contract gates after the final signoff wording update.
6. Replace the NO-GO verdict with GO only for the included web/Cloud Run scope, preserving native-channel and partner deferrals unless separately proven.

## Explicit Deferrals

- Native-channel app-store release operations are deferred from this blanket platform packet. The validated mobile evidence-chain and Flutter web/Cloud Run slices remain gold-candidate evidence, but iOS, macOS, Android store distribution, signing, notarization, and app-store promotion are not included in this signoff.

## Boundary

This artifact supports a **gold-candidate** readiness packet for the proven slices above. It must not be used to describe Scholesa as blanket platform gold-ready until the remaining NO-GO conditions are closed with live operator evidence and any future native-channel inclusion is separately proven.