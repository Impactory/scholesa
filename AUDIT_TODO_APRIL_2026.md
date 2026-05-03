# Scholesa Capability-First Audit — April 2, 2026 (updated 2026-04-30)

> Comprehensive audit of every major route, component, schema, and workflow against Scholesa's capability-first evidence model.
> Classifies each item as: aligned and usable / reusable with modification / misleading / LMS-shaped / fake / disconnected / missing.

---

## FINAL RECOMMENDATION: ⚠️ PLATFORM BETA-READY; MILOOS WEB + FOCUSED FLUTTER/MOBILE GOLD-CANDIDATE GATE PASSED

**The core evidence chain is real and materially stronger, but Scholesa is not yet gold-ready.** Recent work tightened the proof boundary, preserved canonical portfolio provenance through rubric application, fixed proof-linked checkpoint growth dead-ends, reused canonical portfolio items during live observation rubric review, taught the learner timeline to back-link direct evidence-triggered growth, promoted proof bundles into standalone learner timeline entries, verified the live educator/learner evidence surfaces on phone-width web viewports, made learner/guardian evidence-bearing report share/export paths fail closed when expected provenance is missing, added explicit audience/visibility share-safety policies to those enforced report deliveries, introduced a server-owned `reportShareRequests` lifecycle with expiry/revocation callables that blocks external/partner/public sharing until explicit consent workflow support exists, wired web plus Flutter completed report deliveries to create share-request records linked to durable audit logs, and hardened MiloOS learner support so `genAiCoach`, `submitExplainBack`, the global MiloOS dock, the governed `/learner/miloos` workflow, and live learner dashboard support snapshot enforce active site scope, dual-stamp learner-loop events, preserve legacy timestamp fallback, behaviorally assemble learner-loop insight state/events/goals/MVL counts, expose opened-help/explain-back/pending support-journey gaps on web and Flutter without calling them mastery, refresh callable-backed learner-loop snapshots after coach and explain-back writes, keep readable response transcripts visible on the full learner screen and global popup when audio is unavailable, surface site-scoped educator AI audit summaries for opened/used/pending explain-back support events without mastery claims, emulator-verify persisted `genAiCoach` → `submitExplainBack` → `bosGetLearnerLoopInsights` journeys that do not write capability mastery, and now exercise a configured internal-inference `genAiCoach` path through the internal-only egress guard. However, unified publish/share workflow parity is still incomplete, legacy compatibility remains visible, and several workflows remain partial rather than gold-certified.

**MiloOS gold-readiness planning files**: `docs/MILOOS_GOLD_READINESS_PLAN_APRIL_30_2026.md` defines the gates and `docs/MILOOS_GOLD_READINESS_EXECUTION_CHECKLIST_APRIL_30_2026.md` gives the ordered execution checklist. The scoped MiloOS web plus focused Flutter/mobile support-provenance gate has passed; the broader Scholesa platform remains beta-ready, not blanket gold-ready.

**Flutter/mobile gold-readiness planning files**: `docs/FLUTTER_MOBILE_GOLD_READINESS_PLAN_APRIL_30_2026.md` defines the broader mobile attack plan and `docs/FLUTTER_MOBILE_GOLD_READINESS_EXECUTION_CHECKLIST_APRIL_30_2026.md` gives the milestone checklist. Guardian/report workflow stabilization now passes via `parent_surfaces_workflow_test.dart`, `docs/FLUTTER_MOBILE_ROUTE_PROOF_MATRIX_APRIL_30_2026.md` now classifies the current Flutter route registry, dashboard cards, persistence paths, proof files, and blockers, the focused offline evidence-chain gate passed with 46 Flutter tests plus focused analyzer, the mobile classroom ergonomics gate passed after phone-width learner/educator evidence workflow fixes, the role permission/site-boundary gate passed with focused Flutter boundary tests plus Firestore rules integration, the focused Flutter/mobile release bundle passed with 133 Flutter tests, full `flutter analyze`, the 187-test source contract, 118 Firestore rules tests, and `git diff --check`, direct parent growth-timeline route proof now passes via `parent_growth_timeline_page_test.dart`, mobile HQ capability/rubric authoring persistence now passes via `hq_authoring_persistence_test.dart`, peer-feedback persistence/role safety now passes via `peer_feedback_page_test.dart` plus Firestore rules coverage, partner deliverable evidence output trust now passes via `partner_deliverables_page_test.dart`, `partner_contracting_workflow_test.dart`, and Firestore rules coverage, learner credential evidence provenance now passes via `learner_credentials_page_test.dart` plus Firestore rules coverage, Flutter `/learner/miloos` route parity now passes with callable-backed web workflow loading, current-worktree full `flutter test` now passes 1075 tests with full app-scoped `flutter analyze` clean, root `npm test` plus production `npm run build` now pass, and the non-deploying `./scripts/deploy.sh release-gate` passes from the current worktree with emulator-backed rules/evidence tests in one Firestore emulator session. The full `./scripts/deploy.sh all` target now runs the Flutter gate before live deploy actions, and the approved 2026-05-03 `CLOUD_RUN_NO_TRAFFIC=1` web rehearsal created ready 0-traffic primary web and Flutter web revisions without moving production traffic. This is a validated release-bundle pass plus targeted route-gap closure and deploy rehearsal, not a blanket platform gold claim.

**MiloOS gold-readiness progress**: Milestone 1 is complete. `PageTransition` now uses native reduced-motion detection after mount so protected MiloOS routes avoid the reduced-motion hydration mismatch and Framer warning while preserving reduced-motion accessibility. Focused MiloOS WCAG and protected-route browser suites pass after the fix.

**MiloOS permission progress**: Milestone 2 is complete. Firestore rules tests now prove linked and unlinked parents cannot read raw MiloOS `interactionEvents` documents or site queries directly, while the server-owned parent bundle and guardian browser route still expose linked learner support provenance without mastery claims.

**MiloOS cross-role progress**: Milestone 3 is complete. A single browser E2E now drives learner help, educator pending-debt visibility, returned learner explain-back completion, guardian support provenance, and site support health without `capabilityMastery` writes. Learner-loop insights now expose pending support interaction IDs so a learner can return to `/learner/miloos` and complete prior pending explain-back verification.

**MiloOS mobile progress**: Milestone 4 is complete. A phone-width browser E2E now proves the learner MiloOS prompt/transcript/explain-back controls, educator follow-up debt card, and site support health tiles remain usable without horizontal overflow.

**MiloOS keyboard progress**: Milestone 5 is complete. A keyboard-only browser E2E now proves the learner can tab through MiloOS mode selection, submit a question, land on the explain-back input, submit verification, and retain focus on the live status message.

**MiloOS observability progress**: Milestone 6 is complete. MiloOS support-turn events now carry joinable opened-event trace metadata across opened, used, response, and explain-back records; emulator-backed tests prove pending explain-back derivation and no support-only mastery writes.

**MiloOS synthetic-state progress**: Milestone 7 is complete. The canonical synthetic importer now creates `syntheticMiloOSGoldStates/latest` plus no-support, pending explain-back, support-current, cross-site denial, and missing-site denial learner states in every seed mode without writing support-only mastery or growth.

**MiloOS Flutter/mobile scope**: Milestone 8 is complete. Focused Flutter/mobile MiloOS role parity now covers learner-loop support journey cards, educator per-learner support provenance/pending explain-back debt, and Admin-School same-site support health from persisted `interactionEvents`, with widget tests and analyzer proof. Broader Flutter workflows remain beta outside this tested MiloOS support-provenance slice.

**MiloOS final gate**: Milestone 9 is complete. The web MiloOS gold-candidate release bundle and focused Flutter/mobile support-provenance gate passed on 2026-04-30. Commands run: `npm run typecheck -- --pretty false`; `npm run lint`; `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/evidence-chain-components.test.ts src/__tests__/miloos-ai-coach-screen.test.tsx src/__tests__/miloos-learner-support-snapshot.test.tsx src/__tests__/educator-ai-audit-miloos-provenance.test.tsx test/synthetic_miloos_gold_states.test.js`; `npm --prefix functions test -- aiHelpWording.test.ts bosRuntimeHonesty.test.ts`; `npm --prefix functions run build`; `npm run test:integration:rules`; `npm run test:integration:evidence-chain`; `npx playwright test --config playwright.config.ts test/e2e/miloos-learner-loop.e2e.spec.ts test/e2e/miloos-educator-support-provenance.e2e.spec.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts test/e2e/miloos-site-support-health.e2e.spec.ts test/e2e/miloos-accessibility.e2e.spec.ts test/e2e/miloos-cross-role-golden-path.e2e.spec.ts test/e2e/miloos-mobile-classroom.e2e.spec.ts test/e2e/miloos-keyboard.e2e.spec.ts`; `npm run seed:synthetic-data:dry-run`; `cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart test/educator_learner_supports_page_test.dart test/site_dashboard_page_test.dart`; `cd apps/empire_flutter/app && flutter analyze`; `git diff --check`.

**MiloOS release reproducibility update**: On 2026-05-01, `./scripts/deploy.sh release-gate` passed from the current worktree after the gate was hardened to run Firestore rules and evidence-chain integration inside one emulator session and to run the Flutter gate before live deploy actions in `deploy_all`. This strengthens the scoped MiloOS gold-candidate release proof without turning the broader platform into gold-ready.

**MiloOS no-traffic deploy rehearsal update**: On 2026-05-03, `CLOUD_RUN_NO_TRAFFIC=1 IMAGE_TAG=rehearsal-20260503-081143 ./scripts/deploy.sh web` passed against `studio-3328096157-e3f79`. Cloud Run created ready 0-traffic revisions `scholesa-web-00040-qpw` and `empire-web-00072-fw6`; service traffic stayed on `scholesa-web-00038-fvt` and `empire-web-00071-6mx`. This closes the deploy-rehearsal blocker for the validated MiloOS/Flutter-web release slice while preserving the broader platform beta boundary.

