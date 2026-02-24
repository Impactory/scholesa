# Implementation Checklist - SDT + Telemetry + Vector DB

## ✅ COMPLETED (Phase 1)

### Core Infrastructure
- [x] **TelemetryService** (src/lib/telemetry/telemetryService.ts)
  - 580 lines, 50+ event types, 8 categories
  - Auto-enrichment (timestamp, device, browser, age band)
  - Daily/weekly aggregation
  - Analytics: `getUserEngagementScore()`, `getSDTProfile()`

- [x] **MotivationEngine** (src/lib/motivation/motivationEngine.ts)
  - AutonomyEngine: Mission choices, goal setting, interests
  - CompetenceEngine: Skill evidence, checkpoints, badges, mastery
  - BelongingEngine: Recognition, showcase, peer feedback
  - ReflectionEngine: Age-appropriate prompts, effort/enjoyment ratings

- [x] **Telemetry Hooks** (src/hooks/useTelemetry.ts)
  - 10 React hooks for easy component integration
  - Auto-tracking: Page views, sessions, interactions
  - Typed: Autonomy, Competence, Belonging, Reflection, AI, Performance

- [x] **Vector Store Stub** (src/lib/ai/vectorStore.ts)
  - EmbeddingService: Generate embeddings (OpenAI text-embedding-3-small)
  - VectorStore: Store/search/update documents
  - VectorIndexer: Batch indexing utilities
  - Similarity utilities (cosine similarity)
  - Migration guide (Firestore Vector Search / Pinecone / Weaviate)

- [x] **Retrieval Service Updated** (src/lib/ai/retrievalService.ts)
  - Hybrid approach: Vector search (Phase 2) + keyword fallback
  - Integrated with vectorStore (ready to enable)
  - Type-safe conversions between context types

### Component Integration
- [x] AICoachPopup - Migrated to `useAITracking()`
- [x] StudentDashboard - Added `usePageViewTracking()`

### Documentation
- [x] SDT_TELEMETRY_IMPLEMENTATION_SUMMARY.md
- [x] This checklist

## 🔄 IN PROGRESS (Phase 2)

### Component Telemetry Expansion
- [ ] **MissionList** - Track mission browsing
  ```tsx
  usePageViewTracking('mission_list');
  const trackAutonomy = useAutonomyTracking();
  // On mission click: trackAutonomy('mission_selected', { missionId });
  ```

- [ ] **CheckpointSubmission** - Track attempts/passes
  ```tsx
  const trackCompetence = useCompetenceTracking();
  // On submit: trackCompetence('checkpoint_attempted', { checkpointNumber });
  // On pass: trackCompetence('checkpoint_passed', { skillsProven: [...] });
  ```

- [ ] **ShowcaseGallery** - Track submissions/views
  ```tsx
  const trackBelonging = useBelongingTracking();
  // On submit: trackBelonging('showcase_submitted', { artifactId });
  ```

- [ ] **RecognitionFlow** - Track peer recognition
  ```tsx
  const trackBelonging = useBelongingTracking();
  // On give: trackBelonging('recognition_given', { recipientId, type });
  ```

- [ ] **ReflectionJournal** - Track reflections/ratings
  ```tsx
  const trackReflection = useReflectionTracking();
  // On submit: trackReflection('reflection_submitted', { promptId });
  // On rating: trackReflection('effort_rated', { rating: 4 });
  ```

### Educator Analytics Dashboard
- [ ] Create `/app/[locale]/(protected)/educator/analytics/page.tsx`
- [ ] Components:
  - [ ] ClassEngagementOverview (heatmap by student)
  - [ ] SDTProfileChart (autonomy/competence/belonging per student)
  - [ ] AtRiskStudents (low engagement alerts)
  - [ ] TopPerformers (high SDT scores)
  - [ ] WeeklyTrends (line charts)
  - [ ] ExportCSV (download analytics)

### Student Motivation Profile
- [ ] Create `/app/[locale]/(protected)/learner/profile/page.tsx`
- [ ] Components:
  - [ ] LearningStyleCard (interests, preferred difficulty)
  - [ ] SkillMasteryDashboard (skills proven, badges earned)
  - [ ] RecognitionWall (peer props received)
  - [ ] ReflectionTimeline (growth over time)
  - [ ] GoalTracker (current goals + progress)

