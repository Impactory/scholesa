# SDT + Motivational Engine - Deployment & Testing Guide

## Overview

This guide covers deployment and testing of the Self-Determination Theory (SDT) framework with AI-powered motivational engine and comprehensive telemetry tracking.

## Pre-Deployment Checklist

### 1. Code Verification
- [ ] All TypeScript files compile without errors (`npm run build`)
- [ ] ESLint passes (`npm run lint`)
- [ ] No console errors in local development
- [ ] Firebase emulators work locally (optional but recommended)

### 2. Firebase Configuration
- [ ] Firestore security rules reviewed ([firestore.rules](../firestore.rules))
- [ ] Composite indexes configured ([firestore.indexes.json](../firestore.indexes.json))
- [ ] Cloud Functions configured ([functions/src/telemetryAggregator.ts](../functions/src/telemetryAggregator.ts))
- [ ] Firebase Admin SDK credentials set (service account JSON or `GOOGLE_APPLICATION_CREDENTIALS`)

### 3. Environment Variables
Ensure all required environment variables are set in production:

**Client-side (Vercel/Cloud Run):**
```bash
NEXT_PUBLIC_FIREBASE_API_KEY=<your-api-key>
NEXT_PUBLIC_FIREBASE_PROJECT_ID=<your-project-id>
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=<your-auth-domain>
NEXT_PUBLIC_FIREBASE_APP_ID=<your-app-id>
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=<your-storage-bucket>
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=<your-sender-id>
```

**Server-side (Cloud Functions):**
```bash
FIREBASE_SERVICE_ACCOUNT=<base64-encoded-service-account-json>
# OR
GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
```

---

## Deployment Steps

### Step 1: Deploy Firestore Rules & Indexes

```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy composite indexes (this takes 5-20 minutes)
firebase deploy --only firestore:indexes
```

**Wait for indexes to build completely before proceeding.**

Check index status:
```bash
firebase firestore:indexes
```

All indexes should show status: `READY`.

### Step 2: Deploy Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies (if not already done)
npm install

# Deploy all functions
firebase deploy --only functions
```

**Functions deployed:**
- `aggregateDailyTelemetry` (runs at 2:00 AM UTC daily)
- `aggregateWeeklyTelemetry` (runs at 3:00 AM UTC every Monday)
- `triggerTelemetryAggregation` (HTTP endpoint for manual triggers)

**Test manual trigger:**
```bash
curl https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/triggerTelemetryAggregation
```

### Step 3: Deploy Next.js Application

**Option A: Vercel (Recommended)**
```bash
# Build locally to verify
npm run build

# Deploy to Vercel
vercel --prod
```

**Option B: Cloud Run**
```bash
# Build Docker image
docker build -t gcr.io/YOUR_PROJECT_ID/scholesa-web:latest .

# Push to Container Registry
docker push gcr.io/YOUR_PROJECT_ID/scholesa-web:latest

# Deploy to Cloud Run
gcloud run deploy scholesa-web \
  --image gcr.io/YOUR_PROJECT_ID/scholesa-web:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

The deploy principal must be able to push to Artifact Registry. When `gcr.io/YOUR_PROJECT_ID/...` names are backed by Artifact Registry, grant `roles/artifactregistry.writer` and verify access to the `gcr.io` repository in the `us` multi-region before running the deploy.

**Web deployment standard**
```bash
./scripts/deploy.sh cloudrun-web
```

---

## Testing Checklist

### Phase 1: Infrastructure Tests

#### 1.1 Telemetry Service
- [ ] Create test telemetry event:
  ```typescript
  await TelemetryService.trackEvent(
    'test-user-id',
    'test-site-id',
    'autonomy',
    'test_event',
    { test: true }
  );
  ```
- [ ] Verify event appears in Firestore `telemetryEvents` collection
- [ ] Verify `userId`, `siteId`, `category`, `eventName`, `timestamp`, and `metadata` fields

#### 1.2 Motivation Engines
- [ ] **AutonomyEngine**: Set a goal
  ```typescript
  const goalId = await AutonomyEngine.setGoal(
    'test-learner-id',
    'test-site-id',
    'Learn TypeScript',
    new Date('2025-02-01')
  );
  ```
- [ ] Verify `learnerGoals` document created with correct fields
- [ ] Verify `goal_set` telemetry event tracked

- [ ] **CompetenceEngine**: Record checkpoint passed
  ```typescript
  await CompetenceEngine.recordCheckpointPassed(
    'test-learner-id',
    'test-site-id',
    'checkpoint-123',
    ['skill-1', 'skill-2'],
    85 // score
  );
  ```
- [ ] Verify `checkpointHistory` document created
- [ ] Verify `checkpoint_passed` telemetry event tracked

- [ ] **BelongingEngine**: Give recognition
  ```typescript
  const recognitionId = await BelongingEngine.giveRecognition(
    'sender-id',
    'recipient-id',
    'test-site-id',
    'helpful',
    'Great teamwork!'
  );
  ```
- [ ] Verify `recognitionBadges` document created
- [ ] Verify `recognition_given` telemetry event tracked

