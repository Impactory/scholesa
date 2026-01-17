# AI Services Quick Reference

## Basic Usage

### 1. Simple AI Request

```typescript
import { AIService } from '@/src/lib/ai/aiService';

const response = await AIService.request({
  learnerId: "user123",
  studentName: "Alex", // For redaction mapping
  siteId: "site1",
  grade: 5,
  studentLevel: "proficient", // optional: emerging | proficient | advanced
  missionId: "python_intro",
  sessionId: "session_abc", // optional
  taskType: "hint_generation", // or: rubric_check, debug_assistance, critique_feedback, explain_concept, reflection_prompt
  question: "Why isn't my for loop working?"
});

// response = {
//   answer: "Try checking if your range starts at 0...",
//   modelUsed: "gemini",
//   logId: "log_xyz", // Use for feedback
//   citations: [...] // Which rubrics/exemplars were used
// }
```

### 2. Convenience Functions

```typescript
import { getAIHint, checkAgainstRubric, getDebugHelp } from '@/src/lib/ai/aiService';

// Hint generation
const hint = await getAIHint(
  learnerId,
  studentName,
  siteId,
  grade,
  missionId,
  "I'm stuck on step 3"
);

// Rubric check
const feedback = await checkAgainstRubric(
  learnerId,
  studentName,
  siteId,
  grade,
  missionId,
  "Here's my code: ..." // Student's artifact
);

// Debug assistance
const debug = await getDebugHelp(
  learnerId,
  studentName,
  siteId,
  grade,
  missionId,
  "print('hello')", // Code
  "SyntaxError: invalid syntax" // Error message
);
```

### 3. Record Feedback (Training Signals)

```typescript
import { recordFeedback as recordAIFeedback } from '@/src/lib/ai/aiService';

// Student clicks thumbs up
await recordAIFeedback(
  response.logId,
  true, // wasHelpful
  "Student clicked helpful button" // optional reason
);

// Student clicks thumbs down
await recordAIFeedback(
  response.logId,
  false,
  "Student said it didn't make sense"
);
```

### 4. Record Outcomes (Did it work?)

```typescript
// After student revises based on AI help
await AIService.recordOutcome(response.logId, {
  studentRevised: true,
  checkpointPassed: true,
  timeToMastery: 180 // seconds from AI help to checkpoint pass
});
```

---

## Rubric Management

### Create a Rubric

```typescript
import { RubricManager } from '@/src/lib/ai/rubricManager';

const rubricId = await RubricManager.createRubric({
  name: "JavaScript Fundamentals",
  description: "Assessment for basic JS concepts",
  status: "active",
  siteId: "site1", // or "*" for global
  grade: 6,
  skillId: "js_basics",
  missionId: "mission_xyz", // optional
  pillarId: "future_skills",
  
  criteria: [
    {
      name: "Syntax & Structure",
      description: "Code follows JS syntax rules",
      weight: 0.4,
      levels: [
        {
          name: "Emerging",
          description: "Frequent syntax errors; needs help fixing",
          score: 1,
          commonMistakes: [
            "Missing semicolons",
            "Undefined variables",
            "Incorrect function syntax"
          ]
        },
        {
          name: "Proficient",
          description: "Code runs without syntax errors",
          score: 2
        },
        {
          name: "Advanced",
          description: "Clean, idiomatic code with best practices",
          score: 3
        }
      ]
    },
    // ... more criteria
  ],
  
  createdBy: educatorId,
  tags: ["javascript", "coding", "fundamentals"]
});
```

### Fetch a Rubric

```typescript
import { getRubricForMission } from '@/src/lib/ai/rubricManager';

// Auto-selects most specific rubric (mission > skill > grade > site > global)
const rubric = await getRubricForMission(
  "site1",
  "mission_xyz",
  6,
  "js_basics" // optional skillId
);

if (rubric) {
  console.log(rubric.name, rubric.version);
}
```

### Update a Rubric (creates new version)

```typescript
await RubricManager.updateRubric(
  rubricId,
  {
    description: "Updated description",
    criteria: [...] // Updated criteria
  },
  educatorId
);

// Version increments automatically
// Old logs still reference old version (audit trail)
```

