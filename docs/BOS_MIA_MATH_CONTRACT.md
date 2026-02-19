# BOS+MIA Math Contract (Implementation Bridge)
**Version:** 1.0  
**Date:** 2026-02-19  
**Scope:** This document *binds* the BOS+MIA paper’s mathematical model to Scholesa’s runtime modules, event schema, and Firestore data model.  
**Audience:** engineers implementing estimator/policy/gating + analysts validating behavior.

---

## 0) Why this exists
The BOS+MIA docs define *architecture* (Sense → Detect → Estimate → Control → Gate → Govern).  
This file defines the **math objects + persistence contracts** so the implementation matches the paper’s formal model.

---

## 1) Core objects (paper → code)
We model learning as a stochastic dynamical system with:

- **Latent state:** \(x_t \in \mathbb{R}^d\)  
- **Control (intervention):** \(u_t \in \mathbb{R}^p\)  
- **Observation (features):** \(y_t \in \mathbb{R}^k\)

### 1.1 Latent learner state \(x_t\)
Paper decomposition (BAE + metacognition):
\[
x_t =
\begin{bmatrix}
c_t \\
a_t \\
m_t
\end{bmatrix}
\]
- \(c_t\): cognition / mastery
- \(a_t\): affect & engagement
- \(m_t\): metacognitive integrity

**Implementation (v1):**
We store a **3D collapsed state**:
```ts
type XHat = {
  cognition: number;    // proxy for c_t (0..1)
  engagement: number;   // proxy for a_t (0..1)
  integrity: number;    // proxy for m_t (0..1)
}
```

> If you later expand \(c_t, a_t, m_t\) into vectors, keep this mapping by storing a `components` object and a `collapsed` summary (for UI + policy gating).

### 1.2 Control input \(u_t\)
\(u_t\) represents the intervention chosen by BOS (hint type, scaffold, retrieval, pacing, teacher handoff).

**Implementation (v1):**
Represent \(u_t\) as a structured action with an internal numeric embedding used by policy:
```ts
type Intervention = {
  type: "nudge" | "scaffold" | "handoff" | "revisit" | "pace";
  salience: "low" | "medium" | "high";   // grade-banded
  mode?: "hint" | "verify" | "explain" | "debug"; // if AI-mediated
  reasonCodes: string[];
  u_vec?: number[];      // optional numeric encoding for simulation/policy
}
```

### 1.3 Observation vector \(y_t\)
\(y_t\) is produced by the Feature Detection Module (FDM) from events.

**Implementation (v1):**
Store \(y_t\) as a named feature map + a stable ordered list:
```ts
type Yt = {
  window: "30s" | "5m" | "session";
  features: Record<string, number | string | boolean>;
  y_vec?: number[]; // stable ordering for estimator
  quality: { missingness: number; driftFlag: boolean; fusionFamiliesPresent: string[] };
}
```

---

## 2) Dynamics model (baseline + nonlinear form)
### 2.1 Linear baseline (reference)
Paper baseline:
\[
x_{t+1} = A x_t + B u_t + w_t,\quad w_t \sim \mathcal{N}(0,Q)
\]
\[
y_t = C x_t + v_t,\quad v_t \sim \mathcal{N}(0,R)
\]

**Implementation guidance**
- v1 can start with **locally linear** heuristics:
  - \(A\): “inertia” (habit persistence + forgetting)
  - \(B\): intervention effect (small bounded changes per step)
  - \(C\): mapping from latent state to observable proxies (often implicit, via learned/fit functions)

### 2.2 Nonlinear EKF form (required contract)
Paper nonlinear form:
\[
x_{t+1} = f(x_t, u_t) + w_t,\quad y_t = h(x_t) + v_t
\]

**Implementation requirement**
- You may implement EKF-lite (heuristic estimator) first,
- **but** you must persist fields so EKF can be swapped in without schema changes.

---

