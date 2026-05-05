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
| HQ framework setup | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins workflow route metadata and custom renderer wiring for `/hq/capability-frameworks`; `syntheticPlatformEvidenceChainGoldStates/latest.routeProofReferences.hqCapabilityFrameworks` pins this reference in the canonical manifest. | `scripts/import_synthetic_data.js` emits `capabilities`, `processDomains`, and route proof metadata; `test/synthetic_miloos_gold_states.test.js` asserts the manifest contract. | `apps/empire_flutter/app/test/hq_authoring_persistence_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`, `apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart`. | Browser proof now shows HQ live rubric create/edit feeding educator selection; blanket gold still needs full live-authored framework/rubric application through growth and reporting. |
| HQ rubric setup | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins workflow route metadata and custom renderer wiring for `/hq/rubric-builder`; `test/e2e/evidence-chain-cross-role.e2e.spec.ts` now verifies the canonical published HQ rubric template is available in `/educator/rubrics/apply` and that a newly authored and edited HQ rubric template from the live form is also available to educators; `syntheticPlatformEvidenceChainGoldStates/latest.routeProofReferences.hqRubricBuilder` pins this reference. | `functions/src/evidenceChainEmulator.test.ts` exercises rubric IDs through `applyRubricToEvidence`; canonical importer now seeds the published `rubricTemplates` record plus downstream applied rubric state and proof metadata. | `apps/empire_flutter/app/test/hq_authoring_persistence_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`, `apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart`. | Needs final proof that the live-authored template is selected and applied through `applyRubricToEvidence`, then appears in growth, portfolio, and guardian passport outputs. |
| Educator live queue | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/educator/today`; `test/e2e/mobile-evidence-workflows.e2e.spec.ts` exercises educator evidence access at mobile width; `routeProofReferences.educatorToday` records both. | Canonical importer links evidence to `session-future-skills` and `educator-alpha`. | `apps/empire_flutter/app/test/educator_today_page_test.dart`, `apps/empire_flutter/app/test/educator_live_session_mode_test.dart`. | Needs timed under-10-second live capture proof in the final packet. |
| Educator evidence capture | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/educator/evidence`; `test/e2e/mobile-evidence-workflows.e2e.spec.ts` covers the mobile-width web evidence route; `routeProofReferences.educatorEvidence` records both. | `functions/src/evidenceChainEmulator.test.ts` seeds session-backed evidence and proves it cannot create growth before verified proof. | `apps/empire_flutter/app/test/observation_capture_page_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`, `apps/empire_flutter/app/test/evidence_chain_offline_queue_test.dart`. | Needs final route proof that live-captured evidence, not only imported evidence, reaches proof/rubric review. |
| Learner proof assembly | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/learner/proof-assembly`; `routeProofReferences.learnerProofAssembly` records web, emulator, importer, and Flutter proof files. | `functions/src/evidenceChainEmulator.test.ts` proves `verifyProofOfLearning` before rubric growth; importer seeds verified proof bundle for browser consumption. | `apps/empire_flutter/app/test/proof_assembly_page_test.dart`, `apps/empire_flutter/app/test/sync_coordinator_test.dart`, `apps/empire_flutter/app/test/mission_proof_bundle_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`. | Needs web browser proof for learner-created proof assembly if web learner proof submission is included in blanket scope. |
| Educator proof review | `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/educator/proof-review`; `routeProofReferences.educatorProofReview` records web, emulator, and Flutter proof files. | `functions/src/evidenceChainEmulator.test.ts` proves authenticity verification remains required before `applyRubricToEvidence`. | `apps/empire_flutter/app/test/proof_verification_page_test.dart`, `apps/empire_flutter/app/test/evidence_chain_routes_test.dart`. | Needs browser route proof for educator review UI if web proof review is included as an active input path. |
| Educator rubric application | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` visits `/en/educator/rubrics/apply` and verifies portfolio handoff, proof, rubric application, and growth collection consumption from importer-backed records; `routeProofReferences.educatorRubricApply` pins the exact proof. | `functions/src/evidenceChainEmulator.test.ts` blocks rubric growth before verified proof, then creates mastery/growth through `applyRubricToEvidence`; `test/synthetic_miloos_gold_states.test.js` asserts importer-owned server interpretation markers. | `apps/empire_flutter/app/test/growth_engine_service_test.dart`, `apps/empire_flutter/app/test/evidence_chain_firestore_service_test.dart`. | Needs final callable failure/permission proof in the blanket gate bundle. |
| Learner portfolio | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` verifies guardian-visible portfolio provenance from the same imported evidence/proof/rubric/growth record; `src/__tests__/evidence-chain-renderer-wiring.test.ts` pins `/learner/portfolio`; `routeProofReferences.learnerPortfolio` pins both references. | Importer links `portfolioItems` to evidence, proof, rubric, AI disclosure, and growth IDs. | `apps/empire_flutter/app/test/learner_portfolio_honesty_test.dart`. | Needs direct learner web portfolio route proof if learner self-view is included beyond guardian/passport communication. |
| Guardian passport | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` visits `/en/parent/passport` and verifies evidence-backed claims, rubric score, proof markers, progression descriptor, portfolio item, and growth timeline; `routeProofReferences.parentPassport` pins the exact proof. | `functions/src/evidenceChainEmulator.test.ts` proves `getParentDashboardBundle` communicates server-owned growth and proof provenance; importer now includes consent-backed external share records. | `apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart`, `apps/empire_flutter/app/test/parent_child_page_test.dart`, `apps/empire_flutter/app/test/parent_growth_timeline_page_test.dart`. | Requester-side UX now exists in educator evidence review for explicit consent request and consent-backed broader share activation; blanket gold still needs browser proof that the granted-consent path is exercised across requester and learner/guardian approval. |
| Site evidence health | `test/e2e/evidence-chain-cross-role.e2e.spec.ts` visits `/en/site/evidence-health` and verifies evidence count, capability-mapped rate, rubric-applied rate, educator aggregation, and raw evidence status; `routeProofReferences.siteEvidenceHealth` pins the exact proof. | Canonical importer ties the same record to site, educator, learner, session, rubric, growth, portfolio, and report-share provenance. | `apps/empire_flutter/app/test/site_dashboard_page_test.dart`, `apps/empire_flutter/app/test/site_sessions_page_test.dart`. | Needs broader site session evidence coverage proof for `/educator/sessions` and `/site/sessions`. |

