#!/usr/bin/env node

const { initializeFirebaseRestClients, resolveProjectId } = require('./firebase_runtime_auth');

const argv = process.argv.slice(2);
const apply = argv.includes('--apply');
const strict = argv.includes('--strict');
const projectArg = argv.find((arg) => arg.startsWith('--project='));
const projectId =
  resolveProjectId((projectArg && projectArg.split('=')[1]) || process.env.FIREBASE_PROJECT_ID) ||
  '';

const password =
  process.env.LIVE_ROLE_UAT_PASSWORD ||
  process.env.TEST_LOGIN_PASSWORD ||
  process.env.TEST_USER_PASSWORD ||
  process.env.SEED_TEST_PASSWORD ||
  'Test123!';

const siteId = process.env.LIVE_ROLE_UAT_SITE_ID || 'pilot-site-001';
const cohortId = process.env.LIVE_ROLE_UAT_COHORT_ID || 'pilot-cohort-001';

const { db, auth } = initializeFirebaseRestClients({ projectId });

const nowIso = () => new Date().toISOString();

const accounts = [
  {
    uid: 'uat-admin-001',
    email: 'admin@scholesa.test',
    displayName: 'UAT Admin',
    appRole: 'hq',
    uatRole: 'Admin',
    purpose: 'Manages tenant, organization, users, cohorts, policies, reporting, and platform operations.',
  },
  {
    uid: 'uat-educator-001',
    email: 'educator@scholesa.test',
    displayName: 'UAT Educator',
    appRole: 'educator',
    uatRole: 'Educator',
    purpose: 'Facilitates learning, assigns Missions, monitors checkpoints, reviews Evidence, performs Capability Reviews, provides feedback, and supports Learner growth.',
  },
  {
    uid: 'uat-discoverer-001',
    email: 'discoverer@scholesa.test',
    displayName: 'UAT Discoverer',
    appRole: 'learner',
    uatRole: 'Learner',
    gradeLevel: 2,
    stage: 'Discoverers',
    aiPolicy: 'educator-led only',
    independentAiChatAllowed: false,
  },
  {
    uid: 'uat-builder-001',
    email: 'builder@scholesa.test',
    displayName: 'UAT Builder',
    appRole: 'learner',
    uatRole: 'Learner',
    gradeLevel: 5,
    stage: 'Builders',
    aiPolicy: 'guided assistive use',
    independentAiChatAllowed: true,
  },
  {
    uid: 'uat-explorer-001',
    email: 'explorer@scholesa.test',
    displayName: 'UAT Explorer',
    appRole: 'learner',
    uatRole: 'Learner',
    gradeLevel: 8,
    stage: 'Explorers',
    aiPolicy: 'logged analytical use',
    independentAiChatAllowed: true,
  },
  {
    uid: 'uat-innovator-001',
    email: 'innovator@scholesa.test',
    displayName: 'UAT Innovator',
    appRole: 'learner',
    uatRole: 'Learner',
    gradeLevel: 11,
    stage: 'Innovators',
    aiPolicy: 'advanced assistive use with full audit trail',
    independentAiChatAllowed: true,
  },
  {
    uid: 'uat-family-001',
    email: 'family@scholesa.test',
    displayName: 'UAT Family',
    appRole: 'parent',
    uatRole: 'Family',
    linkedLearnerIds: ['uat-builder-001'],
    purpose: 'Views selected Learner progress, Home Connections, milestones, and Portfolio highlights.',
    restrictions: ['Cannot edit official learning Evidence or Capability Reviews.'],
  },
  {
    uid: 'uat-mentor-001',
    email: 'mentor@scholesa.test',
    displayName: 'UAT Mentor',
    appRole: 'partner',
    uatRole: 'Mentor',
    purpose: 'Approved external expert, advisor, community partner, or Showcase reviewer.',
    access: 'Assigned Showcase or Portfolio items only when Mentor-specific access is enabled; live app role maps this account to partner surfaces today.',
  },
];

const baseSiteDoc = {
  id: siteId,
  name: 'Scholesa UAT Pilot Site',
  location: 'Live UAT',
  status: 'active',
  updatedAt: nowIso(),
};

const effectiveUidByRequestedUid = new Map();

function resolveLinkedUid(requestedUid) {
  return effectiveUidByRequestedUid.get(requestedUid) || requestedUid;
}

