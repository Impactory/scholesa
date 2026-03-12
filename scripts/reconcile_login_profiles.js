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
const password =
  process.env.TEST_USER_PASSWORD ||
  process.env.SEED_TEST_PASSWORD ||
  process.env.TEST_LOGIN_PASSWORD ||
  'Test123!';

const { db, auth } = initializeFirebaseRestClients({ projectId });

const TARGET_UIDS = new Set([
  'WXmnwwgFlpfQNeQ8ixVq',
  'i7dq6t07N8MTR22eTVbg',
  'u-partner',
]);

function claimsForRole(role) {
  return {
    role,
    roles: [role],
  };
}

async function ensureAuthUser(auth, userDoc) {
  const email = String(userDoc.email || '').trim().toLowerCase();
  const displayName = String(userDoc.displayName || '').trim();
  const role = String(userDoc.role || '').trim();
  const uid = userDoc.uid;
  const claims = claimsForRole(role);

  if (!email || !displayName || !role) {
    throw new Error(`Incomplete user doc for ${uid}`);
  }

  const outcome = {
    uid,
    email,
    role,
    displayName,
    created: false,
    updated: false,
    claimsUpdated: false,
  };

  let authUser;
  try {
    authUser = await auth.getUser(uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (authUser) {
    const needsUpdate =
      String(authUser.email || '').toLowerCase() !== email ||
      String(authUser.displayName || '') !== displayName ||
      authUser.disabled === true ||
      authUser.emailVerified !== true;

    if (needsUpdate) {
      outcome.updated = true;
      if (apply) {
        await auth.updateUser(uid, {
          email,
          displayName,
          password,
          disabled: false,
          emailVerified: true,
        });
      }
    }
  } else {
    outcome.created = true;
    if (apply) {
      try {
        await auth.createUser({
          uid,
          email,
          displayName,
          password,
          disabled: false,
          emailVerified: true,
        });
      } catch (error) {
        if (error?.code !== 'auth/email-already-exists') {
          throw error;
        }

        const existingByEmail = await auth.getUserByEmail(email);
        await auth.updateUser(existingByEmail.uid, {
          displayName,
          password,
          disabled: false,
          emailVerified: true,
        });
        authUser = existingByEmail;
        outcome.updated = true;
      }
    }
  }

  const currentClaims = authUser?.customClaims || {};
  const currentRole = typeof currentClaims.role === 'string' ? currentClaims.role : '';
  const currentRoles = Array.isArray(currentClaims.roles) ? currentClaims.roles : [];
  const needsClaimsUpdate = currentRole !== role || currentRoles.length !== 1 || currentRoles[0] !== role;
  if (needsClaimsUpdate) {
    outcome.claimsUpdated = true;
    if (apply) {
      await auth.setCustomUserClaims(uid, claims);
    }
  }

  return outcome;
}

async function main() {
  const targets = [];

  for (const uid of TARGET_UIDS) {
    const snap = await db.collection('users').doc(uid).get();
    if (!snap.exists) {
      throw new Error(`Missing Firestore user doc for ${uid}`);
    }
    targets.push({ uid, ...snap.data() });
  }

  const results = [];
  for (const target of targets) {
    results.push(await ensureAuthUser(auth, target));
  }

  const summary = {
    projectId,
    apply,
    password,
    reconciled: results.length,
    results,
  };

  if (json || !apply) {
    console.log(JSON.stringify(summary, null, 2));
  } else {
    console.log(JSON.stringify(summary, null, 2));
  }

  if (strict) {
    const pending = results.filter((item) => item.created || item.updated || item.claimsUpdated);
    if (!apply && pending.length > 0) {
      process.exit(1);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});