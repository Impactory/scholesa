# Platform Gold Readiness Master Plan - May 2026

Current verdict: **not blanket platform gold-ready yet**. Scholesa has validated gold-candidate slices, including MiloOS web, focused Flutter/mobile MiloOS parity, canonical MiloOS synthetic manifest consumption, the non-deploying release gate, and the 2026-05-03 no-traffic Cloud Run web rehearsal. Blanket platform gold still requires every release-critical workflow to be classified, proven with current systems, and signed off with role-based operator evidence.

This document is the master certification queue. It does not replace the detailed route matrices; it points to them and names the remaining proof needed before a platform-wide gold claim is safe.

## Sources Checked

| Source | Purpose |
| --- | --- |
| `src/lib/routing/workflowRoutes.ts` | Canonical web protected workflow paths, role access, and data modes. |
| `docs/ROUTE_MODULE_MATRIX.md` | Current web and Flutter route inventory plus routing drift notes. |
| `docs/PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md` | Platform-wide route classification for blanket gold certification. |
| `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` | Flutter route-level evidence-chain proof status. |
| `docs/FLUTTER_MOBILE_GOLD_READINESS_PLAN_APRIL_30_2026.md` | Current mobile release-bundle and no-traffic rehearsal boundary. |
| `docs/MILOOS_GOLD_READINESS_PLAN_APRIL_30_2026.md` | Current MiloOS gold-candidate scope and truth boundary. |
| `scripts/import_synthetic_data.js` | Canonical synthetic data importer and source-count summary. |
| `functions/src/index.ts` | Firebase Functions evidence-chain and runtime callables. |
| `firestore.rules` | Firestore role, site, and evidence-boundary enforcement. |
| `scripts/deploy.sh` | Release gate and deploy rehearsal entry point. |

## Certification Language

| Status | Meaning |
| --- | --- |
| Gold-ready | Fully proven end to end for the included release scope, including persistence, role/site boundaries, provenance, mobile/desktop usability, synthetic data, and release rehearsal where applicable. |
| Gold-candidate | Strong focused slice with clean gates, but not enough by itself for blanket platform gold. |
| Aligned and reusable | Real implementation and proof exists, but it must be included in the final blanket bundle before platform gold. |
| Reusable with modification | Real implementation exists, but proof depth, parity, or workflow completion is incomplete. |
| Partial | Evidence-chain connection is incomplete or indirect. |
| Ops-only | Operationally honest, but not a direct evidence-chain proof. |
| Deferred | Explicitly outside the blanket gold claim. |
| Blocked | Cannot be gold until a named missing capability or proof is built. |

## Master Matrix

