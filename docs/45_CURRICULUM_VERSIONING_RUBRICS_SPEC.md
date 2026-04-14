> **CONSTITUTIONAL TRUST: TIER 4 — UNIMPLEMENTED SPEC**
> This specification was never implemented. The curriculum versioning and
> rubric system described here does not exist in the codebase. The current
> rubric system is in CapabilityGrowthEngine (Flutter) and applyRubricToEvidence
> (Cloud Functions). Do not implement from this spec without reconciling with
> the current evidence chain architecture and the canonical K-12 curriculum
> architecture in `src/lib/curriculum/architecture.ts`.
> Flagged: March 2026 constitutional audit.

# 45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md
Curriculum versioning + rubrics (without “versioning issues”)

This prevents breaking changes to missions that already have learner attempts.

---

## 1) Mission versioning model (required)
Rule: once a mission is used in a MissionAttempt that is submitted, the mission content that attempt references must be immutable.

Implementation options:
A) Snapshot model (recommended)
- Mission is a “template”
- When published/used, create MissionSnapshot with immutable content hash
- MissionAttempt references snapshotId

B) Version field model (acceptable)
- Mission has version + immutable fields enforced by API
- MissionAttempt stores missionVersion and content hash

Snapshot model is safer.

---

## 2) Rubrics
Educators need consistent assessment language aligned to pillars.
Rubric supports:
- criteria (mapped to pillars/skills)
- levels (0-4 or similar)
- teacher comments

Rubrics should not “grade automatically”.
They support review consistency and parent-safe summaries.

---

## 3) Pacing guides
Add “session plan” templates:
- recommended time blocks
- evidence expectations
- differentiation tips

---

## 4) Marketplace compatibility
When a mission pack is sold, the pack references immutable mission snapshots or locked versions so buyers get stable content.

---

## 5) Telemetry
- mission.snapshot.created
- rubric.applied
- rubric.shared_to_parent_summary

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
