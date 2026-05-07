# Platform Gold Readiness Final Signoff - May 2026

Verdict: **NO-GO for blanket platform gold**.

This signoff records the current evidence packet without converting bounded proof into a platform-wide gold claim. Scholesa has strong gold-candidate slices across the capability evidence chain, site ops proof, local operator release safety, Cloud Run no-traffic deploy rehearsal, live synthetic dashboard readiness, and read-only Cloud Run release state, but the full six-role operator cutover has not been executed and recorded.

Forward plan: `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md` is the required step-by-step runbook for converting this NO-GO packet into a GO packet.

## Evidence Recorded

| Area | Evidence | Result |
| --- | --- | --- |
| Evidence chain browser proof | `npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts` | Passed |
| Site ops browser proof | `npx playwright test test/e2e/workflow-routes.e2e.spec.ts --grep "site ops workflow"` | Passed |
| Source contracts | `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts` | Passed, 191 tests |
| Local operator release safety | `bash ./scripts/operator_release_proof.sh` | Passed |
| Read-only Cloud Run release state | `bash ./scripts/cloud_run_release_state_probe.sh` | Passed |
| Full release reproducibility gate | `./scripts/deploy.sh release-gate` | Passed |
| AI internal-only policy | `npm run ai:internal-only:all` | Passed |
| Synthetic data dry-run | `npm run seed:synthetic-data:dry-run` | Passed |
| Live synthetic data import | `FIREBASE_PROJECT_ID=studio-3328096157-e3f79 node scripts/import_synthetic_data.js --mode starter --apply --batch-size 400` | Passed; merge-only gcloud OAuth import wrote canonical starter docs plus dashboard readiness state |
| Learner dashboard Firestore indexes | `firebase deploy --only firestore:indexes --project studio-3328096157-e3f79` and exact `gcloud firestore indexes composite list` check | Passed; `capabilityGrowthEvents`, `portfolioItems`, and `missionAttempts` dashboard indexes READY |
| MiloOS learner-loop backend contract | `cd functions && npm test -- --runTestsByPath src/bosRuntimeHonesty.test.ts src/bosRuntime.test.ts`, `npm run build`, `firebase deploy --only functions:bosGetLearnerLoopInsights` | Passed; callable returns support/opened/explain-back verification fields consumed by web |
| Learner dashboard live smoke | `gold-rehearsal` `/en/learner/today` as `test-learner-001` / `pilot-site-001` | Passed; capability assessments, growth events, active mission, and MiloOS support snapshot render from live data |
| Current-worktree no-traffic deploy rehearsal | `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh web` and `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh compliance-operator` | Passed; rehearsal revisions created with 0% production traffic |
| Tagged rehearsal smoke | `gold-rehearsal` Cloud Run tag URLs | Primary web `/` 200, primary web `/en/login` 200, Flutter root 200, compliance unauthenticated endpoints 403 |
| Native-channel release scope | Explicitly deferred from this blanket platform packet | Deferred |
| TypeScript and lint | `npm run typecheck && npm run lint` | Passed |

## Operator Proof Summary

- `/site/ops` can create and resolve a site-scoped operator event with refresh persistence and `site_ops.event_resolved` audit proof.
- Local compliance runtime smoke verifies `/` 200, `/health` 200, and unauthenticated `/compliance/status` 401.
- Local operator release proof verifies the cutover guide, no-traffic guards, compliance auth posture, and rollback rule without deploying.
- Read-only Cloud Run release state probe verifies Cloud Run traffic has 100% serving revisions, optional exact revision expectations can be supplied for rehearsals/promotions, and unauthenticated compliance edge access returns 403.
- Current-worktree no-traffic rehearsal created fixed primary web revision `scholesa-web-00042-2jl`, Flutter web revision `empire-web-00073-9wk`, and compliance revision `scholesa-compliance-00038-dt7` while keeping traffic pinned to `scholesa-web-00038-fvt`, `empire-web-00071-6mx`, and `scholesa-compliance-00037-bvx`.
- Canonical live synthetic data now includes `syntheticMiloOSGoldStates/latest`, `syntheticPlatformEvidenceChainGoldStates/latest`, and `syntheticDashboardReadinessStates/latest`.
- Learner dashboard proof for `test-learner-001` at `pilot-site-001` shows 3 capability assessments, 3 growth observations, verified MiloOS learner-loop signals, and one active mission backed by seeded evidence/proof/rubric/growth/portfolio records.

## Remaining NO-GO Conditions

- Full live six-role operator browser cutover has not been executed and recorded. The learner dashboard slice is recorded, but HQ, site, educator, guardian, and any included partner cutover proof remain outstanding.
- Traffic promotion or rollback proof has not been executed and recorded for the rehearsed revisions.

## Steps Required To Convert This Signoff To GO

1. Complete every phase in `docs/PLATFORM_BLANKET_GOLD_ACHIEVEMENT_PLAN_MAY_2026.md`.
2. Attach current-worktree no-traffic web, Flutter web, and compliance deploy evidence.
3. Attach six-role browser cutover evidence for HQ, site, educator, learner, guardian, and partner if partner is included.
4. Attach traffic promotion or rollback/traffic-pinning evidence for `scholesa-web`, `empire-web`, and `scholesa-compliance`.
5. Re-run the post-promotion smoke and source-contract gates.
6. Replace the NO-GO verdict with GO only for the included web/Cloud Run scope, preserving native-channel and partner deferrals unless separately proven.

## Explicit Deferrals

- Native-channel app-store release operations are deferred from this blanket platform packet. The validated mobile evidence-chain and Flutter web/Cloud Run slices remain gold-candidate evidence, but iOS, macOS, Android store distribution, signing, notarization, and app-store promotion are not included in this signoff.

## Boundary

This artifact supports a **gold-candidate** readiness packet for the proven slices above. It must not be used to describe Scholesa as blanket platform gold-ready until the remaining NO-GO conditions are closed with live operator evidence and any future native-channel inclusion is separately proven.