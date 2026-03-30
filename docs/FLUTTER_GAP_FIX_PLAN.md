# Flutter Evidence Chain Gap Fix Plan

**Created:** 2026-03-29
**Status:** In Progress
**Branch:** `claude/add-claude-documentation-pT4PS`

This document tracks every gap between the Flutter app and the CLAUDE.md constitution.
Each phase is ordered by dependency — later phases depend on earlier ones.
Mark tasks `[x]` as they are completed.

---

## Phase 1: Evidence Chain Models (Foundation)

**Why first:** Every other phase depends on these types existing.
**File:** `apps/empire_flutter/app/lib/domain/models.dart`
**Pattern:** `@immutable` class with `factory X.fromDoc(DocumentSnapshot)` + `Map<String,dynamic> toMap()`

### Missing Models (10)

- [ ] **1.1 `CheckpointModel`** — Fast-feedback points with explain-it-back
  - Fields: `id`, `missionId`, `learnerId`, `siteId`, `sessionId`, `skillId`, `question`, `learnerResponse`, `isCorrect`, `explainItBackRequired`, `explainItBackResponse`, `educatorId`, `score`, `createdAt`
  - Collection: `checkpointHistory`

- [ ] **1.2 `ReflectionEntryModel`** — Learner metacognitive reflections
  - Fields: `id`, `learnerId`, `siteId`, `sessionId`, `missionId`, `prompt`, `response`, `engagementRating`, `confidenceRating`, `educatorNotes`, `createdAt`
  - Collection: `learnerReflections` (partially exists — `LearnerReflectionRepository` already in repos)

- [ ] **1.3 `SkillEvidenceModel`** — Evidence linked to micro-skills
  - Fields: `id`, `learnerId`, `skillId`, `capabilityId`, `evidenceType` (artifact/observation/checkpoint/reflection), `evidenceRefId`, `educatorId`, `siteId`, `notes`, `createdAt`
  - Collection: `skillEvidence`

- [ ] **1.4 `AICoachInteractionModel`** — AI help log with guardrails
  - Fields: `id`, `learnerId`, `sessionId`, `mode` (hint/verify/debug/explain), `question`, `response`, `explainItBackRequired`, `explainItBackPassed`, `versionHistoryCheck`, `toolsUsed`, `duration`, `createdAt`
  - Collection: `aiCoachInteractions`

- [ ] **1.5 `PeerFeedbackModel`** — Structured peer review
  - Fields: `id`, `fromLearnerId`, `toLearnerId`, `missionAttemptId`, `rating`, `strengths`, `suggestions`, `siteId`, `sessionId`, `createdAt`
  - Collection: `peerFeedback`

- [ ] **1.6 `MicroSkillModel`** — Granular skill definitions with rubric levels
  - Fields: `id`, `capabilityId`, `pillarCode`, `name`, `description`, `rubricLevels` (Map of level -> descriptor), `createdAt`, `updatedAt`
  - Collection: `microSkills`

- [ ] **1.7 `MissionVariantModel`** — Difficulty-differentiated missions
  - Fields: `id`, `missionId`, `difficultyLevel`, `description`, `adjustedCheckpoints`, `scaffolding`, `createdAt`
  - Collection: embedded in missions or `missionVariants`

- [ ] **1.8 `ShowcaseSubmissionModel`** — Public showcase of learner work
  - Fields: `id`, `learnerId`, `portfolioItemId`, `title`, `description`, `visibility` (public/school/class), `approvalStatus`, `approvedBy`, `createdAt`
  - Collection: `showcaseSubmissions`

- [ ] **1.9 `WeeklyGoalModel`** — Learner goal-setting
  - Fields: `id`, `learnerId`, `siteId`, `weekStartDate`, `goalText`, `targetCapabilityId`, `status` (active/completed/abandoned), `reflectionOnCompletion`, `createdAt`
  - Collection: `weeklyGoals`

