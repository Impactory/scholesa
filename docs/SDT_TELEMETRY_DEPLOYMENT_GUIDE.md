# SDT + Telemetry Deployment Guide

This guide covers deploying the Self-Determination Theory (SDT) motivation framework and universal telemetry system to production.

## 📋 Pre-Deployment Checklist

### 1. Code Complete ✅
- [x] TelemetryService implemented (`src/lib/telemetry/telemetryService.ts`)
- [x] SDT Motivation Engine with 4 phases (`src/lib/motivation/motivationEngine.ts`)
- [x] React telemetry hooks (`src/hooks/useTelemetry.ts`)
- [x] Component integration (AICoachPopup, StudentDashboard, MissionList, ReflectionForm)
- [x] Educator analytics dashboard (`src/components/analytics/AnalyticsDashboard.tsx`)
- [x] Student motivation profile (`src/components/motivation/StudentMotivationProfile.tsx`)

### 2. Firestore Configuration ✅
- [x] Security rules updated (`firestore.rules`)
- [x] Composite indexes defined (`firestore.indexes.json`)

### 3. Environment Variables
Verify these are set in production (Vercel/Cloud Run):

```bash
# Firebase Client SDK (Public)
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_APP_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=

# Firebase Admin SDK (Server)
FIREBASE_SERVICE_ACCOUNT=  # JSON string or base64
# OR
GOOGLE_APPLICATION_CREDENTIALS=  # Path to service account JSON
```

## 🚀 Deployment Steps

### Step 1: Deploy Firestore Rules & Indexes

```bash
# From project root
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

**Expected output:**
```
✔  firestore: released rules firestore.rules to cloud.firestore
✔  firestore: deployed indexes in firestore.indexes.json successfully
```

**⚠️ Important:** Index creation can take 5-20 minutes. Monitor progress:
```bash
firebase firestore:indexes
```

### Step 2: Test with Emulators (Optional but Recommended)

```bash
# Start Firebase emulators
firebase emulators:start

# In another terminal, run Next.js dev server
npm run dev
```

Test the following flows:
1. ✅ Mission selection (autonomy tracking)
2. ✅ Checkpoint submission (competence tracking)
3. ✅ Reflection submission (reflection tracking)
4. ✅ Analytics dashboard loads
5. ✅ Student profile loads

### Step 3: Deploy Frontend

```bash
# Build Next.js app
npm run build

# Test production build locally
npm run start

# Deploy to Vercel (if using Vercel)
vercel --prod

# OR deploy to Cloud Run
./scripts/deploy.sh cloudrun-web
```

### Step 4: Deploy Cloud Functions (If Using Aggregation)

**Note:** Telemetry aggregation is currently client-side. For production scale, implement Cloud Functions to compute daily/weekly rollups.

Create `functions/src/telemetryAggregator.ts`:

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const aggregateDailyTelemetry = functions.pubsub
  .schedule('every day 02:00')
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    
    const endOfYesterday = new Date(yesterday);
    endOfYesterday.setHours(23, 59, 59, 999);
    
    // Query all telemetry events from yesterday
    const eventsSnapshot = await db.collection('telemetryEvents')
      .where('timestamp', '>=', yesterday)
      .where('timestamp', '<=', endOfYesterday)
      .get();
    
    // Group by userId + siteId
    const aggregates: Map<string, any> = new Map();
    
    eventsSnapshot.forEach(doc => {
      const event = doc.data();
      const key = `${event.userId}_${event.siteId}`;
      
      if (!aggregates.has(key)) {
        aggregates.set(key, {
          userId: event.userId,
          siteId: event.siteId,
          date: yesterday,
          aggregationType: 'daily',
          totalEvents: 0,
          categoryCounts: {},
          sdtCounts: { autonomy: 0, competence: 0, belonging: 0, reflection: 0 }
        });
      }
      
      const agg = aggregates.get(key)!;
      agg.totalEvents++;
      agg.categoryCounts[event.category] = (agg.categoryCounts[event.category] || 0) + 1;
      
      // Increment SDT counters
      if (['autonomy', 'competence', 'belonging', 'reflection'].includes(event.category)) {
        agg.sdtCounts[event.category as keyof typeof agg.sdtCounts]++;
      }
    });
    
    // Write aggregates to Firestore
    const batch = db.batch();
    aggregates.forEach((agg, key) => {
      const docRef = db.collection('telemetryAggregates').doc(`${key}_${yesterday.toISOString().split('T')[0]}`);
      batch.set(docRef, agg);
    });
    
    await batch.commit();
    console.log(`Aggregated ${aggregates.size} user-site pairs for ${yesterday.toISOString()}`);
  });
```

