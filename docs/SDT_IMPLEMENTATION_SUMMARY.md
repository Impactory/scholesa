# Scholesa Motivation Engine - SDT Implementation

## Overview

A comprehensive Self-Determination Theory (SDT) based motivation system for K-9 learners with age-appropriate feature gating and telemetry.

**Core Equation**: Motivation = Autonomy + Competence + Belonging

**Latest Updates** (Dec 2025):
- ✅ AI Help Popup (speech + text input, age-aware)
- ✅ GradeBandPolicy system (K-3, 4-6, 7-9, 10-12 feature gating)
- ✅ Telemetry system with real-time insights
- ✅ Phase A UI components complete

## What's Been Built

### 1. Schema & Types ✅

**File**: [src/types/schema.ts](src/types/schema.ts)

Added 400+ lines of SDT-specific types:

**Autonomy Types**:
- `DifficultyLevel` - Bronze/Silver/Gold challenge levels
- `MissionVariant` - Different paths for same learning goal
- `WeeklyGoal` - Student-set goals
- `LearnerInterestProfile` - Hobbies/themes for mission skinning

**Competence Types**:
- `MicroSkill` - Granular skills with evidence requirements
- `SkillEvidence` - Proof of mastery submissions
- `Badge` + `BadgeAward` - Evidence-based recognition
- `SprintSession` - 15-30min focused work blocks
- `Checkpoint` - Fast feedback points
- `MotivationAnalytics` - Growth metrics (not vanity metrics)

**Belonging Types**:
- `Crew` - Stable teams (4-8 sessions)
- `CrewRole` - Builder/Tester/Reporter rotation
- `ShowcaseSubmission` - Share artifacts with crew/site
- `RecognitionType` - Helper/Debugger/Communicator/Courage
- `PeerFeedback` - Structured "I like/I wonder/Next step"

**Reflection Types**:
- `ReflectionEntry` - "I'm proud of... Next I will..."
- `AICoachInteraction` - Safe AI help with guardrails
- `ParentSnapshot` - Weekly summary for families

### 2. Data Layer ✅

**File**: [src/lib/firestore/collections.ts](src/lib/firestore/collections.ts)

Added 16 new Firestore collections:
```typescript
microSkillsCollection
missionVariantsCollection
crewsCollection
badgesCollection
badgeAwardsCollection
skillEvidenceCollection
sprintSessionsCollection
checkpointsCollection
showcaseSubmissionsCollection
reflectionEntriesCollection
aiCoachInteractionsCollection
weeklyGoalsCollection
learnerInterestProfilesCollection
parentSnapshotsCollection
peerFeedbackCollection
motivationAnalyticsCollection
```

### 3. SDT Motivation Service ✅

**File**: [src/lib/motivation/sdtMotivation.ts](src/lib/motivation/sdtMotivation.ts)

Comprehensive TypeScript service (~400 lines) with three modules:

#### A) Autonomy Module
```typescript
getMissionOptions()      // Bronze/Silver/Gold choices
selectMission()          // Student picks their challenge
updateInterests()        // Hobbies for mission skinning
setWeeklyGoal()         // "Try stretch", "Give feedback", etc.
```

#### B) Competence Module
```typescript
submitSkillEvidence()    // Proof of micro-skill mastery
getProgressInsights()    // Skills proven vs. in-progress
submitCheckpoint()       // Fast feedback with explain-it-back
```

#### C) Belonging Module
```typescript
submitShowcase()         // Share work with crew/site
giveRecognition()        // Celebrate peer strategies
submitPeerFeedback()     // "I like / I wonder / Next step"
```

#### Reflection & AI Help
```typescript
submitReflection()       // "Proud of... Next I will..."
requestAICoach()         // Hint / Rubric Check / Debug
submitExplainBack()      // Guardrail: student must explain
```

#### Dashboard Data
```typescript
getDashboardData()       // Today's mission, streak, notifications
getLearningPath()        // Units → Missions → Skills progression
```

### 4. Phase A UI Components ✅

All components in [src/components/sdt/](src/components/sdt/)

#### Student Dashboard
**File**: `StudentDashboard.tsx`

- **Hero Card**: Today's mission with progress bar
- **Quick Resume**: Continue where they left off  
- **Streak Tracker**: Current/best streaks (attendance + effort)
- **Next Checkpoint**: Due time and number
- **Notifications**: Unread feedback + pending reflections
- **Compact Version**: For mobile/sidebar

#### Learning Path Map
**File**: `LearningPathMap.tsx`