## First Rows Needing Work

| Priority | Route | Current status | Why it blocks blanket gold | Next proof |
| --- | --- | --- | --- | --- |
| 1 | `/educator/rubrics/apply` joined to `/parent/passport` | gold-candidate | Functions emulator proof now blocks rubric growth before verified proof and proves the resulting parent/passport output after server-owned growth. Browser route proof now consumes `syntheticPlatformEvidenceChainGoldStates/latest` from `scripts/import_synthetic_data.js` through `test/e2e/platform-evidence-chain-gold-fixture.ts` and verifies educator rubric handoff, guardian passport provenance, site evidence-health consumption, route proof metadata, consent-backed broader report-share records, requester-side broader share UX/source contracts, and live HQ rubric create/edit before educator consumption. | Expand the same chain across live rubric application, learner-created proof, requester/approver consent browser flow, and site session coverage rows. |
| 2 | `/hq/capability-frameworks` + `/hq/rubric-builder` | aligned and reusable | Canonical importer seeds framework and published rubric template records, browser proof consumes the canonical template in educator rubricing, and the HQ create/edit flow now writes a template consumed by educator selection. Blanket gold still needs that live-authored template applied through the growth/reporting chain. | Select and apply the live-authored template through educator rubricing, then verify growth, portfolio, and guardian passport provenance. |
| 3 | `/site/evidence-health` | gold-candidate | Browser route proof now shows site leaders evidence coverage, capability-mapped rate, and rubric-applied rate from the same importer-backed learner/educator evidence record used by guardian passport. Blanket gold still needs broader site session coverage. | Expand evidence-health proof to site session evidence coverage. |
| 4 | `/educator/sessions` and `/site/sessions` | reusable with modification | Session views communicate evidence coverage but still need final joined proof across educator and site scopes. | Add route proof that session coverage counts are site-scoped and evidence-backed. |
| 5 | `/partner/deliverables` | deferred unless partner scope is included | Partner output trust is real, but external-facing surfaces should not be included in blanket gold without explicit permission and evidence-safety scope. | Decide release inclusion; if included, run partner deliverable proof in the final packet. |

## Web Protected Workflow Routes