| System | Included scope | Current proof | Status | Gold blocker | Next proof task |
| --- | --- | --- | --- | --- | --- |
| MiloOS support provenance | Learner support loop, educator follow-up debt, guardian support provenance, site support health, canonical synthetic manifest, web and focused Flutter/mobile parity | `docs/MILOOS_GOLD_READINESS_PLAN_APRIL_30_2026.md`, `test/e2e/miloos-*.spec.ts`, `test/synthetic_miloos_gold_states.test.js`, `synthetic_miloos_gold_states_mobile_test.dart` | Gold-candidate | None for the focused MiloOS slice; not a full-platform claim | Keep in final bundle and do not broaden support events into mastery. |
| Web route inventory | 63 protected workflow paths, 30 custom evidence surfaces, 33 generic operational surfaces | `src/lib/routing/workflowRoutes.ts`, `docs/ROUTE_MODULE_MATRIX.md`, `docs/PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md`, `functions/src/evidenceChainEmulator.test.ts`, `test/e2e/evidence-chain-cross-role.e2e.spec.ts`, source-contract tests, `syntheticPlatformEvidenceChainGoldStates/latest.routeProofReferences` | Reusable with modification | Routes are classified, the server-side proof -> rubric -> growth -> parent/passport boundary is proven, and a browser route proof now consumes importer-backed `syntheticPlatformEvidenceChainGoldStates/latest` records across educator rubric handoff, canonical HQ rubric template selection, live HQ rubric create/edit, live-authored rubric application, learner-created artifact/reflection/mission-checkpoint submission, learner checkpoint-history submission, learner-created proof assembly through educator verification, timed under-10-second educator live capture, guardian passport, fail-closed Passport export/provenance audit, site evidence-health, educator/site session evidence coverage, route proof metadata, consent-backed broader report-share records, requester/approver consent flow, and requester-side broader share UX/source contracts. Blanket gold still needs operator proof depth | Expand the same certification path into operator proof. |
| Flutter/mobile route inventory | Learner, educator, guardian, site, HQ, partner, and shared mobile routes | `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`, full Flutter gate, no-traffic web rehearsal | Gold-candidate for validated mobile release bundle | Some routes remain reusable with modification for blanket claims, especially evidence coverage depth on session/analytics/ops surfaces | Promote the Flutter route matrix into the platform matrix and mark native-channel release proof as included or deferred. |
| HQ capability and rubric setup | Capability frameworks, progression descriptors, curriculum alignment, rubric templates | Web custom renderers, Flutter HQ persistence tests, route proof matrix, canonical rubric template consumed by educator browser route, live HQ rubric create/edit consumed by educator browser route, live-authored rubric application recorded in browser E2E growth state | Aligned and reusable | Canonical seeded HQ setup and a newly authored/edited HQ rubric template now feed educator rubric selection and live-authored rubric application in browser proof; the same browser proof now includes learner-created artifact/reflection/checkpoint evidence, learner-created proof assembly through educator verification, timed educator live capture, consent-backed broader sharing across requester and guardian approval, fail-closed report/export provenance, and evidence-backed educator/site session coverage. Blanket gold still needs operator proof depth beyond the newly browser-proven site ops event lifecycle | Expand from route evidence depth into operator trust gates. |
| Educator live evidence workflow | Today, observations, evidence review, proof review, rubric apply, mission review | Web custom renderers, Flutter observation/proof/mission review tests, `applyRubricToEvidence` callable tests, timed live-capture browser proof | Aligned and reusable | Browser proof now logs capability-mapped live educator evidence in under 10 seconds and keeps it pending for rubric/growth; learner-created artifact/reflection/checkpoint evidence is also browser-proven without creating client-owned mastery writes | Keep live capture and learner-created evidence in the final route-level regression bundle. |
| Learner evidence workflow | Today, missions, checkpoints, reflections, proof assembly, portfolio, credentials | Flutter route tests, web learner renderers, synthetic importer, route proof matrix, learner-created artifact/reflection/checkpoint browser proof, learner-created proof assembly and educator verification browser proof | Aligned and reusable | Web proof now creates learner-authored artifact, reflection, mission-checkpoint, and checkpoint-history records, links them to portfolio evidence and capability IDs, then carries a learner-created proof bundle through educator verification. Learner submissions remain pending evidence and do not create client-owned mastery/growth | Keep the learner-created evidence journey in the final certification run. |
| Guardian and report outputs | Parent summary, portfolio, growth timeline, passport, report share lifecycle | Parent surface workflow tests, report provenance contracts, Firestore raw-event denial, requester-side explicit-consent share helpers, requester/approver browser proof, fail-closed Passport export browser proof | Aligned and reusable | Browser proof now exercises educator request, guardian grant, consent-backed activation for broader report sharing, and a weak Passport export that fails closed with a blocked delivery audit instead of an active share | Keep consent and fail-closed report export in the final route-level regression bundle. |
| Site and implementation health | Site dashboard, evidence health, support health, sessions, provisioning, ops trust | Site dashboard tests, support-health tests, provisioning tests, mobile route matrix, educator/site session browser proof, `/site/ops` browser create/resolve/audit proof in `test/e2e/workflow-routes.e2e.spec.ts` | Aligned and reusable for evidence coverage surfaces | Site evidence-health and sessions now communicate evidence-backed coverage without presenting attendance/completion as mastery; `/site/ops` now has a browser-proven persisted event lifecycle with audit rows, but broader operator cutover, rollback, and compliance proof are still needed for blanket gold | Certify operator readiness, support debt, and ops surfaces without treating operational activity as mastery. |
| Partner evidence-facing outputs | Partner deliverables and contract/deliverable evidence trust if included in release scope | Flutter partner deliverable tests, Firestore rules coverage | Aligned and reusable if partner scope is included | Partner public/external outputs must remain permission-safe and evidence-backed | Decide release inclusion; if included, run partner deliverable proof in the final route-level regression bundle. |
| Synthetic data | Starter/full/all packs, MiloOS gold states, evidence records, portfolio items, proof bundles, rubric templates, growth, reports, consent-backed report shares | `npm run seed:synthetic-data:dry-run`, importer contracts, MiloOS web/Flutter consumption, `test/e2e/platform-evidence-chain-gold-fixture.ts`, `test/e2e/evidence-chain-cross-role.e2e.spec.ts` | Gold-candidate for MiloOS; reusable for broader platform | Non-MiloOS importer consumption now covers the first HQ-to-passport chain, canonical HQ rubric template selection, route proof metadata, and consent-backed broader share records; browser proof now adds live HQ rubric create/edit, live-authored rubric application, learner-created artifact/reflection/checkpoint creation, learner-created proof assembly through educator verification, requester/approver consent-backed share activation, fail-closed Passport export audit, educator/site session evidence coverage, and timed educator live capture before educator/guardian/site consumption. Remaining blanket proof must move through operator depth | Expand importer-backed consumption across operator proof. |
| Functions and growth engine | `applyRubricToEvidence`, `processCheckpointMasteryUpdate`, `verifyProofOfLearning`, parent bundles, report share callables, AI runtimes | Release gate, Functions build/tests, evidence-chain emulator tests | Aligned and reusable | Final platform packet must pin that proof verification remains authenticity-only and growth is server-owned | Include focused callable assertions in the final blanket gate, especially no client-owned mastery/growth writes. |
| Firestore and Storage rules | Role/site scoping, parent raw-event denial, partner evidence boundaries, append-only growth | Firestore rules integration, route proof matrix references | Aligned and reusable | Storage artifact rules need explicit inclusion if storage-backed evidence is in release scope | Decide storage scope; run Firestore plus Storage rules gates in the final packet. |
| AI transparency and internal-only policy | MiloOS support, AI disclosure, internal inference guard, audit trail | MiloOS tests, AI honesty tests, internal-only policy gate references | Gold-candidate for MiloOS | Broader AI-assisted evidence/report paths need final disclosure and audit proof | Run `npm run ai:internal-only:all` and certify AI disclosure visibility on portfolio/report outputs. |
| Deploy and operator readiness | Release gate, Cloud Run web no-traffic rehearsal, full deploy script, compliance operator, native build paths if in scope | `./scripts/deploy.sh release-gate`, `CLOUD_RUN_NO_TRAFFIC=1 ... ./scripts/deploy.sh web`, `./scripts/deploy.sh all` terminal pass, local compliance runtime smoke (`/` 200, `/health` 200, unauthenticated `/compliance/status` 401), local operator release proof (`bash ./scripts/operator_release_proof.sh`), read-only Cloud Run release state probe (`bash ./scripts/cloud_run_release_state_probe.sh`: web/Flutter traffic pinned to prior serving revisions, compliance latest serving, unauth compliance edge 403), native-channel app-store release operations explicitly deferred in `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md` | Gold-candidate for web deploy path | Blanket gold still needs live operator/browser cutover evidence and current-worktree live compliance deploy proof | Run six-role operator smoke against rehearsed/live environment and record compliance inclusion or deferral. |
| Compliance and trust operations | Compliance operator, audit logs, COPPA/report lifecycle, consent and revocation | Compliance docs, parent consent/report-share tests, deploy targets | Reusable with modification | Compliance operator deploy rehearsal and final operator evidence are not yet recorded in this master packet | Run or explicitly defer compliance operator no-traffic/live rehearsal; record audit and consent proof. |

