# Platform Route Gold Matrix - May 2026

Current verdict: **route coverage is classified, but blanket platform gold is still blocked**. This matrix turns `WORKFLOW_ROUTE_DEFINITIONS` into the first platform-wide route certification view. A route appearing here means it is inventoried and classified; it does not mean the whole platform is gold-ready.

Primary sources:

- `src/lib/routing/workflowRoutes.ts`
- `src/features/workflows/customRouteRenderers.tsx`
- `docs/ROUTE_MODULE_MATRIX.md`
- `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`
- `docs/PLATFORM_GOLD_READINESS_MASTER_PLAN_MAY_2026.md`
- `functions/src/evidenceChainEmulator.test.ts`
- `test/e2e/evidence-chain-cross-role.e2e.spec.ts`

Classification key:

- **gold-candidate**: focused slice has current proof, but this is not a blanket platform claim.
- **aligned and reusable**: real implementation strengthens the evidence chain and should be included in the final bundle.
- **reusable with modification**: real implementation exists, but blanket gold needs deeper joined proof or release-scope decision.
- **ops-only**: operationally useful, but not direct evidence-chain proof.
- **deferred**: should stay outside the blanket gold claim unless explicitly included and proven.
- **blocked**: cannot be included in a gold claim until the named proof exists.

## Gold-Critical Route Chain

The first route chain to certify is:

`/hq/capability-frameworks` -> `/hq/rubric-builder` -> `/educator/today` -> `/educator/evidence` -> `/learner/proof-assembly` -> `/educator/proof-review` -> `/educator/rubrics/apply` -> `/learner/portfolio` -> `/parent/passport` -> `/site/evidence-health`

This is the smallest route-level path that can prove Scholesa's central capability-first claim: framework setup produces evidence-backed rubric interpretation, server-owned growth, portfolio linkage, guardian communication, and site evidence-health interpretation.

## Gold-Critical Route Proof References