- [ ] **1.10 `ProofOfLearningBundleModel`** — Assembled proof bundle
  - Fields: `id`, `learnerId`, `portfolioItemId`, `capabilityId`, `hasExplainItBack`, `hasOralCheck`, `hasMiniRebuild`, `explainItBackExcerpt`, `oralCheckExcerpt`, `miniRebuildExcerpt`, `verificationStatus` (missing/partial/verified), `educatorVerifierId`, `version`, `createdAt`, `updatedAt`
  - Collection: `proofOfLearningBundles`

**Insertion point:** After existing evidence models (~line 900+ in models.dart, after `CapabilityGrowthEventModel`)

---

## Phase 2: Evidence Chain Repositories

**Why second:** Services and UI need repository abstractions to read/write evidence.
**File:** `apps/empire_flutter/app/lib/domain/repositories.dart`
**Pattern:** Class with `CollectionReference get _col`, CRUD methods (`getById`, `listByLearner`, `listBySite`, `create`, `upsert`)

### Missing Repositories (8)

- [ ] **2.1 `CheckpointRepository`** — CRUD for checkpoints
  - Methods: `create(CheckpointModel)`, `listByLearnerAndMission(learnerId, missionId)`, `listBySession(sessionId)`, `getById(id)`

- [ ] **2.2 `SkillEvidenceRepository`** — CRUD for skill evidence
  - Methods: `create(SkillEvidenceModel)`, `listByLearner(learnerId)`, `listBySkill(skillId)`, `getById(id)`

- [ ] **2.3 `AICoachInteractionRepository`** — Log AI interactions
  - Methods: `create(AICoachInteractionModel)`, `listByLearner(learnerId)`, `listBySession(sessionId)`

- [ ] **2.4 `PeerFeedbackRepository`** — Peer review CRUD
  - Methods: `create(PeerFeedbackModel)`, `listForLearner(toLearnerId)`, `listByAuthor(fromLearnerId)`

- [ ] **2.5 `ProofOfLearningBundleRepository`** — Proof bundle CRUD
  - Methods: `create(ProofOfLearningBundleModel)`, `update(ProofOfLearningBundleModel)`, `getByPortfolioItem(portfolioItemId)`, `listByLearner(learnerId)`

- [ ] **2.6 `RubricApplicationRepository`** — Educator rubric judgments
  - Methods: `create(RubricApplicationModel)`, `listByLearner(learnerId)`, `listByEducator(educatorId)`, `listByCapability(capabilityId)`
  - Note: `RubricApplicationModel` exists in models.dart already — verify and wire

- [ ] **2.7 `EvidenceRecordRepository`** — Educator evidence records
  - Methods: `create(EvidenceRecordModel)`, `listBySite(siteId)`, `listByLearner(learnerId)`, `getById(id)`

- [ ] **2.8 `ShowcaseSubmissionRepository`** — Showcase CRUD
  - Methods: `create(ShowcaseSubmissionModel)`, `listByLearner(learnerId)`, `listApproved(siteId)`

**Insertion point:** After `CapabilityGrowthEventRepository` in repositories.dart

---

## Phase 3: Firestore Service Methods

**Why third:** Connects repositories to the direct Firestore service used by offline sync and UI.
**File:** `apps/empire_flutter/app/lib/services/firestore_service.dart`
**Pattern:** `Future<String> submitX({required fields}) async { ... _firestore.collection('x').add({...}); }`

### Missing Methods (grouped by evidence chain step)

#### Capture
- [ ] **3.1** `submitCheckpointResult({learnerId, missionId, sessionId, skillId, question, response, isCorrect, explainItBackRequired})`
- [ ] **3.2** `submitReflection({learnerId, sessionId, missionId, prompt, response, engagementRating, confidenceRating})`
- [ ] **3.3** `logAICoachInteraction({learnerId, sessionId, mode, question, response, explainItBackRequired, toolsUsed})`
- [ ] **3.4** `submitPeerFeedback({fromLearnerId, toLearnerId, missionAttemptId, rating, strengths, suggestions})`

