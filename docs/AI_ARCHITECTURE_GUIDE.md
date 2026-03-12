# AI Architecture Guide - Vendor-Agnostic Intelligence Layer

## Production Status (March 12, 2026)

The current production runtime is no longer a permissive multi-provider fallback surface for learner-facing help.

- Learner-facing web and callable BOS/MIA flows are internal-inference only.
- Autonomous learner help requires certified confidence `>= 0.97`.
- Low-confidence, unavailable, or non-compliant inference escalates safely instead of fabricating help.
- Active school consent and site-scoped authorization are mandatory for learner AI and voice flows.
- Test harnesses and adapter-level mocks remain test-only and are not part of the production release path.

## Overview

This architecture makes **your app the system of record** and **AI providers stateless reasoning services**. This means:

✅ **Keep provider choice abstracted behind your own contracts**  
✅ **Your rubrics/policies** stored in your DB, not hardcoded prompts  
✅ **Your retrieval/memory** via vector store (not vendor lock-in)  
✅ **Training dataset** collected for future fine-tuning  
✅ **PII redaction** before ANY model call  
✅ **Audit trail** for every AI interaction  
✅ **Learner-safe confidence gating and COPPA enforcement**

---

## Architecture Layers

### 1. Model Adapter Layer
**File**: `src/lib/ai/modelAdapter.ts`

**Purpose**: Vendor-agnostic AI interface

```typescript
// Your app owns the schema
interface ModelRequest {
  taskType: TaskType;
  gradeBand: AgeBand;
  question: string;
  contextBlocks: ContextBlock[]; // From YOUR retrieval
  safetyConstraints: SafetyConstraints; // YOUR rules
}

// Adapters map to vendor APIs
class GeminiAdapter implements ModelAdapter {
  complete(request: ModelRequest): Promise<ModelResponse>
}

class OpenAIAdapter implements ModelAdapter {
  complete(request: ModelRequest): Promise<ModelResponse>
}

// Router handles guarded orchestration
modelRouter.complete(request) // Internal inference first; learner-facing failures escalate safely
```

**Key Insight**: Model receives YOUR rubrics/policies as context (not baked into training), but learner-facing production responses must still pass confidence and compliance gates before they can be shown autonomously.

---

### 2. Redaction Service
**File**: `src/lib/ai/redactionService.ts`

**Purpose**: Strip PII before sending to ANY model

```typescript
const result = RedactionService.redact(
  "My name is Sarah and my email is sarah@example.com",
  getConfigForPolicy('k3_safe'),
  { studentNames: ['Sarah'] }
);

// result.redacted: "My name is STUDENT_A and my email is EMAIL_1"
// result.replacements: Map for restoration (logging only)
```

**Policy-based configs**:
- K-3: Strictest (redact names, ages, schools)
- Grades 4-6: Moderate
- Grades 7-9: Standard
- Grades 10-12: Relaxed (but still emails/IDs)

---

### 3. Retrieval Service
**File**: `src/lib/ai/retrievalService.ts`

**Purpose**: Fetch context from YOUR data stores

```typescript
const contextBlocks = await RetrievalService.retrieve({
  query: "Need help with for loops",
  missionId: "python_intro",
  learnerId: "user123",
  gradeBand: 'grades_4_6',
  topK: 5
});

// Returns:
// - Rubric for this mission (from rubricManager)
// - Exemplars (good examples from past students)
// - Misconceptions (common errors curated by educators)
// - Student's past work
// - Teacher feedback patterns
```

**Vector Store Pattern** (TODO: implement real vector DB):
- Store embeddings for rubrics, exemplars, misconceptions
- Semantic search for relevant context
- Provenance tracking (which blocks informed the answer)

---

### 4. Rubric Manager
**File**: `src/lib/ai/rubricManager.ts`

**Purpose**: Store assessment rubrics as versioned configs

```typescript
// Create a rubric (YOUR intelligence)
const id = await RubricManager.createRubric({
  name: "K-3 Coding Foundations",
  siteId: "*", // Global or site-specific
  grade: 2,
  criteria: [
    {
      name: "Understanding",
      weight: 0.4,
      levels: [
        { name: "Emerging", score: 1, description: "..." },
        { name: "Proficient", score: 2, description: "..." },
        { name: "Advanced", score: 3, description: "..." }
      ]
    }
  ]
});

// Fetch for context injection
const rubric = await getRubricForMission(siteId, missionId, grade);
const formatted = formatRubricForAI(rubric); // Markdown for model
```

