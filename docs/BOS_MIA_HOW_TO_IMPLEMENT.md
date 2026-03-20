# BOS+MIA Vibe Coding Master Instructions (Gold Release)
**Product:** Scholesa (BOS + MIA/MVL runtime)
**Goal:** Ship a deployable closed-loop learning runtime with integrity gating + AI help, grounded in BOS+MIA docs.

---

## 0) Prime Directive (Non-Negotiables)
1) **Everything is a closed-loop runtime.** All learning flows pass through:
   Sense → Detect → Estimate → Control → Gate → Govern.  
2) **No punitive language, ever.** MVL is formative: “verify / explain / show evidence.”  
3) **Privacy-minimized telemetry.** Default to derived features + buckets; avoid raw student text storage unless explicitly allowed.  
4) **Sensor fusion rule:** No single proxy triggers high-salience actions (MVL/teacher alerts). Needs corroboration.
5) **COPPA-first gating:** BOS + voice AI access requires active school consent (`coppaSchoolConsents/{siteId}`) and site-scoped authorization.
6) **Confidence-first learner autonomy:** learner-facing BOS/MIA responses may be autonomous only when certified confidence is `>= 0.97`; otherwise the runtime must escalate safely instead of fabricating help.

**Source spine:**
- Rewire Plan (runtime modules + sequence)  
- Event Schema (telemetry contract)  
- Data Model (Firestore + Storage)  
- UI Wiring Map (routes → responsibilities)  

---

## 1) Repo Structure (recommended)
- `/docs/`
  - `BOS_MIA_REWIRE_PLAN.md`
  - `BOS_MIA_EVENT_SCHEMA.md`
  - `BOS_MIA_DATA_MODEL.md`
  - `BOS_MIA_UI_WIRING_MAP.md`
  - `BOS_MIA_VIBE_MASTER.md` (this file)
- `/client/`
  - `runtime/LearningRuntimeProvider.tsx`
  - `runtime/EventBus.ts`
  - `runtime/MVLGate.tsx`
  - `runtime/GradeBandPolicy.ts`
- `/server/`
  - `routes/ingest-event.ts`
  - `services/FDMService.ts`
  - `services/StateEstimatorService.ts`
  - `services/PolicyService.ts`
  - `services/IntegrityService.ts`
  - `services/GovernanceService.ts`
  - `ai/AICoachService.ts`
  - `ai/rag/*` (optional)
- `/infra/` (Terraform/Pulumi or minimal scripts)
- `/tests/`
  - `unit/`
  - `integration/`
  - `e2e/`
  - `ai-evals/`

---

## 2) Definition of “AI Fully Implemented”
AI is “fully implemented” only when all are true:
- AI help is live behind a stable API contract.
- AI usage emits required events (`ai_help_opened`, `ai_help_used`) and triggers MVL when needed.
- Reliability risk + autonomy risk gates exist (even as v1 heuristics).
- You can reconstruct a learner timeline: events → features → state → interventions → outcomes.
- Teacher override + contestability workflow exists (minimum viable).
- Learner-facing low-confidence or unavailable inference degrades to escalation/review, not deterministic fake help.

---

## 3) Event Contract (hard rules)
**All learning actions emit standardized events** using the event envelope.
- Server timestamps only.
- Must include: `siteId`, `sessionOccurrenceId`, `gradeBand`, `actorId`.
- Payload is privacy-minimized.

### Required event categories
- Session/mission: `mission_viewed`, `mission_selected`, `mission_started`, `mission_completed`, etc.
- Build/iteration: `artifact_*`, `artifact_version_saved`, `debug_attempted`
- Checkpoints/mastery: `checkpoint_*`
- Metacognition: `retrieval_*`, `explain_it_back_submitted`, `reflection_*`
- AI/MVL: `ai_help_opened`, `ai_help_used`, `mvl_gate_triggered`, `mvl_evidence_attached`, `mvl_passed|failed`

**Rule:** If it affects BOS state, it must be an event.

---

