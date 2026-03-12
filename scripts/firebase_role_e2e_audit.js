#!/usr/bin/env node

const { initializeFirebaseRestClients } = require('./firebase_runtime_auth');

const VALID_ROLES = new Set(['learner', 'educator', 'parent', 'site', 'partner', 'hq']);
const argv = process.argv.slice(2);
const strict = argv.includes('--strict');
const json = argv.includes('--json');
const projectArg = argv.find((arg) => arg.startsWith('--project='));
const projectId =
  (projectArg && projectArg.split('=')[1]) ||
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  'studio-3328096157-e3f79';

const { db, auth } = initializeFirebaseRestClients({ projectId });

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
  const firestoreUsers = new Map(userDocsSnap.docs.map((doc) => [doc.id, doc.data() || {}]));
  const authUsers = await listAuthUsers(auth);

  const report = {
    projectId,
    firestoreCount: firestoreUsers.size,
    authCount: authUsers.size,
    firestoreRoles: {},
    authRoleClaims: {},
    invalidFirestoreRoles: [],
    missingFirestoreRoles: [],
    missingDisplayNames: [],
    missingSiteContext: [],
    missingAuthRoleClaims: [],
    firestoreOnly: [],
    authOnlyLoginCapable: [],
    authOnlyEphemeral: [],
    mismatchedRoles: [],
  };

  for (const [uid, data] of firestoreUsers) {
    const role = typeof data.role === 'string' ? data.role.trim() : '';
    report.firestoreRoles[role || '__missing__'] =
      (report.firestoreRoles[role || '__missing__'] || 0) + 1;

    if (!role) {
      report.missingFirestoreRoles.push({ uid, email: data.email || null });
    } else if (!VALID_ROLES.has(role)) {
      report.invalidFirestoreRoles.push({ uid, role, email: data.email || null });
    }

    if (!data.displayName) {
      report.missingDisplayNames.push({ uid, role: role || null, email: data.email || null });
    }

    const siteIds = Array.isArray(data.siteIds) ? data.siteIds.filter(Boolean) : [];
    const activeSiteId = typeof data.activeSiteId === 'string' ? data.activeSiteId.trim() : '';
    const requiresSite = role === 'educator' || role === 'parent' || role === 'site' || role === 'partner';
    if (requiresSite && !activeSiteId && siteIds.length === 0) {
      report.missingSiteContext.push({ uid, role, email: data.email || null });
    }

    const authUser = authUsers.get(uid);
    if (!authUser) {
      report.firestoreOnly.push({ uid, role: role || null, email: data.email || null });
      continue;
    }

    const claimRole = typeof authUser.customClaims?.role === 'string'
      ? authUser.customClaims.role.trim()
      : '';
    if (role && !claimRole) {
      report.missingAuthRoleClaims.push({ uid, email: data.email || authUser.email || null, role });
    }
    if (claimRole && role && claimRole !== role) {
      report.mismatchedRoles.push({ uid, email: data.email || authUser.email || null, firestoreRole: role, claimRole });
    }
  }

  for (const [uid, user] of authUsers) {
    const claimRole = typeof user.customClaims?.role === 'string'
      ? user.customClaims.role.trim()
      : '';
    report.authRoleClaims[claimRole || '__missing__'] =
      (report.authRoleClaims[claimRole || '__missing__'] || 0) + 1;

    if (firestoreUsers.has(uid)) {
      continue;
    }

    const providers = (user.providerData || []).map((provider) => provider.providerId || '__unknown__');
    const isLoginCapable = Boolean(user.email) || providers.length > 0 || Boolean(claimRole);
    const item = {
      uid,
      email: user.email || null,
      providers,
      claimRole: claimRole || null,
      disabled: user.disabled,
    };

    if (isLoginCapable) {
      report.authOnlyLoginCapable.push(item);
    } else {
      report.authOnlyEphemeral.push(item);
    }
  }

  const blockers = [];
  if (report.invalidFirestoreRoles.length > 0) blockers.push('invalid-firestore-roles');
  if (report.missingFirestoreRoles.length > 0) blockers.push('missing-firestore-roles');
  if (report.missingAuthRoleClaims.length > 0) blockers.push('missing-auth-role-claims');
  if (report.mismatchedRoles.length > 0) blockers.push('mismatched-role-claims');
  if (report.authOnlyLoginCapable.length > 0) blockers.push('login-capable-auth-users-without-profiles');
  if (report.missingSiteContext.length > 0) blockers.push('site-scoped-users-without-site-context');

  if (json) {
    console.log(JSON.stringify({ ...report, blockers }, null, 2));
  } else {
    console.log(`Firebase role audit for ${projectId}`);
    console.log(`Firestore users: ${report.firestoreCount}`);
    console.log(`Auth users: ${report.authCount}`);
    console.log(`Firestore roles: ${JSON.stringify(report.firestoreRoles)}`);
    console.log(`Auth role claims: ${JSON.stringify(report.authRoleClaims)}`);
    console.log(`Invalid Firestore roles: ${report.invalidFirestoreRoles.length}`);
    console.log(`Missing Firestore roles: ${report.missingFirestoreRoles.length}`);
    console.log(`Missing auth role claims: ${report.missingAuthRoleClaims.length}`);
    console.log(`Missing display names: ${report.missingDisplayNames.length}`);
    console.log(`Missing site context: ${report.missingSiteContext.length}`);
    console.log(`Firestore-only users: ${report.firestoreOnly.length}`);
    console.log(`Auth-only login-capable users: ${report.authOnlyLoginCapable.length}`);
    console.log(`Auth-only ephemeral users: ${report.authOnlyEphemeral.length}`);
    console.log(`Mismatched roles: ${report.mismatchedRoles.length}`);

    if (report.authOnlyLoginCapable.length > 0) {
      console.log('Sample login-capable auth users without Firestore profiles:');
      for (const item of report.authOnlyLoginCapable.slice(0, 10)) {
        console.log(`- ${item.uid} email=${item.email ?? 'null'} providers=${item.providers.join(',') || '__none__'} claimRole=${item.claimRole ?? 'null'}`);
      }
    }

    if (report.missingSiteContext.length > 0) {
      console.log('Sample site-context gaps:');
      for (const item of report.missingSiteContext.slice(0, 10)) {
        console.log(`- ${item.uid} role=${item.role} email=${item.email ?? 'null'}`);
      }
    }

    if (report.missingAuthRoleClaims.length > 0) {
      console.log('Sample missing auth role claims:');
      for (const item of report.missingAuthRoleClaims.slice(0, 10)) {
        console.log(`- ${item.uid} role=${item.role} email=${item.email ?? 'null'}`);
      }
    }

    if (blockers.length === 0) {
      console.log('Status: PASS');
    } else {
      console.log(`Status: FAIL (${blockers.join(', ')})`);
    }
  }

  if (strict && blockers.length > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});