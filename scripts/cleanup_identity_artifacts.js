#!/usr/bin/env node

const admin = require('firebase-admin');

const argv = process.argv.slice(2);
const apply = argv.includes('--apply');
const strict = argv.includes('--strict');
const json = argv.includes('--json');
const projectArg = argv.find((arg) => arg.startsWith('--project='));
const projectId =
  (projectArg && projectArg.split('=')[1]) ||
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  'studio-3328096157-e3f79';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

const VOICE_UID_PATTERN = /^voice-live-(admin|teacher|student)-\d+(?:-[a-f0-9]{4})?$/;
const FIRESTORE_ARTIFACT_PATTERNS = [
  /^seed_[a-z0-9_]+$/,
  /^seed-live-[a-f0-9]+$/,
  /^e2e-runner-[a-f0-9]+$/,
];

function matchesFirestoreArtifact(uid) {
  return FIRESTORE_ARTIFACT_PATTERNS.some((pattern) => pattern.test(uid));
}

function compactAuthUser(user) {
  return {
    uid: user.uid,
    email: user.email || null,
    providers: (user.providerData || []).map((provider) => provider.providerId || '__unknown__'),
    disabled: Boolean(user.disabled),
    created: user.metadata.creationTime || null,
    lastSignIn: user.metadata.lastSignInTime || null,
  };
}

async function listAuthUsers(auth) {
  const users = new Map();
  let nextPageToken;
  do {
    const page = await auth.listUsers(1000, nextPageToken);
    for (const user of page.users) {
      users.set(user.uid, user);
    }
    nextPageToken = page.pageToken;
  } while (nextPageToken);
  return users;
}

async function main() {
  const db = admin.firestore();
  const auth = admin.auth();
  const authUsers = await listAuthUsers(auth);
  const userDocsSnap = await db.collection('users').get();

  const authTargets = [];
  const firestoreTargets = [];
  const skipped = [];

  for (const user of authUsers.values()) {
    const item = compactAuthUser(user);
    const hasProviders = item.providers.length > 0;
    const qualifies =
      VOICE_UID_PATTERN.test(item.uid) &&
      !item.email &&
      !hasProviders &&
      !item.disabled;

    if (qualifies) {
      authTargets.push(item);
    } else if (item.uid.startsWith('voice-live-')) {
      skipped.push({ type: 'auth', reason: 'voice-live-user-not-safe', ...item });
    }
  }

  for (const doc of userDocsSnap.docs) {
    const data = doc.data() || {};
    if (!matchesFirestoreArtifact(doc.id)) {
      continue;
    }

    firestoreTargets.push({
      uid: doc.id,
      email: data.email || null,
      role: data.role || null,
      displayName: data.displayName || null,
      siteIds: Array.isArray(data.siteIds) ? data.siteIds.filter(Boolean) : [],
      activeSiteId: data.activeSiteId || null,
    });
  }

  const summary = {
    projectId,
    apply,
    authTargets: authTargets.length,
    firestoreTargets: firestoreTargets.length,
    skipped: skipped.length,
    authTargetSamples: authTargets.slice(0, 10),
    firestoreTargetSamples: firestoreTargets.slice(0, 10),
    skippedSamples: skipped.slice(0, 10),
  };

  if (!apply) {
    if (json) {
      console.log(JSON.stringify(summary, null, 2));
    } else {
      console.log(`Identity artifact cleanup plan for ${projectId}`);
      console.log(`Auth targets: ${summary.authTargets}`);
      console.log(`Firestore targets: ${summary.firestoreTargets}`);
      console.log(`Skipped voice-live users: ${summary.skipped}`);
      if (summary.authTargetSamples.length > 0) {
        console.log('Sample auth targets:');
        for (const item of summary.authTargetSamples) {
          console.log(`- ${item.uid} created=${item.created ?? 'null'}`);
        }
      }
      if (summary.firestoreTargetSamples.length > 0) {
        console.log('Sample Firestore targets:');
        for (const item of summary.firestoreTargetSamples) {
          console.log(`- ${item.uid} role=${item.role ?? 'null'} email=${item.email ?? 'null'}`);
        }
      }
    }

    if (strict && (summary.authTargets > 0 || summary.firestoreTargets > 0 || summary.skipped > 0)) {
      process.exit(1);
    }
    return;
  }

  for (const target of firestoreTargets) {
    await db.collection('users').doc(target.uid).delete();
  }

  for (const target of authTargets) {
    await auth.deleteUser(target.uid);
  }

  const result = {
    projectId,
    deletedAuthUsers: authTargets.length,
    deletedFirestoreUsers: firestoreTargets.length,
    skipped: skipped.length,
  };

  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});