#### Verify
- [ ] **3.5** `createProofOfLearningBundle({learnerId, portfolioItemId, capabilityId})`
- [ ] **3.6** `updateProofOfLearningBundle({bundleId, hasExplainItBack, hasOralCheck, hasMiniRebuild, excerpts})`
- [ ] **3.7** `verifyProofOfLearning({bundleId, educatorId, verificationStatus})`

#### Interpret
- [ ] **3.8** `applyRubric({learnerId, capabilityId, educatorId, level, feedback, evidenceRefIds})`
- [ ] **3.9** `updateCapabilityMastery({learnerId, capabilityId, newLevel, educatorId})` — write to `capabilityMastery`
- [ ] **3.10** `createCapabilityGrowthEvent({learnerId, capabilityId, fromLevel, toLevel, educatorId, rubricApplicationId, evidenceIds})` — append-only write to `capabilityGrowthEvents`

#### Read helpers
- [ ] **3.11** `getCheckpointsByMission(missionId)` / `getCheckpointsByLearner(learnerId)`
- [ ] **3.12** `getPortfolioItemsByLearner(learnerId)`
- [ ] **3.13** `getProofBundlesByLearner(learnerId)`
- [ ] **3.14** `getEvidenceRecordsBySite(siteId)`
- [ ] **3.15** `getCapabilityMasteryByLearner(learnerId)`
- [ ] **3.16** `getGrowthEventsByLearner(learnerId)`

**Insertion point:** After `getLearnerSkillAssessments()` (~line 510), before "GENERIC OPERATIONS" comment

---

## Phase 4: Offline Queue + Sync

**Why fourth:** Evidence capture must work offline for classroom use.
**Files:**
- `apps/empire_flutter/app/lib/offline/offline_queue.dart` (OpType enum, line 14)
- `apps/empire_flutter/app/lib/offline/sync_coordinator.dart` (processOperation switch, ~line 140)

### New OpType Values
- [ ] **4.1** Add to `OpType` enum:
  ```
  checkpointSubmit,
  reflectionSubmit,
  aiCoachLog,
  peerFeedbackSubmit,
  portfolioItemCreate,
  proofBundleCreate,
  proofBundleUpdate,
  rubricApply,
  ```

### New Sync Cases
- [ ] **4.2** Add `case OpType.checkpointSubmit:` → write to `checkpointHistory` collection
- [ ] **4.3** Add `case OpType.reflectionSubmit:` → write to `learnerReflections` collection
- [ ] **4.4** Add `case OpType.aiCoachLog:` → write to `aiCoachInteractions` collection
- [ ] **4.5** Add `case OpType.peerFeedbackSubmit:` → write to `peerFeedback` collection
- [ ] **4.6** Add `case OpType.portfolioItemCreate:` → write to `portfolioItems` collection
- [ ] **4.7** Add `case OpType.proofBundleCreate:` → write to `proofOfLearningBundles` collection
- [ ] **4.8** Add `case OpType.proofBundleUpdate:` → update in `proofOfLearningBundles` collection
- [ ] **4.9** Add `case OpType.rubricApply:` → write to `rubricApplications` + trigger mastery update

---

## Phase 5: Evidence Chain UI Pages

**Why fifth:** Users need screens to capture, verify, and interpret evidence.
**Directory:** `apps/empire_flutter/app/lib/modules/`
**Pattern:** `StatefulWidget` with `_PageState`, uses `FirestoreService` or repository, wrapped in `RoleGate`

### New Pages

#### Learner Evidence Capture
- [ ] **5.1** `lib/modules/learner/checkpoint_submission_page.dart` — Answer checkpoint questions, explain-it-back
- [ ] **5.2** `lib/modules/learner/reflection_journal_page.dart` — Metacognitive reflection with prompts
- [ ] **5.3** `lib/modules/learner/proof_assembly_page.dart` — Assemble ExplainItBack + OralCheck + MiniRebuild for portfolio items
- [ ] **5.4** `lib/modules/learner/peer_feedback_page.dart` — Give structured feedback to peers

