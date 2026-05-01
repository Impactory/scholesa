# Flutter/Mobile Route Proof Matrix - April 30, 2026

Current verdict: **mobile route coverage is mapped, but Flutter/mobile is not gold-ready yet**. This matrix classifies the current Flutter route registry and dashboard entry points against the evidence chain. A route being enabled in `kKnownRoutes` means it is routable, not that it is gold-certified.

Sources checked:

- `apps/empire_flutter/app/lib/router/app_router.dart`
- `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`
- `apps/empire_flutter/app/lib/services/firestore_service.dart`
- `apps/empire_flutter/app/lib/services/capability_growth_engine.dart`
- `apps/empire_flutter/app/lib/offline/offline_queue.dart`
- `apps/empire_flutter/app/lib/offline/sync_coordinator.dart`
- `apps/empire_flutter/app/test/`
- `./scripts/deploy.sh release-gate`

Classification key:

- **aligned and reusable**: real route, real persistence/service path, focused proof exists.
- **reusable with modification**: real route and useful implementation, but proof or workflow depth is incomplete.
- **partial**: route exists but evidence-chain certification is incomplete or indirect.
- **fake/stubbed**: route depends on placeholder/fake actions for the evidence-chain claim.
- **misaligned**: route presents completion/engagement as capability mastery.
- **missing entirely**: required evidence-chain route is absent.

## Evidence-Chain Routes

