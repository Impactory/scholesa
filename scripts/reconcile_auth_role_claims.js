#!/usr/bin/env node

const { initializeFirebaseRestClients, resolveProjectId } = require('./firebase_runtime_auth');

const argv = process.argv.slice(2);
const apply = argv.includes('--apply');
const strict = argv.includes('--strict');
const json = argv.includes('--json');
const projectArg = argv.find((arg) => arg.startsWith('--project='));
const projectId =
  resolveProjectId((projectArg && projectArg.split('=')[1]) || process.env.FIREBASE_PROJECT_ID) ||
  '';

const { db, auth } = initializeFirebaseRestClients({ projectId });

function expectedClaims(role, existingClaims = {}) {
  const nextClaims = { ...existingClaims };
  nextClaims.role = role;
  const nextRoles = new Set(Array.isArray(existingClaims.roles) ? existingClaims.roles : []);
  nextRoles.add(role);
  if (existingClaims.superuser) {
    nextRoles.add('superuser');
  }
  nextClaims.roles = Array.from(nextRoles);
  return nextClaims;
}

function claimsNeedUpdate(role, existingClaims = {}) {
  const claimRole = typeof existingClaims.role === 'string' ? existingClaims.role.trim() : '';
  const roles = Array.isArray(existingClaims.roles) ? existingClaims.roles : [];
  return claimRole !== role || !roles.includes(role);
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
  const userDocsSnap = await db.collection('users').get();
  const authUsers = await listAuthUsers(auth);
  const pending = [];

  for (const doc of userDocsSnap.docs) {
    const data = doc.data() || {};
    const role = typeof data.role === 'string' ? data.role.trim() : '';
    if (!role) {
      continue;
    }

    const authUser = authUsers.get(doc.id);
    if (!authUser) {
      continue;
    }

    if (!claimsNeedUpdate(role, authUser.customClaims || {})) {
      continue;
    }

    const nextClaims = expectedClaims(role, authUser.customClaims || {});
    pending.push({
      uid: doc.id,
      email: authUser.email || data.email || null,
      role,
      currentClaims: authUser.customClaims || {},
      nextClaims,
    });
  }

  if (apply) {
    for (const item of pending) {
      await auth.setCustomUserClaims(item.uid, item.nextClaims);
    }
  }

  const summary = {
    projectId,
    apply,
    pending: pending.length,
    updates: pending.map((item) => ({
      uid: item.uid,
      email: item.email,
      role: item.role,
      currentClaims: item.currentClaims,
      nextClaims: item.nextClaims,
    })),
  };

  if (json) {
    console.log(JSON.stringify(summary, null, 2));
  } else {
    console.log(`Auth role claim reconciliation for ${projectId}`);
    console.log(`Pending updates: ${pending.length}`);
    for (const item of pending.slice(0, 20)) {
      console.log(`- ${item.uid} email=${item.email ?? 'null'} role=${item.role}`);
    }
  }

  if (strict && !apply && pending.length > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});