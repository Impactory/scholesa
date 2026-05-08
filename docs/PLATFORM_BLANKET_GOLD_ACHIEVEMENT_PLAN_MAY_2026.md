# Platform Blanket Gold Achievement Plan - May 2026

Current verdict: **NO-GO for blanket platform gold**.

This is the operator-facing plan for turning the current gold-candidate packet into a blanket platform Gold signoff. It is intentionally procedural: every step names the command, evidence to capture, and the stop condition. Do not convert the final signoff to GO until every required step below has current-worktree evidence.

## Scope And Boundaries

| Item | Decision |
| --- | --- |
| Included release scope | Web app, Flutter web on Cloud Run, Firebase Functions/rules, compliance operator, evidence-chain workflows, guardian/passport/report outputs, site ops/readiness surfaces. |
| Deferred scope | Native-channel app-store release operations: iOS, macOS, Android store distribution, signing, notarization, and app-store promotion. |
| Partner scope | Deferred unless a release owner explicitly includes partner evidence-facing outputs and runs partner permission/evidence proof. |
| Current hard blockers | Release-owner decision to either promote traffic or explicitly accept recorded traffic-pinning as the final release control; final GO source-contract update. Role-cutover indexes, live synthetic dashboard readiness, six-role web browser cutover, traffic-pinning proof, and post-pinning smoke are now recorded in the final signoff. |
| Gold claim rule | Blanket Gold can only be claimed for the included scope above; deferred native/partner scope must remain outside the claim. |

## May 7 Continuation Delta - Broad Gold Deployment

This delta is the current broad deployment plan from the latest worktree. It does not authorize live traffic changes by itself.

Current late-cycle changes that must be included in the next deploy proof:

- Proof-of-learning verification queue hardening: educator proof review now uses the status-backed portfolio item query and the Firestore manifest includes the related proof bundle indexes.
- Theme mode switch presentation: the public/protected theme selector must render as icon-only controls for system, light, and dark mode. The May 7 browser screenshot that still shows visible `System`, `Light`, and `Dark` text is a NO-GO runtime artifact for the currently viewed bundle until a fresh no-traffic rehearsal screenshot proves icon-only rendering.
- Firestore index posture: the May 7 read-only `gcloud firestore indexes composite list` check confirmed the six proof/verification index shapes are READY (`READY=6`, `MISSING=0`). Re-run the same readiness check before final GO and stop on any missing or building release-critical shape.
- Worktree hygiene: `.firebase/logs/vsce-debug.log` is generated tooling noise and must be excluded from the release artifact unless an operator intentionally records it.

Deployment continuation order:

1. Freeze the worktree and classify intentional diffs.
2. Re-run focused verification for the proof queue, Firestore index coverage, theme icon controls, evidence-chain contracts, and navigation/logo contracts.
3. Re-run broad non-mutating local gates.
4. Verify Firebase index readiness for all release-critical proof/verification, dashboard, role-cutover, and evidence-chain query shapes.
5. Create a new current-worktree no-traffic web revision that includes the proof queue and icon-only theme switch changes.
6. Smoke the tagged rehearsal URL before any traffic movement.
7. Run the six-role browser sweep against the rehearsal URL, with explicit checks for proof-review queue loading and icon-only theme controls. Capture a screenshot or browser accessibility note proving `System`, `Light`, and `Dark` are available only through `aria-label`/`title`, not as visible text inside the switch.
8. Ask the release owner to choose exactly one final control: traffic promotion, rollback drill, or documented traffic-pinning acceptance.
9. Convert the final signoff to GO only after the chosen control is recorded and source-contract gates pass.

Stop if any included screen still shows text `System`, `Light`, or `Dark` inside the theme switch, any proof-review route shows `Failed to load verification queue`, any Firestore index is missing for a release-critical query, or the release owner has not closed the promotion-versus-pinning decision.

## Evidence Bundle To Preserve