## First Gold-Critical Gap

The highest-value remaining gap is **one canonical full evidence-chain certification path**:

HQ setup -> educator live evidence capture -> learner artifact/reflection/checkpoint/proof -> educator proof review -> rubric application -> server-owned growth -> portfolio linkage -> guardian passport/report -> site evidence-health interpretation.

MiloOS support provenance is strong, but blanket platform gold depends on the capability-growth chain above. The final proof must show the same canonical data flowing through web, Flutter/mobile where relevant, Functions, Firestore rules, portfolio, and reports.

## Work Package 1 - Build The Route Gold Matrix

Goal: no release-critical route remains unclassified.

Current artifact: `docs/PLATFORM_ROUTE_GOLD_MATRIX_MAY_2026.md`.

Current status: complete for the first gold-critical route chain. The remaining blanket-gold blocker is operator proof depth beyond the site ops event lifecycle, not route inventory classification.

Tasks:

- Generate or manually populate a table from `WORKFLOW_ROUTE_DEFINITIONS`.
- Join each web route to any custom renderer, E2E proof, source-contract proof, and synthetic data source.
- Join each Flutter route from `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` to its proof file and release scope.
- Mark operational routes as ops-only unless they create, verify, interpret, or communicate evidence.
- Mark partner and native release surfaces as included or deferred.