## 3) Estimator contract (EKF / EKF-lite)
### 3.1 EKF equations (reference)
Predict:
\[
\hat{x}_{t|t-1} = f(\hat{x}_{t-1|t-1}, u_{t-1})
\]
\[
P_{t|t-1} = F_t P_{t-1|t-1} F_t^\top + Q
\]
Update:
\[
K_t = P_{t|t-1} H_t^\top (H_t P_{t|t-1} H_t^\top + R)^{-1}
\]
\[
\hat{x}_{t|t} = \hat{x}_{t|t-1} + K_t (y_t - h(\hat{x}_{t|t-1}))
\]
\[
P_{t|t} = (I - K_t H_t) P_{t|t-1}
\]
with Jacobians \(F_t = \partial f / \partial x\), \(H_t = \partial h / \partial x\).

### 3.2 What MUST be stored (Firestore)
Collection: `orchestrationStates/{docId}`

Minimum required fields (v1):
```json
{
  "siteId": "string",
  "learnerId": "string",
  "sessionOccurrenceId": "string",
  "x_hat": { "cognition": 0.0, "engagement": 0.0, "integrity": 0.0 },
  "P": {
    "diag": [0.0, 0.0, 0.0],
    "trace": 0.0,
    "confidence": 0.0
  },
  "model": {
    "estimator": "ekf-lite|ekf",
    "version": "semver",
    "Q_version": "string",
    "R_version": "string"
  },
  "fusion": {
    "familiesPresent": ["cognitive", "affective", "strategy", "integrity"],
    "sensorFusionMet": true
  },
  "lastUpdatedAt": "server_timestamp"
}
```

**Notes**
- v1 may store only `diag/trace` rather than full \(P\) to reduce complexity.
- Keep `model.version` so you can compare behavior across estimator changes.

### 3.3 Conservative sensor-fusion constraint (governance → code)
**Rule:** No single proxy may trigger high-salience actions (MVL gate, teacher alert, “high” salience intervention).  
Implementation:
- Compute `fusionFamiliesPresent` for each feature window.
- Set `sensorFusionMet = (uniqueFamilies >= 2)` for any escalation path.

---

## 4) Control policy contract (autonomy-regularized)
### 4.1 Objective (reference)
Paper finite-horizon objective:
\[
J = \sum_{t=0}^{T-1} \Big[(x_t - x^\star)^\top W_x (x_t - x^\star) + u_t^\top W_u u_t + \lambda \Omega(u_t, x_t)\Big]
\]
- \(x^\star\): target region (“productive band”), not necessarily a point
- \(W_x \succeq 0\), \(W_u \succ 0\)
- \(\lambda \ge 0\) weights autonomy preservation

### 4.2 Autonomy cost \(\Omega(u_t, x_t)\) (required)
Paper practical form:
\[
\Omega(u_t, x_t) = \mathbf{1}_{\text{high-assist}(u_t)} \cdot \max(0, m^\dagger - m_t)
\]

**Implementation contract**
- Define `highAssist(u)` deterministically from the intervention:
  - `salience === "high"` OR
  - `type === "scaffold"` with “answer-revealing” hint OR
  - AI `mode === "hint"` with `assistLevel === "high"`
- Define \(m_t\) as `x_hat.integrity`.
- \(m^\dagger\) is a config threshold per grade band:
```ts
const M_DAGGER = {
  G1_3: 0.55,
  G4_6: 0.60,
  G7_9: 0.65,
  G10_12: 0.70
};
```
> Tune these during Phase 1/2; do not hardcode without versioning.

### 4.3 What gets persisted (interventions)
Collection: `interventions/{docId}`
Must include the policy terms needed for audits:
```json
{
  "type": "nudge|scaffold|handoff|revisit|pace",
  "salience": "low|medium|high",
  "reasonCodes": ["..."],
  "policy": {
    "lambda": 0.0,
    "m_dagger": 0.6,
    "highAssist": false,
    "omega": 0.0
  },
  "outcome": "accepted|dismissed|completed|timeout"
}
```

---

## 5) Teacher override & contestability (supervisory control)
Paper supervisory control:
\[
u^{exec}_t = (1 - g_t)u^{BOS}_t + g_t u^{teacher}_t,\quad g_t \in \{0,1\}
\]