Create or update a dated evidence bundle before running live steps. The bundle must include command output, operator identity, timestamp, project, region, commit SHA, Cloud Run revisions, traffic allocation, screenshots or browser notes for each role, and final GO / NO-GO.

Required destination:

- `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md`

Supporting artifacts:

- `docs/PLATFORM_GOLD_READINESS_MASTER_PLAN_MAY_2026.md`
- `docs/PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md`
- `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md`
- `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md`
- `RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md`

## Phase 0 - Freeze Scope And Record Baseline

Goal: prove the operator is acting on the intended worktree and release scope.

Run:

```bash
git rev-parse --short HEAD
git status --short
git diff --check
```

Capture:

- Commit SHA.
- Clean worktree or exact intentional diffs.
- Explicit native-channel deferral.
- Partner inclusion decision.

Stop if:

- Worktree has unexplained diffs.
- Native-channel or partner scope is ambiguous.
- Operator cannot identify the target GCP/Firebase project and region.

## Phase 1 - Reproduce The Non-Mutating Gold Gate

Goal: prove the current worktree still passes the bounded evidence, source, and operator-safety contracts before any live mutation.

Run:

```bash
npm run typecheck
npm run lint
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
npm test -- --runTestsByPath src/__tests__/evidence-chain-components.test.ts src/__tests__/firestore-index-coverage.test.ts src/__tests__/navigation-signout-availability.test.ts
bash ./scripts/operator_release_proof.sh
bash ./scripts/cloud_run_release_state_probe.sh
npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts
PLAYWRIGHT_BASE_URL="https://gold-rehearsal---<web-service-url>" npx playwright test test/e2e/theme-mode-toggle.e2e.spec.ts --grep "public entrypoints"
npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts
npx playwright test test/e2e/workflow-routes.e2e.spec.ts --grep "site ops workflow"
git diff --check
```

Capture:

- Passing output for every command.
- Browser proof pass counts.
- Browser proof that public entrypoints and protected navigation render the theme switch as icon-only buttons with `System`, `Light`, and `Dark` available only as accessibility metadata.
- Rehearsal URL browser proof using `PLAYWRIGHT_BASE_URL` so Playwright does not start a local web server when validating the tagged no-traffic revision.
- Cloud Run release state probe output.

Stop if:

- Any source contract, route proof, or Cloud Run state probe fails.
- Any test creates unreviewed artifact churn.

## Phase 2 - Run The Full Release Reproducibility Gate

Goal: prove the broad release gate is reproducible from the current worktree before deployment.

Run:

```bash
./scripts/deploy.sh release-gate
npm run ai:internal-only:all
npm run seed:synthetic-data:dry-run
```

Capture:

- `release-gate` completion output.
- AI internal-only gate output.
- Synthetic dry-run source-count output.

If the live cutover environment needs canonical synthetic data, apply the starter pack with merge-only writes and verify the manifest docs before browser proof:

```bash
firebase deploy --only firestore:indexes --project studio-3328096157-e3f79
FIREBASE_PROJECT_ID=studio-3328096157-e3f79 node scripts/import_synthetic_data.js --mode starter --apply --batch-size 400
```

Capture:

- `syntheticMiloOSGoldStates/latest`
- `syntheticPlatformEvidenceChainGoldStates/latest`
- `syntheticDashboardReadinessStates/latest`
- Dashboard readiness docs for `test-learner-001` at `pilot-site-001`, including evidence/proof/rubric/growth/portfolio/MiloOS learner-loop provenance.
- Pilot role-readiness seed counts: 6 users, 1 pilot site, 1 session, 1 session occurrence, 1 enrollment, 1 attendance record, and 1 guardian link.
- READY state for the educator/site cutover index shapes: `sessionOccurrences(siteId, educatorId, date)`, `enrollments(sessionId, status)`, `evidenceRecords(siteId, createdAt)`, `evidenceRecords(siteId, educatorId, createdAt)`, and `users(siteIds array-contains, role)`.
- READY state for proof/verification index shapes used by the included screens: `portfolioItems(siteId, verificationStatus, createdAt)`, `portfolioItems(siteId, createdAt)`, `proofOfLearningBundles(siteId, verificationStatus, createdAt)`, `proofOfLearningBundles(verificationStatus, createdAt)`, `proofOfLearningBundles(learnerId, createdAt)`, and `proofOfLearningBundles(learnerId, updatedAt)`. The latest May 7 read-only check recorded all six as READY; re-check immediately before final signoff.