## ⏳ PENDING (Phase 3)

### Vector DB Implementation
Choose ONE option:

#### **Option A: Firestore Vector Search** (Recommended)
- [ ] Enable Firestore Vector Search in Firebase Console
- [ ] Create vector index on `vectorDocuments` collection
- [ ] Get OpenAI API key (for embeddings)
- [ ] Implement `EmbeddingService.generateEmbedding()`:
  ```typescript
  const response = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
    dimensions: 1536
  });
  return response.data[0].embedding;
  ```
- [ ] Implement `VectorStore.search()` using Firestore Vector Search
- [ ] Run `VectorIndexer.reindexAll()` to populate
- [ ] Set `useVectorSearch = true` in retrievalService.ts
- [ ] Test with sample queries

#### **Option B: Pinecone** (If need >1000 dims)
- [ ] Sign up for Pinecone (free tier or $70/month)
- [ ] Create index (1536 dims, cosine similarity)
- [ ] Install `@pinecone-database/pinecone`
- [ ] Implement VectorStore methods with Pinecone SDK
- [ ] Migrate existing rubrics/exemplars
- [ ] Set `useVectorSearch = true`

#### **Option C: Weaviate** (Self-hosted)
- [ ] Deploy Weaviate (Cloud Run / GKE / Weaviate Cloud)
- [ ] Install `weaviate-ts-client`
- [ ] Define schema (VectorDocument class)
- [ ] Implement VectorStore methods
- [ ] Migrate data

### Firestore Security Rules
Add rules for new collections:

```javascript
// telemetryEvents - Learners write own, educators/HQ read all
match /telemetryEvents/{eventId} {
  allow write: if request.auth.uid == request.resource.data.userId;
  allow read: if hasRole(['educator', 'hq']);
}

// telemetryAggregates - Read-only for educators/HQ
match /telemetryAggregates/{aggregateId} {
  allow read: if hasRole(['educator', 'hq']);
  allow write: if false; // Only Cloud Functions can write
}

// learnerGoals - Learners manage own, educators can view
match /learnerGoals/{goalId} {
  allow read: if request.auth.uid == resource.data.learnerId || hasRole(['educator', 'hq']);
  allow create: if request.auth.uid == request.resource.data.learnerId;
  allow update, delete: if request.auth.uid == resource.data.learnerId;
}

// learnerInterestProfiles - Learners manage own, educators can view
match /learnerInterestProfiles/{profileId} {
  allow read: if request.auth.uid == profileId || hasRole(['educator', 'hq']);
  allow write: if request.auth.uid == profileId;
}

// skillMastery - Learners read own, educators write
match /skillMastery/{masteryId} {
  allow read: if request.auth.uid == resource.data.learnerId || hasRole(['educator', 'hq']);
  allow write: if hasRole(['educator']);
}

// recognitionBadges - Public within site
match /recognitionBadges/{badgeId} {
  allow read: if resource.data.siteId == getUserSiteId();
  allow create: if request.auth.uid != null; // Any authenticated user
}

// learnerReflections - Learners write own, educators read
match /learnerReflections/{reflectionId} {
  allow read: if request.auth.uid == resource.data.learnerId || hasRole(['educator', 'hq']);
  allow create: if request.auth.uid == request.resource.data.learnerId;
}

// showcaseSubmissions - Public within site
match /showcaseSubmissions/{submissionId} {
  allow read: if resource.data.siteId == getUserSiteId();
  allow create: if request.auth.uid == request.resource.data.learnerId;
  allow update: if request.auth.uid == resource.data.learnerId; // Can edit caption/delete
}

// peerFeedback - Public within site
match /peerFeedback/{feedbackId} {
  allow read: if resource.data.siteId == getUserSiteId();
  allow create: if request.auth.uid == request.resource.data.giverId;
}

// vectorDocuments - System-only (no direct user access)
match /vectorDocuments/{docId} {
  allow read, write: if false; // Only server-side code
}
```