### Archive a Rubric

```typescript
await RubricManager.archiveRubric(rubricId, educatorId);
// Status changed to "archived", no longer used for new requests
```

---

## Redaction Service

### Manual Redaction (if needed)

```typescript
import { RedactionService, redactStudentQuestion } from '@/src/lib/ai/redactionService';

// Quick redaction for student input
const redacted = redactStudentQuestion(
  "My name is Sarah and my email is sarah@school.com",
  "k3_safe", // or: grades_4_6, grades_7_9, grades_10_12
  { studentNames: ["Sarah"] }
);

// redacted = {
//   redacted: "My name is STUDENT_A and my email is EMAIL_1",
//   replacements: Map { "STUDENT_A" => "Sarah", "EMAIL_1" => "sarah@school.com" },
//   flagged: [] // Potential PII that wasn't replaced
// }
```

**Note**: `AIService.request()` automatically redacts, you usually don't need to call this directly.

---

## Retrieval Service

### Manual Retrieval (advanced)

```typescript
import { RetrievalService } from '@/src/lib/ai/retrievalService';

const contextBlocks = await RetrievalService.retrieve({
  query: "Need help with Python lists",
  missionId: "python_intro",
  learnerId: "user123",
  gradeBand: "grades_4_6",
  topK: 5, // Return top 5 most relevant blocks
  filters: {
    types: ['rubric', 'exemplar'], // Only fetch these types
    minRelevance: 0.7 // Minimum relevance score
  }
});

// contextBlocks = [
//   { type: 'rubric', content: "...", relevance: 0.95 },
//   { type: 'exemplar', content: "...", relevance: 0.85 },
//   ...
// ]
```

**Note**: `AIService.request()` automatically retrieves context, you usually don't need to call this directly.

---

## Interaction Logging

### View Logs (for debugging)

```typescript
import { collection, query, where, getDocs } from 'firebase/firestore';
import { db } from '@/src/firebase/client-init';

const logsQuery = query(
  collection(db, 'aiInteractionLogs'),
  where('learnerId', '==', 'user123'),
  orderBy('timestamp', 'desc'),
  limit(10)
);

const snapshot = await getDocs(logsQuery);
snapshot.docs.forEach(doc => {
  const log = doc.data();
  console.log(log.request.question, log.response.answer, log.outcome?.wasHelpful);
});
```

### Export Training Dataset

```typescript
import { AIInteractionLogger } from '@/src/lib/ai/interactionLogger';

const jsonl = await AIInteractionLogger.exportForTraining(
  "site1",
  {
    minHelpfulRating: 0.7, // Only helpful interactions
    startDate: new Date('2024-01-01'),
    endDate: new Date('2024-12-31'),
    includeOutcomes: true
  }
);

// Download as JSONL file for model fine-tuning
const blob = new Blob([jsonl], { type: 'application/jsonl' });
const url = URL.createObjectURL(blob);
// ... trigger download
```

---

## UI Integration

### In a React Component

```tsx
import { AIService } from '@/src/lib/ai/aiService';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';

function MyComponent() {
  const { user, profile } = useAuthContext();
  const [response, setResponse] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const handleAskAI = async (question: string) => {
    setLoading(true);
    
    try {
      const aiResponse = await AIService.request({
        learnerId: user.id,
        studentName: profile.firstName,
        siteId: profile.activeSiteId,
        grade: profile.gradeLevel || 5,
        studentLevel: profile.level || 'proficient',
        missionId: currentMissionId,
        taskType: 'hint_generation',
        question
      });
      
      setResponse(aiResponse);
    } catch (err) {
      console.error('AI error:', err);
      // Show friendly error
    } finally {
      setLoading(false);
    }
  };
  
  const handleFeedback = async (helpful: boolean) => {
    if (!response?.logId) return;
    
    await recordAIFeedback(
      response.logId,
      helpful,
      helpful ? "Student clicked helpful" : "Student clicked not helpful"
    );
  };
  
  return (
    <div>
      {/* Your UI */}
      <button onClick={() => handleAskAI("Need help")}>Ask AI</button>
      
      {response && (
        <>
          <p>{response.answer}</p>
          <button onClick={() => handleFeedback(true)}>👍</button>
          <button onClick={() => handleFeedback(false)}>👎</button>
        </>
      )}
    </div>
  );
}
```