| Route | Role group | Renderer | Evidence function | Status | Blanket-gold note |
| --- | --- | --- | --- | --- | --- |
| `/learner/today` | learner | custom | Communicate current work, evidence queue, and support state | aligned and reusable | Include in learner journey proof. |
| `/learner/missions` | learner | custom | Capture mission attempts and artifact evidence | aligned and reusable | Include in learner artifact proof. |
| `/learner/portfolio` | learner | custom | Communicate portfolio artifacts and provenance | aligned and reusable | Must show only evidence-backed portfolio claims. |
| `/learner/timeline` | learner | custom | Communicate all evidence chronology | aligned and reusable | Include as read-side provenance proof. |
| `/learner/checkpoints` | learner | custom | Capture checkpoint evidence | aligned and reusable | Growth remains server-owned through `processCheckpointMasteryUpdate`. |
| `/learner/peer-feedback` | learner | custom | Capture peer evidence and feedback | aligned and reusable | Include in route-level regression bundle. |
| `/learner/proof-assembly` | learner | custom | Verify proof-of-learning bundles | aligned and reusable | Required for the gold-critical route chain. |
| `/learner/reflections` | learner | custom | Capture reflection evidence | aligned and reusable | Include in learner evidence proof. |
| `/learner/habits` | learner | custom | Operational learner routine tracking | ops-only | Keep separate from capability mastery. |
| `/learner/miloos` | learner | custom | Support provenance and explain-back | gold-candidate | Focused MiloOS slice is proven; not a mastery substitute. |
| `/educator/today` | educator | custom | Live class queue and evidence handoff | aligned and reusable | Required for under-10-second live workflow proof. |
| `/educator/attendance` | educator | generic | Attendance operations | ops-only | Attendance must not be framed as mastery. |
| `/educator/sessions` | educator | custom | Communicate session evidence coverage | reusable with modification | Needs final site-scoped evidence coverage proof. |
| `/educator/learners` | educator | custom | Communicate support and evidence follow-up | aligned and reusable | Include support provenance without mastery overclaiming. |
| `/educator/missions/review` | educator | custom | Verify submissions and create reviewed provenance | aligned and reusable | Include portfolio handoff proof. |
| `/educator/mission-plans` | educator | generic | Instructional planning operations | ops-only | Useful setup, not direct evidence proof. |
| `/educator/learner-supports` | educator | generic | Support intervention operations | gold-candidate | MiloOS support provenance is proven for focused scope. |
| `/educator/evidence` | educator | custom | Capture educator evidence | aligned and reusable | Required for the gold-critical route chain. |
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
| `/site/sessions` | site | generic | Communicate site sessions | reusable with modification | Needs evidence coverage linkage proof. |
| `/site/ops` | site | generic | Site operations | reusable with modification | Needs evidence-health tie-in if used in gold claims. |
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
| Portfolio/report | `/learner/portfolio`, `/parent/summary`, `/parent/child/:learnerId`, `/parent/portfolio`, `/parent/growth-timeline` | aligned and reusable | Prove evidence provenance survives report/export actions. |
| Site interpretation | `/site/dashboard`, `/site/sessions` | dashboard aligned, sessions reusable with modification | Prove evidence coverage and support debt are site-scoped. |

## Exit Criteria For Work Package 1

Work Package 1 is complete when:

- every web protected workflow route is classified in this matrix;
- every evidence-chain route has a status and next proof note;
- ops-only routes are kept out of capability mastery claims;
- partner routes are either explicitly included with proof or deferred;
- the first gold-critical route chain is named and pinned by source-contract tests.

Current status: **Work Package 1 is complete for the first gold-critical route chain, but blanket gold remains blocked**. The route matrix exists and is pinned. `functions/src/evidenceChainEmulator.test.ts` proves the first server-side route chain boundary from verified proof to rubric growth to parent/passport output and site-health-readable evidence. `test/e2e/evidence-chain-cross-role.e2e.spec.ts` proves the browser route layer consumes importer-backed `syntheticPlatformEvidenceChainGoldStates/latest` records across educator rubric handoff, guardian passport, site evidence-health, route proof metadata, consent-backed report-share records, and live HQ rubric create/edit before educator selection. The remaining blanket-gold gap is live application depth, learner-created proof, requester/approver consent browser proof, and site-session proof, not route classification.