# BOS+MIA Event Schema (Scholesa)
**Version:** 1.0  
**Date:** 2026-02-07  
**Purpose:** Standardize event telemetry so BOS (sensing + estimation + control) and MIA/MVL (integrity) can be computed reliably.

---

## 1) Event envelope (required for every event)
```json
{
  "eventId": "uuid",
  "eventType": "checkpoint_submitted",
  "timestamp": "server_timestamp",
  "siteId": "string",
  "actorId": "uid",
  "actorRole": "learner|educator|parent|hq|site|partner",
  "gradeBand": "G1_3|G4_6|G7_9|G10_12",
  "sessionId": "string|null",
  "sessionOccurrenceId": "string|null",
  "missionId": "string|null",
  "context": {
    "locale": "en",
    "device": "web|ios|android",
    "appVersion": "semver"
  },
  "payload": {}
}
```

**Rules**
- `timestamp` must be server time
- `siteId` is mandatory for all tenant-owned events
- `payload` must be privacy-minimized (no sensitive raw text unless explicitly allowed)

---

## 2) Required student learning events
### 2.1 Session / mission
- `mission_viewed`
- `mission_selected` (payload: difficulty, reasonCodes[])
- `mission_started`
- `mission_abandoned` (payload: step, reason)
- `mission_completed`

### 2.2 Build + iteration
- `artifact_created`
- `artifact_uploaded` (payload: artifactType, sizeKb)
- `artifact_version_saved` (payload: revisionDepthDelta)
- `debug_attempted` (payload: errorType, attemptIndex)

### 2.3 Checkpoints + mastery
- `checkpoint_started`
- `checkpoint_submitted` (payload: checkpointId, attemptIndex)
- `checkpoint_passed` (payload: checkpointId, conceptTags[])
- `checkpoint_failed` (payload: checkpointId, conceptTags[], errorCategory)

### 2.4 Retrieval + metacognition
- `retrieval_prompt_shown` (payload: conceptTags[])
- `retrieval_response_submitted` (payload: correct, confidence)
- `explain_it_back_submitted` (payload: rubricScore, lengthBucket)

### 2.5 Reflection + portfolio
- `reflection_started`
- `reflection_submitted` (payload: mode=voice|text, lengthBucket)
- `portfolio_published` (payload: shareScope=private|class|parent)

---

## 3) Integrity / MIA / MVL events
- `ai_help_opened` (payload: mode=hint|example|debug)
- `ai_help_used` (payload: mode, accepted=true|false)
- `mvl_gate_triggered` (payload: riskType=reliability|autonomy, reasonCodes[])
- `mvl_evidence_attached` (payload: evidenceType=steps|citation|draft|counterexample)
- `mvl_passed` (payload: gateType=submission|ai_use)
- `mvl_failed` (payload: failureReason)

**Policy**
- Do not store raw student text by default. Prefer:
  - length buckets
  - rubric scores
  - concept tags
  - derived features

---

## 4) Collaboration / belonging events (Phase 3)
- `crew_created`
- `role_assigned` (payload: roleName)
- `role_rotated`
- `help_requested` (payload: category, urgency)
- `help_resolved` (payload: resolvedBy=crew|educator)
- `peer_feedback_given` (payload: templateUsed, moderationRequired)
- `peer_feedback_moderated` (educator)

---

## 5) Teacher supervision events
- `teacher_intervention_applied` (payload: type, targetLearnerId)
- `teacher_override_mvl` (payload: decision=allow|deny, reason)
- `contestability_request_created` (payload: learnerId, gateId)
- `contestability_request_resolved` (payload: decision)

---

## 6) Feature families (FDM output targets)
Events must enable these derived feature families:
- **Cognitive:** correctness, attempts-to-mastery, revision depth
- **Engagement proxies:** latency deviation, idle bursts, abandonment points
- **Strategy / integrity:** hint dependency, verification actions, explain-it-back compliance

---

## 7) Storage targets
Recommended collections:
- `interactionEvents` (short retention)
- `fdmFeatures` (windowed)
- `orchestrationStates`
- `interventions`
- `mvlEpisodes`
- `fairnessAudits`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `BOS_MIA_EVENT_SCHEMA.md`
<!-- TELEMETRY_WIRING:END -->