**Why this matters**:
- Iterate on rubrics without retraining models
- Version tracking for experiments
- Audit which rubric version was used
- Compare student performance across rubric versions

---

### 5. AI Interaction Logger
**File**: `src/lib/ai/interactionLogger.ts`

**Purpose**: Collect training dataset (YOUR proprietary data)

```typescript
// Log every AI interaction
const logId = await AIInteractionLogger.logInteraction({
  learnerId: "user123",
  siteId: "site1",
  request: { question: "How do I...", taskType: "hint_generation" },
  response: { answer: "Try...", modelUsed: "gemini" },
  contextUsed: contextBlocks,
  redactionAudit: { piiRemoved: ["EMAIL_1"], restorable: true }
});

// Record outcomes (training signals)
await AIInteractionLogger.updateOutcome(logId, {
  wasHelpful: true,
  studentRevised: true,
  checkpointPassed: true,
  timeToMastery: 300 // seconds
});

// Export for fine-tuning
const jsonl = await AIInteractionLogger.exportForTraining(siteId, {
  minHelpfulRating: 0.7,
  startDate: startOfMonth
});
```

**Training dataset includes**:
- Question (redacted)
- Answer
- Context blocks used (which rubrics/exemplars informed response)
- UI trigger (coach popup, inline help, reflection prompt)
- Outcomes (was it helpful? did student improve?)
- Redaction audit (what PII was removed)

---

### 6. Integrated AI Service
**File**: `src/lib/ai/aiService.ts`

**Purpose**: Orchestrate all components

```typescript
// One-line AI request (handles everything)
const response = await AIService.request({
  learnerId: "user123",
  studentName: "Alex",
  siteId: "site1",
  grade: 5,
  studentLevel: "proficient",
  missionId: "python_intro",
  taskType: "hint_generation",
  question: "Why isn't my loop working?"
});

// Behind the scenes:
// 1. Redact PII from question
// 2. Retrieve context (rubric, exemplars, misconceptions, past work)
// 3. Build ModelRequest with YOUR rules
// 4. Call internal inference via router; if confidence/compliance is insufficient, escalate safely
// 5. Parse response & extract citations
// 6. Log everything (request, response, context, outcomes)
// 7. Return to UI

// Record feedback
await AIService.recordFeedback(response.logId, true, "Student said helpful");

// Record outcome
await AIService.recordOutcome(response.logId, {
  studentRevised: true,
  checkpointPassed: true
});
```

**Convenience functions**:
```typescript
// Hint generation
const hint = await getAIHint(learnerId, studentName, siteId, grade, missionId, "Stuck on...");

// Rubric check
const feedback = await checkAgainstRubric(learnerId, studentName, siteId, grade, missionId, artifact);

// Debug help
const debug = await getDebugHelp(learnerId, studentName, siteId, grade, missionId, code, error);
```

---

## UI Integration

### AICoachPopup Component
**File**: `src/components/sdt/AICoachPopup.tsx`

**Changes**:
1. Added `studentName` prop (required for redaction)
2. Replaced `sdtMotivation.requestAICoach()` with `AIService.request()`
3. Added feedback buttons ("Was this helpful?")
4. Records feedback to training dataset
5. Shows model attribution ("Powered by gemini")
6. Displays citations (which context blocks were used)

**Usage**:
```tsx
<AICoachPopup
  learnerId={user.id}
  studentName={user.firstName} // NEW
  siteId={activeSiteId}
  grade={5}
  studentLevel="proficient" // NEW (optional)
  missionId={currentMissionId}
  sprintSessionId={sessionId}
/>
```

---

## Data Vault Architecture

### Student Data Vault (NEVER for training by default)
- User profiles (`users` collection)
- Artifacts (`artifacts` collection)
- Enrollments, attendance, assessments
- **Privacy**: Firestore rules enforce role-based access
- **Consent**: K-3 requires teacher approval for AI features

### Model Improvement Dataset (De-identified, opt-in)
- AI interaction logs (`aiInteractionLogs` collection)
- Outcomes tracking (helpful?, revised?, passed checkpoint?)
- Redacted student questions + model responses
- Context provenance (which rubrics/exemplars were used)
- **Export**: JSONL format for fine-tuning (`AIInteractionLogger.exportForTraining()`)