**Implementation contract**
- Any educator override sets `g_t = 1` and records both recommendations:
  - `u_bos` (what BOS suggested)
  - `u_teacher` (what teacher applied)

Persist as:
- Event: `teacher_override_applied`
- Doc update: `interventions/{docId}` with:
```json
{
  "supervision": {
    "g": 1,
    "u_bos": {"type":"...", "salience":"..."},
    "u_teacher": {"type":"...", "salience":"..."},
    "reason": "string"
  }
}
```

---

## 6) Reliability risk via Sampling-Based Semantic Entropy (MIA)
### 6.1 Semantic entropy definition (reference)
Given prompt \(p\), sample \(K\) responses \(\{r^{(k)}\}_{k=1}^K\).  
Cluster responses into \(M\) semantic equivalence classes \(\{C_j\}_{j=1}^M\).  
Let:
\[
p_j = \frac{1}{K}\sum_{k=1}^K \mathbf{1}_{r^{(k)} \in C_j}
\]
Semantic entropy:
\[
H_{\text{sem}}(p) = -\sum_{j=1}^M p_j \log p_j
\]

### 6.2 Implementation options
**Option A (offline / eval / slow path):** compute \(H_{\text{sem}}\) with true sampling + clustering.  
**Option B (real-time):** use **SEPs** (Semantic Entropy Probes) as lightweight proxies for “high dispersion”.

**Contract (v1):**
- Store a reliability-risk score in `mvlEpisodes` for any AI-mediated action:
```json
{
  "riskType": "reliability",
  "reliability": {
    "method": "semantic-entropy|sep",
    "K": 0,
    "M": 0,
    "H_sem": 0.0,
    "riskScore": 0.0,
    "threshold": 0.0
  }
}
```
- **Never** treat this as punitive. It only gates *formative verification prompts*.

---

## 7) Autonomy risk signatures (MIA → MVL triggers)
Autonomy risk is inferred from behavior patterns (non-punitive), e.g.:
- rapid submit immediately after high-assist
- minimal edits/paraphrase variance
- low self-explanation following assistance
- repeated hints without independent attempt
- verification gap when reliability risk is non-trivial

**Contract:** Autonomy risk is stored as *evidence and reason codes*:
```json
{
  "riskType": "autonomy",
  "autonomy": {
    "signals": ["rapid_submit", "verification_gap"],
    "riskScore": 0.0,
    "threshold": 0.0
  }
}
```

---

## 8) MVL (Metacognitive Verification Loop) outputs → estimator inputs
MVL is a pedagogical gate converting risk into observable evidence.

**Implementation contract**
- MVL must create new *evidence-producing* events that feed FDM:
  - `mvl_gate_triggered`
  - `mvl_evidence_attached`
  - `explain_it_back_submitted`
  - `source_check_performed`
  - `mvl_passed|failed|needs_more_evidence`

**Key rule:** MVL artifacts increase observability of \(m_t\) by generating higher-quality \(y_t\).

---

## 9) Tuning & versioning (required for field validity)
Every deployed estimator/policy must be versioned and reproducible.
Persist:
- `estimator.version`
- `policy.version`
- `Q_version`, `R_version`, `thresholds_version`
- grade-band thresholds (`m_dagger`, salience caps)

---

## 10) Minimal “math-complete” acceptance criteria
You are mathematically aligned to the paper when:
1) You can point to where \(x_t, u_t, y_t\) live in code + Firestore.
2) You can run predict/update (EKF or EKF-lite) and persist uncertainty \(P\) summary.
3) You compute autonomy cost \(\Omega\) deterministically and log it per intervention.
4) You record supervisory override \(g_t\) and executed control.
5) Reliability risk uses semantic entropy (offline) or SEPs (online) and routes to MVL.
6) MVL outputs feed back into features \(y_t\) and state estimation.

---

## Appendix A — Suggested dimensions (v1 defaults)
- \(d = 3\) (collapsed cognition/engagement/integrity)
- \(p = 1..8\) (action encoding; optional)
- \(k = 20..80\) (feature map; grows with instrumentation)

Keep the schema stable even if these sizes grow.
