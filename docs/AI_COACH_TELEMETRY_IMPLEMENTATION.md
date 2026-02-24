# AI Coach Popup + Telemetry Implementation Summary

## What Was Built (December 2025)

### 1. AI Coach Popup Component ✅
**File**: [src/components/sdt/AICoachPopup.tsx](src/components/sdt/AICoachPopup.tsx)

A floating, always-available AI assistant in the lower-right corner that adapts to learner age and developmental stage.

**Key Features**:
- **Minimizable floating button** - Stays accessible without blocking workspace
- **Speech input** - Microphone button uses Web Speech API (perfect for younger learners)
- **Text input** - Typed questions for older students
- **Age-aware modes** - Automatically filters AI Coach modes based on grade level:
  - K-3: Hint only (teacher guidance required)
  - 4-6: Hint + Debug
  - 7-9: Hint + Rubric Check + Debug
  - 10-12: All modes including Critique
- **Explain-back requirement** - Learners must demonstrate understanding before proceeding
- **Telemetry integration** - Tracks usage patterns by mode, grade, and explain-back compliance
- **Safety-first messaging** - "AI helps you think, not do the work"

**Technical Implementation**:
- Web Speech API with TypeScript declarations
- GradeBandPolicy integration for age-appropriate feature gating
- Real-time telemetry tracking
- Rubric alignment display
- Suggested next steps
- Error handling and graceful degradation

### 2. Age-Band Policy System ✅
**File**: [src/lib/policies/gradeBandPolicy.ts](src/lib/policies/gradeBandPolicy.ts)

Complete developmental appropriateness framework defining what features are available at each age band.

**4 Age Bands**:

#### K-3 (Ages 5-9) - Safety + Wonder
```typescript
{
  sprint: { minMinutes: 5, maxMinutes: 10 },
  aiCoach: { 
    modes: ['hint'],
    requireTeacherGuidance: true 
  },
  social: { peerFeedbackEnabled: false },
  portfolio: { visibility: 'parent_educator_only' },
  gamification: { badgeStyle: 'sticker' }
}
```

#### 4-6 (Ages 10-12) - Agency + Teamwork
- 15-30min sprints, Hint + Debug AI, crews enabled, evidence-based badges

#### 7-9 (Ages 13-15) - Identity + Relevance
- 20-45min sprints, Hint + Rubric + Debug AI, student-owned portfolio, mastery badges

#### 10-12 (Ages 16-18) - Purpose + Credibility
- 30-90min sprints, all AI modes including Critique, exportable portfolio, professional badges

**Helper Functions**:
```typescript
getPolicyForGrade(grade: number): GradeBandPolicy
getAgeBandFromGrade(grade: number): AgeBand
isFeatureAvailable(grade: number, feature: string): boolean
getAICoachModesForGrade(grade: number): CoachMode[]
```

### 3. Telemetry & Intelligence System ✅
**File**: [src/lib/telemetry/sdtTelemetry.ts](src/lib/telemetry/sdtTelemetry.ts)

Real-time behavioral tracking system to understand what motivates each learner.

**Event Types Tracked**:
- **Autonomy signals**: mission browsed/selected/switched, goals set
- **Competence signals**: evidence submitted/revised, checkpoints attempted/passed/failed
- **Belonging signals**: showcases submitted, recognition given/received, peer feedback
- **Reflection signals**: reflections submitted, effort/enjoyment rated
- **AI Coach signals**: AI used, explain-back submitted
- **Time signals**: sessions started/resumed/paused/completed

**Motivation Metrics Computed**:
```typescript
{
  // Autonomy
  choiceDiversity: 0-1,           // Variety in mission choices
  goalAlignmentScore: 0-100,      // % missions aligned with goals
  
  // Competence
  firstTimeSuccessRate: 0-100,    // % passed without revision
  revisionPersistence: number,    // Avg attempts before mastery
  
  // Belonging
  feedbackGivingRate: number,     // Peer feedback per week
  crewParticipation: 0-100,       // % crew sessions attended
  
  // Reflection
  reflectionConsistency: 0-100,   // % sessions with reflection
  effortTrend: number,            // Change in effort rating over time
}
```

**Motivation Insights Generated**:
- "High first-time success rate → Suggest harder missions"
- "Struggles with checkpoints but persists → Offer AI Coach nudge"
- "Not giving peer feedback → Prompt to review teammate's work"

**Collections**:
- `telemetryEvents` - Raw event stream (timestamp, type, metadata, ageBand)
- `motivationAnalytics` - Real-time aggregates (efficient reads, auto-increments)

**Convenience Functions**:
```typescript
trackMissionSelected()
trackCheckpointAttempt()
trackPeerFeedback()
trackReflection()
trackAICoachUse()
```

## Integration Guide

### Add AI Coach Popup to Layout
```tsx
'use client';

import { AICoachPopup } from '@/src/components/sdt';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';

export function LearnerLayout({ children, siteId }) {
  const { profile } = useAuthContext();
  
  return (
    <div>
      {children}
      
      {/* Global AI Coach - always available */}
      {profile && (
        <AICoachPopup
          learnerId={profile.uid}
          siteId={siteId}
          grade={profile.grade || 1}
          sprintSessionId={currentSprint?.id}
          missionId={currentMission?.id}
        />
      )}
    </div>
  );
}
```