**MiloOS final signoff**: MiloOS creates support/provenance evidence (`ai_help_opened`, `ai_help_used`, `ai_coach_response`, `explain_it_back_submitted`), lets learners/educators/guardians/site leaders observe the right scoped summaries on web, adds focused Flutter/mobile learner/educator/site support-provenance parity, verifies authenticity through explain-back linked to the support turn, and keeps support separate from mastery by never writing support-only `capabilityMastery` or `capabilityGrowthEvents`. Broader platform and broader Flutter workflows remain beta.

| Metric | Value |
|--------|-------|
| Web routes | 70 total app routes per current Next.js build; 63 protected workflow paths in `workflowRoutes.ts` (30 dedicated custom-rendered evidence surfaces + 33 generic workflow routes) |
| Schema types | 75 exported interfaces |
| Firestore collections (typed web) | 53 |
| Firestore rules collections | 136 |
| Cloud Functions | 65 exported |
| Gold workflows verified | Not blanket-certified |
| P0 blockers | Gold-blocking gaps remain |
| P1 systems needed (GA credibility) | 6 |
| TypeScript | Clean (exit 0) |
| Jest (web) | 32 suites, 480/480 pass |
| Next.js build | 70 routes, exit 0 |
| Functions tests | 33 suites, 127/127 pass |
| Flutter tests | 318+ pass, 0 fail |

---

## §1. ROUTE INVENTORY AND GOLD-CRITICAL CLASSIFICATION (70 total app routes / 63 protected workflow paths)

The full live route inventory is maintained in `docs/ROUTE_MODULE_MATRIX.md`. This audit section classifies the gold-gate custom evidence slice and the remaining workflow buckets rather than pretending the smaller tables below are the whole registry.

### 1A. Gold-Gate Custom Evidence Route Slice (10 of 30 dedicated evidence surfaces)

| Route | Component | Role | Cap Track | Evidence | Portfolio | Rubric | PoL | AI Trans | Growth | Profile Gen |
|-------|-----------|------|-----------|----------|-----------|--------|-----|----------|--------|-------------|
| `/learner/today` | LearnerDashboardToday | learner | ✅ | ✅ | ref | — | — | — | ✅ | — |
| `/learner/miloos` | LearnerMiloOSRenderer | learner | — | support provenance | — | — | ✅ | ✅ | — | — |
| `/educator/today` | EducatorDashboardToday | educator | ✅ | ✅ | — | — | — | — | ✅ | — |
| `/educator/evidence` | EducatorEvidenceCapture | educator | ✅ | ✅ | flows→ | — | ✅ | — | ✅ | — |
| `/educator/verification` | ProofOfLearningVerification | educator | ✅ | ✅ | flows→ | — | ✅ | — | ✅ | — |
| `/learner/portfolio` | LearnerPortfolioBrowser + LearnerEvidenceSubmission | learner | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | — |
| `/parent/summary` | GuardianCapabilityViewRenderer | parent | ✅ | ✅ | ✅ | — | — | — | ✅ | — |
| `/parent/passport` | GuardianPassportRenderer | parent | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| `/site/evidence-health` | SiteEvidenceHealthDashboard | site | ✅ | ✅ | — | — | — | — | — | — |
| `/hq/capabilities` | CapabilityFrameworkEditor | hq | ✅ | — | — | ✅ | — | — | — | — |

**Classification: ALIGNED AND USABLE** — These 10 routes are the gold-gate slice inside the larger 30-route custom evidence surface set. Each connects to real Firestore or callable-backed data and serves the evidence chain.

### 1B. Remaining Workflow Route Buckets

#### Learner Operational Remainder
| Route | Data Source | Classification | Notes |
|-------|------------|----------------|-------|
| `/learner/missions` | `missionAttempts` collection | **Reusable with modification** | CRUD list of mission attempts; no capability binding in UI. Could add capability tags. |

`/learner/habits` now renders through a dedicated `LearnerHabitsRenderer` backed by persisted `habits` and `habitLogs` documents. It is operationally real and end-to-end for learner routine tracking, but it intentionally stays separate from capability mastery claims.

#### Educator Operational Remainder
| Route | Data Source | Classification | Notes |
|-------|------------|----------------|-------|
| `/educator/sessions` | `sessions` collection | **Operational (aligned)** | Session scheduling supports evidence chain by creating session context. |
| `/educator/attendance` | `attendanceRecords` collection | **Operational (aligned)** | Attendance ≠ mastery, but required for studio operations. |
| `/educator/learners` | `users`, `aiInteractionLogs`, `interactionEvents` collections | **Operational with support provenance** | Roster + AI audit now summarizes site-scoped MiloOS support/explain-back gaps, but still no full learner profile synthesis. |
| `/educator/missions/review` | `missionAttempts` collection | **Aligned and reusable** | Review queue now embeds rubric assessment, preserves linked `portfolioItemId` when present, and writes through the canonical callable path. |
| `/educator/mission-plans` | `missions` collection | **Reusable with modification** | Mission authoring but not mapped to capability sequencing. |
| `/educator/learner-supports` | `learnerSupports` collection | **Operational** | Intervention tracking. Not capability-informed. |
| `/educator/integrations` | callable | **Operational** | External system connections (Clever, LTI). |

#### Parent Operational Remainder
| Route | Data Source | Classification | Notes |
|-------|------------|----------------|-------|
| `/parent/portfolio` | `portfolioItems` collection | **Reusable with modification** | CRUD list; no capability mapping in parent view. Could show capability tags. |
| `/parent/billing` | callable | **Operational** | Billing/subscriptions. Not evidence-related. |
| `/parent/schedule` | `sessionOccurrences` collection | **Operational** | Calendar visibility. |

#### Site Admin Operational Remainder
| Route | Classification | Notes |
|-------|----------------|-------|
| `/site/dashboard` | **Operational** | Daily site overview. |
| `/site/sessions` | **Operational** | Session configuration and staffing. |
| `/site/checkin` | **Operational** | Arrival/departure logging. |
| `/site/ops` | **Operational** | Daily events, site health. |
| `/site/incidents` | **Operational** | Incident lifecycle management. |
| `/site/identity` | **Operational** | Identity reconciliation. |
| `/site/clever` | **Operational** | Roster sync integration. |
| `/site/provisioning` | **Operational** | User linking and onboarding. |
| `/site/integrations-health` | **Operational** | Integration health monitoring. |
| `/site/billing` | **Operational** | Billing ops. |

#### HQ Admin Operational Remainder
| Route | Classification | Notes |
|-------|----------------|-------|
| `/hq/sites` | **Operational** | Network site management. |
| `/hq/user-admin` | **Operational** | User administration. |
| `/hq/curriculum` | **Reusable with modification** | Curriculum admin; could link to capability framework. |
| `/hq/analytics` | **Operational** | Platform KPIs (not capability-scoped). |
| `/hq/approvals` | **Operational** | Content approval workflows. |
| `/hq/audit` | **Operational** | Audit log viewer. |
| `/hq/safety` | **Operational** | Safety controls / COPPA. |
| `/hq/billing` | **Operational** | Revenue ops. |
| `/hq/integrations-health` | **Operational** | Integration monitoring. |
| `/hq/feature-flags` | **Operational** | Feature flag management. |
| `/hq/role-switcher` | **Dev tool** | Role simulation for testing. |

#### Partner (5 routes)
| Route | Classification | Notes |
|-------|----------------|-------|
| `/partner/listings` | **Operational** | Marketplace listings. |
| `/partner/contracts` | **Operational** | Contract lifecycle. |
| `/partner/deliverables` | **Operational** | Submission tracking. |
| `/partner/integrations` | **Operational** | External integrations. |
| `/partner/payouts` | **Operational** | Payout reconciliation. |

### 1C. Auth & Infrastructure Routes (12)
| Route | Classification |
|-------|----------------|
| `/login` | **Aligned** — Firebase Auth + enterprise SSO |
| `/register` | **Aligned** — Role selection on signup |
| `/dashboard` | **Aligned** — Role-based redirect |
| `/notifications` | **Operational** |
| `/messages` | **Operational** |
| `/profile` | **Operational** |
| `/settings` | **Operational** |
| 5 legacy redirects | **Deprecated** — `/learner` → `/learner/today`, etc. |

### 1D. API Routes (6)
| Endpoint | Classification | Notes |
|----------|----------------|-------|
| `POST /api/ai/complete` | **Aligned** | Internal-only AI inference with guardrails. |
| `POST /api/auth/session-login` | **Infrastructure** | Session cookie + SSO profile sync. |
| `POST /api/auth/session-logout` | **Infrastructure** | Session cleanup. |
| `GET /api/auth/sso/providers` | **Infrastructure** | SSO provider discovery. |
| `POST /api/lti/launch` | **Operational** | LTI 1.3 deep linking. |
| `GET /api/healthz` | **Infrastructure** | Build tag + dependency health. |

---

## §2. FULL SCHEMA CLASSIFICATION (69 interfaces)

### 2A. Core Evidence Chain (Aligned)
| Type | Purpose | Supports |
|------|---------|----------|
| `Capability` | Pillar-scoped capability with progressionDescriptors, checkpointMappings | Cap track, Growth |
| `CapabilityMastery` | Learner's current + highest level per capability | Growth, Profile |
| `CapabilityGrowthEvent` | Append-only level change record | Growth |
| `ProcessDomain` | Cross-cutting skill (collaboration, thinking) | Cap track |
| `ProcessDomainMastery` | Learner's mastery per process domain | Growth |
| `ProcessDomainGrowthEvent` | Append-only domain level change | Growth |
| `EvidenceRecord` | Educator observation with provenance | Evidence |
| `RubricTemplate` + `RubricTemplateCriterion` | HQ-authored rubric criteria→capability mapping | Rubric |
| `RubricApplication` | Applied rubric scores per evidence bundle | Rubric |
| `PortfolioItem` | Artifact/reflection/checkpoint with AI disclosure, PoL status | Portfolio, AI trans, PoL |
| `LearnerReflection` | Reflection cross-linked to portfolio | Portfolio, Evidence |
| `MissionAttempt` | Student checkpoint submission | Evidence |
| `Badge` + `BadgeAward` | Evidence-backed badge credentials | Profile |
| `Checkpoint` + `SprintSession` | Fast-feedback classroom cycles | Evidence |
| `ShowcaseSubmission` | Public artifact presentation | Portfolio |

