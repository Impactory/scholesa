# BOS Requirement Audit — 2026-03-03

## Scope
Audit baseline: `docs/BOS_MIA_HOW_TO_IMPLEMENT.md` (Prime Directive, §2, §3, §4, §5).

Assessment target: current Scholesa BOS + AI runtime implementation across Flutter + Cloud Functions.

## Verdict
- **Conversational AI:** **PASS** (implemented in both callable and voice runtime paths).
- **"Fully wired into BOS requirements" claim:** **NOT YET (PARTIAL)**.

Overall status: **8 PASS / 4 PARTIAL / 2 GAP** for the highest-impact BOS requirements below.

## Requirement Matrix

| Requirement | Status | Evidence | Notes |
|---|---|---|---|
| AI Coach live behind stable API contract | PASS | `functions/src/index.ts` (`genAiCoach`), `apps/empire_flutter/app/lib/runtime/bos_service.dart` (`callAiCoach`) | Contract currently stable and consumed by client. |
| AI emits `ai_help_opened` + `ai_help_used` | PASS | `functions/src/index.ts` (`genAiCoach` event writes), `functions/src/voiceSystem.ts` (`recordBosInteractionEvent` for `ai_help_opened` / `ai_help_used`) | Emitted on callable and voice HTTP paths. |
| Reliability + autonomy risk gates exist | PASS | `functions/src/index.ts` (`computeReliabilityRisk`, `computeAutonomyRisk`, `checkAndMaybeCreateMvl`), `functions/src/bosRuntime.ts` risk pipeline | Implemented as v1 heuristics and used in gating decisions. |
| Learner timeline reconstructable (events → features → state → interventions → outcomes) | PASS | `functions/src/bosRuntime.ts` writes `interactionEvents`, `fdmFeatures`, `orchestrationStates`, `interventions`, `mvlEpisodes`; score/override/contestability endpoints | Core chain exists and is queryable. |
| Teacher override + contestability workflow | PASS | `functions/src/bosRuntime.ts` (`bosTeacherOverrideMvl`, `bosContestability`), `apps/empire_flutter/app/lib/runtime/bos_service.dart` | Minimum viable supervisory + contestability flow implemented. |
| Required event categories represented (mission/checkpoint/metacognition/AI/MVL) | PARTIAL | `apps/empire_flutter/app/lib/runtime/bos_event_bus.dart` allowed events + `mvl_gate_widget.dart` emits evidence/pass/fail | `mvl_gate_triggered` is emitted server-side in `genAiCoach`, but not consistently from all MVL creation paths. |
| Endpoint 1 `ingest-event` with validation + write path | PARTIAL | `functions/src/bosRuntime.ts` (`bosIngestEvent`) exists; Flutter `BosEventBus` writes directly to Firestore | Ingestion function exists but client primary path bypasses server validation/sanitization contract. |
| Required CRUD endpoints 2–8 implemented | PASS | `functions/src/bosRuntime.ts` exports + `functions/src/index.ts` re-exports + Flutter service wrappers | Implemented as callable functions (not REST paths). |
| Every write includes `siteId` | PARTIAL | BOS writes generally include `siteId`; verify all legacy/non-BOS telemetry writes separately | BOS runtime path compliant; broader repository has mixed legacy patterns. |
| Server timestamps only | PARTIAL | Many writes use `FieldValue.serverTimestamp()` in server + client BOS envelopes | Client direct writes use server timestamp sentinel, but strict interpretation favors server-ingest-only. |
| Sensor fusion: no single proxy for high-salience MVL | GAP | `functions/src/index.ts` enforces ≥2 risk sources; `functions/src/bosRuntime.ts` can trigger MVL when `intervention.triggerMvl` from integrity-only | `bosRuntime` path allows single-source MVL trigger via `computeIntervention` integrity condition. |
| Weekly fairness audits collection (`fairnessAudits`) | GAP | Collection referenced in docs/comments; no active writer found in runtime code | Requires scheduled audit writer and read path. |
| Privacy-minimized telemetry payloads | PASS | `functions/src/bosRuntime.ts` payload sanitizer, `functions/src/voiceSystem.ts` redaction + derived metrics | Good baseline in server paths. |
| Conversational, kid-friendly spoken AI | PASS | `functions/src/index.ts` (`applyKidFriendlyConversationalTone`), `functions/src/voiceSystem.ts` persona + tone shaping, `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` voice-first flow | Behavior implemented end-to-end for learner-facing responses. |

## Priority Remediation (to reach “fully wired”)

1. **Unify ingestion through server endpoint**
   - Route Flutter BOS event bus writes through `bosIngestEvent` instead of direct Firestore writes.
   - Keep local queue, but flush via callable endpoint for validation + redaction consistency.

2. **Close sensor-fusion gap in `bosRuntime`**
   - Update MVL trigger logic in `bosGetIntervention` path to require corroboration (≥2 independent risk sources), matching `genAiCoach` gate behavior.

3. **Implement weekly `fairnessAudits` writer**
   - Add scheduled function to compute and store audit summaries in `fairnessAudits`.
   - Include model version, cohort slices, drift indicators, and action recommendations.

4. **Standardize endpoint contract naming/docs**
   - Either (a) expose REST aliases matching spec paths (`/ingest-event`, `/score-mvl`, etc.), or (b) update BOS spec to declare callable endpoint names as canonical.

## Confidence
- **High** for identified PASS/GAP items tied to concrete code paths.
- **Medium** for global “every write includes `siteId`” outside BOS runtime due large legacy surface.
