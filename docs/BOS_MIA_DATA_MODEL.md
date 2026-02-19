# BOS+MIA Data Model (Firestore + Storage)
**Version:** 1.0  
**Date:** 2026-02-07  
**Purpose:** Define the minimum collections required to compute BOS state, interventions, MVL integrity, and class insights.

---

## 1) Collections (minimum)
### 1.1 Raw event stream (short retention)
- `interactionEvents/{eventId}`
  - event envelope + privacy-minimized payload

### 1.2 Derived features (FDM)
- `fdmFeatures/{docId}`
  - `siteId, learnerId, sessionOccurrenceId`
  - window (`30s`, `5m`, `session`)
  - feature vector `y_t`
  - quality flags (missingness, drift)

### 1.3 Orchestration state (EKF / estimator)
- `orchestrationStates/{docId}`
  - `x_hat`: { cognition, engagement, integrity }
  - `P`: covariance/uncertainty summary
  - `lastUpdatedAt`

### 1.4 Interventions (control actions u_t)
- `interventions/{docId}`
  - `type`: nudge|scaffold|handoff|revisit|pace
  - `salience`: low|medium|high (grade-banded)
  - `reasonCodes[]` (sensor fusion)
  - `outcome`: accepted|dismissed|completed|timeout

### 1.5 MVL / integrity episodes
- `mvlEpisodes/{docId}`
  - `riskType`: reliability|autonomy
  - `gateType`: submission|ai_use|publish
  - `evidenceIds[]`
  - `selfExplanationScore` (rubric)
  - `resolvedBy`: learner|educator|system

### 1.6 Teacher/class aggregates (long retention)
- `telemetryAggregates/{docId}`
- `classInsights/{docId}` (optional cache)
- `fairnessAudits/{docId}`

---

## 2) Storage (artifacts)
**Path pattern**
- `artifacts/{siteId}/{learnerId}/{artifactId}/{fileName}`

**Artifact metadata (Firestore)**
- `portfolioItems/{id}`
  - `siteId, learnerId`
  - `artifactRefs[]`
  - `shareScope`
  - `rubricEvidence`

---

## 3) Required fields (multi-tenant)
- Every tenant-owned doc includes `siteId`
- Every timestamp uses server time
- Writes use create/update separation for rules correctness

---

## 4) Retention policy (recommended)
- `interactionEvents`: 30–90 days (configurable by site)
- `fdmFeatures`: 90–180 days
- `orchestrationStates`: per-term
- `interventions` + `mvlEpisodes`: per-term (needed for evaluation)
- aggregates: multi-year (de-identified when possible)

---

## 5) Indexes you will need
- `interactionEvents`: (siteId, sessionOccurrenceId, timestamp desc)
- `fdmFeatures`: (siteId, learnerId, sessionOccurrenceId, window)
- `interventions`: (siteId, learnerId, sessionOccurrenceId, timestamp desc)
- `mvlEpisodes`: (siteId, learnerId, sessionOccurrenceId, timestamp desc)