Stop if:

- Release gate fails.
- AI dependency/import/domain/egress policy fails.
- Synthetic dry-run output drifts from source contracts without an intentional update.
- Live synthetic apply cannot be read back from Firestore or does not map to the cutover account under test.
- Firebase or Cloud auth cannot deploy indexes or apply/read back the canonical seed.

## Phase 3 - Rehearse Current-Worktree No-Traffic Deploys

Goal: create current-worktree Cloud Run revisions without moving production traffic.

Use a unique tag, for example:

```bash
export IMAGE_TAG="gold-$(date -u +%Y%m%d-%H%M%S)"
export CLOUD_RUN_NO_TRAFFIC=1
export CLOUD_RUN_REHEARSAL_TAG=gold-rehearsal
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
```

No-traffic Cloud Run deploys retag `gold-rehearsal` to the latest created revision by default while preserving the existing 100% production traffic allocation. Set `CLOUD_RUN_REHEARSAL_TAG=` only when a rehearsal must intentionally skip tag retargeting.

Run web and Flutter web rehearsal:

```bash
./scripts/deploy.sh web
```

Run compliance operator rehearsal:

```bash
./scripts/deploy.sh compliance-operator
```

Capture for `scholesa-web`, `empire-web`, and `scholesa-compliance`:

```bash
gcloud run services describe SERVICE_NAME \
  --project studio-3328096157-e3f79 \
  --region us-central1 \
  --format='json(metadata.name,status.url,status.traffic,status.latestCreatedRevisionName,status.latestReadyRevisionName)'
```

Capture:

- New no-traffic revision names.
- Current traffic allocation proving production traffic did not move.
- Compliance unauthenticated edge denial result.

Stop if:

- Any service cannot create a ready no-traffic revision.
- Any rehearsal moves production traffic unexpectedly.
- Compliance operator is publicly reachable without auth.

## Phase 4 - Verify No-Traffic Revisions Before Promotion

Goal: prove the new revisions can serve the included scope before any traffic change.

Run service-level checks against revision URLs or approved authenticated preview paths. If the rehearsal deploys are untagged, attach a temporary no-traffic preview tag first, then verify traffic allocation has not moved. At minimum record:

- Primary web root/login path resolves.
- Flutter web root resolves.
- Compliance operator unauthenticated edge returns `403`.
- Authenticated compliance status path is reachable by the authorized operator if credentials are available.

Then run the six-role browser sweep against the rehearsed environment using:

- `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md`
- `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md`

For the canonical pilot synthetic cutover path, use this coherent account set with password `Test123!`:

| Role | Account | Required route |
| --- | --- | --- |
| Learner | `learner@scholesa.dev` | `/en/learner/today` |
| Educator | `educator@scholesa.dev` | `/en/educator/today` |
| Guardian | `parent@scholesa.dev` | `/en/parent/summary` |
| Site | `site@scholesa.dev` | `/en/site/dashboard` and `/en/site/evidence-health` |
| HQ | `hq@scholesa.dev` | `/en/hq/sites` |
| Partner, if included | `partner@scholesa.dev` | `/en/partner/listings` |

Required role checks:

