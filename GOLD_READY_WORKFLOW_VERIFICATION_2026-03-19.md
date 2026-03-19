# Gold-Ready Workflow Verification

Date: 2026-03-19
Status: Not gold-ready

This matrix applies the release gate in `.github/copilot-instructions.md` to the current repo state.
Only active product code paths were considered. A workflow is not "verified" unless the chain is real, connected, and evidence-backed end to end.

## Verification Matrix

| # | Required workflow | Status | Judgment |
| --- | --- | --- | --- |
| 1 | Curriculum admin can define capabilities and map them to units/checkpoints | Partial | HQ curriculum authoring now persists first-class capability references on missions and rubrics, but checkpoint-level mapping and downstream usage are still incomplete. |
| 2 | Teacher can run a session and quickly log capability observations during build time | Partial | Live capture exists in Flutter educator sessions and mapped evidence can now be linked forward into rubric, growth, and portfolio records, but reporting still does not consume that chain. |
| 3 | Student can submit artifacts, reflections, and checkpoint evidence | Partial | Reflection and checkpoint submission paths exist, and portfolio items load, but the submission chain is fragmented and not consistently linked to capability evidence lineage. |
| 4 | Teacher can apply a 4-level rubric tied to capabilities and process domains | Partial | Educator review now preserves capability-linked rubric scores and writes downstream growth data, but process-domain coverage and report consumption remain incomplete. |
| 5 | Proof-of-learning can be captured and reviewed | Partial | Explain-back capture exists, but the current path records a generic event and does not form a teacher-reviewed proof chain attached to capability evidence. |
| 6 | Capability growth updates over time from evidence | Partial | Educator rubric reviews now write capability mastery and append-only growth events, and linked evidence can now flow into portfolio items, but reporting still does not consume that chain. |
| 7 | Student portfolio shows real artifacts and reflections | Partial | Portfolio items can now be created from reviewed educator evidence with capability and growth provenance, but reflection linkage and family/report trust layers are still incomplete. |
| 8 | Ideation Passport/report can be generated from actual evidence | Partial | Parent bundle and child detail views now generate capability claims from evidence, growth, and verified portfolio artifacts, but there is still no full exportable Passport/report workflow with end-to-end provenance presentation. |
| 9 | AI-use is disclosed and visible where relevant | Partial | AI surfaces expose guardrails and explain-back prompts in some places, but disclosure is not consistently attached to learner artifacts, portfolio items, or reports. |
| 10 | Family/student/teacher views are understandable and trustworthy | Partial | Active views exist, but several still rely on levels, XP, snapshots, and aggregate progress rather than direct evidence-backed claims. |

## Evidence By Workflow

### 1. Capability framework and curriculum mapping

- `schema.ts` now defines a first-class `Capability` entity and missions can persist `capabilityIds` and `capabilityTitles`.
- `firestore.rules` now includes a `capabilities` collection rule so the model is real persistence, not a stray type.
- `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` now requires capability mappings during curriculum create and edit, persists them onto missions, creates missing capability records, and threads capability references into rubric criteria.
- Remaining gap: there is still no checkpoint-level mapping or downstream capability consumption in live evidence, growth, portfolio, or reporting.
- Current judgment: partial.

### 2. Live teacher observation during session

- `apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart` now supports live evidence capture into `evidenceRecords` with `capabilityId`, `capabilityLabel`, `capabilityMapped`, `phaseKey`, `portfolioCandidate`, `rubricStatus`, and `growthStatus`.
- The dialog now loads mapped capabilities by pillar from the new `capabilities` collection and only falls back to free-text capture when HQ has not authored mappings yet.
- `firestore.rules` includes read and write rules for `evidenceRecords`.
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now links matching `evidenceRecords` forward when a capability-linked rubric review is submitted by setting rubric and growth linkage fields and attaching the latest growth event.
- Remaining gap: portfolio and reporting still do not consume linked evidence provenance.
- Current judgment: partial.

### 3. Learner artifact, reflection, and checkpoint submission

- `ReflectionForm.tsx` writes learner reflections.
- `src/components/checkpoints/CheckpointSubmission.tsx` records checkpoint attempts and explicitly says the result is submitted for review.
- `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` loads learner profile, portfolio items, and credentials from Firestore.
- Missing link: the current paths do not consistently tie a learner submission to a capability claim, verification state, and portfolio evidence lineage.
- Current judgment: partial.

### 4. 4-level rubric tied to capabilities and process domains