### Intelligence Store (YOUR proprietary knowledge)
- Assessment rubrics (`assessmentRubrics` collection)
- Exemplars (TODO: `exemplarArtifacts` collection)
- Misconceptions library (TODO: `commonMisconceptions` collection)
- Teacher feedback patterns (TODO: aggregate from logs)
- **Version control**: Rubrics have version numbers, track which version was used

---

## Environment Setup

### Required Runtime Configuration
```bash
# Server-side internal inference credentials only
FIREBASE_SERVICE_ACCOUNT=...
INTERNAL_INFERENCE_AUTH=...
```

### Model Router Configuration
```typescript
// Default: internal inference gateway for production learner flows
modelRouter.setDefaultAdapter('internal');

// Non-learner or offline eval traffic may override adapter selection where policy permits
await modelRouter.complete(request, 'internal');
```

---

## Firestore Collections

### New Collections
1. **`aiInteractionLogs`** - Training dataset
   - Request, response, context, outcomes
   - Redaction audit trail
   - UI trigger, timestamp, model used
   
2. **`assessmentRubrics`** - Versioned rubrics
   - Name, description, version, status
   - Criteria with levels (Emerging, Proficient, Advanced)
   - Site/grade/skill/mission scoping
   - Tags for retrieval

### Security Rules
```javascript
// aiInteractionLogs: Educator + Admin read, System write
match /aiInteractionLogs/{logId} {
  allow read: if isEducator() || isHQ();
  allow write: if isSystem();
}

// assessmentRubrics: Educator + Admin read/write
match /assessmentRubrics/{rubricId} {
  allow read: if isEducator() || isHQ();
  allow write: if isEducator() || isHQ();
  allow create: if isEducator() || isHQ();
}
```

---

## Seed Data

### Default Rubrics
**File**: `scripts/seedRubrics.ts`

```typescript
import { seedDefaultRubrics } from '@/scripts/seedRubrics';

// Seed K-3, grades 4-6, grades 7-9 rubrics
const ids = await seedDefaultRubrics('admin-user-id');
// Returns: [rubricId1, rubricId2, rubricId3]
```

**Included rubrics**:
1. **K-3 Coding Foundations** (Understanding, Problem-Solving, Communication)
2. **Grades 4-6 Project Assessment** (Research, Technical Execution, Critical Thinking, Communication)
3. **Grades 7-9 Agency & Impact** (Personal Voice, Real-World Impact, Technical Quality, Metacognition)

---

## Implementation Roadmap

### ✅ Completed (Phase 1)
- [x] Model Adapter layer (Gemini + OpenAI)
- [x] Redaction Service (PII stripping)
- [x] AI Interaction Logger (training dataset)
- [x] Retrieval Service structure
- [x] Integrated AI Service
- [x] AICoachPopup integration
- [x] Rubric Manager (versioned configs)
- [x] Seed rubrics script

### ⏳ Phase 2: Vector Store & Retrieval
- [ ] Integrate vector DB (Pinecone, Weaviate, or Firestore Vector Search)
- [ ] Generate embeddings for rubrics, exemplars, misconceptions
- [ ] Implement semantic search for context retrieval
- [ ] Store exemplar artifacts (educator-curated)
- [ ] Build misconceptions library (educator-contributed)
- [ ] Aggregate teacher feedback patterns from logs

### ⏳ Phase 3: Educator Tooling
- [ ] Rubric editor UI (create, version, archive)
- [ ] Exemplar curation UI (tag good student work)
- [ ] Misconception library UI (contribute common errors by skill/grade)
- [ ] "Was this helpful?" dashboard (see what AI help worked)
- [ ] Training dataset export tool (JSONL download for fine-tuning)
- [ ] A/B testing dashboard (compare Gemini vs OpenAI)

### ⏳ Phase 4: Advanced Features
- [ ] Context provenance UI (show students which context informed answer)
- [ ] Outcome tracking (correlate AI help with checkpoint pass rates)
- [ ] Parent data export ("see what AI said to my kid")
- [ ] Consent flow for K-3 (teacher approval required)
- [ ] Retention policy (how long to keep logs)
- [ ] Multi-language support (rubrics in Spanish, French, etc.)

---

## Testing & Validation

### Unit Tests (TODO)
- Redaction Service: Ensure PII removed
- Retrieval Service: Verify context relevance
- Model Adapter: Mock API responses
- AI Service: Guarded end-to-end flow with confidence escalation

