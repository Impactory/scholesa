# Platform Route Gold Matrix - May 2026

Current verdict: **route coverage is classified, but blanket platform gold is still blocked**. This matrix turns `WORKFLOW_ROUTE_DEFINITIONS` into the first platform-wide route certification view. A route appearing here means it is inventoried and classified; it does not mean the whole platform is gold-ready.

Primary sources:

- `src/lib/routing/workflowRoutes.ts`
- `src/features/workflows/customRouteRenderers.tsx`
- `docs/ROUTE_MODULE_MATRIX.md`
- `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md`
- `docs/PLATFORM_GOLD_READINESS_MASTER_PLAN_MAY_2026.md`

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

## First Rows Needing Work

| Priority | Route | Current status | Why it blocks blanket gold | Next proof |
| --- | --- | --- | --- | --- |
| 1 | `/educator/rubrics/apply` joined to `/parent/passport` | aligned and reusable | Functions emulator proof now blocks rubric growth before verified proof and proves the resulting parent/passport output after server-owned growth, but blanket gold still needs browser coverage using canonical synthetic data. | Add a cross-role evidence-chain E2E using canonical synthetic data. |
| 2 | `/hq/capability-frameworks` + `/hq/rubric-builder` | aligned and reusable | HQ setup is real, but the final route chain must prove setup feeds educator rubricing without manual fixture shortcuts. | Seed/import canonical framework and rubric records, then consume them in educator rubric flow. |
| 3 | `/site/evidence-health` | aligned and reusable | Site leaders must see evidence coverage gaps from the same route chain, not generic operational totals. | Assert evidence-health reflects the canonical full-chain learner/educator records. |
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

Current status: **Work Package 1 is substantially started, not complete**. The route matrix exists and is pinned, and `functions/src/evidenceChainEmulator.test.ts` now proves the first server-side route chain boundary from verified proof to rubric growth to parent/passport output and site-health-readable evidence. The next pass must attach exact E2E/test file references to each route and implement browser coverage for the same cross-role evidence-chain proof using canonical synthetic data.