---

## Environment Variables

### Required

```bash
# Client-side (NEXT_PUBLIC_*)
NEXT_PUBLIC_GEMINI_API_KEY=AIza...

# Server-side (optional, for OpenAI fallback)
OPENAI_API_KEY=sk-...
```

### Model Router Config

```typescript
import { modelRouter } from '@/src/lib/ai/modelAdapter';

// Set default adapter
modelRouter.setDefaultAdapter('gemini'); // or 'openai'

// Override for specific request
const response = await modelRouter.complete(request, 'openai');
```

---

## Best Practices

### ✅ DO

- Always provide `studentName` for redaction mapping
- Record feedback for training dataset
- Use `AIService.request()` (not direct model calls)
- Version your rubrics when making significant changes
- Tag rubrics for easy retrieval
- Check response.citations to see which context was used

### ❌ DON'T

- Don't send raw student data to models (use AIService for auto-redaction)
- Don't hardcode rubrics in prompts (store in DB)
- Don't skip feedback recording (you lose training signals)
- Don't delete old rubric versions (breaks audit trail)
- Don't expose API keys in client code (use NEXT_PUBLIC_* only for Gemini)

---

## Troubleshooting

### "Model request failed"
**Check**: API key valid? Quota not exceeded?  
**Fix**: Verify env vars, check API console for errors

### "No rubric found"
**Check**: Does a rubric exist for this mission/grade/site?  
**Fix**: Create a global fallback (`siteId: '*'`) or seed default rubrics

### "PII detected in logs"
**Check**: Are you using `AIService.request()` or bypassing redaction?  
**Fix**: Always use `AIService.request()`, never call model adapters directly

### "Context not relevant"
**Check**: Vector store not implemented yet (using mocks)  
**Fix**: Wait for Phase 2 (vector DB integration) or manually curate exemplars

---

## Common Patterns

### Pattern 1: Hint → Feedback → Outcome

```typescript
// 1. Get hint
const hint = await getAIHint(learnerId, name, siteId, grade, missionId, question);

// 2. Student clicks "helpful"
await recordAIFeedback(hint.logId, true);

// 3. Student revises and passes checkpoint
await AIService.recordOutcome(hint.logId, {
  studentRevised: true,
  checkpointPassed: true,
  timeToMastery: 120
});
```

### Pattern 2: Rubric Check → Revision Loop

```typescript
// Check work against rubric
const feedback = await checkAgainstRubric(
  learnerId, name, siteId, grade, missionId, artifact
);

// Show feedback to student
// (they revise)

// Check again
const feedback2 = await checkAgainstRubric(...);

// Track revision cycle
await AIService.recordOutcome(feedback2.logId, {
  studentRevised: true,
  checkpointPassed: feedback2.answer.includes("meets criteria")
});
```

### Pattern 3: Debug → Fix → Pass

```typescript
// Get debug help
const debug = await getDebugHelp(
  learnerId, name, siteId, grade, missionId, code, error
);

// Student fixes bug
// (verify fix)

// Record success
await AIService.recordOutcome(debug.logId, {
  studentRevised: true,
  checkpointPassed: true,
  timeToMastery: 60
});
```

---

## Reference

- **Architecture Guide**: `docs/AI_ARCHITECTURE_GUIDE.md`
- **Model Adapter**: `src/lib/ai/modelAdapter.ts`
- **AI Service**: `src/lib/ai/aiService.ts`
- **Rubric Manager**: `src/lib/ai/rubricManager.ts`
- **Redaction Service**: `src/lib/ai/redactionService.ts`
- **Retrieval Service**: `src/lib/ai/retrievalService.ts`
- **Interaction Logger**: `src/lib/ai/interactionLogger.ts`

---

**Last Updated**: December 2024  
**Version**: 1.0
