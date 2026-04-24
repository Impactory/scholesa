# Gold-Ready Workflow Verification

Date: 2026-04-22
Status: Not gold-ready

This is a failure-against-the-gold-gate verification artifact, not a gold certification note.
The title reflects the gate being tested, not the outcome achieved.

This matrix applies the release gate in `.github/copilot-instructions.md` to the current repo state.
Only active product code paths were considered. A workflow is not "verified" unless the chain is real, connected, and evidence-backed end to end.

## Update — 2026-04-22

- `verifyProofOfLearning` is now an **authenticity boundary only**: it updates proof state and canonical linkage, but no longer writes growth or mastery directly.
- Verified proof now hands off canonically into `/educator/rubrics/apply?portfolioItemId=...`, and `applyRubricToEvidence` updates that **same verified portfolio item** in place instead of forking provenance into duplicate rubric artifacts.
- `/educator/missions/review` now forwards linked `portfolioItemId` into rubric application when available, preserving artifact lineage on mission-review flows too.
- Proof-linked checkpoint review now uses `pending_proof`: blocked checkpoints stay visible until proof is verified, and educators can then record growth from the same review surface through `processCheckpointMasteryUpdate`.
- `/educator/evidence` now reuses the canonical portfolio item created for portfolio-candidate observations when educators open rubric review from the recent-observations list.
- `LearnerEvidenceTimelineRenderer` now back-links growth from `linkedEvidenceRecordIds`, so direct educator-observation evidence can show the growth it triggered.
- `LearnerEvidenceTimelineRenderer` now renders `proofOfLearningBundles` as standalone learner-visible timeline entries instead of only attaching proof status to linked portfolio items.
- These changes strengthen the chain materially, but the platform is still **not gold-ready** because workflow-level verification and downstream communication surfaces remain incomplete.

## Verification Matrix

| # | Required workflow | Status | Judgment |
| --- | --- | --- | --- |
| 1 | Curriculum admin can define capabilities and map them to units/checkpoints | Partial | HQ curriculum authoring now persists first-class capability references on missions and rubrics, but checkpoint-level mapping and downstream usage are still incomplete. |
| 2 | Teacher can run a session and quickly log capability observations during build time | Partial | Web educator capture now uses educator-scoped live session occurrences, attendance-first rosters, canonical `sessionOccurrenceId`, creates canonical portfolio candidates, and reuses that same artifact during later rubric review, but full downstream reporting and mobile/offline parity are still incomplete. |
| 3 | Student can submit artifacts, reflections, and checkpoint evidence | Partial | Reflection and checkpoint submission paths create stronger portfolio linkage than before, and proof-linked checkpoints now stay reviewable until growth can be truthfully recorded, but learner submission lineage is still not uniformly canonical across every path. |
| 4 | Teacher can apply a 4-level rubric tied to capabilities and process domains | Partial | Educator rubric review now preserves canonical `portfolioItemId` provenance from proof review and mission review, and writes downstream growth data through the callable path, but full route parity and report consumption remain incomplete. |
| 5 | Proof-of-learning can be captured and reviewed | Partial | Proof review is now a teacher-reviewed authenticity boundary with excerpt capture and canonical handoff into rubric application on the same portfolio item, but broader workflow certification across all evidence surfaces remains incomplete. |
| 6 | Capability growth updates over time from evidence | Partial | Growth writes now remain rubric/checkpoint-owned, proof-linked checkpoints no longer dead-end before growth can be recorded, canonical artifact linkage is preserved, and the learner timeline now consumes direct evidence-linked growth plus standalone proof bundles more truthfully, but broader report communication still does not consume all provenance end to end. |
| 7 | Student portfolio shows real artifacts and reflections | Partial | Portfolio items now preserve verified-proof and rubric provenance more truthfully, especially for educator observations and mission review, but reflection linkage and non-mission artifact parity are still incomplete. |
| 8 | Ideation Passport/report can be generated from actual evidence | Partial | Parent/learner passport surfaces now read real evidence and growth with richer claim, artifact, and growth provenance in the export path; both web passport routes provide dedicated PDF/share actions; and Flutter parent child detail now offers passport export/share actions too, but the reporting chain still lacks one unified publishable family-safe workflow and uniform parity across every product path. |
| 9 | AI-use is disclosed and visible where relevant | Partial | Mission-reviewed artifacts now carry direct learner AI disclosure, family portfolio surfaces prefer that artifact-level provenance over fallback inference, and manual learner portfolio curation now preserves AI detail text too, but disclosure is still not attached consistently across every learner submission and reporting path. |
| 10 | Family/student/teacher views are understandable and trustworthy | Partial | Active views exist, but several still rely on levels, XP, snapshots, and aggregate progress rather than direct evidence-backed claims. |