### Firestore Composite Indexes
Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "telemetryEvents",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "siteId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "telemetryEvents",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "siteId", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "skillMastery",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "learnerId", "order": "ASCENDING" },
        { "fieldPath": "siteId", "order": "ASCENDING" },
        { "fieldPath": "level", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "learnerReflections",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "learnerId", "order": "ASCENDING" },
        { "fieldPath": "siteId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

### Cloud Functions (Aggregation)
Create background function to aggregate telemetry daily:

```typescript
// functions/src/telemetryAggregation.ts
export const aggregateTelemetryDaily = functions.pubsub
  .schedule('0 2 * * *') // Run at 2 AM daily
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    // 1. Query all telemetryEvents from yesterday
    // 2. Group by userId + siteId
    // 3. Count events by category
    // 4. Calculate session duration
    // 5. Write to telemetryAggregates
  });
```

### Testing
- [ ] **Unit tests** for each engine
  - AutonomyEngine: Mission relevance scoring
  - CompetenceEngine: Mastery dashboard calculation
  - BelongingEngine: Recognition filtering
  - ReflectionEngine: Age-band prompt selection
  
- [ ] **Integration tests**
  - Telemetry → Firestore write → Aggregate update
  - Motivation engine → Telemetry trigger
  - Vector search → Context retrieval
  
- [ ] **E2E tests**
  - Mission select → checkpoint → reflection flow
  - Recognition given → notification received
  - Showcase submit → peer feedback
  
- [ ] **Load testing**
  - 1000 events/second telemetry throughput
  - 100 concurrent vector searches
  - Aggregate calculation time (10K events)

### Performance Optimization
- [ ] Batch telemetry writes (max 1 write/5 sec per user)
- [ ] Cache motivation profiles (update hourly)
- [ ] Use aggregates for dashboards (no raw event queries)
- [ ] Lazy-load reflection history (paginate)
- [ ] CDN cache for rubrics/exemplars (rarely change)

### COPPA Compliance
- [ ] PII redaction in telemetry (truncate questions/reflections)
- [ ] Parental consent flags in UserProfile
- [ ] Data retention policy (delete telemetry after 2 years)
- [ ] Opt-out mechanism (pause telemetry collection)
- [ ] Export learner data (GDPR right to access)

## 📊 Success Metrics

Track these KPIs after deployment:

### Engagement Metrics
- **Average session duration**: Target >20 minutes
- **Return rate**: Target >80% weekly
- **Idle time %**: Target <10%

### SDT Metrics
- **Autonomy score**: Target >70% (missions self-selected)
- **Competence score**: Target >60% (checkpoints passed)
- **Belonging score**: Target >50% (recognition + showcase participation)

### AI Interaction Metrics
- **AI hint usage**: Track by grade band (expect higher in K-3)
- **Explain-back completion**: Target >40%
- **AI feedback positive**: Target >75%

### Performance Metrics
- **Page load P90**: Target <2 seconds
- **API error rate**: Target <0.5%
- **Telemetry write latency**: Target <100ms

## 🚀 Deployment Steps

### Pre-Production
1. [ ] Run `npm run lint` - Fix all errors
2. [ ] Run `npm run build` - Verify no build errors
3. [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
4. [ ] Deploy Firestore indexes: `firebase deploy --only firestore:indexes`
5. [ ] Test telemetry in staging with 10 test users
6. [ ] Validate aggregates generate correctly

### Production
1. [ ] Deploy to Vercel: `vercel --prod`
2. [ ] Monitor error logs (first 24 hours)
3. [ ] Check telemetry write volume (expect spike)
4. [ ] Validate educator dashboards load <3 seconds
5. [ ] Send announcement to educators (new analytics available)

### Post-Deployment
1. [ ] Week 1: Monitor engagement metrics
2. [ ] Week 2: Gather educator feedback on analytics
3. [ ] Week 4: Review SDT scores, identify at-risk students
4. [ ] Month 2: A/B test motivation features (e.g., badge notifications)

---

**Last updated**: December 26, 2025  
**Estimated completion**: Phase 1 ✅ (2 hours), Phase 2 (4 hours), Phase 3 (8 hours)  
**Total effort**: ~14 hours to full production

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `IMPLEMENTATION_CHECKLIST.md`
<!-- TELEMETRY_WIRING:END -->
