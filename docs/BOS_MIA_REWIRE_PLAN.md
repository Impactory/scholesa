# BOS+MIA Rewire Plan for Scholesa
**Version:** 1.0  
**Date:** 2026-02-07  
**Purpose:** Rewire Scholesa so the product architecture directly supports the BOS+MIA research paper (closed-loop orchestration + metacognitive integrity), while remaining deployable in real classrooms.

---

## 0) What “rewire” means
Scholesa becomes a **closed-loop learning runtime** (BOS) with an **integrity gating system** (MIA/MVL).

**Old spine:** routes/screens + ad-hoc logic  
**New spine:** **Learning Runtime** that every learning interaction passes through:

1) **Sense** → events  
2) **Detect** → features (FDM)  
3) **Estimate** → latent state (EKF / EKF-lite)  
4) **Control** → select intervention (policy)  
5) **Gate** → MVL (proof-of-work)  
6) **Govern** → privacy, contestability, fairness auditing  

---

## 1) New runtime modules (must exist)
### 1.1 Client Runtime
- `LearningRuntimeProvider` (global provider)
- `EventBus` (standardized telemetry emit)
- `MVLGate` (UI gate for submission + AI usage)
- `GradeBandPolicy` (feature gating + limits)

### 1.2 Server Runtime (Cloud Run recommended)
- `IngestionService` (`/ingest-event`)
- `FDMService` (windowed feature extraction)
- `StateEstimatorService` (EKF-lite → EKF)
- `PolicyService` (`/get-intervention`)
- `IntegrityService` (`/score-mvl`, autonomy vs reliability risk)
- `GovernanceService` (retention jobs, audits, contestability logs)

---

## 2) Product rewiring steps (sequence)
### Step A — Introduce Learning Runtime (foundation)
- Wrap all protected routes with `LearningRuntimeProvider`
- Replace scattered `telemetry.track` calls with an `EventBus` wrapper
- Ensure every learning flow emits standardized events (see `BOS_MIA_EVENT_SCHEMA.md`)

**Definition of Done**
- All “learning actions” produce events with `siteId`, `sessionOccurrenceId`, `gradeBand`, `actorId`

### Step B — Add MVL gating (proof-of-work)
- Add MVL gates before:
  - checkpoint submission
  - AI coach “use” actions (copy, apply suggestion)
  - portfolio publish/share actions
- Add contestability UI (“Why am I seeing this?” + “Request teacher review”)

**Definition of Done**
- MVL episodes stored with evidence and self-explanation payloads
- No punitive language anywhere (“cheating detection” is never shown)

### Step C — Server orchestration (closed-loop)
- Route “intervention” selection to server:
  - `getIntervention(learnerId, context)` returns: nudge type, scaffold level, next step
- Store `orchestrationStates` snapshots

**Definition of Done**
- Every intervention logged with reason codes and outcomes

### Step D — EKF-lite to EKF
- Start with conservative heuristic estimator (avoid false positives)
- Replace with EKF once feature stability and R/Q are tuned

**Definition of Done**
- State estimate contains: cognition, engagement/affect proxy, integrity proxy + uncertainty

### Step E — Fairness + governance
- Weekly audit:
  - intervention rates by gradeBand, group, language, baseline mastery
- Add “mitigation knobs”:
  - raise uncertainty (R)
  - require sensor fusion (>=2 feature families)
  - reduce intervention salience for impacted groups until recalibrated

---

## 3) What gets rewired (screens)
### 3.1 Student
- Mission selection becomes a control input (“Choose” step)
- Build studio emits iteration signals (revision depth, time-on-task, help seeking)
- Checkpoint submission is MVL-gated (explain-it-back + evidence)
- Reflection becomes part of integrity loop (metacognitive checkpoint)

### 3.2 Educator
- Replace “static analytics” with:
  - supervisory control panel (override gates, accommodations)
  - actionable insights (concept friction, stuck points)
  - contestability inbox (requests, approvals)

### 3.3 Parent/HQ
- Parent: read-only progress + portfolio, strict scope
- HQ: governance and safety dashboards (aggregates, audits)

---

## 4) Phase alignment
This plan **does not delete** your existing phase roadmap; it **re-anchors** it:
- Phase 2/3 become “learning runtime + collaboration signals”
- Phase 4 becomes “Integrity-first AI Coach (MVL-aware)”
- Phase 7 becomes “BOS-ready teacher analytics derived from orchestration logs”

---

## 5) Acceptance criteria (research support)
Scholesa supports the research paper when:
- You can reconstruct per-learner timelines: events → features → state → interventions → outcomes
- MVL gates enforce proof-of-work without punitive messaging
- Contestability + fairness auditing exist and are operational
- Experiment assignment (clusters/time windows) is supported for SW-CRT
