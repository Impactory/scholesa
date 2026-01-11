import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const genAiCoach = onCall(async (request: CallableRequest) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const userId = request.auth.uid;
  
  // 1. Fetch User Profile
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const userData = userDoc.data();

  // 2. Fetch recent KPIs or Progress (Mocked logic)
  // const kpiDoc = await admin.firestore().collection('accountabilityKPIs').where('learnerId', '==', userId).limit(1).get();
  
  // 3. Construct Prompt with Context
  // const prompt = `Act as a coach for ${userData?.displayName}. They are strong in Future Skills but need help with Leadership. Suggest a mission.`;

  // 4. Call Gemini API (Placeholder)
  // const response = await callGemini(prompt);

  return { message: `Hello ${userData?.displayName}, this is your AI Coach. Focus on your Leadership & Agency pillar this week!` };
});

export const genAiLessonPlanner = onCall(async (request: CallableRequest) => {
  // Input: educator's target skill, age group, time.
  // Output: suggested lesson sequence aligned with future skills.
  return { message: "Hello from GenAI Lesson Planner. Here is a drafted lesson plan for 'Intro to Robotics'..." };
});

export const nightlyStudioSummary = onSchedule('every 24 hours', async () => {
  console.log("Running nightly studio summary");
  
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const timestamp = admin.firestore.Timestamp.fromDate(today);

  // 1. Get all studios (sites)
  const sitesSnapshot = await admin.firestore().collection('sites').get();

  const batch = admin.firestore().batch();

  for (const siteDoc of sitesSnapshot.docs) {
    const siteId = siteDoc.id;

    // 2. Aggregate Attendance for today
    const attendanceQuery = await admin.firestore().collection('attendanceRecords')
      .where('studioId', '==', siteId)
      .where('date', '>=', timestamp)
      .get();
    
    const attendanceCount = attendanceQuery.size;
    
    // 3. Create a Daily Summary Document
    const summaryRef = admin.firestore().collection('studioSummaries').doc();
    batch.set(summaryRef, {
      siteId,
      date: timestamp,
      attendanceCount,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  await batch.commit();
});

// Note: User profile creation should be handled client-side after Firebase Auth sign-up
// The beforeUserCreated trigger requires Firebase Identity Platform (GCIP) which is not enabled
// Alternative: Use a callable function to create user profiles after successful auth

export const createUserProfile = onCall(async (request: CallableRequest) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }
  
  const userId = request.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  
  // Only create if profile doesn't exist
  if (!userDoc.exists) {
    await admin.firestore().collection('users').doc(userId).set({
      email: request.auth.token.email || '',
      displayName: request.auth.token.name || '',
      role: 'learner', // Default role
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  
  return { success: true };
});

export const logAnalyticsEvent = onCall(async (request: CallableRequest) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }
  return admin.firestore().collection('analyticsEvents').add({
    ...request.data,
    userId: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
});

// Placeholder for Next.js SSR function
export const nextServer = onRequest((req, res) => {
  res.status(200).send("Next.js Server Placeholder - Configure next-on-firebase-functions or similar for full SSR.");
});

// REST API endpoint for /v1/me - returns current user profile
export const apiV1 = onRequest({ cors: true }, async (req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Get auth token from Authorization header
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized - missing or invalid token' });
    return;
  }

  const idToken = authHeader.split('Bearer ')[1];
  
  try {
    // Verify the token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    // Route based on path
    const path = req.path;

    if (path === '/v1/me' || path === '/me') {
      // Get user profile from Firestore
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        // Create default profile if doesn't exist
        const defaultProfile = {
          email: decodedToken.email || '',
          displayName: decodedToken.name || decodedToken.email?.split('@')[0] || '',
          role: 'learner',
          siteIds: [],
          entitlements: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await admin.firestore().collection('users').doc(userId).set(defaultProfile);
        
        res.json({
          userId,
          email: defaultProfile.email,
          displayName: defaultProfile.displayName,
          role: defaultProfile.role,
          activeSiteId: null,
          siteIds: [],
          entitlements: [],
        });
        return;
      }

      const userData = userDoc.data()!;
      res.json({
        userId,
        email: userData.email || decodedToken.email,
        displayName: userData.displayName || decodedToken.name,
        role: userData.role || 'learner',
        activeSiteId: userData.activeSiteId || (userData.siteIds?.[0] ?? null),
        siteIds: userData.siteIds || [],
        entitlements: userData.entitlements || [],
      });
      return;
    }

    // 404 for unknown paths
    res.status(404).json({ error: 'Not found' });
  } catch (error) {
    console.error('API error:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
});