#### Educator Evidence Review
- [ ] **5.5** `lib/modules/educator/rubric_application_page.dart` — Apply rubric levels to learner evidence, write growth events
- [ ] **5.6** `lib/modules/educator/observation_capture_page.dart` — Quick evidence capture (10-second rule), wire existing `EducatorFeedbackForm` concept
- [ ] **5.7** `lib/modules/educator/proof_verification_page.dart` — Review and verify learner proof-of-learning bundles

#### HQ Capability Framework
- [ ] **5.8** `lib/modules/hq_admin/capability_framework_page.dart` — Define capabilities, progression descriptors, map to pillars
- [ ] **5.9** `lib/modules/hq_admin/rubric_builder_page.dart` — Create/edit rubric templates with levels and descriptors

#### Parent Evidence View
- [ ] **5.10** `lib/modules/parent/growth_timeline_page.dart` — Rich growth timeline (not flat cards), proof badges, AI disclosure

---

## Phase 6: Route Registration

**Why sixth:** Pages must be reachable.
**File:** `apps/empire_flutter/app/lib/router/app_router.dart`
**Pattern:** Add to `kKnownRoutes` map + `routes: <RouteBase>[...]` list with `RoleGate`

### New Routes

- [ ] **6.1** `/learner/checkpoints` → `CheckpointSubmissionPage` (roles: learner)
- [ ] **6.2** `/learner/reflections` → `ReflectionJournalPage` (roles: learner)
- [ ] **6.3** `/learner/proof-assembly` → `ProofAssemblyPage` (roles: learner)
- [ ] **6.4** `/learner/peer-feedback` → `PeerFeedbackPage` (roles: learner)
- [ ] **6.5** `/educator/observations` → `ObservationCapturePage` (roles: educator)
- [ ] **6.6** `/educator/rubrics/apply` → `RubricApplicationPage` (roles: educator)
- [ ] **6.7** `/educator/proof-review` → `ProofVerificationPage` (roles: educator)
- [ ] **6.8** `/hq/capability-frameworks` → `CapabilityFrameworkPage` (roles: hq)
- [ ] **6.9** `/hq/rubric-builder` → `RubricBuilderPage` (roles: hq)
- [ ] **6.10** `/parent/growth-timeline` → `GrowthTimelinePage` (roles: parent)

---

## Phase 7: Growth Engine (Write Path)

**Why seventh:** Connects evidence capture to capability growth.
**Location:** New service file `apps/empire_flutter/app/lib/services/growth_engine_service.dart`

### Growth Write Logic

- [ ] **7.1** Create `GrowthEngineService` class
- [ ] **7.2** Method: `onRubricApplied(RubricApplicationModel)` →
  1. Read current `capabilityMastery` for learner+capability
  2. Compute new mastery level from rubric score
  3. Write updated `capabilityMastery` doc
  4. Append `capabilityGrowthEvent` (immutable, educator attribution)
- [ ] **7.3** Method: `onCheckpointCompleted(CheckpointModel)` →
  1. If checkpoint maps to a micro-skill, update `skillMastery`
  2. If skill maps to a capability, check threshold for mastery bump
- [ ] **7.4** Method: `onProofVerified(ProofOfLearningBundleModel)` →
  1. Update portfolio item proof status
  2. Optionally bump capability confidence

---

## Phase 8: Localization Completion

**Why eighth:** Doesn't block functionality but required for production.
**File:** `apps/empire_flutter/app/lib/i18n/app_strings.dart`

### Missing Locales
- [ ] **8.1** Add `es` (Spanish) translations for all existing keys
- [ ] **8.2** Add `th` (Thai) translations for all existing keys

