import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const logAnalyticsEvent = functions.https.onCall((data, context) => {
  const { eventName, params } = data;
  return admin.firestore().collection('analyticsEvents').add({
    eventName,
    params,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    uid: context.auth?.uid,
  });
});