| Chain step | Web route proof | Server / synthetic proof | Mobile parity proof | Remaining blanket-gold note |
| --- | --- | --- | --- | --- |
| HQ framework setup | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins workflow route metadata and custom renderer wiring for `/hq/capability-frameworks`; `syntheticPlatformEvidenceChainGoldStates/latest.routeProofReferences.hqCapabilityFrameworks` pins this reference in the canonical manifest. | `scripts/import_synthetic_data.js` emits `capabilities`, `processDomains`, and route proof metadata; `test/synthetic_miloos_gold_states.test.js` asserts the manifest contract. | `apps/empire_flutter/app/test/hq_authoring_persistence_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`, `apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart`. | Browser proof now shows HQ live rubric create/edit feeding educator selection and application, learner-created artifact/reflection/checkpoint creation, learner-created proof assembly, timed educator live capture, fail-closed Passport export audit, site-scoped session coverage, and site ops event create/resolve audit proof; blanket gold still needs operator proof depth beyond that route lifecycle. |
| HQ rubric setup | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins workflow route metadata and custom renderer wiring for `/hq/rubric-builder`; `test/e2e/evidence-chain-cross-role.e2e.spec.ts` now verifies the canonical published HQ rubric template is available in `/educator/rubrics/apply`, that a newly authored and edited HQ rubric template from the live form is available to educators, and that the live-authored template is selected and applied into browser rubric/growth state; `syntheticPlatformEvidenceChainGoldStates/latest.routeProofReferences.hqRubricBuilder` pins this reference. | `functions/src/evidenceChainEmulator.test.ts` exercises rubric IDs through `applyRubricToEvidence`; canonical importer now seeds the published `rubricTemplates` record plus downstream applied rubric state and proof metadata. | `apps/empire_flutter/app/test/hq_authoring_persistence_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`, `apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart`. | Learner-created evidence, fail-closed Passport export proof, and `/site/ops` event lifecycle audit proof are browser-proven; blanket gold still needs broader operator proof depth. |
| Educator live queue and capture | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/educator/today` and `/educator/evidence`; `test/e2e/mobile-evidence-workflows.e2e.spec.ts` exercises educator evidence access at mobile width; `test/e2e/evidence-chain-cross-role.e2e.spec.ts` logs capability-mapped live evidence from `/en/educator/evidence` in under 10 seconds and verifies the new record stays rubric/growth pending. | Canonical importer links evidence to `session-future-skills` and `educator-alpha`; browser proof adds a second live educator observation linked to the same session. | `apps/empire_flutter/app/test/educator_today_page_test.dart`, `apps/empire_flutter/app/test/educator_live_session_mode_test.dart`. | Timed live capture is browser-proven and now sits beside learner-created evidence proof in the same cross-role run. |
| Educator evidence capture | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/educator/evidence`; `test/e2e/mobile-evidence-workflows.e2e.spec.ts` covers the mobile-width web evidence route; `test/e2e/evidence-chain-cross-role.e2e.spec.ts` proves live capture writes a session-linked, capability-mapped pending evidence record. | `functions/src/evidenceChainEmulator.test.ts` seeds session-backed evidence and proves it cannot create growth before verified proof. | `apps/empire_flutter/app/test/observation_capture_page_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`, `apps/empire_flutter/app/test/evidence_chain_offline_queue_test.dart`. | Needs final joined proof that live-captured evidence itself reaches proof/rubric review if blanket scope demands all evidence be newly created in-browser. |
| Learner proof assembly | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/learner/proof-assembly`; `test/e2e/evidence-chain-cross-role.e2e.spec.ts` now creates learner-authored artifact, reflection, mission-checkpoint, checkpoint-history, and proof-bundle records in browser state, mirrors pending-review proof fields onto the portfolio item, and carries that same item into educator verification; `routeProofReferences.learnerProofAssembly` records web, emulator, importer, and Flutter proof files. | `functions/src/evidenceChainEmulator.test.ts` proves `verifyProofOfLearning` before rubric growth; importer seeds verified proof bundle for browser consumption. | `apps/empire_flutter/app/test/proof_assembly_page_test.dart`, `apps/empire_flutter/app/test/sync_coordinator_test.dart`, `apps/empire_flutter/app/test/mission_proof_bundle_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`. | Complete learner-created evidence is browser-proven. |
| Educator proof review | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/educator/proof-review`; `test/e2e/evidence-chain-cross-role.e2e.spec.ts` now verifies the learner-created pending-review proof bundle through the educator review UI and updates the linked proof/portfolio records to verified; `routeProofReferences.educatorProofReview` records web, emulator, and Flutter proof files. | `functions/src/evidenceChainEmulator.test.ts` proves authenticity verification remains required before `applyRubricToEvidence`. | `apps/empire_flutter/app/test/proof_verification_page_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`. | Needs final permission/failure proof if web proof review is included in the blanket gate bundle. |
| Educator rubric application | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` visits `/en/educator/rubrics/apply` and verifies portfolio handoff, proof, rubric application, and growth collection consumption from importer-backed records; `routeProofReferences.educatorRubricApply` pins the exact proof. | `functions/src/evidenceChainEmulator.test.ts` blocks rubric growth before verified proof, then creates mastery/growth through `applyRubricToEvidence`; `test/synthetic_miloos_gold_states.test.js` asserts importer-owned server interpretation markers. | `apps/empire_flutter/app/test/growth_engine_service_test.dart`, `apps/empire_flutter/app/test/evidence_chain_firestore_service_test.dart`. | Needs final callable failure/permission proof in the blanket gate bundle. |
| Learner portfolio | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` verifies guardian-visible portfolio provenance from the same imported evidence/proof/rubric/growth record; `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/learner/portfolio`; `routeProofReferences.learnerPortfolio` pins both references. | Importer links `portfolioItems` to evidence, proof, rubric, AI disclosure, and growth IDs. | `apps/empire_flutter/app/test/learner_portfolio_honesty_test.dart`. | Needs direct learner web portfolio route proof if learner self-view is included beyond guardian/passport communication. |
| Guardian passport | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` visits `/en/parent/passport` and verifies evidence-backed claims, rubric score, proof markers, progression descriptor, portfolio item, growth timeline, guardian approval of a broader-share consent request, and a weak Passport export that fails closed with `report.delivery_blocked` audit instead of an active share request; `routeProofReferences.parentPassport` pins the exact proof. | `functions/src/evidenceChainEmulator.test.ts` proves `getParentDashboardBundle` communicates server-owned growth and proof provenance; importer now includes consent-backed external share records. | `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart`, `apps/empire_flutter/app/test/parent_child_page_test.dart`, `apps/empire_flutter/app/test/parent_growth_timeline_page_test.dart`. | Guardian report/export provenance is browser-proven; broader ops/operator proof remains outside this slice. |
| Site evidence health and sessions | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` visits `/en/site/evidence-health`, `/en/educator/sessions`, and `/en/site/sessions`; it verifies evidence count, capability-mapped rate, rubric-applied rate, educator aggregation, educator session evidence counts, and site-session evidence coverage metadata from the same canonical record. | Canonical importer ties the same record to site, educator, learner, session, rubric, growth, portfolio, and report-share provenance. | `apps/empire_flutter/app/test/site_dashboard_page_test.dart`, `apps/empire_flutter/app/test/site_sessions_page_test.dart`. | Site session evidence coverage is now browser-proven; broader ops/operator proof remains outside this slice. |