#### 1.3 Vector Store
- [ ] Add test vector document:
  ```typescript
  await VectorStore.addDocument(
    'test-doc-id',
    'test-site-id',
    'Test content for similarity search',
    'skill', // type
    [0.1, 0.2, 0.3, ..., 0.9] // 384-dim embedding
  );
  ```
- [ ] Verify document in `vectorDocuments` collection
- [ ] Test similarity search (returns empty array without OpenAI API key)

---

### Phase 2: Component Integration Tests

#### 2.1 Goal Setting Form
**Test Flow:**
1. Navigate to [Student Motivation Profile](../src/components/motivation/StudentMotivationProfile.tsx)
2. Click "+ Set New Goal" button
3. Fill in goal description: "Complete 5 missions this month"
4. Set target date: Tomorrow's date
5. Click "Set Goal"

**Verify:**
- [ ] Modal closes after submission
- [ ] `learnerGoals` document appears in Firestore with correct `userId`, `siteId`, `description`, `targetDate`, `status='active'`
- [ ] `goal_set` telemetry event in `telemetryEvents` with metadata: `{ goalId, description, targetDate, daysUntilTarget }`

#### 2.2 Checkpoint Submission
**Test Flow:**
1. Navigate to checkpoint submission page
2. Answer questions (any answers)
3. Submit checkpoint

**Verify:**
- [ ] "Grading" loader appears briefly
- [ ] Result screen shows either "Passed" or "Try Again"
- [ ] `checkpointHistory` document created with `status='passed'` or `status='failed'`
- [ ] `checkpoint_attempted` telemetry event tracked
- [ ] `checkpoint_passed` telemetry event tracked (if passed)

#### 2.3 Showcase Submission
**Test Flow:**
1. Navigate to [Showcase Gallery](../src/components/showcase/ShowcaseGallery.tsx)
2. Click "Submit Work" button
3. Fill in title: "My Amazing Project"
4. Fill in description: "I built a robot that..."
5. Select visibility: "Site"
6. Click "Submit to Showcase"

**Verify:**
- [ ] Modal closes after submission
- [ ] `showcaseSubmissions` document created with `status='pending'`
- [ ] `showcase_submitted` telemetry event tracked with metadata: `{ visibility, titleLength, descriptionLength, hasArtifact }`
- [ ] Document appears in Firestore with correct fields

#### 2.4 Peer Recognition
**Test Flow:**
1. Navigate to Showcase Gallery
2. Click "Recognize" button on any showcase item
3. Select recognition type: "Helpful"
4. Add optional message: "You helped me so much!"
5. Click "Send Recognition"

**Verify:**
- [ ] Modal closes after submission
- [ ] `recognitionBadges` document created
- [ ] `recognition_given` telemetry event tracked with metadata: `{ recipientId, recognitionType, hasMessage, messageLength }`
- [ ] Recognition count increments on showcase item (after refresh)

#### 2.5 Reflection Form
**Test Flow:**
1. Navigate to mission completion page
2. Fill in reflection prompts:
   - Effort rating: 4/5
   - Enjoyment rating: 5/5
   - What I learned: "I learned about..."
   - What was challenging: "The hardest part was..."
3. Submit reflection

**Verify:**
- [ ] `reflectionEntries` document created
- [ ] `reflection_submitted` telemetry event tracked with metadata: `{ effort, enjoyment, hasLearning, hasChallenges }`

---

### Phase 3: Analytics Dashboard Tests

#### 3.1 Educator Analytics Dashboard
**Test Flow:**
1. Log in as educator
2. Navigate to [Analytics Dashboard](../src/components/analytics/AnalyticsDashboard.tsx)
3. Select time range: "Last Week"
4. View student engagement data

**Verify:**
- [ ] Table displays students with real data (not mock data)
- [ ] SDT scores calculated correctly (autonomy %, competence %, belonging %)
- [ ] Event count matches Firestore `telemetryEvents` count for each student
- [ ] Last active timestamp is accurate
- [ ] At-risk students highlighted (engagement < 30%)

#### 3.2 Weekly Trends Chart
**Verify:**
- [ ] SVG chart renders with 4 lines (engagement, autonomy, competence, belonging)
- [ ] X-axis labels show dates for last 7 days
- [ ] Y-axis scale 0-100%
- [ ] Legend displays with color indicators
- [ ] Data points match aggregated telemetry data

#### 3.3 CSV Export
**Test Flow:**
1. Click "Export CSV" button
2. Wait for download

**Verify:**
- [ ] CSV file downloads with correct filename: `{siteName}_analytics_YYYY-MM-DD.csv`
- [ ] CSV has headers: `Student Name,Engagement %,Autonomy %,Competence %,Belonging %,Events,Last Active`
- [ ] All students included in export
- [ ] Data matches table display

---

### Phase 4: Cloud Function Tests

#### 4.1 Daily Aggregation Function
**Manual Trigger:**
```bash
curl -X POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/triggerTelemetryAggregation
```