- **Visual Journey**: Units → Missions → Micro-skills
- **Locked/Unlocked States**: Evidence gates progress
- **Next Mission Highlight**: What to do next
- **Skills Proven**: Green badges for completed micro-skills
- **Skills In Progress**: Blue indicators
- **Expandable Units**: Click to see details
- **Compact Version**: Current unit progress only

#### AI Help Screen
**File**: `AICoachScreen.tsx`

- **3 Safe Modes**:
  1. **Give me a hint** - Nudge without answers
  2. **Check my work vs rubric** - Gap analysis
  3. **Help me debug** - Ask questions to guide thinking
  
- **Guardrails**:
  - Explain-it-back required
  - Version history checks
  - No direct answers
  
- **Rubric Alignment**: Shows current vs. target level
- **Next Steps**: Suggested actions
- **Safety Reminders**: "AI helps you think, not do the work"

#### Reflection Journal
**File**: `ReflectionJournal.tsx`

- **Core Prompts**:
  - "I'm proud of..." (accomplishment)
  - "Next I will..." (growth mindset)
  
- **Emoji Scales**:
  - Effort: 😴 🙂 💪 🔥 🚀
  - Enjoyment: 😐 🙂 😊 😄 🤩
  
- **Effective Strategy**: Optional meta-cognition
- **Quick Version**: Post-sprint compact form
- **Encouragement**: "Reflection helps your brain remember!"

#### AI Help Popup ✨ NEW
**File**: `AICoachPopup.tsx`

- **Floating Assistant**: Lower-right corner, minimizable
- **Speech Input**: Microphone button for younger learners (Web Speech API)
- **Text Input**: Typed questions for older students
- **Age-Aware Modes**: Adapts based on GradeBandPolicy
  - K-3: Hint only, teacher guidance required
  - 4-6: Hint + Debug
  - 7-9: Hint + Rubric Check + Debug
  - 10-12: All modes including Critique
- **Explain-Back Requirement**: Must demonstrate understanding
- **Telemetry Integration**: Tracks usage patterns by age band
- **Safety First**: "AI helps you think, not do the work"

### 5. Age-Band Policy System ✨ NEW

**File**: [src/lib/policies/gradeBandPolicy.ts](src/lib/policies/gradeBandPolicy.ts)

Complete developmental appropriateness framework with 4 age bands:

#### Grades K-3 (ages 5-9)
```typescript
{
  sprint: { minMinutes: 5, maxMinutes: 10, suggestedCheckpoints: 1 },
  aiCoach: { 
    modes: ['hint'],
    explainBackRequired: true,
    requireTeacherGuidance: true 
  },
  social: {
    peerFeedbackEnabled: false,
    crewsEnabled: false,
    publicLeaderboards: false
  },
  reflection: {
    promptDepth: 'one_emoji_one_sentence',
    requiredFrequency: 'every_session'
  },
  rubric: { maxLevels: 2, childFriendlyLanguage: true },
  portfolio: { visibility: 'parent_educator_only' },
  gamification: { badgeStyle: 'sticker' }
}
```

#### Grades 4-6 (ages 10-12)
- 15-30min sprints with 2 checkpoints
- Hint + Debug AI modes
- Structured peer feedback enabled
- Crew system introduced
- 3-level rubrics
- Badge style: evidence-based

#### Grades 7-9 (ages 13-15)
- 20-45min sprints with 2-3 checkpoints
- Hint + Rubric Check + Debug AI modes
- Identity-focused reflection ("I am becoming...")
- Student-owned portfolio
- 3-level rubrics with criteria co-creation
- Badge style: mastery-based

#### Grades 10-12 (ages 16-18)
- 30-90min sprints with 3-4 checkpoints
- All AI modes including Critique
- Professional badging (LinkedIn-style)
- Exportable portfolio
- 4-level rubrics
- Real-world showcase events

**Policy Enforcement**:
```typescript
getPolicyForGrade(grade: number)
getAgeBandFromGrade(grade: number)
isFeatureAvailable(grade: number, feature: string)
getAICoachModesForGrade(grade: number)
```

### 6. Telemetry & Intelligence System ✨ NEW

**File**: [src/lib/telemetry/sdtTelemetry.ts](src/lib/telemetry/sdtTelemetry.ts)

Real-time behavioral tracking to understand motivation patterns:

#### Event Tracking
```typescript
// Autonomy signals
trackMissionSelected(learnerId, siteId, grade, missionId, chosenFromOptions)

// Competence signals
trackCheckpointAttempt(learnerId, siteId, grade, sessionId, missionId, passed, attemptNumber)

// Belonging signals
trackPeerFeedback(learnerId, siteId, grade, targetLearnerId, showcaseId)

// Reflection signals
trackReflection(learnerId, siteId, grade, sessionId, effortRating, enjoymentRating)

// AI help signals
trackAICoachUse(learnerId, siteId, grade, sessionId, mode, explainedBack)
```