## First Rows Needing Work

| Priority | Route | Current status | Why it blocks blanket gold | Next proof |
| --- | --- | --- | --- | --- |
| 1 | Operator and ops proof | reusable with modification | Route-level evidence proof now includes `/site/ops` event create/resolve persistence with audit rows, local compliance runtime endpoints smoke (`/` 200, `/health` 200, unauthenticated `/compliance/status` 401), local operator release proof (`bash ./scripts/operator_release_proof.sh`) for the cutover guide, traffic-pinning guards, compliance auth posture, and rollback rule, and read-only Cloud Run release state probe (`bash ./scripts/cloud_run_release_state_probe.sh`) for web/Flutter traffic pinning plus unauthenticated compliance edge denial. Blanket gold still needs live operator cutover and current-worktree live compliance deploy proof if those surfaces are included. | Run six-role operator smoke and document inclusion/deferral. |
| 5 | `/partner/deliverables` | deferred unless partner scope is included | Partner output trust is real, but external-facing surfaces should not be included in blanket gold without explicit permission and evidence-safety scope. | Decide release inclusion; if included, run partner deliverable proof in the final packet. |

## Web Protected Workflow Routes

| Route | Role group | Renderer | Evidence function | Status | Blanket-gold note |
| --- | --- | --- | --- | --- | --- |
| `/learner/today` | learner | custom | Communicate current work, evidence queue, and support state | aligned and reusable | Include in learner journey proof. |
| `/learner/missions` | learner | custom | Capture mission attempts and artifact evidence | aligned and reusable | Browser-proven for learner artifact, reflection, and mission-checkpoint creation. |
| `/learner/portfolio` | learner | custom | Communicate portfolio artifacts and provenance | aligned and reusable | Must show only evidence-backed portfolio claims. |
| `/learner/timeline` | learner | custom | Communicate all evidence chronology | aligned and reusable | Include as read-side provenance proof. |
| `/learner/checkpoints` | learner | custom | Capture checkpoint evidence | aligned and reusable | Browser-proven for checkpoint-history creation; growth remains server-owned through `processCheckpointMasteryUpdate`. |
| `/learner/peer-feedback` | learner | custom | Capture peer evidence and feedback | aligned and reusable | Include in route-level regression bundle. |
| `/learner/proof-assembly` | learner | custom | Verify proof-of-learning bundles | aligned and reusable | Required for the gold-critical route chain. |
| `/learner/reflections` | learner | custom | Capture reflection evidence | aligned and reusable | Include in learner evidence proof. |
| `/learner/habits` | learner | custom | Operational learner routine tracking | ops-only | Keep separate from capability mastery. |
| `/learner/miloos` | learner | custom | Support provenance and explain-back | gold-candidate | Focused MiloOS slice is proven; not a mastery substitute. |
| `/educator/today` | educator | custom | Live class queue and evidence handoff | aligned and reusable | Include with timed live evidence proof in final regression bundle. |
| `/educator/attendance` | educator | generic | Attendance operations | ops-only | Attendance must not be framed as mastery. |
| `/educator/sessions` | educator | custom | Communicate session evidence coverage | aligned and reusable | Browser proof shows site-scoped learner and evidence counts from canonical evidence records. |
| `/educator/learners` | educator | custom | Communicate support and evidence follow-up | aligned and reusable | Include support provenance without mastery overclaiming. |
| `/educator/missions/review` | educator | custom | Verify submissions and create reviewed provenance | aligned and reusable | Include portfolio handoff proof. |
| `/educator/mission-plans` | educator | generic | Instructional planning operations | ops-only | Useful setup, not direct evidence proof. |
| `/educator/learner-supports` | educator | generic | Support intervention operations | gold-candidate | MiloOS support provenance is proven for focused scope. |
| `/educator/evidence` | educator | custom | Capture educator evidence | aligned and reusable | Browser proof logs capability-mapped evidence under 10 seconds and leaves growth pending. |
| `/educator/observations` | educator | custom | Capture and manage observations | aligned and reusable | Must remain pending rubric/growth until reviewed. |
| `/educator/proof-review` | educator | custom | Verify proof-of-learning | aligned and reusable | Must remain authenticity boundary, not growth writer. |
| `/educator/rubrics/apply` | educator | custom | Interpret evidence through rubric | aligned and reusable | Growth must go through `applyRubricToEvidence`. |
| `/educator/verification` | educator | custom | Verify proof and evidence authenticity | aligned and reusable | Include as proof-review companion route. |
| `/educator/integrations` | educator | generic | Integration operations | ops-only | Include only as operational readiness scope. |
| `/parent/summary` | parent | custom | Communicate evidence-backed capability summary | aligned and reusable | Guardian claims must include provenance. |
| `/parent/billing` | parent | generic | Billing operations | ops-only | Not evidence-chain proof. |
| `/parent/schedule` | parent | generic | Schedule communication | ops-only | Useful workflow dependency, not mastery. |
| `/parent/portfolio` | parent | custom | Communicate reviewed learner artifacts | aligned and reusable | Must fail closed without evidence provenance. |
| `/parent/growth-timeline` | parent | custom | Communicate capability growth over time | aligned and reusable | Include server-owned growth provenance. |
| `/parent/passport` | parent | custom | Communicate passport/report output | aligned and reusable | Required for the gold-critical route chain. |
| `/site/checkin` | site | generic | Presence operations | ops-only | Presence must not be mastery. |
| `/site/provisioning` | site | generic | User and guardian-link setup | ops-only | Include as setup dependency where needed. |
| `/site/dashboard` | site | custom | Communicate implementation and support health | aligned and reusable | Include site interpretation proof. |
| `/site/sessions` | site | generic | Communicate site sessions | aligned and reusable | Generic site sessions now include evidence count, checkpoint count, and observed learner count metadata. |
| `/site/ops` | site | generic | Site operations | aligned and reusable for ops trust | Browser proof logs and resolves a site-scoped operator event, verifies persistence after refresh, and records `site_ops.event_resolved` audit evidence; keep separate from learner mastery claims. |
| `/site/incidents` | site | generic | Safety and trust workflow | ops-only | Include only in trust/ops bundle. |
| `/site/identity` | site | generic | Identity reconciliation | ops-only | Include only in ops readiness. |
| `/site/clever` | site | generic | SIS/integration operations | ops-only | Include only in ops readiness. |
| `/site/integrations-health` | site | generic | Integration health | ops-only | Not direct evidence-chain proof. |
| `/site/billing` | site | generic | Billing operations | ops-only | Not evidence-chain proof. |
| `/site/evidence-health` | site | custom | Communicate evidence coverage and gaps | aligned and reusable | Required for the gold-critical route chain. |
| `/partner/listings` | partner | generic | Partner listing operations | deferred | Keep outside blanket gold unless partner scope is included. |
| `/partner/contracts` | partner | generic | Partner contract operations | deferred | Include only with partner trust proof. |
| `/partner/deliverables` | partner | generic | External evidence-facing deliverables | deferred | Evidence-backed, but release inclusion must be explicit. |
| `/partner/integrations` | partner | generic | Partner integration operations | deferred | Include only with partner scope. |
| `/partner/payouts` | partner | generic | Payout operations | deferred | Not evidence-chain proof. |
| `/hq/user-admin` | hq | generic | User administration | ops-only | Setup dependency, not evidence proof. |
| `/hq/role-switcher` | hq | generic | Role impersonation/testing operations | ops-only | Useful for QA, not evidence proof. |
| `/hq/sites` | hq | generic | Site administration | ops-only | Setup dependency. |
| `/hq/analytics` | hq | custom | Communicate platform evidence/ops health | reusable with modification | Must avoid completion-as-mastery claims. |
| `/hq/billing` | hq | generic | Billing operations | ops-only | Not evidence-chain proof. |
| `/hq/approvals` | hq | generic | Approval operations | ops-only | Include only in ops readiness. |
| `/hq/audit` | hq | generic | Audit/trust output | ops-only | Include in trust bundle. |
| `/hq/safety` | hq | generic | Safety operations | ops-only | Include in trust bundle. |
| `/hq/integrations-health` | hq | generic | Integration health | ops-only | Not direct evidence-chain proof. |
| `/hq/curriculum` | hq | custom | Capability framework setup | aligned and reusable | Required setup surface. |
| `/hq/capabilities` | hq | custom | Capability authoring | aligned and reusable | Required setup surface. |
| `/hq/capability-frameworks` | hq | custom | Framework and progression authoring | aligned and reusable | Required for the gold-critical route chain. |
| `/hq/rubric-builder` | hq | custom | Rubric template setup | aligned and reusable | Required for the gold-critical route chain. |
| `/hq/feature-flags` | hq | generic | Feature flag operations | ops-only | Include only in operator readiness. |
| `/messages` | common | generic | Communication operations | ops-only | Support route, not evidence proof. |
| `/notifications` | common | generic | Notification operations | ops-only | Support route, not evidence proof. |
| `/profile` | common | generic | Profile operations | ops-only | Support route. |
| `/settings` | common | generic | Settings operations | ops-only | Support route. |

