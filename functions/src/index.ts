import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const genAiCoach = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const userId = context.auth.uid;
  
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

export const genAiLessonPlanner = functions.https.onCall(async (data, context) => {
  // Input: educator’s target skill, age group, time.
  // Output: suggested lesson sequence aligned with future skills.
  return { message: "Hello from GenAI Lesson Planner. Here is a drafted lesson plan for 'Intro to Robotics'..." };
});

export const nightlyStudioSummary = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
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
  return null;
});

export const onUserCreate = functions.auth.user().onCreate((user) => {
  return admin.firestore().collection('users').doc(user.uid).set({
    email: user.email,
    displayName: user.displayName || '',
    role: 'learner', // Default role
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

export const logAnalyticsEvent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }
  return admin.firestore().collection('analyticsEvents').add({
    ...data,
    userId: context.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
});

// Placeholder for Next.js SSR function
export const nextServer = functions.https.onRequest((req, res) => {
  res.status(200).send("Next.js Server Placeholder - Configure next-on-firebase-functions or similar for full SSR.");
});