## 4) Database (Firestore + Storage) — CRUD You Must Support
### Collections (minimum)
- `interactionEvents/{eventId}` (append-only, short retention)
- `fdmFeatures/{docId}` (windowed feature vectors)
- `orchestrationStates/{docId}` (x_hat + uncertainty summary)
- `interventions/{docId}` (control actions + outcomes)
- `mvlEpisodes/{docId}` (gate episodes + evidence + resolution)
- `fairnessAudits/{docId}` (weekly)
- `portfolioItems/{id}` + Storage `artifacts/{siteId}/{learnerId}/{artifactId}/{fileName}`

### Required CRUD endpoints (server)
1) `POST /ingest-event`
   - Validates envelope; writes `interactionEvents`; queues feature extraction.
2) `GET /orchestration-state?learnerId&sessionOccurrenceId`
3) `POST /get-intervention`
   - Returns recommended action + reason codes (and logs it).
4) `POST /score-mvl`
   - Returns `pass|fail|needs_evidence` + reason codes.
5) `POST /mvl/submit-evidence`
6) `GET /educator/class/:sessionOccurrenceId/insights`
7) `POST /teacher/override-mvl`
8) `POST /contestability/request` and `POST /contestability/resolve`

### Callable Mapping (Scholesa production runtime)
The deployed runtime exposes the same contract through Firebase callable names:
- `/ingest-event` → `bosIngestEvent`
- `/orchestration-state` → `bosGetOrchestrationState`
- `/get-intervention` → `bosGetIntervention`
- `/score-mvl` → `bosScoreMvl`
- `/mvl/submit-evidence` → `bosSubmitMvlEvidence`
- `/educator/class/:sessionOccurrenceId/insights` → `bosGetClassInsights`
- `/teacher/override-mvl` → `bosTeacherOverrideMvl`
- `/contestability/request|resolve` → `bosContestability` (`action=request|resolve`)

**Rule:** Every write includes `siteId`. Every timestamp is server time.

### COPPA Runtime Enforcement
- `bosIngestEvent`, `bosGetIntervention`, `bosGetClassInsights`, and MVL mutation endpoints enforce:
  - active school consent,
  - site membership scope,
  - server-side writes only.
- Voice paths (`/copilot/message`, `/voice/transcribe`, `/tts/speak`) enforce active school consent before model/tool execution.
- Student-facing payloads remain privacy-minimized through server-side sanitization/redaction.
- Learner-facing BOS/MIA responses enforce a certified confidence threshold of `0.97` before autonomous delivery.
- Regression gate: run `cd functions && npm run test:coppa` to verify consent + cross-site denial guards.
- Full completion gate: run `npm run qa:bos:mia:complete` from repo root.
- Production signoff report: run `npm run qa:bos:mia:signoff` to generate `audit-pack/reports/bos-mia-signoff.json`.
- Latest release certificate: `docs/BOS_MIA_RELEASE_CERTIFICATE_2026-03-03.md`.
- Production sign-off checklist: `docs/BOS_MIA_PROD_SIGNOFF_CHECKLIST.md`.

### Production rollout rule
- Production releases use a full big-bang cutover after all gates are green.
- Use `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md` and `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md` for the manual release-control sweep.

---

## 5) AI Help Contract (v1)
### Coach modes
- `hint` (low assist)
- `verify` (evidence + checking)
- `explain` (self-explanation scaffolds)
- `debug` (guided debugging, not solutions-first)

### Request (example)
```json
{
  "siteId": "S",
  "learnerId": "L",
  "gradeBand": "G4_6",
  "sessionOccurrenceId": "SO",
  "mode": "hint|verify|explain|debug",
  "context": {
    "missionId": "M",
    "checkpointId": "C",
    "conceptTags": ["fractions"],
    "learnerState": { "cognition": 0.6, "engagement": 0.4, "integrity": 0.7 },
    "recentEventsRef": ["eventId1","eventId2"]
  },
  "studentInput": "string (minimize; do not store by default)"
}

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `BOS_MIA_HOW_TO_IMPLEMENT.md`
<!-- TELEMETRY_WIRING:END -->