## Evidence By Workflow

### 1. Capability framework and curriculum mapping

- `schema.ts` now defines a first-class `Capability` entity and missions can persist `capabilityIds` and `capabilityTitles`.
- `firestore.rules` now includes a `capabilities` collection rule so the model is real persistence, not a stray type.
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` now requires capability mappings during curriculum create and edit, persists them onto missions, creates missing capability records, and threads capability references into rubric criteria.
- Remaining gap: checkpoint mapping exists, but downstream learner/guardian communication is still incomplete and not every live evidence path consumes that structure uniformly.
- Current judgment: partial.

### 2. Live teacher observation during session

- `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` now supports live evidence capture into `evidenceRecords` with `capabilityId`, `capabilityLabel`, `capabilityMapped`, `phaseKey`, `portfolioCandidate`, `rubricStatus`, and `growthStatus`.
- The dialog now loads mapped capabilities by pillar from the new `capabilities` collection and only falls back to free-text capture when HQ has not authored mappings yet.
- `firestore.rules` includes read and write rules for `evidenceRecords`.
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now links matching `evidenceRecords` forward when a capability-linked rubric review is submitted by setting rubric and growth linkage fields and attaching the latest growth event.
- Remaining gap: portfolio/reporting still do not consume linked evidence provenance uniformly across every web, Flutter, and export path.
- Current judgment: partial.

### 3. Learner artifact, reflection, and checkpoint submission

- `ReflectionForm.tsx` writes learner reflections.
- `src/components/checkpoints/CheckpointSubmission.tsx` records checkpoint attempts and explicitly says the result is submitted for review.
- `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` loads learner profile, portfolio items, and credentials from Firestore.
- Missing link: the current paths are stronger than the March snapshot, but learner submission lineage is still not uniformly tied to capability claims, verification state, and portfolio evidence lineage across every path.
- Current judgment: partial.

### 4. 4-level rubric tied to capabilities and process domains

- `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` creates rubrics whose criteria include `levels: [0, 1, 2, 3, 4]`.
- `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` now preserves `capabilityId` and `capabilityTitle` when an educator scores rubric criteria.
- `apps/empire_flutter/app/lib/domain/models.dart` and `apps/empire_flutter/app/lib/domain/repositories.dart` persist `RubricModel` and `RubricApplicationModel`.
- Gap: rubric application now updates growth and preserves canonical portfolio provenance on key educator paths, but route parity and report consumption remain incomplete.
- Current judgment: partial.

### 5. Proof-of-learning capture and review

- `src/components/sdt/AICoachScreen.tsx` exposes explain-back for AI help sessions.
- `functions/src/aiCoachExplainBack.ts` records an `explain_it_back_submitted` event.
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` now requires learners to complete proof-of-learning fields and declare whether AI supported the mission before submission.
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now persists learner AI disclosure directly into `proofOfLearningBundles` and carries a minimal disclosure summary onto submitted mission attempts.
- The current implementation is now teacher-reviewed and canonically linked forward into rubric application on the same portfolio item, but proof review still needs wider full-flow certification across all evidence surfaces before this workflow can be called verified.
- Current judgment: partial.

### 6. Capability growth over time from evidence

- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now derives capability-level outcomes from educator rubric scores and writes both `capabilityMastery` and append-only `capabilityGrowthEvents` records.
- The same review path now updates matching `evidenceRecords` so the originating observation no longer stays stranded in `pending` when a capability-linked rubric review is applied.
- The same review path now creates or updates `portfolioItems` for reviewed `portfolioCandidate` evidence, carrying `evidenceRecordIds`, `capabilityIds`, `capabilityTitles`, `growthEventIds`, and verification metadata forward into the learner portfolio layer.
- `schema.ts` now defines `CapabilityMastery` and `CapabilityGrowthEvent` entities.
- `firestore.rules` now includes access rules for `capabilityMastery` and `capabilityGrowthEvents`.
- `apps/empire_flutter/app/lib/domain/models.dart` and `apps/empire_flutter/app/lib/domain/repositories.dart` now include Flutter models and repositories for those records.
- Remaining gap: Passport/report outputs still do not consume these growth records and evidence backlinks end to end, so the chain is still partial rather than verified.
- Current judgment: partial.

### 7. Portfolio with real artifacts and reflections

- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now turns reviewed `portfolioCandidate` evidence into deterministic `portfolioItems` records keyed by the source evidence record.
- Those portfolio records now carry provenance fields including `evidenceRecordIds`, `capabilityIds`, `capabilityTitles`, `growthEventIds`, `rubricApplicationId`, and `verificationStatus`.
- `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` now surfaces linked evidence status and capability tags on learner project cards.
- `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` now surfaces portfolio proof-of-learning status, AI visibility status, capability evidence tags, verification prompts, and provenance IDs in family-facing artifact details and exports.
- Storage rules allow learner uploads to `portfolioMedia/{learnerId}/{fileName}`.
- Gap: reflection linkage and non-mission artifact submission paths are still incomplete, even though verified-proof and mission-reviewed portfolio artifacts now carry stronger rubric/growth provenance into family-facing output.
- Current judgment: partial.