Deploy:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Step 5: Verify Production Data Flow

1. **Log in as a test student**
2. **Complete a mission** (triggers `mission_selected`, `artifact_submitted`)
3. **Submit a reflection** (triggers `reflection_submitted`)
4. **Check Firestore Console:**
   - `telemetryEvents` collection should have 3+ documents
   - Each event should have: `userId`, `siteId`, `category`, `eventName`, `timestamp`, `metadata`

5. **Log in as educator**
6. **Open Analytics Dashboard** (`/educator/analytics`)
   - Should display student engagement scores
   - SDT heatmap should show autonomy/competence/belonging percentages

7. **Check student profile** (`/learner/profile`)
   - Should display SDT scores from telemetry
   - Skills/badges sections ready for data (once populated)

## 📊 Monitoring & Debugging

### Check Telemetry Events
```javascript
// Firestore Console or Admin SDK
db.collection('telemetryEvents')
  .where('siteId', '==', 'YOUR_SITE_ID')
  .orderBy('timestamp', 'desc')
  .limit(50)
  .get()
```

### Check SDT Profile Calculation
```javascript
// In browser console (after login)
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';

const learnerId = 'USER_ID';
const siteId = 'SITE_ID';
const scores = await TelemetryService.getSDTProfile(learnerId, siteId);
console.log(scores);
// Expected: { autonomy: 0-100, competence: 0-100, belonging: 0-100 }
```

### Check Firestore Rules
If writes are failing, check rules:
```bash
firebase firestore:rules
```

Test specific operations:
```javascript
// Should succeed (user writing their own event)
await db.collection('telemetryEvents').add({
  userId: currentUserId,
  siteId: 'site1',
  category: 'autonomy',
  eventName: 'mission_selected',
  timestamp: Timestamp.now()
});

// Should fail (user writing another user's event)
await db.collection('telemetryEvents').add({
  userId: 'other-user-id',  // ❌ Not allowed
  siteId: 'site1',
  category: 'autonomy',
  eventName: 'mission_selected',
  timestamp: Timestamp.now()
});
```

## 🔧 Troubleshooting

### Indexes Not Ready
**Symptom:** Error: "The query requires an index."

**Solution:**
1. Check index status: `firebase firestore:indexes`
2. Wait for indexes to build (can take 5-20 minutes)
3. Alternatively, click the URL in the error message to auto-create the index

### Telemetry Events Not Saving
**Symptom:** TelemetryService.track() doesn't create documents

**Possible causes:**
1. **Firestore rules:** User not authenticated
2. **Missing siteId:** Check `profile.activeSiteId` is set
3. **Network error:** Check browser console for Firebase errors

**Debug:**
```javascript
// Add error handling to TelemetryService.track()
try {
  await addDoc(collection(db, 'telemetryEvents'), eventData);
  console.log('✅ Telemetry event saved:', eventData);
} catch (err) {
  console.error('❌ Telemetry failed:', err);
  // Don't throw - telemetry should never break app functionality
}
```

### Analytics Dashboard Empty
**Symptom:** Dashboard shows no data despite events in Firestore

**Possible causes:**
1. **No aggregates:** Aggregation functions not deployed
2. **Date filtering:** Check queries for date range mismatch
3. **Site scoping:** User's `activeSiteId` doesn't match event `siteId`