#### Motivation Metrics
```typescript
{
  // Autonomy
  choiceDiversity: 0-1,           // How varied are choices
  missionSwitchRate: number,      // Switches per session
  goalAlignmentScore: 0-100,      // % aligned with goals
  
  // Competence
  proofSubmissionRate: number,    // Submissions per week
  firstTimeSuccessRate: 0-100,    // % passed without revision
  revisionPersistence: number,    // Avg attempts before passing
  skillMasteryRate: number,       // Skills proven per week
  
  // Belonging
  feedbackGivingRate: number,     // Feedback given per week
  recognitionReceived: number,    // Shout-outs received
  crewParticipation: 0-100,       // % crew sessions attended
  
  // Reflection
  reflectionConsistency: 0-100,   // % sessions with reflection
  effortTrend: number,            // Change in effort rating
  enjoymentTrend: number,         // Change in enjoyment rating
  
  // Time patterns
  avgSessionDuration: number,     // Minutes
  sessionCompletionRate: 0-100,   // % started sessions completed
  optimalTimeOfDay: string        // When most engaged
}
```

#### Motivation Insights
```typescript
{
  type: 'strength' | 'opportunity' | 'nudge',
  category: 'autonomy' | 'competence' | 'belonging',
  message: string,
  suggestedAction?: string,
  confidence: 0-1
}
```

**Example Insights**:
- "High first-time success rate → Suggest harder missions"
- "Struggles with checkpoints but persists → Offer AI help nudge"
- "Not giving peer feedback → Prompt to review teammate's work"

#### Collections
- `telemetryEvents` - Raw event stream with timestamps
- `motivationAnalytics` - Real-time aggregates (efficient reads)
- Auto-increments on key events (mission selected, checkpoint passed, etc.)

## The Core Loop (What Happens Every Session)

```
1. Hook (curiosity) → Mystery/demo/real problem (30-90s)
2. Pick a Path (autonomy) → Choose Bronze/Silver/Gold
3. Build Sprint (competence) → 15-30min with clear "done looks like..."
4. Checkpoint (fast feedback) → Upload + explain-it-back
5. Showcase (belonging) → Share artifact (photo/video/code)
6. Reflection (identity) → "Proud of... Next I will..."
```

## Integration Examples

### Learner Dashboard with AI Help
```tsx
import { 
  StudentDashboard, 
  LearningPathMap, 
  ReflectionJournal,
  AICoachScreen,
  AICoachPopup  // ✨ NEW
} from '@/src/components/sdt';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';

function LearnerHome({ siteId }) {
  const { profile } = useAuthContext();
  
  return (
    <div>
      <StudentDashboard 
        learnerId={profile.uid} 
        siteId={siteId}
        onStartMission={() => navigate('/missions')}
        onResumeWork={() => navigate('/sprint')}
      />
      
      <LearningPathMap
        learnerId={profile.uid}
        siteId={siteId}
        onSelectMission={(id) => startMission(id)}
      />
      
      {/* AI Help Popup - always available */}
      <AICoachPopup
        learnerId={profile.uid}
        siteId={siteId}
        grade={profile.grade || 1}
        sprintSessionId={currentSprint?.id}
        missionId={currentMission?.id}
      />
    </div>
  );
}
```

### Telemetry Integration
```tsx
import { 
  trackMissionSelected,
  trackCheckpointAttempt,
  trackReflection,
  trackAICoachUse
} from '@/src/lib/telemetry/sdtTelemetry';

// When learner selects a mission
await trackMissionSelected(
  learnerId, 
  siteId, 
  grade, 
  selectedMissionId,
  optionsCount  // How many they chose from
);

// When checkpoint is attempted
await trackCheckpointAttempt(
  learnerId,
  siteId,
  grade,
  sprintId,
  missionId,
  passed,
  attemptNumber
);

// When reflection submitted
await trackReflection(
  learnerId,
  siteId,
  grade,
  sprintId,
  effortRating,     // 1-5
  enjoymentRating   // 1-5
);
```