### 2B. Operational (Aligned, not evidence-producing)
| Type | Purpose |
|------|---------|
| `User` + `UserProfile` | Identity, role, siteIds |
| `Site` | School configuration |
| `Session` + `SessionOccurrence` | Class scheduling |
| `Enrollment` + `AttendanceRecord` | Participation tracking |
| `Mission` | Learning activity definition |
| `Program` + `Course` | Curriculum structure |
| `Incident` | Safety/behavioral log |
| `LearnerSupport` | Intervention tracking |
| 20+ billing, integration, notification types | Platform operations |

### 2C. Misleading / LMS-Shaped (Legacy, inactive)
| Type | Issue | Risk |
|------|-------|------|
| `AccountabilityKPI` | `attendancePct` + `missionsCompleted` presented as `pillarScores` | **Conflates completion with capability mastery.** Not used by any active component under `src/` — legacy only (root-level `LearnerSummaryCard.tsx`, `PillarProgress.tsx`, `SiteStats.tsx`). |
| `ParentSnapshot` | `skillsImproved: string[]` with no evidence links, `missionsCompleted` + `badgesEarned` as stats | **Fake skill claims without provenance.** Only referenced in documentation. Superseded by `getParentDashboardBundle` callable. |

### 2D. Engagement (Not Evidence)
| Type | Purpose | Classification |
|------|---------|----------------|
| `LearnerMotivationProfile` | Engagement tracking (autonomy, mastery signals) | **Reusable** — tracks motivation, not capability |
| `LearnerInteraction` | App behavior telemetry | **Operational** — analytics, not evidence |
| `MotivationNudge` | Gamification nudges | **Operational** — engagement, not mastery |

### 2E. Missing from Schema
| Gap | Impact |
|-----|--------|
| No `LearnerCapabilityProfile` synthesis type | No composite type aggregating full capability profile from evidence. Data exists across `CapabilityMastery` + `ProcessDomainMastery` + `PortfolioItem` but no single view type. |

---

## §3. CLOUD FUNCTIONS CLASSIFICATION (63 exports)

### 3A. Evidence Chain Functions (Aligned)
| Function | Purpose |
|----------|---------|
| `applyRubricToEvidence` | Educator rubric → RubricApplication + CapabilityGrowthEvent + CapabilityMastery + ProcessDomainGrowthEvent + ProcessDomainMastery, while preserving canonical `portfolioItemId` provenance when supplied |
| `verifyProofOfLearning` | PoL verification authenticity boundary → proof state + proof bundle + canonical linkage updates, returns `capabilitiesReadyForRubric` (no direct growth write) |
| `getParentDashboardBundle` | Aggregates all evidence data for parent/passport views |
| `bosScoreMvl` + `bosSubmitMvlEvidence` | Minimal viable learning evidence submission (BOS runtime) |
| `genAiCoach` | Internal AI inference with COPPA grade-band gating and learner site-access enforcement before interaction audit writes |

### 3B. Operational Functions (32+)
Session management, billing, Clever sync, LTI, user admin, telemetry, incident ops, notification dispatch, etc. All real, none stubbed.

### 3C. Engagement Functions (Not Capability)
| Function | Classification |
|----------|----------------|
| `computeMotivationSignals` | **Reusable** — tracks engagement signals |
| `generateMotivationNudges` | **Reusable** — nudge generation |
| `logTelemetryEvent` | **Operational** — app analytics |
| `getLearnerMotivationProfile` | **Reusable** — motivation state |

---

## §4. FIRESTORE COLLECTIONS CLASSIFICATION

### 4A. Typed Web Collections (52)
All 52 collection references in `src/firebase/firestore/collections.ts` are TypeScript-typed. Includes all evidence chain collections plus the top-priority P1-F web refs for `showcaseSubmissions`, `peerFeedback`, `learnerProfiles`, and `recognitionBadges`.

### 4B. Rules-Only Collections (~89 additional)
135 total collection rules minus 52 typed = ~83 collections that exist in `firestore.rules` but have no typed web collection reference. Used by Flutter mobile client (Dart models), Firebase Functions (admin SDK), and BOS/MIA runtime services.

### 4C. Security Model
| Layer | Status |
|-------|--------|
| Site-scoping | ✅ All evidence/session/enrollment collections scoped by `siteId` |
| Role checks | ✅ `isHQ()`, `isEducator()`, `isSiteLead()`, ownership via `userId == auth.uid` |
| Learner read-own | ✅ Mastery, growth events, portfolio items, reflections |
| Parent read-linked | ✅ Via `isParentLinkedToLearner()` helper |
| Default-deny | ✅ Unlisted collections blocked |
| Server-only writes | ✅ Billing, telemetry aggregates, feature flags |

---

## §5. EIGHT-DIMENSION MATRIX

| System | Cap Track | Evidence | Portfolio | Rubric | PoL | AI Trans | Growth | Profile |
|--------|-----------|----------|-----------|--------|-----|----------|--------|---------|
| **HQ Capability Framework** | ✅ | — | — | ✅ | — | — | — | — |
| **Educator Evidence Capture** | ✅ | ✅ | flows→ | — | ✅ | — | ✅ | — |
| **Learner Evidence Submission** | ✅ | ✅ | ✅ | — | — | ✅ | — | — |
| **Rubric Review + Apply** | ✅ | ✅ | — | ✅ | — | — | ✅ | — |
| **Proof-of-Learning Verification** | ✅ | ✅ | ✅ | — | ✅ | — | ✅ | — |
| **Capability Growth Engine** | ✅ | — | — | — | — | — | ✅ | — |
| **Portfolio Browser** | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | — |
| **Learner Dashboard** | ✅ | — | ref | — | — | — | ✅ | — |
| **Educator Dashboard** | ✅ | ✅ | — | — | — | — | ✅ | — |
| **Parent Summary** | ✅ | ✅ | ✅ | — | — | — | ✅ | — |
| **Ideation Passport** | ✅ | ✅ | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| **Site Evidence Health** | ✅ | ✅ | — | — | — | — | — | — |
| **Sessions / Attendance** | — | — | — | — | — | — | — | — |
| **Missions (CRUD)** | — | partial | — | — | — | — | — | — |
| **Billing / Ops / Partner** | — | — | — | — | — | — | — | — |

**Coverage**: 12/15 major systems touch capability tracking. 10/15 touch evidence. The 3 that don't (sessions, missions CRUD, billing/ops) are operational scaffolding.

---

## §6. P0 BLOCKERS TO CAPABILITY-FIRST LAUNCH

Gold blockers remain. The evidence chain is connected more truthfully than the April 2 snapshot, but not all workflows are gold-certified end to end:

```
HQ defines capabilities + rubrics + process domains
  → Educator runs session + logs observation (<10s)
    → Learner submits artifact/reflection/checkpoint + AI disclosure
      → Educator verifies proof-of-learning where authenticity is required
        → Educator applies rubric on the same canonical portfolio item (4-level, capabilities + process domains)
          → Growth engine: atomic batch / checkpoint callable → CapabilityGrowthEvent → CapabilityMastery update
            → Portfolio: browsable with verification status + AI badges
              → Passport: evidence-backed claims + growth timeline + export
                → Parent: per-learner capability bands + growth + portfolio highlights
```

Recent educator-side fixes closed three live gaps in the chain:
- verified proof now hands off into rubric application on the same portfolio item
- mission review now preserves canonical artifact provenance during rubric application
- proof-linked checkpoints now stay visible as `pending_proof` until growth can be recorded truthfully

Remaining gold blockers now sit mainly in communication/read-side parity rather than missing write paths.

---

## §7. P1 SYSTEMS NEEDED FOR CREDIBILITY (GA, not blocking launch)

### P1-A. Learner Profile Synthesis — ✅ DONE
- **Gap**: No single type that synthesizes a learner's full capability profile.
- **Fix**: Added `LearnerCapabilityProfile` composite type to `schema.ts` — aggregates `CapabilityMastery[]`, `ProcessDomainMastery[]`, pillar summaries, growth events, and portfolio highlights.
- **Next**: Build query-time assembly function and optional route.

### P1-B. Mission → Capability Binding in UI — ✅ DONE
- **Gap**: Missions CRUD showed no capability context.
- **Fix**: `MissionAttempt` schema now has `capabilityIds` and `pillarCodes` fields. Creation copies from `Mission`. CRUD views resolve and display capability titles via `enrichRecordsWithCapabilityTitles()`.

### P1-C. Educator Mission Review → Rubric Integration — ✅ DONE
- **Gap**: `/educator/missions/review` showed mission submissions as a CRUD list but could not apply rubrics canonically.
- **Fix**: Mission review now renders rubric assessment inline, enriches attempts with linked `portfolioItemId`, and forwards that canonical artifact identity into `applyRubricToEvidence` so rubric growth does not fork provenance away from verified work.

### P1-D. Parent Portfolio Capability Mapping — ✅ DONE
- **Gap**: Parent portfolio items showed no capability tags.
- **Fix**: Parent portfolio records now enriched with resolved capability titles via `enrichRecordsWithCapabilityTitles()`. Data from `PortfolioItem.capabilityIds`.

### P1-E. AccountabilityKPI + ParentSnapshot Deprecation — ✅ DONE
- **Gap**: Legacy types conflating completion with mastery.
- **Fix**: Both types marked `@deprecated` in `schema.ts` with JSDoc explaining the issue and pointing to evidence-backed alternatives.