### 8. Passport/report generated from actual evidence

- `functions/src/index.ts` now computes parent bundle evidence and growth summaries from `evidenceRecords`, `capabilityMastery`, `capabilityGrowthEvents`, `portfolioItems`, `learnerReflections`, and proof-ready mission attempts.
- The same callable now generates `ideationPassport.claims` directly from capability mastery, linked evidence, growth records, and reviewed portfolio artifacts where rubric-linked provenance is available.
- `apps/empire_flutter/app/lib/modules/parent/parent_child_page.dart` now renders an `Ideation Passport` section from those evidence-backed claims.
- `apps/empire_flutter/app/lib/modules/parent/parent_child_page.dart` now exports an `Ideation Passport` text report with claim-by-claim evidence counts, verification status, proof-of-learning status, AI visibility status, and direct evidence/portfolio item/mission attempt IDs.
- `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` exports portfolio summaries with evidence-linked, proof-of-learning, AI visibility, and provenance details included.
- Parent and learner passport/report surfaces now consume richer capability-growth backlinks, review attribution, proof-method context, evidence/portfolio/mission linkage counts, and exported portfolio/growth detail from the callable payloads.
- Blockers that keep this workflow partial: learner and parent web passport routes plus the Flutter parent child passport surface now have concrete export/share actions, but there is still no single polished publishable family-safe Passport workflow or perfectly uniform provenance/display parity across every remaining product path.
- Remaining gap: publish/share is still route-specific rather than unified, and AI/provenance disclosure is stronger for canonically linked artifacts than for every remaining product path.
- Current judgment: partial.

### 9. Visible AI-use disclosure

- `src/components/sdt/AICoachScreen.tsx` shows guardrails and explain-back prompts.
- `AiDraftBadge.tsx` provides a visible AI draft badge.
- `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` carries `requiresExplainBack` in runtime metadata.
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart` and `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now capture learner AI-use declaration and details in the proof bundle before mission submission.
- Gap: AI disclosure is still not consistently attached at creation time across every artifact submission and reporting path, even though mission review now stamps direct learner disclosure onto portfolio artifacts and family portfolio and Passport claim surfaces prefer that provenance before falling back to session-linked interaction evidence.
- Current judgment: partial.

### 10. Trustworthy family, student, and teacher views

- `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` now frames the session as a studio flow and supports live evidence capture.
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart` was updated earlier in this thread to surface an evidence loop.
- `apps/empire_flutter/app/lib/modules/parent/parent_summary_page.dart` now asks evidence-first family questions.
- `functions/src/index.ts` now returns evidence-backed parent summaries and claim-based Passport data for reviewed observations, capability growth, verified artifacts, and reflections.
- Remaining gap: legacy level/xp/streak fields still exist for compatibility, and family reporting is not yet a fully polished evidence-traceable Passport/report surface.
- Current judgment: partial.

## Honesty Report

### A. Reusable

- Firestore persistence for sessions, missions, portfolio items, reflections, rubric applications, and skill mastery.
- Active Flutter role surfaces for educator, learner, and parent.
- New `evidenceRecords` capture path and rules.
- AI explain-back primitives.

### B. Misaligned

- Legacy level/xp/streak constructs still exist in family payloads for compatibility.
- Mission-oriented rubric flows without capability lineage.
- Passport/report workflows still stop short of a complete shareable/exportable claim-by-claim report surface.

### C. Fake or partial

- Capability labels that are free text rather than references into a defined capability framework.
- Explain-back recorded as telemetry without full proof review workflow.
- Reporting surfaces now use more real evidence and portfolio provenance, but the full report/export workflow is still incomplete.

### D. Missing

- Full Passport/report export and publishing workflow from actual evidence provenance.

### E. Gold-ready blockers

- The capability model and growth records now anchor reviewed educator evidence into portfolio items, but reporting still does not consume that chain end to end.
- Family reporting and Passport claims are more evidence-backed now, but the full report/export workflow still does not consume the chain end to end.
- AI transparency is not consistently visible across all relevant learner outputs.

## Recommended build order from here

1. Replace free-text capability labels with first-class capability entities and mappings.
2. Wire `evidenceRecords` into rubric review and capability update logic.
3. Link verified evidence and growth records into learner portfolio items.
4. Rebuild Passport and family reporting from evidence provenance, not rollups.