- `apps/empire_flutter/app/lib/modules/hq_admin/hq_curriculum_page.dart` creates rubrics whose criteria include `levels: [0, 1, 2, 3, 4]`.
- `apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart` now preserves `capabilityId` and `capabilityTitle` when an educator scores rubric criteria.
- `apps/empire_flutter/app/lib/domain/models.dart` and `apps/empire_flutter/app/lib/domain/repositories.dart` persist `RubricModel` and `RubricApplicationModel`.
- Gap: rubric criteria are not keyed to a shared capability framework, and the rubric application does not update capability growth or evidence provenance.
- Current judgment: partial.

### 5. Proof-of-learning capture and review

- `src/components/sdt/AICoachScreen.tsx` exposes explain-back for AI help sessions.
- `functions/src/aiCoachExplainBack.ts` records an `explain_it_back_submitted` event.
- The current implementation is event-centric. The submitted explain-back is marked with `approved: true` in the generated payload and does not create a teacher-reviewed proof object attached to a learner capability record.
- Current judgment: partial.

### 6. Capability growth over time from evidence

- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now derives capability-level outcomes from educator rubric scores and writes both `capabilityMastery` and append-only `capabilityGrowthEvents` records.
- The same review path now updates matching `evidenceRecords` so the originating observation no longer stays stranded in `pending` when a capability-linked rubric review is applied.
- The same review path now creates or updates `portfolioItems` for reviewed `portfolioCandidate` evidence, carrying `evidenceRecordIds`, `capabilityIds`, `capabilityTitles`, `growthEventIds`, and verification metadata forward into the learner portfolio layer.
- `schema.ts` now defines `CapabilityMastery` and `CapabilityGrowthEvent` entities.
- `firestore.rules` now includes access rules for `capabilityMastery` and `capabilityGrowthEvents`.
- `apps/empire_flutter/app/lib/domain/models.dart` and `apps/empire_flutter/app/lib/domain/repositories.dart` now include Flutter models and repositories for those records.
- Remaining gap: Passport/report outputs still do not consume these growth records, so the chain is still partial rather than verified.
- Current judgment: partial.

### 7. Portfolio with real artifacts and reflections

- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart` now turns reviewed `portfolioCandidate` evidence into deterministic `portfolioItems` records keyed by the source evidence record.
- Those portfolio records now carry provenance fields including `evidenceRecordIds`, `capabilityIds`, `capabilityTitles`, `growthEventIds`, `rubricApplicationId`, and `verificationStatus`.
- `apps/empire_flutter/app/lib/modules/learner/learner_portfolio_page.dart` now surfaces linked evidence status and capability tags on learner project cards.
- Storage rules allow learner uploads to `portfolioMedia/{learnerId}/{fileName}`.
- Gap: reflection linkage and downstream AI disclosure are still incomplete across every submission and artifact path, even though Passport claims now consume session-linked learner interaction signals where available.
- Current judgment: partial.

### 8. Passport/report generated from actual evidence

- `functions/src/index.ts` now computes parent bundle evidence and growth summaries from `evidenceRecords`, `capabilityMastery`, `capabilityGrowthEvents`, `portfolioItems`, `learnerReflections`, and proof-ready mission attempts.
- The same callable now generates `ideationPassport.claims` directly from capability mastery, linked evidence, growth records, and verified portfolio artifacts.
- `apps/empire_flutter/app/lib/modules/parent/parent_child_page.dart` now renders an `Ideation Passport` section from those evidence-backed claims.
- `apps/empire_flutter/app/lib/modules/parent/parent_child_page.dart` now exports an `Ideation Passport` text report with claim-by-claim evidence counts, verification status, proof-of-learning status, AI visibility status, and direct evidence/portfolio item/mission attempt IDs.
- `apps/empire_flutter/app/lib/modules/parent/parent_portfolio_page.dart` exports portfolio summaries with evidence-linked and verification status included.
- Remaining gap: there is still no polished family-safe publishing flow, no richer formatted Passport document, and learner-facing AI-use disclosure is still only partial because claims can now surface session-linked learner AI verification gaps, but there is still no full artifact-level learner AI provenance trail across the product.
- Current judgment: partial.

### 9. Visible AI-use disclosure

- `src/components/sdt/AICoachScreen.tsx` shows guardrails and explain-back prompts.
- `AiDraftBadge.tsx` provides a visible AI draft badge.
- `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` carries `requiresExplainBack` in runtime metadata.
- Gap: AI disclosure is still not consistently attached across artifact creation, portfolio display, family reporting, and teacher review, even though family Passport claims now surface learner AI verification gaps when session-linked interaction data exists.
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