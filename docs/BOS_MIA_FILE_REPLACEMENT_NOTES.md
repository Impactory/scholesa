# BOS+MIA MD Files — What They Replace / Supersede
**Version:** 1.0  
**Date:** 2026-02-07  
**Purpose:** Track how the new BOS+MIA documents relate to (and replace parts of) existing Scholesa implementation docs.

---

## 1) New files created
- `BOS_MIA_REWIRE_PLAN.md`
- `BOS_MIA_EVENT_SCHEMA.md`
- `BOS_MIA_DATA_MODEL.md`
- `BOS_MIA_UI_WIRING_MAP.md`

---

## 2) Existing files impacted (superseded sections)
> These new BOS+MIA files are intended to **supersede specific sections** of existing plans—without deleting them.

### 2.1 `MASTER_IMPLEMENTATION_GUIDE.md` — superseded areas
- **Telemetry pattern** → superseded by `BOS_MIA_EVENT_SCHEMA.md`
- **Age band differentiation pattern** → kept, but should be referenced by `BOS_MIA_UI_WIRING_MAP.md` as the enforcement map
- **Data model guidance** → superseded by `BOS_MIA_DATA_MODEL.md` where BOS state and MVL are required

### 2.2 `PHASE2_IMPLEMENTATION_PLAN.md` — superseded areas
- Skill/badge progress tracking events and schema → superseded by `BOS_MIA_EVENT_SCHEMA.md`
- Any collection naming guidance for analytics events → superseded by `BOS_MIA_DATA_MODEL.md`

### 2.3 `PHASE3_IMPLEMENTATION_PLAN.md` — superseded areas
- Collaboration telemetry events and their properties → superseded by `BOS_MIA_EVENT_SCHEMA.md` (collab section)
- Any security assumptions for immutable messaging → should be implemented with the same “append-only events” principle in `interactionEvents`

### 2.4 `PHASES_4_TO_10_ROADMAP.md` — superseded areas
- AI Coach requirements → must now be MVL-aware and integrity-gated per `BOS_MIA_REWIRE_PLAN.md`
- Teacher analytics requirements → must be derived from orchestration logs and features in `BOS_MIA_DATA_MODEL.md`

---

## 3) Files NOT replaced
- `MOTIVATION_ENGINE_VIBE_INSTRUCTIONS.md` is **complementary**:
  - Use it to ensure the BOS+MIA interventions keep the correct student-facing tone.
  - The BOS+MIA docs define the runtime + evidence loop; the motivation doc defines the human experience.

---

## 4) How to use these docs in development
1) Start with `BOS_MIA_REWIRE_PLAN.md` to restructure the app runtime.
2) Implement instrumentation strictly by `BOS_MIA_EVENT_SCHEMA.md`.
3) Update Firestore/Storage and rules using `BOS_MIA_DATA_MODEL.md`.
4) Rewire routes and layouts using `BOS_MIA_UI_WIRING_MAP.md`.
5) Validate UX tone with `MOTIVATION_ENGINE_VIBE_INSTRUCTIONS.md`.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `BOS_MIA_FILE_REPLACEMENT_NOTES.md`
<!-- TELEMETRY_WIRING:END -->