Exit proof:

```bash
npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts
git diff --check
```

## Work Package 2 - Certify The Full Evidence Chain

Goal: one current workflow proves Scholesa's central capability-first claim end to end.

Tasks:

- Seed or import production-shaped canonical data for capability framework, rubric, session, learner, educator, guardian, evidence, proof, and portfolio.
- Drive educator observation and learner proof through current UI/service paths.
- Apply rubric through `applyRubricToEvidence`.
- Assert `capabilityGrowthEvents` and `capabilityMastery` are server-created with provenance.
- Assert guardian passport/report shows the claim only when evidence, proof, rubric, reviewer, and portfolio links exist.
- Assert support/completion/attendance data is never framed as mastery.

Exit proof:

```bash
npm run test:integration:evidence-chain
npm run test:integration:rules
npx playwright test test/e2e/evidence-chain-cross-role.e2e.spec.ts
```

## Work Package 3 - Expand Synthetic Consumption Beyond MiloOS

Goal: synthetic data is not just present; current systems use it.

Tasks:

- Add source-count and manifest assertions for non-MiloOS evidence-chain records. Initial importer state: `syntheticPlatformEvidenceChainGoldStates/latest`; current manifest also pins `routeProofReferences`, `reportShareConsents`, and `reportShareRequests`.
- Add a web E2E fixture that maps importer output for the full evidence chain. Initial fixture: `test/e2e/platform-evidence-chain-gold-fixture.ts`, now including consent-backed broader share records and route proof metadata.
- Add a Flutter fake Firestore bridge that hydrates the same canonical records.
- Add Functions/rules emulator setup that consumes the same generated subset where practical.

Exit proof:

```bash
npm run seed:synthetic-data:dry-run
npm test -- --runTestsByPath test/synthetic_miloos_gold_states.test.js
cd apps/empire_flutter/app && flutter test test/synthetic_miloos_gold_states_mobile_test.dart
```

## Work Package 4 - Operator And Release Gold Packet

Goal: a human operator can reproduce the platform release claim.

Tasks:

- Record `./scripts/deploy.sh release-gate` output.
- Record no-traffic Cloud Run revisions and traffic allocations.
- Record compliance operator deploy or explicit deferral.
- Record `bash ./scripts/operator_release_proof.sh` output for the cutover guide, traffic-pinning guards, compliance auth posture, and rollback rule.
- Record `bash ./scripts/cloud_run_release_state_probe.sh` output for read-only Cloud Run traffic state and unauthenticated compliance edge denial.
- Run six-role browser smoke: HQ, site, educator, learner, guardian, partner if included.
- Record live rollback or traffic-pinning execution evidence if the rehearsed/live environment is available.

Exit artifact:

- `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md`

## Stop Conditions

Do not call the platform blanket gold-ready if any of these are true:

- Any included release-critical route is unclassified.
- Any evidence-chain route is partial, fake, blocked, or mock-only.
- Any report, passport, credential, or partner output lacks evidence provenance.
- Any client/mobile path writes `capabilityMastery` or `capabilityGrowthEvents` directly.
- Any support, completion, attendance, XP, or engagement path is presented as mastery.
- Synthetic data is not consumed by current web, Flutter/mobile, Functions, and rules tests.
- Parent, partner, or cross-site raw access bypasses server-owned summaries or permission boundaries.
- The release gate or deploy rehearsal cannot be reproduced from the current worktree.
- Operator cutover proof is missing for an included role.

## Current Recommendation

Proceed with **Work Package 1** immediately, then use its first `partial` evidence-chain row to drive Work Package 2. The likely first certification target is HQ setup -> educator rubric application -> server-owned growth -> portfolio -> guardian passport/report, because it is the backbone of the platform's capability-first promise.