### Integration Tests (TODO)
- Full AI request → response → logging flow
- Rubric retrieval hierarchy (mission > skill > pillar > grade > site > global)
- Confidence/COPPA behavior (high confidence help vs guarded escalation)
- Feedback recording → training dataset

### Manual Testing
1. **AI Coach Popup**: Ask question → See response → Click "helpful" → Check log
2. **Rubric Retrieval**: Create mission-specific rubric → Request AI help → Verify context includes rubric
3. **Redaction**: Student asks "My name is X" → Verify "STUDENT_A" sent to model
4. **Guardrail**: Force low-confidence learner inference → Verify safe escalation instead of fabricated help

---

## Security & Privacy

### PII Redaction
- **Names**: STUDENT_A, TEACHER_B
- **Emails**: EMAIL_1, EMAIL_2
- **Phones**: PHONE_1
- **Addresses**: ADDRESS_1
- **IDs**: ID_1 (Firestore IDs)

### Provider Settings
- **Gemini**: Disable training, use enterprise tier
- **OpenAI**: Set `user_id` to hashed learner ID (no PII)
- **Claude**: TBD (when added)

### Audit Trail
- Every AI call logged with redaction audit
- Track which educator accessed logs
- Retention policy (configurable per site)

---

## Key Metrics to Track

### Effectiveness
- **Helpfulness rate**: % of "👍 Yes" feedback
- **Revision rate**: % of students who revised after AI help
- **Checkpoint pass rate**: % who passed after AI help
- **Time to mastery**: Avg seconds from AI help to checkpoint pass

### Usage
- **AI requests per student**: Track over-reliance
- **Most common task types**: Hint vs rubric check vs debug
- **Most common questions**: Surface patterns for curriculum improvement

### Quality
- **Context relevance**: Avg relevance score of retrieved blocks
- **Citation accuracy**: % of responses with citations to context
- **Model performance**: Compare Gemini vs OpenAI on same questions

---

## Troubleshooting

### "No rubric found for mission X"
**Cause**: No rubric matches the mission/grade/site hierarchy  
**Fix**: Create a global fallback rubric (`siteId: '*'`, no grade/skill/mission filters)

### "PII detected in model logs"
**Cause**: Redaction service not called or misconfigured  
**Fix**: Ensure `AIService.request()` is used (not direct model calls); check redaction config

### "Learner AI keeps escalating"
**Cause**: Confidence is below `0.97`, consent is inactive, or site scope is invalid  
**Fix**: Verify consent, identity scoping, and internal inference health before lowering risk posture

### "Training dataset too large"
**Cause**: Logs not filtered before export  
**Fix**: Use export filters (`minHelpfulRating`, `startDate`, `endDate`)

---

## FAQs

**Q: Why not just use Gemini's built-in memory?**  
A: Vendor lock-in. If Gemini changes pricing/policies or you want to switch to OpenAI/Claude, you lose all your "smartness."

**Q: Can I use multiple models for the same request?**  
A: Only behind your own routing policy. For learner-facing production flows, the system must still enforce internal policy gates, confidence `>= 0.97`, and COPPA/site checks before showing an autonomous answer.

**Q: How do I know which rubric version was used?**  
A: Check `aiInteractionLogs` → `contextUsed` → find rubric block → `metadata.rubricVersion`.

**Q: Can students see the context blocks?**  
A: Not yet. Phase 4 will add "provenance UI" showing which exemplars/rubrics informed the answer.

**Q: How do I export training data for fine-tuning?**  
A: `await AIInteractionLogger.exportForTraining(siteId, { minHelpfulRating: 0.7 })` → JSONL file.

---

## Next Steps

1. **Seed rubrics**: Run `seedDefaultRubrics('your-user-id')`
2. **Test AI Coach**: Update component with `studentName` prop
3. **Verify logging**: Check `aiInteractionLogs` collection after AI request
4. **Add feedback UI**: Ensure thumbs up/down buttons work
5. **Plan vector store**: Choose Pinecone/Weaviate/Firestore Vector Search
6. **Build educator tools**: Rubric editor, exemplar curator, dashboard

---

**Documentation Date**: March 2026  
**Architecture Version**: 1.1  
**Status**: Production learner guardrails active; retrieval/tooling roadmap still in progress ✅

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `AI_ARCHITECTURE_GUIDE.md`
<!-- TELEMETRY_WIRING:END -->