| Role | Required proof |
| --- | --- |
| HQ | Capability framework/rubric setup opens and the release-critical rubric path is usable. |
| Site | `/site/evidence-health`, `/site/sessions`, and `/site/ops` show evidence/ops state; site ops event can be created and resolved if rehearsal data allows. |
| Educator | Live evidence capture, proof review, and rubric application are usable; partner-only routes remain denied. |
| Learner | Artifact/reflection/checkpoint/proof flow is usable; portfolio claims remain evidence-backed. |
| Guardian | Passport/report surfaces show provenance and fail closed when provenance is missing; unrelated learner data is not visible. |
| Partner | If partner is included, deliverable evidence is permission-safe; if deferred, partner routes remain outside the Gold claim. |

Capture:

- Start/end timestamps.
- Operator name.
- Browser and environment.
- Per-role GO / NO-GO.
- Screenshots or concise route notes for every role.
- For learner dashboard readiness, record that `/en/learner/today` renders capability assessments, recent growth, active missions, and MiloOS support signals from live synthetic Firestore/Functions data without empty-state or index errors.
- For site readiness, record that `/en/site/dashboard` resolves past `Loading implementation health...` and shows evidence coverage plus MiloOS support health from live same-site data.
- For educator readiness, record that `/en/educator/today` resolves past index errors and shows the live session plus under-10-second evidence capture controls.

Stop if:

- Any included role fails primary CTA, persistence, provenance, or scope boundary.
- Any included role hits a Firestore index error or an unresolved loading state.
- Learner-facing AI fabricates low-confidence help instead of escalating safely.
- Partner/native scope drifts from the recorded inclusion decision.
- `/educator/proof-review` or `/educator/verification` shows `Failed to load verification queue`.
- The theme mode switch renders visible text labels instead of the expected system, sun, and moon icons.

## Phase 5 - Promote Or Roll Back Under Operator Control

Goal: prove the operator can either promote the approved revision or keep/restore traffic on the previous revision.

Before any traffic change, record previous serving revisions:

```bash
gcloud run services describe scholesa-web --project studio-3328096157-e3f79 --region us-central1 --format='value(status.traffic[0].revisionName)'
gcloud run services describe empire-web --project studio-3328096157-e3f79 --region us-central1 --format='value(status.traffic[0].revisionName)'
gcloud run services describe scholesa-compliance --project studio-3328096157-e3f79 --region us-central1 --format='value(status.traffic[0].revisionName)'
```

Promotion, if approved by the release owner:

```bash
gcloud run services update-traffic scholesa-web --project studio-3328096157-e3f79 --region us-central1 --to-revisions NEW_WEB_REVISION=100 --quiet
gcloud run services update-traffic empire-web --project studio-3328096157-e3f79 --region us-central1 --to-revisions NEW_FLUTTER_REVISION=100 --quiet
gcloud run services update-traffic scholesa-compliance --project studio-3328096157-e3f79 --region us-central1 --to-revisions NEW_COMPLIANCE_REVISION=100 --quiet
```

Rollback proof, if any check fails or as a controlled rollback drill:

```bash
gcloud run services update-traffic scholesa-web --project studio-3328096157-e3f79 --region us-central1 --to-revisions PREVIOUS_WEB_REVISION=100 --quiet
gcloud run services update-traffic empire-web --project studio-3328096157-e3f79 --region us-central1 --to-revisions PREVIOUS_FLUTTER_REVISION=100 --quiet
gcloud run services update-traffic scholesa-compliance --project studio-3328096157-e3f79 --region us-central1 --to-revisions PREVIOUS_COMPLIANCE_REVISION=100 --quiet
```

Capture:

- Previous revisions.
- New promoted revisions, if promotion happens.
- Rollback command output or explicit traffic-pinning proof.
- Final traffic allocation for every service.

Stop if:

- Traffic allocation cannot be verified.
- Rollback command cannot restore the intended previous revision.

## Phase 6 - Post-Promotion Smoke And Trust Checks

Goal: prove live traffic remains evidence-safe after promotion.

Run:

