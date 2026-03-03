# BOS Requirement Audit — 2026-03-03

## Scope
Audit baseline: `docs/BOS_MIA_HOW_TO_IMPLEMENT.md` (Prime Directive, §2, §3, §4, §5).

Assessment target: current Scholesa BOS + AI runtime implementation across Flutter + Cloud Functions.

## Verdict
- **Conversational AI:** **PASS** (implemented in both callable and voice runtime paths).
- **"Fully wired into BOS requirements" claim:** **YES (runtime-complete)**.
- **COPPA adherence (BOS + spoken AI):** **PASS** (active school consent + site scope enforced across BOS callables and voice endpoints).

Overall status: **14 PASS / 0 PARTIAL / 0 GAP** for the highest-impact BOS requirements below.

## Requirement Matrix

| Requirement | Status | Evidence | Notes |
|---|---|---|---|
| AI Coach live behind stable API contract | PASS | `functions/src/index.ts` (`genAiCoach`), `apps/empire_flutter/app/lib/runtime/bos_service.dart` (`callAiCoach`) | Contract currently stable and consumed by client. |
| AI emits `ai_help_opened` + `ai_help_used` | PASS | `functions/src/index.ts` (`genAiCoach` event writes), `functions/src/voiceSystem.ts` (`recordBosInteractionEvent` for `ai_help_opened` / `ai_help_used`) | Emitted on callable and voice HTTP paths. |
| Reliability + autonomy risk gates exist | PASS | `functions/src/index.ts` (`computeReliabilityRisk`, `computeAutonomyRisk`, `checkAndMaybeCreateMvl`), `functions/src/bosRuntime.ts` risk pipeline | Implemented as v1 heuristics and used in gating decisions. |
| Learner timeline reconstructable (events → features → state → interventions → outcomes) | PASS | `functions/src/bosRuntime.ts` writes `interactionEvents`, `fdmFeatures`, `orchestrationStates`, `interventions`, `mvlEpisodes`; score/override/contestability endpoints | Core chain exists and is queryable. |
| Teacher override + contestability workflow | PASS | `functions/src/bosRuntime.ts` (`bosTeacherOverrideMvl`, `bosContestability`), `apps/empire_flutter/app/lib/runtime/bos_service.dart` | Minimum viable supervisory + contestability flow implemented. |
| Required event categories represented (mission/checkpoint/metacognition/AI/MVL) | PASS | `apps/empire_flutter/app/lib/runtime/bos_event_bus.dart`, `apps/empire_flutter/app/lib/runtime/mvl_gate_widget.dart`, `functions/src/bosRuntime.ts` (`mvl_gate_triggered` write) | MVL trigger/evidence/result events are emitted across server + client paths. |
| Endpoint 1 `ingest-event` with validation + write path | PASS | `functions/src/bosRuntime.ts` (`bosIngestEvent` + queue write), `apps/empire_flutter/app/lib/runtime/bos_event_bus.dart` (flush via `BosService.ingestEvent`) | Primary client path now routes through server ingest endpoint. |
| Required CRUD endpoints 2–8 implemented | PASS | `functions/src/bosRuntime.ts` exports + `functions/src/index.ts` re-exports + Flutter service wrappers | Implemented as callable functions (not REST paths). |
| Every write includes `siteId` | PASS | `functions/src/bosRuntime.ts` endpoint writes include `siteId`; Flutter ingress now server-routed | BOS runtime write path is site-scoped. |
| Server timestamps only | PASS | `functions/src/bosRuntime.ts` uses server timestamps; direct BOS client writes removed from event bus | BOS event flow now server-timestamped through ingestion. |
| Sensor fusion: no single proxy for high-salience MVL | PASS | `functions/src/bosRuntime.ts` requires ≥2 risk sources before MVL trigger | Policy request cannot bypass corroboration rule. |
| Weekly fairness audits collection (`fairnessAudits`) | PASS | `functions/src/bosRuntime.ts` (`bosWeeklyFairnessAudit`) | Weekly scheduler writes per-site fairness audit summaries. |
| Privacy-minimized telemetry payloads | PASS | `functions/src/bosRuntime.ts` payload sanitizer, `functions/src/voiceSystem.ts` redaction + derived metrics | Good baseline in server paths. |
| Conversational, kid-friendly spoken AI | PASS | `functions/src/index.ts` (`applyKidFriendlyConversationalTone`), `functions/src/voiceSystem.ts` persona + tone shaping, `apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart` voice-first flow | Behavior implemented end-to-end for learner-facing responses. |

## Residual Partial

- None. Runtime and operational gates are fully wired for BOS+MIA + COPPA.
- Consolidated verification gate: `npm run qa:bos:mia:complete`.

## Confidence
- **High** for identified PASS/GAP items tied to concrete code paths.
- **Medium** for global “every write includes `siteId`” outside BOS runtime due large legacy surface.