### P1-F. Untyped Collections Registry — ✅ TOP-PRIORITY WEB REFS DONE
- **Gap**: ~89 Firestore collections have rules but no typed web collection reference. Used by Flutter/Functions but invisible to web.
- **Fix**: Added typed refs in `src/firebase/firestore/collections.ts` for `recognitionBadges`, `showcaseSubmissions`, `peerFeedback`, and `learnerProfiles`; reconciled active web writes/reads in showcase, peer feedback, learner profile provisioning, and motivation recognition paths.
- **Validation**: `npx tsc --noEmit --pretty false --incremental false`; `npm test -- --runTestsByPath src/__tests__/evidence-chain-components.test.ts` (139/139 pass).
- **Residual risk**: `recognitionBadges` is still semantically overloaded by legacy belonging recognition records and evidence-based badge definitions. The typed web ref closes the immediate untyped-access gap; a future data-model cleanup should split peer recognition from badge definitions instead of expanding this collection further.

### P1-G. Mobile Viewport QA for Evidence Capture — ✅ DONE
- **Gap**: Educator live evidence capture and learner evidence submission had no browser-level phone viewport coverage, so the 10-second classroom workflow could regress without detection.
- **Fix**: Added focused Playwright mobile coverage for `/educator/evidence` and `/learner/missions`; restored the root mobile viewport metadata and Tailwind utility layers so responsive classes actually apply in browser rendering; hardened evidence capture/submission status rows and learner submission tabs for narrow screens.
- **Validation**: `npx playwright test --config playwright.config.ts test/e2e/mobile-evidence-workflows.e2e.spec.ts` (2/2 pass, no SSO/telemetry/i18n missing-key noise); `npx tsc --noEmit --pretty false --incremental false`; `npm test -- --runTestsByPath src/__tests__/enterprise-sso.test.ts src/__tests__/e2e-infrastructure-noise.test.ts src/__tests__/navigation-signout-availability.test.ts` (11/11 pass).
- **E2E infrastructure cleanup**: Explicit fake-mode SSO provider discovery returns an empty provider list without requiring Firebase Admin; telemetry tracking returns deterministic fake IDs without calling Firebase Functions; shared Navigation sign-out copy exists in all root runtime locales.

---

## §8. EXISTING STRENGTHS WORTH PRESERVING

### Evidence Chain (Gold Core)
1. **EducatorEvidenceCapture** — Under 10 seconds per observation. Retains session/learner context across entries. Real Firestore writes with full provenance.
2. **LearnerEvidenceSubmission** — Three evidence types (artifact, reflection, checkpoint) each with AI disclosure. Creates companion portfolio items with cross-links.
3. **RubricReviewPanel** — Template-driven 4-level scoring with progression descriptors. Scores both capabilities and process domains. Calls atomic backend callable.
4. **ProofOfLearningVerification** — 3-point verification (explain-it-back, oral check, mini rebuild) with excerpt capture. Verifies authenticity, updates proof state, and hands educators into rubric application on the same canonical portfolio item.
5. **Growth Engine** — Append-only `CapabilityGrowthEvent` trail. Atomic mastery/growth writes remain rubric/checkpoint-owned; proof verification no longer writes growth directly.
6. **LearnerPassportExport** — Evidence-backed claims plus process-domain progress with rubric scores, PoL status, AI disclosure, educator attribution. Text, HTML, PDF, print, and family-safe share export.

### Architecture
7. **Firestore Security** — Site-scoped, role-checked, ownership-enforced. 135 collection rules. Default-deny on unlisted.
8. **63 Cloud Functions** — All real, zero stubs. Evidence chain callables are atomic. Segregated concerns (auth, billing, evidence, motivation, ops).
9. **Flutter Parity** — Custom dashboards for all roles, offline sync queue, queued `rubricApply` / legacy `rubricApplication` replay through `applyRubricToEvidence`, eligible offline checkpoint replay through `processCheckpointMasteryUpdate`, queued `capabilityGrowthEvent` direct writes blocked as server-owned output, legacy Flutter growth helpers closed so rubric interpretation routes through `applyRubricToEvidence`, direct mastery/growth helpers fail closed, and generic Flutter repositories for `rubricApplications`, `capabilityMastery`, and `capabilityGrowthEvents` no longer expose client-side write paths.
10. **Test Coverage** — 472 web tests, 127 function tests, 318+ Flutter tests. All green. Total: 917+ tests.

### Platform Operations
11. **WorkflowRoutePage** — Generic CRUD framework serves 38 routes consistently. Data loading, role gating, create/edit/delete all handled.
12. **i18n** — 5 locales (en, es, th, zh-CN, zh-TW) with server-side caching.
13. **Enterprise SSO** — OIDC/SAML provider discovery, session cookie sync.
14. **Site Evidence Health Dashboard** — School-level evidence coverage metrics.

---

## §9. PROPOSED REFACTOR ORDER

### Phase 1: GA Polish (Low Effort, High Credibility) — DONE
1. ~~**P1-E**: Deprecate `AccountabilityKPI` + `ParentSnapshot` in schema~~ ✅
2. ~~**P1-D**: Add capability tags to parent portfolio view~~ ✅
3. ~~**P1-B**: Add capability tags to mission CRUD views~~ ✅
4. ~~Restore `/learner/habits` as a dedicated persisted habit workflow instead of a disconnected placeholder~~ ✅

### Phase 2: Assessment Depth (Medium Effort)
5. ~~**P1-C**: Embed `RubricReviewPanel` in `/educator/missions/review`~~ ✅
6. ~~**P1-A**: Create learner capability profile synthesis view~~ ✅
7. ~~Process domain progress display in passport + portfolio views~~ ✅

### Phase 3: Operational Hardening
8. ~~**P1-F**: Add typed collection references for top-priority untyped collections~~ ✅
9. ~~E2E emulator test: full evidence chain (capability → session → evidence → rubric → PoL → mastery → passport)~~ ✅
10. ~~Mobile viewport QA for educator evidence capture + learner submission~~ ✅

### Phase 4: Platform Expansion
11. Custom dashboards for remaining high-value generic routes
12. Admin-School implementation health dashboard
13. Partner evidence-backed output surfaces

---

## §10. CLASSIFICATION SUMMARY

| Classification | Count | Examples |
|----------------|-------|----------|
| **Aligned and usable** | 48 components, 9 routes, 15 schema types, 5 callables | Evidence chain core |
| **Reusable with modification** | 5 routes, 4 schema types | Missions, parent portfolio, curriculum |
| **Misleading / LMS-shaped** | 2 schema types | `AccountabilityKPI`, `ParentSnapshot` (both legacy, unused) |
| **Fake / disconnected** | 0 routes | None |
| **Operational (not evidence)** | 32 routes, 30+ schema types, 32+ functions | Sessions, billing, ops, partner, admin |
| **Missing** | 0 | `LearnerCapabilityProfile` added to schema |

---

## §11. GOLD-READY WORKFLOW VERIFICATION (current state: mixed / not certified)

### WF1. Curriculum admin can define capabilities and map them to units/checkpoints

**Status**: ◐ PARTIAL

**Evidence**:
- ✅ `CapabilityFrameworkEditor.tsx` — Full CRUD for capabilities: title, pillar (FUTURE_SKILLS/LEADERSHIP_AGENCY/IMPACT_INNOVATION), descriptor, sortOrder
- ✅ Progression descriptors — 4 text fields (beginning/developing/proficient/advanced) saved to `progressionDescriptors` object on capability doc
- ✅ Unit/mission mapping — Checkbox list of missions via `unitMappings: string[]` array storing mission IDs
- ✅ Rubric template creation — Criteria mapped to capabilities with `maxScore` and optional descriptors
- ✅ Firestore persistence — `addDoc(capabilitiesCollection)` / `updateDoc()` site-scoped, `isHQ()` gated writes
- ✅ `useCapabilities` hook loads and caches capabilities per-site
- ✅ **G9 CLOSED**: Checkpoint mapping admin UI in `CapabilityFrameworkEditor` — add/remove checkpoint mappings per capability with label + description fields, stored as `checkpointMappings: Array<{label, description?}>` on capability doc

**Blocker**: None

---

### WF2. Teacher can run a session and quickly log capability observations during build time

**Status**: ✅ VERIFIED