| Role | Route | Surface | Evidence function | Persistence/service path | Current proof | Classification | Blocker before mobile gold |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Learner | `/learner/today` | `LearnerTodayPage` | Communicate daily learner work and support state | learner/dashboard services, MiloOS runtime cards | `learner_today_page_test.dart`, `bos_insights_cards_test.dart` | reusable with modification | Needs small-screen classroom proof tied to current evidence actions. |
| Learner | `/learner/missions` | `MissionsPage` | Capture mission attempts, proof bundle fields, AI disclosure | `MissionService`, `missionAttempts`, `proofOfLearningBundles` | `missions_page_test.dart`, `mission_proof_bundle_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Include in final mobile release bundle and offline replay gate. |
| Learner | `/learner/checkpoints` | `CheckpointSubmissionPage` | Capture checkpoint evidence | `checkpointHistory`; offline `checkpointSubmit` path | `evidence_chain_routes_test.dart`, `evidence_chain_offline_queue_test.dart` | reusable with modification | Needs current focused UI proof and checkpoint mastery replay proof. |
| Learner | `/learner/reflections` | `ReflectionJournalPage` | Capture learner reflection evidence | `learnerReflections` / reflection repositories | `reflection_journal_page_test.dart` | reusable with modification | Needs route-level proof that reflections link to capability/portfolio surfaces. |
| Learner | `/learner/proof-assembly` | `ProofAssemblyPage` | Verify proof-of-learning | `proofOfLearningBundles`, mission proof summaries | `mission_proof_bundle_test.dart`, `evidence_chain_routes_test.dart` | reusable with modification | Needs small-screen proof assembly test and offline proof update replay. |
| Learner | `/learner/peer-feedback` | `PeerFeedbackPage` | Capture peer evidence/feedback | active-site `missionAttempts`, active-site `peerFeedback`, Firestore rules | `peer_feedback_page_test.dart`, `evidence_chain_routes_test.dart`, `test/firestore-rules.test.js` | aligned and reusable | Include in final route-level regression bundle. |
| Learner | `/learner/portfolio` | `LearnerPortfolioPage` | Communicate learner artifacts | portfolio item readers/writers | `learner_portfolio_honesty_test.dart` | reusable with modification | Needs current route proof that created items preserve evidence/proof provenance. |
| Learner | `/learner/credentials` | `LearnerCredentialsPage` | Communicate recognitions/credentials | active-site `credentials`, Firestore rules | `learner_credentials_page_test.dart`, `test/firestore-rules.test.js` | aligned and reusable | Include in final route-level regression bundle; credentials show issuer, evidence, portfolio, proof, growth, and rubric provenance. |
| Educator | `/educator/today` | `EducatorTodayPage` | Live class workflow and evidence context | session/roster/evidence services | `educator_today_page_test.dart`, `educator_live_session_mode_test.dart` | reusable with modification | Needs under-10-second mobile classroom evidence capture proof. |
| Educator | `/educator/sessions` | `EducatorSessionsPage` | Communicate session evidence coverage | sessions, attendance, evidence records | `educator_sessions_page_test.dart`, `site_sessions_page_test.dart` | reusable with modification | Needs site-scoped evidence coverage proof in final bundle. |
| Educator | `/educator/learners` | `EducatorLearnersPage` | Communicate learner support/progress | `EducatorService`, learner support data | `educator_learners_page_test.dart`, `educator_service_site_scope_test.dart` | reusable with modification | Needs current support/evidence provenance cross-check in route bundle. |
| Educator | `/educator/learner-supports` | `EducatorLearnerSupportsPage` | Communicate support provenance and follow-up debt | `learnerSupportPlans`, `learnerSupportOutcomes`, `interactionEvents` | `educator_learner_supports_page_test.dart`, `educator_learner_supports_route_gate_test.dart` | aligned and reusable | Include in final mobile classroom and release gates. |
| Educator | `/educator/missions/review` | `EducatorMissionReviewPage` | Verify submissions, create reviewed portfolio provenance | `MissionService`, `missionAttempts`, `evidenceRecords`, `portfolioItems`; server `applyRubricToEvidence` | `educator_mission_review_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Final bundle must still prove server-owned growth path, not local mastery writes. |
| Educator | `/educator/observations` | `ObservationCapturePage` | Capture educator observations | `evidenceRecords`; offline `observationCapture` | `evidence_chain_routes_test.dart`, `evidence_chain_offline_queue_test.dart` | reusable with modification | Needs live classroom small-screen proof and site-boundary proof. |
| Educator | `/educator/rubrics/apply` | `RubricApplicationPage` | Interpret evidence through rubric | `CapabilityGrowthEngine`, `applyRubricToEvidence` callable | `growth_engine_service_test.dart`, `evidence_chain_firestore_service_test.dart` | aligned and reusable | Needs offline replay gate and callable failure behavior in release bundle. |
| Educator | `/educator/proof-review` | `ProofVerificationPage` | Verify proof-of-learning | proof verification services and Firestore proof bundles | `evidence_chain_routes_test.dart` | reusable with modification | Needs focused proof-review persistence test. |
| Parent | `/parent/summary` | `ParentSummaryPage` | Communicate linked learner evidence summary | `ParentService`, `getParentDashboardBundle` fallback, report actions | `parent_summary_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Include in final release bundle with parent raw-event denial covered by rules/web tests. |
| Parent | `/parent/child/:learnerId` | `ParentChildPage` | Communicate passport, claims, family summary | `ParentService`, `ReportActions`, passport export/share | `parent_child_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Needs final bundle inclusion; export must keep provenance contract enforced. |
| Parent | `/parent/portfolio` | `ParentPortfolioPage` | Communicate reviewed portfolio artifacts | `ParentService`, `ReportActions`, support requests | `parent_portfolio_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Needs final bundle inclusion; no export without evidence provenance. |
| Parent | `/parent/growth-timeline` | `GrowthTimelinePage` | Communicate capability growth over time | `guardianLinks`, `capabilityGrowthEvents`, `capabilities` | `parent_growth_timeline_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Include in final route-level regression bundle. |
| Parent | `/parent/schedule` | `ParentSchedulePage` | Communicate linked schedule | linked enrollments/session occurrences | `parent_schedule_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Operational support route; include as guardian workflow dependency. |
| Site | `/site/dashboard` | `SiteDashboardPage` | Communicate implementation/support health | site metrics, KPI packs, recent activity, `interactionEvents` | `site_dashboard_page_test.dart` | aligned and reusable | Include in final mobile release and site-boundary gate. |
| Site | `/site/sessions` | `SiteSessionsPage` | Communicate site sessions | sessions/session occurrences | `site_sessions_page_test.dart`, `site_sessions_route_gate_test.dart` | reusable with modification | Needs evidence coverage linkage proof. |
| Site | `/site/provisioning` | `ProvisioningPage` | Trust/ops: user and guardian links | provisioning service, users, guardian links | `provisioning_page_test.dart`, `parent_surfaces_workflow_test.dart` | aligned and reusable | Include as setup dependency for parent workflow proof. |
| Site | `/site/checkin` | `CheckinPage` | Operational attendance/presence capture | `checkins`, attendance-ish presence records | `checkin_placeholder_actions_test.dart` | reusable with modification | Presence is not mastery; keep out of capability claims. |
| Site | `/site/ops` | `SiteOpsPage` | Operational site health | ops service/data | `site_ops_page_test.dart`, `site_ops_honesty_test.dart`, `site_ops_provisioning_workflow_test.dart` | reusable with modification | Needs evidence health tie-in if used for gold claims. |
| Site | `/site/incidents` | `SiteIncidentsPage` | Safety/trust workflow | incident records | `site_incidents_honesty_test.dart` | reusable with modification | Not a core evidence-chain route unless linked to safety/trust reporting. |
| Site | `/site/audit` | `SiteAuditPage` | Audit/trust output | audit/report services | `site_audit_page_test.dart` | reusable with modification | Needs release-bundle inclusion only for ops trust scope. |
| HQ | `/hq/curriculum` | `HqCurriculumPage` | Capability framework setup | curriculum/config services | `hq_curriculum_workflow_test.dart` | reusable with modification | Mobile HQ authoring is useful but web remains canonical for gold setup until deeper tests pass. |
| HQ | `/hq/capability-frameworks` | `CapabilityFrameworkPage` | Capability framework setup | active-site `capabilities` records | `hq_authoring_persistence_test.dart`, `evidence_chain_routes_test.dart`, `hq_curriculum_workflow_test.dart` | aligned and reusable | Include in final route-level regression bundle. |
| HQ | `/hq/rubric-builder` | `RubricBuilderPage` | Rubric setup | canonical active-site `rubricTemplates` records | `hq_authoring_persistence_test.dart`, `evidence_chain_routes_test.dart`, `hq_curriculum_workflow_test.dart` | aligned and reusable | Needs later capability-binding UX depth, but canonical persistence is now proven. |
| HQ | `/hq/analytics` | `HqAnalyticsPage` | Communicate platform evidence/ops health | analytics/report services | `hq_analytics_page_test.dart` | reusable with modification | Ensure analytics do not present completion as mastery. |
| HQ | `/hq/audit` | `HqAuditPage` | Audit/trust output | audit services | `hq_audit_page_test.dart` | reusable with modification | Include only in ops release bundle, not capability mastery proof. |
| Partner | `/partner/deliverables` | `PartnerDeliverablesPage` | External evidence-facing deliverables | `partnerContracts`, `partnerDeliverables`, audit logs, Firestore rules | `partner_deliverables_page_test.dart`, `partner_contracting_workflow_test.dart`, `test/firestore-rules.test.js` | aligned and reusable | Include in final route-level regression bundle; partner deliverables carry partner/site/contract/evidence provenance. |

## Operational Routes

These routes are enabled and useful, but they are not sufficient evidence-chain proof by themselves.

| Role | Routes | Current proof | Classification | Notes |
| --- | --- | --- | --- | --- |
| Learner | `/learner/habits`, `/learner/settings` | `habits_page_test.dart`, settings tests | reusable with modification | Habits/settings must not be presented as capability mastery. |
| Educator | `/educator/attendance`, `/educator/mission-plans`, `/educator/integrations` | `attendance_route_gate_test.dart`, `educator_mission_plans_page_test.dart`, `educator_integrations_page_test.dart` | reusable with modification | Attendance and integrations support workflows; they are not mastery signals. |
| Parent | `/parent/billing`, `/parent/consent`, `/parent/messages`, `/parent/settings` | `parent_billing_page_test.dart`, `parent_consent_page_test.dart`, messages/settings tests | aligned and reusable for ops | Consent matters for trust, but billing/messages are not evidence-chain proof. |
| Site | `/site/identity`, `/site/pickup-auth`, `/site/consent`, `/site/integrations-health`, `/site/billing` | route/page tests exist for identity, integrations, billing, pickup, consent | reusable with modification | Operational trust surfaces; include only when release scope includes ops readiness. |
| HQ | `/hq/user-admin`, `/hq/role-switcher`, `/hq/sites`, `/hq/billing`, `/hq/approvals`, `/hq/safety`, `/hq/exports`, `/hq/integrations-health`, `/hq/feature-flags` | page/route tests exist | reusable with modification | HQ ops routes are real but not direct learner evidence-chain proof. |
| Partner | `/partner/listings`, `/partner/contracts`, `/partner/integrations`, `/partner/payouts` | partner page/workflow tests exist | reusable with modification | Operational partner surfaces; evidence-facing deliverable trust is certified separately. |
| Cross-role | `/messages`, `/notifications`, `/profile`, `/settings` | messages/profile/settings tests exist | aligned and reusable for ops | Shared support surfaces; not capability proof. |

## Missing Or Partial Gold Proof

1. **Offline evidence chain gate** passed after this matrix via the Milestone 3 bundle: 46 focused offline/growth tests and focused analyzer on growth, Firestore, mission, and sync files.
2. **Mobile classroom ergonomics gate** passed after this matrix via phone-width learner mission submission, educator quick evidence capture, educator support, site support health, and dashboard overflow tests.
3. **Non-deploying release script gate** passed after route-level blocker closure via `./scripts/deploy.sh release-gate`, covering root typecheck/lint/Jest, Firestore rules and evidence-chain integration in one emulator session, Functions build/verify and split tests, full Flutter analyze/test, and diff hygiene.
4. **Role permission and site-boundary review** passed after this matrix via 50 focused Flutter boundary tests and 118 Firestore rules integration tests after peer-feedback, partner deliverable, and credential provenance boundary coverage was added.
5. **Focused Flutter/mobile release bundle** passed after this matrix via 133 Flutter tests, full Flutter analyzer, 187-test source contract, 118-test Firestore rules integration, and diff hygiene. Current-worktree full `flutter test` now passes 1075 tests, and full app-scoped `flutter analyze` reports no issues.
6. **Direct parent growth timeline route proof** passed after this matrix via `parent_growth_timeline_page_test.dart`, proving linked learner growth provenance while excluding unlinked learner growth.
7. **Mobile HQ authoring persistence** passed after this matrix via `hq_authoring_persistence_test.dart`, proving active-site capability creation and canonical active-site `rubricTemplates` creation while excluding other-site authoring data.
8. **Peer-feedback persistence and role-safety proof** passed after this matrix via `peer_feedback_page_test.dart` and 114 Firestore rules tests, proving same-site peer review capture, author-owned writes, and cross-site/missing-site denial.
9. **Partner deliverable evidence output trust** passed after this matrix via `partner_deliverables_page_test.dart`, `partner_contracting_workflow_test.dart`, and 116 Firestore rules tests, proving partner/site/contract/evidence provenance and blocking partner self-acceptance.
10. **Learner credential evidence provenance** passed after this matrix via `learner_credentials_page_test.dart` and 118 Firestore rules tests, proving source evidence, issuer, learner ownership, site scoping, portfolio/proof/growth/rubric links, and evidence-required issuance.
11. **Flutter `/learner/miloos` route parity** passed after this matrix via `test/web-route-parity.test.ts` and `test/workflow-security-contract.test.ts`; Flutter now registers/routes the learner support surface, and the web workflow data loader calls `bosGetLearnerLoopInsights` for support-loop provenance.

## Next Gate

Proceed to approved live or no-traffic deploy rehearsal reproducibility. Do not call Flutter/mobile gold-ready until the current-worktree live or `CLOUD_RUN_NO_TRAFFIC=1` rehearsal is clean. The latest failed `./scripts/deploy.sh all` stopped at Flutter tests; current full Flutter tests/analyzer, root tests, production build, Firestore rules, Functions gates, and `./scripts/deploy.sh release-gate` now pass locally, and `deploy_all` now runs the Flutter gate before live deploy actions.