**Verify:**
- [ ] Function completes without errors (check Cloud Functions logs)
- [ ] `telemetryAggregates` collection has new documents
- [ ] Document ID format: `{userId}_{siteId}_YYYY-MM-DD`
- [ ] Fields populated correctly:
  - `userId`, `siteId`, `date`, `aggregationType='daily'`
  - `totalEvents` > 0
  - `categoryCounts` object with counts per category
  - `sdtCounts` object with autonomy/competence/belonging/reflection counts
  - `engagementScore` (0-100)
  - `createdAt` timestamp

#### 4.2 Weekly Aggregation Function
**Manual Test:** Change schedule to run in 1 minute, redeploy, wait

**Verify:**
- [ ] Function runs on schedule (check logs every Monday at 3:00 AM UTC)
- [ ] `telemetryAggregates` collection has weekly documents
- [ ] Document ID format: `{userId}_{siteId}_week_YYYY-MM-DD`
- [ ] `aggregationType='weekly'`
- [ ] Data aggregates last 7 days correctly

---

### Phase 5: End-to-End User Flow

#### Learner Journey Test
1. **Login** as learner
2. **Set Goal**: "Complete 3 missions this week"
3. **Start Mission**: Select a mission from dashboard
4. **Complete Checkpoint**: Submit answers, receive feedback
5. **Submit Reflection**: Rate effort/enjoyment, write learnings
6. **Submit to Showcase**: Share completed work with site
7. **Give Recognition**: Recognize a peer's showcase submission
8. **View Motivation Profile**: Check SDT scores and progress

**Verify at each step:**
- [ ] Telemetry events tracked correctly
- [ ] Firestore documents created
- [ ] UI updates reflect changes
- [ ] No console errors

#### Educator Journey Test
1. **Login** as educator
2. **View Analytics Dashboard**: See real-time student engagement
3. **Identify At-Risk Students**: Check students with low engagement
4. **Export CSV**: Download analytics report
5. **View Weekly Trends**: Analyze engagement over time

**Verify:**
- [ ] Dashboard displays real data (not mock)
- [ ] Charts render correctly
- [ ] Export works
- [ ] Data is accurate

---

## Performance Monitoring

### Firestore Read Costs
Monitor daily reads to ensure costs stay within budget:

- **Without aggregation**: ~100 reads per dashboard load (queries all events for all students)
- **With aggregation**: ~10 reads per dashboard load (queries aggregates only)

**Expected savings**: ~90% reduction in Firestore reads after aggregation is active.

### Cloud Function Monitoring
Check Cloud Functions dashboard for:
- [ ] Execution times (should be < 30 seconds for daily aggregation)
- [ ] Error rates (should be 0%)
- [ ] Memory usage (should be < 512MB)
- [ ] Cold start times

---

## Rollback Plan

If critical issues are found after deployment:

### 1. Rollback Next.js Deployment
**Vercel:**
```bash
vercel rollback
```

**Cloud Run:**
```bash
gcloud run services update scholesa-web \
  --image gcr.io/YOUR_PROJECT_ID/scholesa-web:PREVIOUS_TAG
```

### 2. Disable Cloud Functions
```bash
# Delete functions
firebase functions:delete aggregateDailyTelemetry
firebase functions:delete aggregateWeeklyTelemetry
```

### 3. Revert Firestore Rules
```bash
# Restore previous rules from Git
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules
```

---

## Production Best Practices

### Security
- [ ] Firestore rules enforce role-based access control
- [ ] Service account credentials stored securely (not in Git)
- [ ] API keys restricted by domain (Firebase Console → Settings → API Restrictions)

### Monitoring
- [ ] Set up Firebase monitoring alerts for Firestore errors
- [ ] Set up Cloud Functions alerts for execution failures
- [ ] Enable Application Insights / Datadog for frontend errors

### Data Retention
- [ ] Configure Firestore TTL policies to delete old telemetry events (optional)
- [ ] Archive old telemetry data to Cloud Storage after 90 days (optional)

### Cost Control
- [ ] Set daily Firestore read budget alerts
- [ ] Monitor Cloud Functions invocations
- [ ] Review Firebase billing dashboard weekly

---

## Support & Troubleshooting

### Common Issues

**Issue**: Firestore indexes not ready
- **Solution**: Wait 5-20 minutes after deploying indexes. Check status: `firebase firestore:indexes`

**Issue**: Cloud Function times out
- **Solution**: Increase timeout in `functions/src/telemetryAggregator.ts` (add `timeoutSeconds: 300` to function config)

**Issue**: Analytics dashboard shows no data
- **Solution**: Verify telemetry events exist in Firestore, check Firestore rules allow educator to read `telemetryEvents`

**Issue**: CSV export is empty
- **Solution**: Ensure students have telemetry data, check console for errors

---

## Next Steps

After successful deployment:
1. Monitor for 48 hours to ensure stability
2. Train educators on analytics dashboard usage
3. Train learners on goal-setting and showcase features
4. Collect user feedback on motivational engine effectiveness
5. Plan Phase 3: Vector DB integration for AI personalization

---

## Contact

For deployment support, contact: [Your Email/Slack Channel]

**Last updated**: December 26, 2024

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `SDT_DEPLOYMENT_GUIDE.md`
<!-- TELEMETRY_WIRING:END -->