**Evidence**:
- `EducatorEvidenceCapture.tsx` — Single-column form: session selector (today's sessions pre-queried), learner selector, phase selector (retrieval_warm_up / mini_lesson / build_sprint / checkpoint / share_out / reflection), description, capability selector, portfolio-candidate toggle
- Retains learner + session context across multiple entries (only clears description/capability/phase on submit)
- `addDoc(evidenceRecordsCollection)` with full provenance: `learnerId`, `educatorId`, `siteId`, `sessionOccurrenceId`, `capabilityId`, `phaseKey`, `portfolioCandidate`, `rubricStatus: 'pending'`, `growthStatus: 'pending'`
- Under 10 seconds per entry: 1 dropdown + 1 phase + 1 text + 1 button, no modal
- Session context from `sessionOccurrences` query joined with parent session docs
- `EvidenceRecord` schema: `schema.ts:1185-1203`

**Blocker**: None

---

### WF3. Student can submit artifacts, reflections, and checkpoint evidence

**Status**: ✅ VERIFIED

**Evidence**:
- **Artifact submission** — `LearnerEvidenceSubmission.tsx` artifact tab: title, description, URL, capability IDs, AI disclosure (used + details). Creates `PortfolioItem` with `source: 'learner_submission'`, `verificationStatus: 'pending'`, `aiDisclosureStatus`, `capabilityIds`, `pillarCodes`
- **Reflection submission** — Creates TWO docs: `PortfolioItem` with `source: 'reflection'` AND `LearnerReflection` with `portfolioItemId` cross-link (G1 fix)
- **Checkpoint submission** — Creates TWO docs: `MissionAttempt` then `PortfolioItem` with `missionAttemptId: attemptRef.id` (G2 fix)
- All three types write real Firestore docs with `siteId`, `learnerId`, AI disclosure fields

**Blocker**: None

---

### WF4. Teacher can apply a 4-level rubric tied to capabilities and process domains

**Status**: ✅ VERIFIED

**Evidence**:
- ✅ `RubricReviewPanel.tsx` — Loads published `rubricTemplates` from Firestore, template selector dropdown, populates criteria scores from template
- ✅ 4-level scoring: `SCORE_LEVELS` = 1=Beginning, 2=Developing, 3=Proficient, 4=Advanced
- ✅ `getDescriptor()` retrieves level-specific progression descriptor text from template
- ✅ `applyRubricToEvidence` callable: atomically creates `RubricApplication`, `CapabilityGrowthEvent` per capability, upserts `CapabilityMastery` with `latestLevel`/`highestLevel`
- ✅ `rubricId` passed to callable (G3 fix)
- ✅ `RubricTemplateCriterion` has `capabilityId`, `processDomainId?`, `pillarCode`, `maxScore`, optional `descriptors`
- ✅ **G10 CLOSED**: Full process domain model:
  - `ProcessDomain` type in schema with `progressionDescriptors`, `sortOrder`, `status`
  - `processDomainId?: string` on `RubricTemplateCriterion`
  - Process domains CRUD in `CapabilityFrameworkEditor` (admin tab)
  - Process domain scoring cards (purple-styled) in `RubricReviewPanel` with ad-hoc add + template-driven population
  - `applyRubricToEvidence` callable creates `ProcessDomainGrowthEvent` + upserts `ProcessDomainMastery` per domain score
  - Firestore collections + rules for `processDomains`, `processDomainMastery`, `processDomainGrowthEvents`

**Blocker**: None

---

### WF5. Proof-of-learning can be captured and reviewed

**Status**: ✅ VERIFIED

**Evidence**:
- `ProofOfLearningVerification.tsx` — 3 verification methods: explainItBack ("Can the learner explain the concept in their own words?"), oralCheck ("Can the learner answer follow-up questions?"), miniRebuild ("Can the learner recreate or extend the work independently?")
- Educator sees original evidence: title, description, capability count, evidence record count, artifact count, capabilities mapped (pill badges), AI disclosure detail
- Checkboxes for each proof check with conditional textareas for excerpts, educator notes field
- Two submit paths: "Verify" (needs ≥2 checks) and "Mark reviewed" (no requirement)
- `verifyProofOfLearning` callable updates `PortfolioItem` proof fields, proof bundles, and canonical linkage, and returns `capabilitiesReadyForRubric`
- Verified proof now deep-links into `/educator/rubrics/apply?portfolioItemId=...`
- `EducatorRubricApplyRenderer` and `RubricReviewPanel` continue rubric application on the same verified portfolio item
- Atomic batch commit

**Blocker**: Proof review is now truthful and canonical, but broader workflow certification across all evidence surfaces is still incomplete.

---

### WF6. Capability growth updates over time from evidence

**Status**: ◐ PARTIAL

**Evidence**:
- ✅ `applyRubricToEvidence` callable creates `capabilityGrowthEvents` with: `level` (1-4), `rawScore`, `maxScore`, `linkedEvidenceRecordIds`, `linkedPortfolioItemIds`, `rubricApplicationId`, `educatorId`, `createdAt`
- ✅ `verifyProofOfLearning` no longer writes `capabilityGrowthEvents` or `capabilityMastery` directly
- ✅ Mission review now forwards linked `portfolioItemId` into `applyRubricToEvidence`, preserving canonical artifact provenance
- ✅ Flutter mission review no longer creates client-owned `rubricApplications`; it calls `applyRubricToEvidence` with linked evidence IDs, leaves evidence `growthStatus` pending until the callable records growth, and links the returned server-created `rubricApplicationId` back to the reviewed attempt, evidence records, and portfolio items.
- ✅ Proof-linked checkpoints now stay in the queue as `pending_proof` until proof is verified and the educator can record growth truthfully
- ✅ Growth events are append-only, queryable by `learnerId` + `createdAt`
- ✅ `LearnerPassportExport.tsx` renders growth timeline (15 most recent): capability title, level, educator name, rubric scores
- ✅ `CapabilityGuidancePanel.tsx` shows per-pillar average level + band (strong/developing/emerging)
- ✅ Flutter has custom growth visualizations in `parent_summary_page.dart` (level progression bars per capability)
- ✅ Flutter offline `rubricApply` and legacy `rubricApplication` replay now call `applyRubricToEvidence` with normalized evidence/mission/portfolio context and rubric scores, instead of writing disconnected `rubricApplications` docs.
- ✅ Flutter offline `capabilityGrowthEvent` replay now fails as server-owned output instead of directly writing append-only growth events from the client queue.
- ✅ Flutter offline `checkpointSubmit` always preserves `checkpointHistory` capture and routes passed, skill-linked educator checkpoint payloads through `processCheckpointMasteryUpdate` for server-side mastery evaluation.
- ✅ Legacy Flutter `CapabilityGrowthEngine.processRubricApplication` now calls `applyRubricToEvidence` with evidence, mission, or portfolio context instead of writing `capabilityGrowthEvents` / `capabilityMastery` locally.
- ✅ Legacy Flutter `FirestoreService.applyRubric` now routes through `applyRubricToEvidence` and refuses evidence-free rubric interpretation; `updateCapabilityMastery` and `createCapabilityGrowthEvent` fail closed as server-owned paths.
- ✅ Legacy Flutter repository write affordances for `rubricApplications`, `capabilityMastery`, and `capabilityGrowthEvents` now fail closed; remaining references are read-side collection queries.
- ✅ **G11 CLOSED**: `LearnerDashboardToday.tsx` custom dashboard with capability guidance panel, recent growth events, active missions, today's sessions — replaces generic session list

**Blocker**: Growth writes are server-owned and provenance-rich, but full gold certification still depends on broad end-to-end workflow verification and uniform reporting/publish parity outside the trust-critical report paths hardened in this pass.

---

### WF7. Student portfolio shows real artifacts and reflections

**Status**: ✅ VERIFIED

**Evidence**:
- `LearnerPortfolioBrowser.tsx` — Queries `portfolioItems` where `learnerId` == current user, `orderBy('createdAt', 'desc')`
- Shows: title, source badge (artifact/reflection/checkpoint), description, verification status badge (pending→yellow, reviewed→blue, verified→green), PoL badge, capability tags (resolved via `useCapabilities`), file count, AI assistance indicator, growth links, proof bundle indicator
- Filters: source type (all/artifact/reflection/checkpoint), verification status (all/pending/reviewed/verified), pillar (all/FUTURE_SKILLS/LEADERSHIP_AGENCY/IMPACT_INNOVATION)
- Tabbed layout on `/learner/portfolio`: "My Portfolio" (browser, default) + "Submit Evidence" (submission form)

**Blocker**: None

---

### WF8. Ideation Passport/report can be generated from actual evidence

**Status**: ✅ VERIFIED

**Evidence**:
- `LearnerPassportExport.tsx` calls `getLearnerPassportBundle` callable with `{ siteId, locale, range: 'all' }`
- Callable aggregates: `capabilityMastery`, `capabilityGrowthEvents`, `portfolioItems`, `evidenceRecords`, `missionAttempts`, `learnerReflections` (+ more)
- Per-capability claims: `evidenceCount`, `verifiedArtifactCount`, `proofOfLearningStatus`, `rubricRawScore`/`rubricMaxScore`, `progressionDescriptors`, `aiDisclosureStatus`, `reviewingEducatorName`, `reviewedAt`
- Parent-facing `GuardianCapabilityViewRenderer` / `GuardianPassportRenderer` now retain linked evidence counts, linked portfolio counts, mission linkage, rubric scores, proof-method signals, and review attribution instead of collapsing that provenance during normalization.
- Learner and guardian passport/report surfaces now also render titled process-domain snapshot + recent process-domain growth from the callable summaries instead of dropping that read-side evidence slice.
- Capability band calculation: normalized per-pillar score → strong/developing/emerging band
- Growth timeline rendered: up to 15 events with capability title, level, date, educator name, rubric score, and evidence/portfolio linkage counts
- Export: learner and parent web passport surfaces now provide text export, dedicated PDF export, browser print, and a family-safe share summary; learner web also keeps portable HTML export for browser viewing/archive; web learner and guardian family-summary sharing now includes current claim, recent growth, and featured portfolio provenance with proof, AI, rubric, reviewer, evidence, portfolio, and mission linkage before using the shared native-share → clipboard → unavailable fallback; guardian sharing also carries recent process-domain growth provenance from the parent dashboard bundle; guardian text/PDF exports preserve recent growth reviewer/rubric detail and portfolio-highlight evidence, mission, reviewer, and rubric provenance; shared web report actions now classify evidence, growth, portfolio, mission, proof, AI disclosure, rubric, reviewer, and verification-prompt signals, send expected/missing provenance-contract metadata through interaction telemetry for learner and guardian share/text/PDF actions, expose a release-gate assertion helper for evidence-bearing payloads, and assert the real learner/guardian report builder outputs satisfy those contracts; Flutter learner/guardian report actions now use a role-neutral shared helper for parent summary export/share, parent child passport export/share, parent portfolio summary download fallback, and learner portfolio clipboard sharing while preserving each surface's evidence-specific report text; shared Flutter report actions now emit report provenance telemetry flags for evidence, growth, portfolio, mission, proof, AI disclosure, rubric, reviewer, and verification-prompt signals present in the actual export/share content, and evidence-bearing Flutter report call sites now declare expected provenance-signal contracts plus a release-gate assertion helper so missing proof/linkage signals are detectable and test-failable per payload; Flutter parent summary, parent child Passport/share, parent portfolio download fallback, and learner portfolio share tests now assert the actual generated report payloads meet those provenance contracts; Flutter parent summary and parent child family-share text now includes recent growth provenance with rubric, educator, linked evidence, linked portfolio, proof, and date details; Flutter parent summary export/share now also carries featured portfolio evidence with proof, AI, reviewer, rubric, evidence IDs, mission linkage, capabilities, and verification prompt detail; Flutter parent child Passport export/copy now also includes recent growth provenance plus featured portfolio evidence with proof, AI, rubric, reviewer, evidence IDs, mission IDs, and verification prompts; Flutter parent portfolio share requests now persist the full evidence review summary plus structured proof, AI, rubric, educator, evidence, and mission metadata for approved staff-mediated sharing; Flutter parent consent now exposes active evidence-bearing report-share lifecycle records for linked learners and lets guardians revoke active shares through the server-owned callable while preserving the audit trail; and Flutter learner portfolio sharing now copies a provenance-aware report that carries reviewed artifacts, linked evidence/growth counts and IDs, mission/proof/rubric/educator identifiers, proof-of-learning checks, capability updates, and AI disclosure.
- Runtime provenance guardrails: web learner/guardian family-share, text, HTML, and PDF export actions plus Flutter parent/learner evidence-bearing report actions now opt into fail-closed provenance enforcement. When expected evidence, growth, portfolio, mission, proof, AI disclosure, rubric, reviewer, or verification-prompt signals are missing, delivery is blocked before native share, clipboard, text download, HTML save, or PDF save. Enforced delivery also now requires a declared report share policy with audience and visibility metadata (family/private today), so report telemetry can distinguish family-safe guardian sharing from learner-private export. Web learner/guardian completed report deliveries and Flutter shared report completed deliveries now create `reportShareRequests` and pass the resulting `shareRequestId` into the durable `recordReportDeliveryAudit` callable so the server links `deliveryAuditId` back onto the active lifecycle record; blocked deliveries remain audit-only.
- Share lifecycle foundation: `ReportShareRequest` now has a typed schema, collection reference, server-owned Firestore rules, focused helper tests, web client helpers, and `createReportShareRequest` / `revokeReportShareRequest` callables. Creation requires a passing report delivery contract, declared share policy, and completed delivery status; external, partner, public, or otherwise externally allowed report sharing is blocked until explicit consent workflow support exists; revocation preserves the lifecycle record and writes an audit action.
- Honest empty state: "No capability claims backed by evidence yet"
- ⚠️ Remaining gaps: web learner/guardian passport routes now include process-domain read-side coverage, concrete export/share actions, a shared fallback helper, durable report-delivery audit, and linked backend share-request lifecycle creation for completed deliveries; Flutter learner/guardian report actions now share common export/share mechanics, durable audit, linked share-request creation, and a guardian-facing same-site active-share revocation surface on parent consent for the trust-critical family/portfolio surfaces touched in this slice; web client share-request management and a unified publish/share workflow across every reporting surface still remain, and disclosure/provenance are still not perfectly uniform across every artifact path.

**Blocker**: Cross-role report/publish workflow polish, web client share-request management, broader explicit consent UX, and uniform provenance parity across every remaining artifact path.

---

### WF9. AI-use is disclosed and visible where relevant

**Status**: ✅ VERIFIED

**Evidence**:
- **Capture**: `LearnerEvidenceSubmission.tsx` — Checkbox "I used AI assistance" + text field "explain what/how" → sets `aiDisclosureStatus` (learner-ai-verified / learner-ai-not-used) and `aiAssistanceDetails`
- **Portfolio display**: `LearnerPortfolioBrowser.tsx` — "AI assisted" badge rendered when `aiAssistanceUsed` is true
- **Passport display**: `LearnerPassportExport.tsx` — `aiLabel(claim.aiDisclosureStatus)` per capability claim → "AI used — verified", "AI used — not verified", "No AI signal"
- **Educator visibility**: Evidence records and portfolio items carry `aiDisclosureStatus` field viewable in review panels
- **MiloOS educator visibility**: `EducatorAiAuditRenderer.tsx` reads site-scoped `interactionEvents` and shows per-learner opened/used/explain-back/pending support provenance while explicitly separating support signals from capability mastery; Playwright now drives `/en/educator/learners` with seeded same-site and other-site support events to verify educators see same-site follow-up debt only.
- **MiloOS learner visibility**: `AICoachScreen.tsx` and `AICoachPopup.tsx` keep the MiloOS response transcript visible and preserve explain-back flow when browser speech or audio playback is unavailable; `/learner/miloos` now has browser-operated Playwright coverage for support-opened/support-used/pending/explain-back counters and explicitly verifies no `capabilityMastery` write occurs.
- **MiloOS guardian visibility**: `buildParentLearnerSummary` now derives `miloosSupportSummary` from site-scoped `interactionEvents`; `GuardianCapabilityViewRenderer` renders and exports opened/used/explain-back/pending support provenance with explicit non-mastery language, and Playwright now drives `/en/parent/summary` with seeded same-site and other-site support events to verify linked-family visibility on the protected route.
- **MiloOS Admin-School visibility**: `SiteImplementationHealthRenderer` now aggregates same-site `interactionEvents` into support-opened/support-used/explain-back/pending counts and learner follow-up counts for site leaders, again framed as support health rather than capability mastery; Playwright now drives `/en/site/dashboard` with seeded same-site and other-site support events to verify the protected route counts only the same-site support debt.
- **MiloOS E2E boundary**: Browser E2E uses deterministic `NEXT_PUBLIC_E2E_TEST_MODE=1` fake callables only inside the existing Playwright harness; production `sdtMotivation` and learner-loop insight helpers still call Firebase Functions (`genAiCoach`, `submitExplainBack`, `bosGetLearnerLoopInsights`).
- **Flutter parent view**: `parent_portfolio_page.dart` — `_formatAiDisclosure()` with human-readable labels
- **Audit trail**: Stored in Firestore `portfolioItems.aiDisclosureStatus`, copied to `capabilityGrowthEvents`, preserved in passport export

**Blocker**: None

---

### WF10. Family/student/teacher views are understandable and trustworthy

**Status**: ✅ VERIFIED

**Evidence**:
- ✅ `getParentDashboardBundle` callable returns comprehensive evidence-backed data: `capabilitySnapshot`, `ideationPassport.claims[]`, `growthTimeline[]`, `portfolioSnapshot`, per-learner summaries
- ✅ `CapabilityGuidancePanel.tsx` exists and shows plain-language bands with progression descriptors + "no-evidence" state
- ✅ Flutter has custom dashboards: `LearnerTodayPage`, `EducatorTodayPage`, `ParentSummaryPage`
- ✅ Flutter Admin-School site dashboard/audit exports, educator learner practice-plan export, and HQ operational exports now use shared `ReportActions` mechanics for file download and clipboard fallback while preserving site, learner, educator, activity, audit, HQ bundle, safety, analytics, and billing telemetry context.
- ✅ **G12 CLOSED**: All three critical web dashboards now have custom UIs:
  - **`/learner/today`** — `LearnerDashboardToday.tsx`: capability guidance, recent growth events, active missions, today's sessions. Learner CAN answer "how am I growing?"
  - **`/educator/today`** — `EducatorDashboardToday.tsx`: today's sessions with learner counts, review queue (pending evidence + PoL), pillar capability snapshots, recent evidence. Educator CAN answer "what needs attention?"
  - **`/parent/summary`** — `GuardianCapabilityViewRenderer.tsx`: calls `getParentDashboardBundle`, per-learner capability snapshots with band + pillar scores, growth timeline, portfolio highlights, and passport-linked provenance details. Parent CAN answer "what can my child do?"

**Blocker**: None

---

## §12. CLOSED GOLD BLOCKERS (G1–G12)

### G1. Reflections disconnected from portfolio items — ✅ CLOSED
- **Fix**: `LearnerEvidenceSubmission.tsx` reflection handler now creates companion `PortfolioItem` with `source: 'reflection'` and `portfolioItemId` cross-link.

### G2. Checkpoint portfolio items missing `missionAttemptId` — ✅ CLOSED
- **Fix**: Checkpoint handler captures `attemptRef.id` and writes `missionAttemptId` on the companion `PortfolioItem`.

### G3. Rubric templates authored but never consumed at apply time — ✅ CLOSED
- **Fix**: `RubricReviewPanel.tsx` now loads published templates, shows selector dropdown, populates criteria scores, displays progression descriptors, passes `rubricId` to callable.

### G4. Overly permissive Firestore rules — ✅ CLOSED
- **Fix**: Ownership checks on `presenceRecords`, `conversations`, `habitLogs`, `incidents`, `offlineDemoActions`, `drafts`.

### G5. No standalone learner portfolio browse view — ✅ CLOSED
- **Fix**: `LearnerPortfolioBrowser.tsx` with source/verification/pillar filters, tabbed layout on `/learner/portfolio`.

### G6. `/educator/evidence` route no case body in workflowData.ts — ✅ CLOSED
- **Fix**: Added case body querying `evidenceRecords` with site-scoping.

### G7. `drafts` collection no ownership check — ✅ CLOSED
- **Fix**: Added `userId == auth.uid` checks on all CRUD operations.

### G8. CapabilityFrameworkEditor missing accessible names — ✅ CLOSED
- **Fix**: Added `aria-label` to 5 form elements.

### G9. No checkpoint mapping admin UI — ✅ CLOSED
- **Fix**: Added checkpoint mapping section to `CapabilityFrameworkEditor` capability form. HQ can add/remove named checkpoints per capability (label + description), stored as `checkpointMappings: Array<{label, description?}>` on capability doc. Saved on both create and update.

### G10. No process domain model for rubric scoring — ✅ CLOSED
- **Fix**: Full implementation across 6 layers:
  - Schema: `ProcessDomain`, `ProcessDomainMastery`, `ProcessDomainGrowthEvent` types + `processDomainId?` on `RubricTemplateCriterion`
  - Collections: `processDomainsCollection`, `processDomainMasteryCollection`, `processDomainGrowthEventsCollection`
  - Admin UI: Process Domains tab in `CapabilityFrameworkEditor` with full CRUD + form modal
  - Rubric review: Purple-styled process domain score cards in `RubricReviewPanel` with ad-hoc add dropdown + template-driven population + progression descriptors
  - Backend: `applyRubricToEvidence` callable creates `ProcessDomainGrowthEvent` + upserts `ProcessDomainMastery` per scored domain
  - Firestore rules: HQ can manage `processDomains`, educators can write mastery/growth, learners can read own

### G11. Web `/learner/today` generic session list — ✅ CLOSED
- **Fix**: Created `LearnerDashboardToday.tsx` replacing `WorkflowRoutePage`. Custom dashboard with: capability guidance panel (pillar progress + bands), recent growth events, active missions, today's sessions. Data from direct Firestore queries.

### G12. Web `/educator/today` and `/parent/summary` generic CRUD lists — ✅ CLOSED
- **Fix**: Created `EducatorDashboardToday.tsx` (sessions, review queue, pillar snapshots, recent evidence) and routed `/parent/summary` through `GuardianCapabilityViewRenderer.tsx` backed by `getParentDashboardBundle` so the parent summary uses the same evidence-backed family surface as the rest of the guardian workflow. Both replace the generic `WorkflowRoutePage` fallback.

---

## §13. BETA-SAFE ISSUES (Track for GA)

| ID | Issue | Severity | Status |
|----|-------|----------|--------|
| B1 | 38/47 page routes use generic CRUD list UI | BETA-SAFE | G11/G12 addresses the 9 critical routes |
| B2 | ~89 Firestore collections have rules but no TS web types | BETA-SAFE | Add as web surfaces need them |
| B3 | `/learner/habits` had no trustworthy web backing | ~~BETA-SAFE~~ **FIXED** | Dedicated web habits renderer now reads and writes persisted `habits` and `habitLogs` data |
| B4 | Partner role thin UX | BETA-SAFE | Defer to partner onboarding |
| B5 | Global content catalog readable by all auth users | BETA-SAFE | Intentional shared model |
| B6 | 37 npm vulns (all transitive, no safe fixes) | BETA-SAFE | Monitor upstream |

---

## §14. EVIDENCE CHAIN INTEGRITY

| Step | WF | Status | Code Evidence |
|------|----|--------|---------------|
| HQ defines capabilities + descriptors | WF1 | ✅ | `CapabilityFrameworkEditor.tsx` CRUD, 4-level descriptors, pillar mapping |
| HQ defines rubric templates | WF1 | ✅ | Rubric Templates tab, criteria+maxScore+descriptors |
| HQ maps capabilities to checkpoints | WF1 | ✅ | `CapabilityFrameworkEditor` checkpoint mapping UI (G9) |
| HQ defines process domains | WF1 | ✅ | Process Domains tab with CRUD + form modal (G10) |
| Educator runs sessions | WF2 | ✅ | workflowData sessions by siteId, create/update |
| Educator logs observations <10s | WF2 | ✅ | `EducatorEvidenceCapture.tsx` with retained context |
| Learner submits artifacts | WF3 | ✅ | `LearnerEvidenceSubmission.tsx` artifact tab |
| Learner submits reflections → portfolio | WF3 | ✅ | Companion portfolioItem with cross-link (G1) |
| Learner submits checkpoints → mission | WF3 | ✅ | `missionAttemptId` linkage (G2) |
| Educator applies rubric with template | WF4 | ✅ | Template selector, descriptors, `rubricId` (G3) |
| Educator scores process domains | WF4 | ✅ | `RubricReviewPanel` process domain scoring cards (G10) |
| Educator verifies proof-of-learning | WF5 | ◐ | 3 verification methods, excerpts, canonical rubric handoff; authenticity-only, not direct growth |
| Growth events created atomically | WF6 | ◐ | Rubric + checkpoint callables; proof-linked checkpoints recover via `pending_proof` |
| Growth visible on web dashboard | WF6 | ✅ | `LearnerDashboardToday.tsx` growth events + capability bands (G11) |
| Portfolio browsable with filters | WF7 | ✅ | `LearnerPortfolioBrowser.tsx` |
| Passport from real evidence | WF8 | ◐ | `LearnerPassportExport.tsx` plus guardian passport surfaces now consume richer claim, portfolio, and growth provenance via callables; learner and parent web passport routes offer dedicated PDF/share actions through a shared browser fallback helper; web learner and guardian family-share summaries now carry claim/growth/portfolio proof, AI, rubric, reviewer, and linkage provenance, with guardian sharing also carrying process-domain growth provenance; guardian text/PDF exports now keep recent-growth and portfolio-highlight reviewer/rubric/provenance detail; shared web and Flutter report telemetry now record present provenance signals plus expected/missing signal contracts, both platforms expose assertion helpers that can fail tests/release gates for weak evidence-bearing export/share payloads, web and Flutter evidence-bearing report actions now fail closed before delivery when expected provenance or declared audience/visibility share policy is missing, and web plus Flutter parent/learner report tests now assert real generated payloads satisfy those contracts; Flutter parent summary export/share and parent child Passport export/copy now preserve recent growth and featured portfolio evidence provenance; Flutter learner portfolio sharing preserves reviewed artifact, evidence/growth IDs, mission/proof/rubric/educator identifiers, proof, capability, and AI disclosure provenance; but unified publish/share workflow parity and full provenance consistency are still incomplete |
| AI disclosure captured + displayed | WF9 | ◐ | Stronger across submission, portfolio, and passport, and non-mission learner portfolio curation now preserves AI detail text as well as status, but not yet uniform on every artifact path |
| Parent answers "what can my child do?" | WF10 | ◐ | `GuardianCapabilityViewRenderer.tsx` is the real web parent summary surface and now preserves more provenance, but downstream communication is still not uniformly polished |
| Educator answers "what needs attention?" | WF10 | ◐ | `EducatorDashboardToday.tsx` review queue is real, but not every trust-critical surface has full evidence parity |
| Learner answers "how am I growing?" | WF10 | ◐ | `LearnerDashboardToday.tsx` shows growth and bands, the learner timeline shows direct evidence-linked growth plus standalone proof bundles, passport/report surfaces are stronger, and learner progress revision reminders now site-scope their read path; communication parity is still incomplete |

---

## §15. BUILD & TEST VERIFICATION — historical April 2 snapshot plus later targeted current-state reruns

| Check | Result | Command |
|-------|--------|---------|
| TypeScript | ✅ EXIT=0 | `npm run typecheck -- --pretty false` |
| Jest (web) | ✅ 32 suites, 480/480 pass | `npm test` |
| Next.js build | ✅ BUILD_EXIT=0, 70 routes | `npm run build` |
| Functions build | ✅ Compiled | `cd functions && npm run build` |
| Functions tests | ✅ 33 suites, 127/127 pass | `cd functions && npx jest --runInBand --forceExit` |
| Evidence-chain emulator integration | ✅ session-backed evidence → proof → rubric → mastery → learner passport + guardian bundle; MiloOS help → explain-back → learner-loop insight with pending verification gap and no mastery write; configured internal-inference MiloOS explain-back journey through internal-only egress guard | `npm run test:integration:evidence-chain` |
| P1-F typed collection reconciliation | ✅ 139/139 focused evidence-chain component/source-contract tests | `npm test -- --runTestsByPath src/__tests__/evidence-chain-components.test.ts` |
| Mobile evidence workflow viewport QA | ✅ 2/2 Playwright mobile browser tests | `npx playwright test --config playwright.config.ts test/e2e/mobile-evidence-workflows.e2e.spec.ts` |
| E2E fake-mode infrastructure quieting | ✅ 11/11 focused SSO, telemetry, and Navigation locale guard tests | `npm test -- --runTestsByPath src/__tests__/enterprise-sso.test.ts src/__tests__/e2e-infrastructure-noise.test.ts src/__tests__/navigation-signout-availability.test.ts` |
| Report share/export web helper + delivery audit | ✅ 159/159 focused share/download provenance, share-policy, delivery-audit, generated payload, and source-contract tests pass | `npm test -- src/__tests__/report-delivery-audit.test.ts src/__tests__/report-share-export.test.ts src/__tests__/evidence-chain-components.test.ts src/__tests__/report-generated-payloads.test.ts` |
| Functions report delivery audit | ✅ 5/5 focused durable audit helper tests; Functions build clean | `npm --prefix functions test -- reportDeliveryAudit.test.ts logoutAudit.test.ts`; `npm --prefix functions run build` |
| Report share request lifecycle | ✅ 156/156 focused web source-contract/helper tests plus 9/9 focused Functions lifecycle/delivery/logout audit tests; TypeScript, Functions build, lint, and diff hygiene clean | `npm test -- src/__tests__/evidence-chain-components.test.ts src/__tests__/report-delivery-audit.test.ts`; `npm --prefix functions test -- reportShareRequests.test.ts reportDeliveryAudit.test.ts logoutAudit.test.ts`; `npm run typecheck -- --pretty false`; `npm --prefix functions run build`; `npm run lint`; `git diff --check` |
| Flutter shared learner/guardian report actions | ✅ 8/8 focused report provenance + durable delivery audit + linked share-request tests; analyzer clean for modified report services/actions. Earlier broader 35/35 parent/child/portfolio/learner report widget suite remains the latest broad pass. | `cd apps/empire_flutter/app && flutter test test/report_actions_provenance_test.dart`; `flutter analyze lib/modules/reports/report_actions.dart lib/services/report_delivery_audit_service.dart lib/services/report_share_request_service.dart test/report_actions_provenance_test.dart` |
| MiloOS learner site boundary + support snapshot | ✅ Focused web route/renderer/source contracts plus render-level learner support snapshot, coach-refresh, visible-transcript, and audio-fallback tests pass; Functions wording/site-scope/timestamp-normalization/index-contract and learner-loop behavioral aggregation tests pass; governed `/learner/miloos` now mounts through `WorkflowRoutePage`, maps to `LearnerMiloOSRenderer`, and reads `bosGetLearnerLoopInsights` instead of stale client-side interaction collections; `AICoachScreen` and `AICoachPopup` keep a readable transcript when spoken playback is unavailable; Firestore emulator now verifies fallback and configured-internal-inference `genAiCoach` → `submitExplainBack` → `bosGetLearnerLoopInsights` journeys; Flutter learner-loop card renders support-journey explain-back gaps; TypeScript, Functions build, root lint, Flutter analyze, and diff hygiene clean | `npm test -- --runTestsByPath src/__tests__/routing.test.ts src/__tests__/evidence-chain.test.ts src/__tests__/navigation-signout-availability.test.ts src/__tests__/miloos-ai-coach-screen.test.tsx src/__tests__/miloos-learner-support-snapshot.test.tsx src/__tests__/evidence-chain-renderer-wiring.test.ts src/__tests__/ai-help-wording-availability.test.ts`; `npm --prefix functions test -- aiHelpWording.test.ts bosRuntimeHonesty.test.ts`; `npm run test:integration:evidence-chain`; `cd apps/empire_flutter/app && flutter test test/bos_insights_cards_test.dart`; `flutter analyze lib/runtime/bos_learner_loop_insights_card.dart lib/i18n/bos_coaching_i18n.dart test/bos_insights_cards_test.dart`; `npm run typecheck -- --pretty false`; `npm --prefix functions run build`; `npm run lint`; `git diff --check` |
| MiloOS learner browser support loop | ✅ Playwright drives the real `/en/learner/miloos` route through hint request, visible transcript, pending explain-back, explain-back submission, refreshed counters, persisted `interactionEvents`, and zero `capabilityMastery` writes. Source contracts pin the E2E fake callable boundary behind `NEXT_PUBLIC_E2E_TEST_MODE` so the browser harness does not replace production Firebase Functions behavior. | `npx playwright test --config playwright.config.ts test/e2e/miloos-learner-loop.e2e.spec.ts`; `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts` |
| MiloOS educator support provenance | ✅ Render-level educator AI audit coverage proves per-learner opened/used/explain-back/pending summaries from site-scoped `interactionEvents`, including support-only learners; Playwright drives `/en/educator/learners` with same-site and other-site support events and verifies educators see same-site pending explain-back debt only; source contracts pin the no-site block, E2E harness boundary, and non-mastery language; Firestore emulator verifies educators can read same-site events and cannot read other-site or missing-site events. | `npx playwright test --config playwright.config.ts test/e2e/miloos-educator-support-provenance.e2e.spec.ts`; `npm test -- --runTestsByPath src/__tests__/educator-ai-audit-miloos-provenance.test.tsx src/__tests__/evidence-chain-renderer-wiring.test.ts`; `npm run test:integration:rules`; `npm run typecheck -- --pretty false`; `npm run lint`; `git diff --check` |
| MiloOS guardian support provenance | ✅ Parent dashboard bundles now expose `miloosSupportSummary` from real `interactionEvents`; guardian dashboard, text export, and family share summary show opened/used/explain-back/pending support provenance while explicitly saying it is not capability mastery. Playwright drives `/en/parent/summary` with same-site and other-site support events and verifies linked guardians see same-site pending support provenance only. Firestore emulator verifies the `genAiCoach` → `submitExplainBack` → `bosGetLearnerLoopInsights` journey also appears in the parent bundle without mastery fields. | `npx playwright test --config playwright.config.ts test/e2e/miloos-guardian-support-provenance.e2e.spec.ts`; `npm run test:integration:evidence-chain`; `npm test -- --runTestsByPath src/__tests__/evidence-chain-components.test.ts src/__tests__/report-generated-payloads.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts`; `npm --prefix functions test -- aiHelpWording.test.ts`; `npm --prefix functions run build`; `npm run typecheck -- --pretty false`; `npm run lint`; `git diff --check` |
| MiloOS Admin-School support health | ✅ Site implementation health now reads same-site `interactionEvents`, aggregates opened/used/explain-back/pending support counts and learners needing follow-up, and labels the panel as support/verification health rather than mastery. Playwright drives `/en/site/dashboard` with seeded same-site and other-site support events and verifies only same-site support debt appears; Firestore rules emulator verifies site admins can read same-site events and cannot read other-site or missing-site events. | `npx playwright test --config playwright.config.ts test/e2e/miloos-site-support-health.e2e.spec.ts`; `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts`; `npm run test:integration:rules`; `npm run typecheck -- --pretty false`; `npm run lint`; `git diff --check` |
| MiloOS protected-route accessibility | ✅ Focused Axe WCAG 2.2 AA automation passes on the protected MiloOS support/provenance regions for learner, educator, guardian, and Admin-School routes in light/reduced-motion mode. PageTransition now uses native reduced-motion detection after mount, so the protected MiloOS routes avoid the previous reduced-motion hydration mismatch while preserving reduced-motion accessibility. | `npx playwright test --config playwright.config.ts test/e2e/miloos-accessibility.e2e.spec.ts`; `npm test -- --runTestsByPath src/__tests__/evidence-chain-renderer-wiring.test.ts`; `npm run typecheck -- --pretty false` |
| Learner progress revision site-scoping | ✅ 314/314 focused evidence-chain component + renderer contract tests; TypeScript clean | `npm test -- --runTestsByPath src/__tests__/evidence-chain-components.test.ts src/__tests__/evidence-chain-renderer-wiring.test.ts`; `npx tsc --noEmit --pretty false --incremental false` |
| Flutter report action parity across learner/guardian/site/educator/HQ operations | ✅ 108/108 focused site dashboard + site audit + educator learners + HQ exports/audit/safety/analytics/billing + learner/guardian report widget tests; analyzer clean | `cd apps/empire_flutter/app && flutter test test/site_dashboard_page_test.dart test/site_audit_page_test.dart test/parent_summary_page_test.dart test/parent_child_page_test.dart test/parent_portfolio_page_test.dart test/learner_site_surfaces_localization_test.dart test/learner_portfolio_honesty_test.dart test/educator_differentiation_workflow_test.dart test/educator_learners_page_test.dart test/hq_exports_page_test.dart test/hq_audit_page_test.dart test/hq_audit_page_localization_test.dart test/hq_safety_page_test.dart test/hq_admin_placeholder_actions_test.dart test/hq_analytics_page_test.dart test/hq_billing_page_test.dart`; `flutter analyze lib/modules/reports/report_actions.dart lib/modules/learner/learner_portfolio_page.dart lib/modules/parent/parent_summary_page.dart lib/modules/parent/parent_child_page.dart lib/modules/parent/parent_portfolio_page.dart lib/modules/site/site_dashboard_page.dart lib/modules/site/site_audit_page.dart lib/modules/educator/educator_learners_page.dart lib/modules/hq_admin/hq_exports_page.dart lib/modules/hq_admin/hq_audit_page.dart lib/modules/hq_admin/hq_safety_page.dart lib/modules/hq_admin/hq_analytics_page.dart lib/modules/hq_admin/hq_billing_page.dart test/site_dashboard_page_test.dart test/site_audit_page_test.dart test/parent_summary_page_test.dart test/parent_child_page_test.dart test/parent_portfolio_page_test.dart test/learner_site_surfaces_localization_test.dart test/learner_portfolio_honesty_test.dart test/educator_differentiation_workflow_test.dart test/educator_learners_page_test.dart test/hq_exports_page_test.dart test/hq_audit_page_test.dart test/hq_audit_page_localization_test.dart test/hq_safety_page_test.dart test/hq_admin_placeholder_actions_test.dart test/hq_analytics_page_test.dart test/hq_billing_page_test.dart` |
| Flutter offline + legacy growth ownership boundary | ✅ 46/46 focused offline sync, mission review, Firestore service, and growth-engine contract tests; analyzer clean | `cd apps/empire_flutter/app && flutter test test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart`; `flutter analyze lib/modules/missions/mission_service.dart lib/services/capability_growth_engine.dart lib/services/firestore_service.dart lib/offline/sync_coordinator.dart test/growth_engine_service_test.dart test/evidence_chain_firestore_service_test.dart test/sync_coordinator_test.dart test/evidence_chain_sync_coordinator_test.dart test/evidence_chain_offline_queue_test.dart` |
| Flutter tests | ✅ 317+ pass, 0 fail | `cd apps/empire_flutter/app && flutter test` |

---

## §16. SECURITY CHECKS

| Check | Result |
|-------|--------|
| Personal collection ownership | ✅ presenceRecords, conversations, habitLogs, drafts, offlineDemoActions |
| Site-scoped collections | ✅ incidents, sessions, enrollments, evidence |
| Default-deny on unlisted | ✅ |
| WCAG 2.2 AA form labels | ✅ CapabilityFrameworkEditor (G8) |
| COPPA guards | ✅ AI grade-band gating |
| No external AI providers | ✅ Internal-only AI inference |

---

## AUDIT COMPLETE

This audit classifies every major route (69), schema type (75), cloud function (65), and Firestore collection (136 rules / 53 typed) against Scholesa's capability-first evidence model across 8 dimensions.

**What exists and is aligned**: HQ capability/rubric/checkpoint authoring, educator evidence capture/review, proof review, rubric growth writes, portfolio linkage, and passport/guardian read paths are all real and connected.
**What exists but needs refactor**: Reporting provenance is now guarded and audited on web and Flutter shared report paths, and completed deliveries now create linked share-request lifecycle records, but the broader product still needs unified publish/share workflow treatment; legacy-pillar compatibility read models still need cleanup.
**What is fake, partial, or misleading**: Any doc or surface that still claims proof verification writes growth directly, or that all 10 gold workflows are fully certified end to end.
**What is missing**: Client-facing report/passport communication with unified share request management, consent UX, active-share/revocation surfaces, plus broader workflow-level certification with real data.
**Which role is most blocked**: Learner/guardian interpretation remains the most blocked because downstream communication is now guarded, audited, and partially governed by linked lifecycle records, but not yet managed by one end-to-end publish/share workflow in the product UI.
**Highest-risk break in evidence chain**: Workflow-level certification gaps — especially report/passport delivery that still needs client-facing consent, revocation, and one unified share-request flow across web and Flutter.
**Recommendation**: ⚠️ BETA-READY, NOT GOLD-READY.