function userDocFor(account, effectiveUid) {
  const linkedLearnerIds = (account.linkedLearnerIds || []).map(resolveLinkedUid);
  return {
    uid: effectiveUid,
    requestedUatUid: account.uid,
    email: account.email,
    displayName: account.displayName,
    role: account.appRole,
    roles: [account.appRole],
    siteIds: [siteId],
    activeSiteId: siteId,
    cohortIds: account.appRole === 'learner' ? [cohortId] : [],
    linkedLearnerIds,
    parentIds: account.uid === 'uat-builder-001' ? [resolveLinkedUid('uat-family-001')] : [],
    gradeLevel: account.gradeLevel || null,
    stage: account.stage || null,
    preferredLocale: 'en',
    status: 'active',
    uatProfile: {
      requestedRole: account.uatRole,
      appRole: account.appRole,
      purpose: account.purpose || null,
      gradeLevel: account.gradeLevel || null,
      stage: account.stage || null,
      aiPolicy: account.aiPolicy || null,
      independentAiChatAllowed:
        typeof account.independentAiChatAllowed === 'boolean'
          ? account.independentAiChatAllowed
          : null,
      restrictions: account.restrictions || [],
      access: account.access || null,
      linkedLearnerEmail: account.uid === 'uat-family-001' ? 'builder@scholesa.test' : null,
      passwordPolicy: 'Test123! for live UAT only',
    },
    updatedAt: nowIso(),
    createdAt: nowIso(),
  };
}

function claimsFor(account) {
  return {
    role: account.appRole,
    roles: [account.appRole],
    uatRole: account.uatRole,
    siteIds: [siteId],
    activeSiteId: siteId,
  };
}

async function ensureAuthAccount(account) {
  const outcome = {
    requestedUid: account.uid,
    effectiveUid: account.uid,
    email: account.email,
    requestedRole: account.uatRole,
    appRole: account.appRole,
    authCreated: false,
    authUpdated: false,
    claimsUpdated: false,
    firestoreUpdated: false,
  };

  let authUser;
  let effectiveUid = account.uid;
  try {
    authUser = await auth.getUser(account.uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (!authUser) {
    try {
      authUser = await auth.getUserByEmail(account.email);
      effectiveUid = authUser.uid;
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        throw error;
      }
      outcome.authCreated = true;
    }
    if (apply) {
      if (!authUser) {
        try {
          authUser = await auth.createUser({
            uid: account.uid,
            email: account.email,
            displayName: account.displayName,
            password,
            disabled: false,
            emailVerified: true,
          });
        } catch (error) {
          if (error?.code !== 'auth/email-already-exists') {
            throw error;
          }
          authUser = await auth.getUserByEmail(account.email);
          effectiveUid = authUser.uid;
          await auth.updateUser(effectiveUid, {
            displayName: account.displayName,
            password,
            disabled: false,
            emailVerified: true,
          });
          outcome.authUpdated = true;
        }
      } else {
        await auth.updateUser(effectiveUid, {
          displayName: account.displayName,
          password,
          disabled: false,
          emailVerified: true,
        });
        outcome.authUpdated = true;
      }
    }
  } else {
    effectiveUid = authUser.uid || account.uid;
    const needsUpdate =
      String(authUser.email || '').toLowerCase() !== account.email ||
      String(authUser.displayName || '') !== account.displayName ||
      authUser.disabled === true ||
      authUser.emailVerified !== true;
    if (needsUpdate) {
      outcome.authUpdated = true;
      if (apply) {
        await auth.updateUser(effectiveUid, {
          email: account.email,
          displayName: account.displayName,
          password,
          disabled: false,
          emailVerified: true,
        });
      }
    }
  }

  outcome.effectiveUid = effectiveUid;
  effectiveUidByRequestedUid.set(account.uid, effectiveUid);

  const currentClaims = authUser?.customClaims || {};
  const nextClaims = claimsFor(account);
  const claimsDiffer =
    currentClaims.role !== nextClaims.role ||
    currentClaims.uatRole !== nextClaims.uatRole ||
    !Array.isArray(currentClaims.roles) ||
    currentClaims.roles.length !== 1 ||
    currentClaims.roles[0] !== nextClaims.role;
  if (claimsDiffer) {
    outcome.claimsUpdated = true;
    if (apply) {
      await auth.setCustomUserClaims(effectiveUid, nextClaims);
    }
  }

  if (apply) {
    await db.collection('users').doc(effectiveUid).set(userDocFor(account, effectiveUid), { merge: true });
    outcome.firestoreUpdated = true;
  } else {
    const snap = await db.collection('users').doc(effectiveUid).get();
    const data = snap.exists ? snap.data() || {} : {};
    if (!snap.exists || data.email !== account.email || data.role !== account.appRole) {
      outcome.firestoreUpdated = true;
    }
  }

  return outcome;
}

async function main() {
  if (!projectId) {
    throw new Error('Unable to resolve project id.');
  }

  if (apply) {
    await db.collection('sites').doc(siteId).set(baseSiteDoc, { merge: true });
  }

  const results = [];
  for (const account of accounts) {
    results.push(await ensureAuthAccount(account));
  }

  const summary = {
    projectId,
    apply,
    siteId,
    cohortId,
    accounts: results.length,
    passwordSetTo: 'Test123!',
    results,
  };

  console.log(JSON.stringify(summary, null, 2));

  if (strict && !apply) {
    const pending = results.filter(
      (result) => result.authCreated || result.authUpdated || result.claimsUpdated || result.firestoreUpdated,
    );
    if (pending.length > 0) {
      process.exit(1);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