## Flutter/Mobile Join Points

The Flutter route proof matrix remains the detailed mobile source. For blanket platform certification, the mobile routes that join the gold-critical route chain are:

| Chain step | Flutter/mobile route | Current mobile status | Blanket-gold requirement |
| --- | --- | --- | --- |
| HQ setup | `/hq/capability-frameworks`, `/hq/rubric-builder`, `/hq/curriculum` | aligned/reusable, with `/hq/curriculum` still reusable with modification | Web remains canonical unless mobile HQ setup is included in final scope. |
| Educator live capture | `/educator/today`, `/educator/observations` | aligned and reusable | Include phone-width live capture proof in final route bundle. |
| Learner evidence/proof | `/learner/missions`, `/learner/checkpoints`, `/learner/reflections`, `/learner/proof-assembly` | aligned and reusable | Include offline replay and no local mastery writes. |
| Educator review/growth | `/educator/proof-review`, `/educator/rubrics/apply`, `/educator/missions/review` | aligned and reusable | Prove callable failure behavior and server-owned growth. |
| Portfolio/report | `/learner/portfolio`, `/parent/summary`, `/parent/child/:learnerId`, `/parent/portfolio`, `/parent/growth-timeline` | aligned and reusable | Keep fail-closed report/export provenance in the final regression bundle. |
| Site interpretation | `/site/dashboard`, `/site/sessions` | aligned and reusable for evidence coverage surfaces | Prove remaining support debt and operator readiness are site-scoped. |