### Age-Aware Feature Gating
```tsx
import { getPolicyForGrade, isFeatureAvailable } from '@/src/lib/policies/gradeBandPolicy';

function MissionScreen({ grade }) {
  const policy = getPolicyForGrade(grade);
  
  return (
    <div>
      {/* Sprint duration adapts by age */}
      <SprintTimer 
        minMinutes={policy.sprint.minMinutes}
        maxMinutes={policy.sprint.maxMinutes}
      />
      
      {/* Peer feedback only for grades 4+ */}
      {policy.social.peerFeedbackEnabled && (
        <PeerFeedbackButton />
      )}
      
      {/* AI help modes filtered by age */}
      <AICoachPopup
        availableModes={policy.aiCoach.modes}
        requireExplainBack={policy.aiCoach.explainBackRequired}
        requireTeacherGuidance={policy.aiCoach.requireTeacherGuidance}
      />
    </div>
  );
}
```

## Key Design Principles

### 1. Visible Mastery, Not Points
- Progress bars show "skills proven" not "time spent"
- Badges require evidence (upload/quiz/demo/version history)
- Rubrics use student-friendly language

### 2. Choice Within Structure
- 3 difficulty levels per mission (Bronze/Silver/Gold)
- Interest-based mission themes
- Student voice: "What do you want to build for?"

### 3. Celebrate Strategies, Not Speed
- Recognition tokens for behaviors (Helper, Debugger, etc.)
- Reflection on "what strategy worked"
- "Mistakes are data" messaging

### 4. Psychological Safety Built-In
- "Show your v1" prompts
- Crew system for stable peer support
- Peer feedback templates with kindness guardrails

## What to Track (Motivation Analytics)

**Evidence-Based Metrics:**
- ✅ Proof of Learning rate (artifact + reflection submitted)
- ✅ Checkpoint pass rate (attempts to mastery)
- ✅ Revisions per project (iteration = learning)
- ✅ Peer feedback given (belonging signals)
- ✅ Role rotation completions (crew engagement)
- ✅ Choice distribution (difficulty levels picked)
- ✅ AI Help usage patterns (by mode and age band)
- ✅ Effort/enjoyment trends over time
- ✅ Session completion rate
- ✅ Optimal time of day for engagement

**Skip (Harmful Vanity Metrics):**
- ❌ Total points
- ❌ Leaderboards (comparison kills motivation)
- ❌ Speed-based rewards
- ❌ Streak shaming ("you broke your streak!")
- ❌ Public failure indicators

**Age-Band Specific Tracking:**
- K-3: Focus on effort emoji trends, teacher guidance needs
- 4-6: Track choice diversity, crew participation
- 7-9: Monitor reflection depth, identity language
- 10-12: Analyze portfolio quality, real-world connections

## Age-Band Tuning (Developmental Appropriateness)

### Grades K-3 (Ages 5-9) - Safety + Wonder
**Sprint**: 5-10 minutes, 1 checkpoint
**AI Help**: Hint only, teacher guidance required, explain-back enforced
**Social**: No peer feedback, no crews (1:1 teacher connection)
**Reflection**: One emoji + one sentence ("I'm proud I...")
**Rubric**: 2 levels (Not Yet / Got It) with pictures
**Portfolio**: Parent + educator view only
**Gamification**: Sticker-style badges
**UI**: Large buttons, lots of visual cues, minimal text

**Key Constraints**:
- No public leaderboards
- No timed challenges
- No peer messaging
- Teacher must approve AI help use

### Grades 4-6 (Ages 10-12) - Agency + Teamwork
**Sprint**: 15-30 minutes, 2 checkpoints
**AI Help**: Hint + Debug modes, explain-back required
**Social**: Structured peer feedback ("I like / I wonder / Next step"), crews enabled with roles
**Reflection**: Two prompts ("Proud of... Next I will..."), effort + enjoyment emojis
**Rubric**: 3 levels (Emerging / Proficient / Advanced) with examples
**Portfolio**: Student-curated, parent + educator view
**Gamification**: Evidence-based badges (upload proof)
**UI**: Clear navigation, progress bars, achievement unlocks

**Key Features**:
- Bronze/Silver/Gold difficulty choice
- Crew roles (Builder/Tester/Reporter) with rotation
- Recognition tokens for behaviors
- "Mistakes are data" messaging

### Grades 7-9 (Ages 13-15) - Identity + Relevance
**Sprint**: 20-45 minutes, 2-3 checkpoints
**AI Help**: Hint + Rubric Check + Debug, explain-back required
**Social**: Open peer feedback with moderation, crew competitions, showcase events
**Reflection**: Identity-focused ("I am becoming... I care about...")
**Rubric**: 3 levels with criteria co-creation
**Portfolio**: Student-owned, selective public sharing
**Gamification**: Mastery-based badges with pathways
**UI**: Personalization options, dark mode, minimal friction

**Key Features**:
- Community issue-based missions
- Plan/Predict/Monitor/Reflect metacognition cycle
- Portfolio as identity artifact
- Real-world mentor connections