### Track Mission Selection
```tsx
import { trackMissionSelected } from '@/src/lib/telemetry/sdtTelemetry';

async function handleMissionSelect(missionId: string) {
  await trackMissionSelected(
    learnerId,
    siteId,
    profile.grade,
    missionId,
    availableOptions.length  // How many they chose from
  );
  
  // Start mission...
}
```

### Age-Aware Feature Rendering
```tsx
import { getPolicyForGrade } from '@/src/lib/policies/gradeBandPolicy';

function MissionWorkspace({ grade }) {
  const policy = getPolicyForGrade(grade);
  
  return (
    <div>
      {/* Sprint timer adapts to age */}
      <Timer maxMinutes={policy.sprint.maxMinutes} />
      
      {/* Peer feedback only for grades 4+ */}
      {policy.social.peerFeedbackEnabled && (
        <PeerFeedbackSection />
      )}
      
      {/* Reflection depth adapts */}
      <ReflectionPrompts depth={policy.reflection.promptDepth} />
    </div>
  );
}
```

## How Intelligence Works

### 1. Track Everything (Without Breaking UX)
- Events fire asynchronously (don't block UI)
- Real-time aggregates update in background
- Telemetry failures are silent (logged but don't throw)

### 2. Compute Metrics (Server-Side)
- Firebase Function processes telemetry events weekly
- Computes motivation metrics per learner
- Groups by age band for cohort analysis

### 3. Generate Insights (Rule-Based + ML)
- Rule-based insights for immediate patterns
- ML model (future) for complex motivation prediction
- Educator dashboard shows actionable suggestions

### 4. Adapt Experience
- Low choice diversity → Surface more mission options
- High revision persistence → Suggest AI Coach or scaffolding
- Low peer feedback → Nudge to review teammate's work
- High first-time success → Recommend harder missions

## Files Created/Modified

### New Files ✨
```
src/lib/policies/gradeBandPolicy.ts        (450 lines)
src/lib/telemetry/sdtTelemetry.ts          (350 lines)
src/components/sdt/AICoachPopup.tsx        (440 lines)
```

### Modified Files
```
src/lib/firestore/collections.ts           (+1 collection: telemetryEvents)
src/lib/motivation/sdtMotivation.ts        (added 'critique' AI mode)
SDT_IMPLEMENTATION_SUMMARY.md              (comprehensive update)
```

## What's Left to Build

### Phase B (Belonging + Community)
- [ ] Crew Hub - Team dashboard with roles and goals
- [ ] Peer Feedback UI - Structured templates with age-appropriate moderation
- [ ] Progress Insights - Skills timeline, next mission suggestions

### Phase C (Mastery + Assessment)
- [ ] Portfolio Builder - Auto-collect with student curation
- [ ] Parent Snapshot - Weekly 1-page auto-generator
- [ ] Rubrics Component - Age-appropriate success criteria viewer

### Backend (HIGH PRIORITY)
- [ ] Firebase Functions for all `sdtMotivation.ts` operations
- [ ] Server-side telemetry aggregation (Cloud Functions)
- [ ] Motivation insight generation (weekly batch job)
- [ ] Firestore security rules for new collections
- [ ] Composite indexes for queries

## Key Design Decisions

### Why Floating Popup Instead of Full Screen?
- **Always accessible** - Don't force context switch away from work
- **Lower barrier** - Quick question without disrupting flow
- **Speech-first for K-3** - Easier than typing for younger learners
- **Minimizable** - Get out of the way when not needed

### Why Age-Band Policies?
- **Developmental appropriateness** - K-3 needs different scaffolding than 10-12
- **Safety first** - Younger learners need more guardrails
- **Gradual release** - Features unlock as students mature
- **Prevents feature creep** - Clear boundaries for what's available when

### Why Telemetry Everything?
- **App learns over time** - Patterns emerge from real behavior
- **Evidence-based nudges** - Don't guess what motivates, measure it
- **Age-specific insights** - K-3 patterns differ from 10-12
- **Educator visibility** - Teachers see what's working at site level

## Success Metrics

### Short-term (1-2 months)
- [ ] 80%+ of learners use AI Coach at least once per week
- [ ] Explain-back completion rate >70% (shows understanding)
- [ ] Age-appropriate mode usage (K-3 stays in 'hint' mode)
- [ ] Telemetry coverage >95% of interactions

### Medium-term (3-6 months)
- [ ] Motivation insights accuracy >75% (educator validation)
- [ ] Learners with low autonomy signals show +20% choice diversity after nudges
- [ ] Reflection consistency improves from <50% to >70%
- [ ] AI Coach reduces checkpoint revision rate by 15%

### Long-term (6-12 months)
- [ ] Predictive model forecasts motivation drop 2 weeks ahead (80% accuracy)
- [ ] Personalized mission recommendations increase engagement by 25%
- [ ] Age-band specific interventions show measurable improvement
- [ ] Educators report 30% time saved on motivation troubleshooting

---

**Built with ❤️ for Scholesa Education 2.0 OS**  
*December 2025 - AI Coach Popup + Age-Band Policies + Telemetry System*

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `AI_COACH_TELEMETRY_IMPLEMENTATION.md`
<!-- TELEMETRY_WIRING:END -->