**Quick fix (historical prototype guidance):**
- Earlier prototype builds used mock data for dashboard demonstration
- Current production signoff must use real Firestore aggregates and live release-gate evidence instead of this prototype shortcut

### Student Profile Scores Zero
**Symptom:** SDT scores show 0% despite activity

**Possible causes:**
1. **Event category mismatch:** Events not tagged with `autonomy`/`competence`/`belonging`
2. **Missing metadata:** Events missing required metadata fields
3. **Query filters:** TelemetryService.getSDTProfile() filtering incorrectly

**Debug:**
```javascript
// Check raw events for user
const events = await db.collection('telemetryEvents')
  .where('userId', '==', learnerId)
  .where('siteId', '==', siteId)
  .get();

console.log('Total events:', events.size);
console.log('Categories:', events.docs.map(d => d.data().category));
```

## 📈 Performance Considerations

### Client-Side Telemetry Impact
- **Average event size:** ~500 bytes
- **Write frequency:** 5-10 events per minute (active user)
- **Firestore writes:** ~0.1 cents per 1000 writes
- **Monthly cost estimate:** $1-5 per 100 active students

### Optimization Strategies

1. **Batch similar events:**
   ```typescript
   // Instead of tracking every scroll event
   useEffect(() => {
     const handleScroll = debounce(() => {
       trackInteraction('page_scrolled', { scrollDepth: window.scrollY });
     }, 5000); // Only track every 5 seconds
   }, []);
   ```

2. **Use aggregates for dashboards:**
   - Query `telemetryAggregates` (1 doc per user-day)
   - Instead of `telemetryEvents` (100+ docs per user-day)

3. **Implement sampling for high-frequency events:**
   ```typescript
   // Only track 10% of clicks
   if (Math.random() < 0.1) {
     trackInteraction('button_clicked', { buttonId });
   }
   ```

## 🎯 Post-Deployment Validation

### Week 1: Data Collection
- [ ] 50+ telemetry events per active student
- [ ] All 4 SDT categories represented (autonomy, competence, belonging, reflection)
- [ ] No Firestore permission errors in logs
- [ ] Analytics dashboard displays data

### Week 2: Educator Feedback
- [ ] Educators can view class engagement
- [ ] SDT heatmap shows meaningful variance (not all 0% or 100%)
- [ ] At-risk student alerts trigger appropriately
- [ ] Export CSV functionality works

### Week 3: Student Engagement
- [ ] Students view their own profiles
- [ ] SDT scores update after activities
- [ ] Badge awards appear in profile
- [ ] Reflection timeline shows growth

### Month 1: ROI Analysis
- [ ] Telemetry insights lead to 1+ educator intervention
- [ ] Student engagement improves (compare SDT scores week-over-week)
- [ ] System performance acceptable (<2s dashboard load)
- [ ] Cost within budget (<$10/month for 100 students)

## 🚨 Rollback Plan

If critical issues arise:

1. **Disable telemetry tracking:**
   ```typescript
   // In TelemetryService.ts
   static async track(...) {
     return; // No-op, disable all tracking
   }
   ```

2. **Revert Firestore rules:**
   ```bash
   git checkout HEAD~1 firestore.rules
   firebase deploy --only firestore:rules
   ```

3. **Roll back Next.js deployment:**
   ```bash
   # Vercel
   vercel rollback
   
   # Firebase Hosting
   firebase hosting:rollback
   ```

## 📞 Support

For issues during deployment:
- **Firestore errors:** Check Firebase Console > Firestore > Usage tab
- **Next.js build errors:** Review `npm run build` logs
- **Runtime errors:** Check Vercel/Cloud Run logs

---

**Last updated:** December 2024  
**Version:** 1.0  
**Status:** Production-ready

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `SDT_TELEMETRY_DEPLOYMENT_GUIDE.md`
<!-- TELEMETRY_WIRING:END -->
