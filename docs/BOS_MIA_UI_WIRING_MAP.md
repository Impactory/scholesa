# BOS+MIA UI Wiring Map (Routes → Runtime → Events)
**Version:** 1.0  
**Date:** 2026-02-07  
**Purpose:** Map Scholesa pages/screens to BOS+MIA responsibilities so every UI surface contributes to sensing, estimation, control, and integrity.

---

## 1) Global wrappers (must exist)
### 1.1 Protected layout wrappers
- `AuthProvider` (identity)
- `LearningRuntimeProvider` (BOS runtime)
- `GradeBandPolicyProvider` (feature gates)
- `TelemetryProvider` (event bus)

### 1.2 Runtime responsibilities per page
Each learning page must:
- declare `RuntimeContext` (siteId, sessionOccurrenceId, missionId)
- emit required events for actions
- respect grade-band gating (UI + rate limits)

---

## 2) Learner routes (must be runtime-enabled)
### `/learner`
- Renders Student Dashboard
- Emits: `dashboard_viewed` + summary events (optional)
- Shows: nudges + next mission (control output)

### `/learner/missions`
- Emits: `mission_viewed`, `mission_selected`
- Receives: recommended mission list + difficulty suggestions

### `/learner/mission/[id]` (recommended new route)
- Session/Mission Player
- Emits: build events, checkpoint events, reflection events
- Enforces: MVL gates before submit/publish

### `/learner/coach`
- AI coach in Hint/Verify/Explain modes
- Emits: `ai_help_opened`, `ai_help_used`
- Triggers MVL when needed

---

## 3) Educator routes (must be BOS supervisory)
### `/educator`
- Shows live class progress
- Emits: `teacher_intervention_applied` when used
- Shows: concept friction + stuck points (from aggregates)

### `/educator/class/[sessionOccurrenceId]`
- Supervisory control panel
- Overrides MVL with explicit logging
- Contestability inbox

---

## 4) Parent routes (strict scope)
### `/parent`
- Read-only: progress + portfolio + weekly digest
- No raw event stream access

---

## 5) HQ routes (governance)
### `/hq`
- Aggregates, audits, configuration, retention settings
- Fairness dashboard and mitigation controls

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `BOS_MIA_UI_WIRING_MAP.md`
<!-- TELEMETRY_WIRING:END -->