### New String Sections (all 5 locales)
- [ ] **8.3** `evidence.*` — checkpoint, reflection, skill evidence, peer feedback strings
- [ ] **8.4** `capability.*` — framework, mastery, growth, progression descriptor strings
- [ ] **8.5** `portfolio.*` — curation, proof assembly, showcase strings
- [ ] **8.6** `rubric.*` — builder, application, level descriptor strings
- [ ] **8.7** `proof.*` — ExplainItBack, OralCheck, MiniRebuild strings

---

## Phase 9: Dashboard Integration

**Why ninth:** Evidence features need to appear on role dashboards.
**File:** `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`

### Dashboard Cards to Add

- [ ] **9.1** Learner dashboard: "My Reflections" card → `/learner/reflections`
- [ ] **9.2** Learner dashboard: "Checkpoints" card → `/learner/checkpoints`
- [ ] **9.3** Learner dashboard: "Proof of Learning" card → `/learner/proof-assembly`
- [ ] **9.4** Educator dashboard: "Quick Observation" card → `/educator/observations`
- [ ] **9.5** Educator dashboard: "Apply Rubric" card → `/educator/rubrics/apply`
- [ ] **9.6** Educator dashboard: "Verify Proof" card → `/educator/proof-review`
- [ ] **9.7** HQ dashboard: "Capability Frameworks" card → `/hq/capability-frameworks`
- [ ] **9.8** HQ dashboard: "Rubric Templates" card → `/hq/rubric-builder`
- [ ] **9.9** Parent dashboard: "Growth Timeline" card → `/parent/growth-timeline`

---

## Phase 10: Tests

**Why last:** Test what's built.
**Directory:** `apps/empire_flutter/app/test/`

### Evidence Chain Test Files

- [ ] **10.1** `test/models/checkpoint_model_test.dart` — fromDoc/toMap round-trip
- [ ] **10.2** `test/models/reflection_entry_model_test.dart`
- [ ] **10.3** `test/models/proof_of_learning_bundle_model_test.dart`
- [ ] **10.4** `test/models/ai_coach_interaction_model_test.dart`
- [ ] **10.5** `test/repositories/checkpoint_repository_test.dart` — CRUD with fake_cloud_firestore
- [ ] **10.6** `test/repositories/proof_bundle_repository_test.dart`
- [ ] **10.7** `test/services/growth_engine_service_test.dart` — rubric -> mastery -> growth event chain
- [ ] **10.8** `test/offline/evidence_chain_sync_test.dart` — queue + sync for evidence ops
- [ ] **10.9** `test/pages/checkpoint_submission_page_test.dart` — widget test
- [ ] **10.10** `test/pages/rubric_application_page_test.dart` — widget test

---

## Progress Tracker

| Phase | Items | Done | Status |
|-------|-------|------|--------|
| 1. Models | 10 | 10 | COMPLETE |
| 2. Repositories | 8 | 8 | COMPLETE |
| 3. Firestore Service | 16 | 16 | COMPLETE |
| 4. Offline Queue + Sync | 9 | 9 | COMPLETE |
| 5. UI Pages | 10 | 10 | COMPLETE |
| 6. Routes | 10 | 10 | COMPLETE |
| 7. Growth Engine | 4 | 4 | COMPLETE |
| 8. Localization | 7 | 7 | COMPLETE |
| 9. Dashboards | 9 | 9 | COMPLETE |
| 10. Tests | 10 | 2 | In progress |
| **TOTAL** | **93** | **85** | |

---

## Confidence Target

After all phases complete, expected confidence ratings:

| Area | Current | Target |
|------|---------|--------|
| Evidence Capture | MEDIUM | HIGH |
| Evidence Verification | LOW | HIGH |
| Evidence Interpretation | LOW | HIGH |
| Evidence Communication | MEDIUM | HIGH |
| Schema Alignment | MEDIUM (5/15) | HIGH (15/15) |
| Offline-First | MEDIUM (6 ops) | HIGH (14 ops) |
| Firestore Integration | MEDIUM | HIGH |
| Localization | MEDIUM (3/5) | HIGH (5/5) |
| Testing | MEDIUM | HIGH |