```bash
bash ./scripts/cloud_run_release_state_probe.sh
npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts
npx playwright test test/e2e/workflow-routes.e2e.spec.ts --grep "site ops workflow"
```

If the probe expectations need the newly promoted revisions, set:

```bash
export EXPECTED_WEB_REHEARSAL_REVISION="NEW_WEB_REVISION"
export EXPECTED_WEB_TRAFFIC_REVISION="NEW_WEB_REVISION"
export EXPECTED_FLUTTER_REHEARSAL_REVISION="NEW_FLUTTER_REVISION"
export EXPECTED_FLUTTER_TRAFFIC_REVISION="NEW_FLUTTER_REVISION"
export EXPECTED_COMPLIANCE_REHEARSAL_REVISION="NEW_COMPLIANCE_REVISION"
export EXPECTED_COMPLIANCE_TRAFFIC_REVISION="NEW_COMPLIANCE_REVISION"
```

Capture:

- Post-promotion Cloud Run state.
- Evidence-chain browser proof.
- Site ops browser proof.

Stop if:

- Live traffic state does not match expected revisions.
- Browser proof fails after promotion.

## Phase 7 - Convert Final Signoff From NO-GO To GO

Goal: update the final MD artifact only after all evidence exists.

Update `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md` with:

- Final verdict: `GO for blanket platform Gold for the included web/Cloud Run scope`.
- Commit SHA.
- Release owner and operator.
- Exact included/deferred scope.
- All command outputs or evidence links.
- Cloud Run revisions before and after promotion.
- Six-role cutover result.
- Rollback or traffic-pinning proof.
- Compliance deploy proof.
- Native-channel deferral boundary.

Then run:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
npm run typecheck
npm run lint
git diff --check
```

Stop if:

- Any final signoff statement lacks evidence.
- The signoff broadens into native-channel or partner scope without proof.
- Source-contract tests do not pin the GO boundary.

## Final GO Checklist

Blanket platform Gold for the included web/Cloud Run scope is achieved only when every item is checked:

- [ ] Scope frozen; native-channel app-store operations deferred or separately proven.
- [ ] Partner scope deferred or separately proven.
- [ ] Clean commit SHA recorded.
- [ ] Non-mutating gold gate passed.
- [ ] Full release reproducibility gate passed.
- [ ] AI internal-only gate passed.
- [ ] Synthetic dry-run passed.
- [x] Firestore role-cutover indexes deployed and READY.
- [x] Firestore proof/verification indexes deployed and READY in the May 7 read-only check; re-check immediately before final release-control decision.
- [x] Live synthetic data applied and read back for the cutover environment, if synthetic data is used for the browser proof.
- [ ] Current-worktree proof queue fix and icon-only theme switch included in a no-traffic web revision.
- [x] Current-worktree web/Flutter no-traffic revisions created and verified.
- [x] Current-worktree compliance operator deploy proof recorded.
- [x] Six-role browser cutover passed for the web cutover slice.
- [x] Traffic promotion or traffic-pinning proof recorded.
- [ ] Rollback proof recorded or release owner accepts traffic-pinning proof as the rollback control.
- [x] Post-promotion or post-pinning smoke passed.
- [ ] Proof-review queue loads without index/load errors on the rehearsed or promoted web revision.
- [ ] Theme mode switch renders icon-only controls on public and protected shells.
- [ ] Final signoff converted from NO-GO to GO with evidence.
- [ ] Source-contract tests pass after signoff update.

## Absolute Stop Conditions

Do not claim blanket Gold if any of these remain true:

- Live operator cutover is missing.
- Current-worktree live compliance deploy proof is missing.
- Any included role lacks persistence/provenance/scope-boundary proof.
- Any included report/passport/portfolio output lacks evidence provenance.
- Any client path writes mastery/growth directly.
- Any completion, attendance, support, XP, or engagement signal is presented as mastery.
- Any deferred native or partner scope is accidentally included in the claim.