### Grades 10-12 (Ages 16-18) - Purpose + Credibility
**Sprint**: 30-90 minutes, 3-4 checkpoints
**AI Help**: All modes including Critique, explain-back for new concepts
**Social**: Full peer review, professional networking, public showcases
**Reflection**: Career + impact focus ("This connects to...")
**Rubric**: 4 levels (professional standard)
**Portfolio**: Exportable (LinkedIn, resume), public by default
**Gamification**: Professional badging (stackable credentials)
**UI**: Clean, portfolio-first, export options

**Key Features**:
- Real clients/problems
- Industry mentors
- "Evidence over opinions" culture
- College/career integration
- Capstone showcase events

## Next Steps

### Phase B (Belonging + Community) - IN PROGRESS
- [ ] **Crew Hub** - Team dashboard with goals, roles, shout-outs
- [ ] **Peer Feedback Screen** - "I like/I wonder/Next step" templates
- [ ] **Progress Insights** - Skills timeline, suggested next missions
- [ ] **Showcase Gallery** - Presentation mode for crew/site showcases

### Phase C (Mastery + Assessment)
- [ ] **Portfolio Builder** - Auto-collect showcase projects with curation
- [ ] **Parent Snapshot** - Weekly 1-page summary generator
- [ ] **Rubrics Editor** - Age-appropriate success criteria
- [ ] **Educator Feedback Inbox** - Comments + resubmission flow

### Phase D (Autonomy + Personalization)
- [ ] **Goal Setter** - Weekly personal targets with progress tracking
- [ ] **Interest Picker** - Mission theme customization engine
- [ ] **Choice History** - Self-awareness tool showing patterns
- [ ] **Motivation Dashboard** - Learner-facing insights

### Backend Implementation (HIGH PRIORITY)
- [ ] Implement Firebase Functions for all `sdtMotivation.ts` operations
- [ ] Add Firestore security rules for 17 new collections
- [ ] Set up composite indexes for compound queries
- [ ] Implement server-side telemetry aggregation (Cloud Functions)
- [ ] Add ML-based motivation insight generation
- [ ] Create parent snapshot auto-generator function
- [ ] Build crew rotation scheduler
- [ ] Implement badge award verification logic

### Infrastructure
- [ ] Add Web Speech API polyfill for older browsers
- [ ] Set up telemetry event batching (reduce Firestore writes)
- [ ] Create admin dashboard for monitoring telemetry patterns
- [ ] Build educator insight reports (per-site analytics)
- [ ] Implement offline support for telemetry (queue events)

## Files Created/Modified

### New Files ✨
```
src/lib/policies/gradeBandPolicy.ts (450 lines)
src/lib/telemetry/sdtTelemetry.ts (350 lines)
src/components/sdt/AICoachPopup.tsx (400 lines)
```

### Enhanced Files
```
src/types/schema.ts (enhanced with 400+ lines)
src/lib/firestore/collections.ts (17 collections total)
src/lib/motivation/sdtMotivation.ts (400 lines)
src/components/sdt/
  ├── StudentDashboard.tsx (290 lines)
  ├── LearningPathMap.tsx (360 lines)
  ├── AICoachScreen.tsx (320 lines) - full-page version
  ├── AICoachPopup.tsx (400 lines) - ✨ floating popup version
  ├── ReflectionJournal.tsx (350 lines)
  └── index.ts (exports)
SDT_IMPLEMENTATION_SUMMARY.md (this file, updated)
```

## Tech Stack

- **TypeScript**: Full type safety
- **React 18**: Client components with hooks
- **Firebase Functions v2**: Backend callable functions
- **Firestore**: NoSQL database
- **TailwindCSS**: Utility-first styling
- **Lucide Icons**: Consistent iconography

## Philosophy

> "Motivation = Autonomy (choice) + Competence (visible progress) + Belonging (team + recognition)"

This implementation productizes Self-Determination Theory into an app-ready system that helps K-9 learners develop intrinsic motivation through:

1. **Autonomy**: Choice of difficulty, themes, goals
2. **Competence**: Micro-skills, evidence, fast feedback
3. **Belonging**: Crews, showcases, peer recognition
4. **Identity**: Reflection, growth mindset, strategy awareness

The system learns what motivates each child through:
- Educator feedback patterns
- Mission choice history
- Engagement analytics
- Reflection content analysis
- Peer interaction quality

---

*Built with ❤️ for Scholesa Education 2.0 OS*

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `SDT_IMPLEMENTATION_SUMMARY.md`
<!-- TELEMETRY_WIRING:END -->