## Exit Criteria For Work Package 1

Work Package 1 is complete when:

- every web protected workflow route is classified in this matrix;
- every evidence-chain route has a status and next proof note;
- ops-only routes are kept out of capability mastery claims;
- partner routes are either explicitly included with proof or deferred;
- the first gold-critical route chain is named and pinned by source-contract tests.

Current status: **Work Package 1 is complete for the first gold-critical route chain, but blanket gold remains blocked**. The route matrix exists and is pinned. `functions/src/evidenceChainEmulator.test.ts` proves the first server-side route chain boundary from verified proof to rubric growth to parent/passport output and site-health-readable evidence. `test/e2e/evidence-chain-cross-role.e2e.spec.ts` proves the browser route layer consumes importer-backed `syntheticPlatformEvidenceChainGoldStates/latest` records across educator rubric handoff, guardian passport, site evidence-health, route proof metadata, consent-backed report-share records, requester/approver consent, live HQ rubric create/edit, live-authored rubric application, learner-created artifact/reflection/checkpoint evidence, learner-created proof assembly through educator verification, fail-closed Passport export provenance, educator/site session evidence coverage, and timed under-10-second educator live capture. `test/e2e/workflow-routes.e2e.spec.ts` now also proves `/site/ops` can create and resolve a site-scoped operator event, persist it after refresh, and write `site_ops.event_resolved` audit evidence. The remaining blanket-gold gap is operator proof depth beyond that route lifecycle; it is not a route classification gap.