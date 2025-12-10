import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const genAiCoach = functions.https.onCall(async (data, context) => {
  // Implement GenAI Coach logic here
  // Input: learner context (age, stage, current mission, last reflection).
  // Output: friendly, age-appropriate coaching advice.
  return { message: "Hello from GenAI Coach" };
});

export const genAiLessonPlanner = functions.https.onCall(async (data, context) => {
  // Implement GenAI Lesson Planner logic here
  // Input: educator’s target skill, age group, time.
  // Output: suggested lesson sequence aligned with future skills.
  return { message: "Hello from GenAI Lesson Planner" };
});

export const nightlyStudioSummary = functions.pubsub.schedule('every 24 hours').onRun((context) => {
  // Implement nightly studio summary logic here
  // Summarize attendance, progress, and alerts per studio into a daily digest document (`studioSummaries` collection).
  console.log("Running nightly studio summary");
  return null;
});

export const onUserCreate = functions.auth.user().onCreate((user) => {
  // Implement user creation logic here
  // When users sign up, initialize a `users/{uid}` document with role and default fields.
  return admin.firestore().collection('users').doc(user.uid).set({
    email: user.email,
    displayName: user.displayName || '',
    role: 'learner', // Default role
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

export const logAnalyticsEvent = functions.https.onCall(async (data, context) => {
  // Implement analytics logging logic here
  // Simple endpoint to log app events into a `analyticsEvents` collection for later reporting.
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
