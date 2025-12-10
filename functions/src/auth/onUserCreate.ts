import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onUserCreate = functions.auth.user().onCreate((user) => {
  const { uid, email, displayName } = user;
  const userProfile = {
    uid,
    email,
    displayName,
    role: 'learner', // Default role
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  return admin.firestore().collection('users').doc(uid).set(userProfile);
});
