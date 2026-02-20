const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path');
}

initializeApp({
  credential: cert(require(path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS))),
});
const db = getFirestore();
const auth = getAuth();

const standardTestPassword = process.env.SEED_TEST_PASSWORD || process.env.TEST_LOGIN_PASSWORD || 'Test123!';
const adminSeedPassword = process.env.ADMIN_SEED_PASSWORD || standardTestPassword;

if (!process.env.SEED_TEST_PASSWORD && !process.env.TEST_LOGIN_PASSWORD) {
  console.warn('Using default test password for seeded accounts. Set SEED_TEST_PASSWORD to override.');
}

function authClaimsForUser(user) {
  if (user.masterAdmin) {
    return { role: 'hq', masterAdmin: true, superuser: true, roles: ['hq', 'superuser'] };
  }

  return { role: user.role, roles: [user.role] };
}

async function upsertAuthUser(user) {
  const { uid, email, displayName, password } = user;

  try {
    const existingByUid = await auth.getUser(uid);
    try {
      await auth.updateUser(uid, { email, displayName, password, emailVerified: true, disabled: false });
      await auth.setCustomUserClaims(uid, authClaimsForUser(user));
      console.log(`Updated auth user ${email} with uid ${uid}`);
      return { resolvedUid: existingByUid.uid, email, role: user.role };
    } catch (error) {
      if (error?.code !== 'auth/email-already-exists') {
        throw error;
      }

      const existingByEmail = await auth.getUserByEmail(email);
      await auth.updateUser(existingByEmail.uid, { displayName, password, emailVerified: true, disabled: false });
      await auth.setCustomUserClaims(existingByEmail.uid, authClaimsForUser(user));
      console.log(`Reconciled auth user ${email} to existing uid ${existingByEmail.uid}`);
      return { resolvedUid: existingByEmail.uid, email, role: user.role };
    }
  } catch (error) {
    if (error?.code && error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    const created = await auth.createUser({ uid, email, displayName, password, emailVerified: true, disabled: false });
    await auth.setCustomUserClaims(created.uid, authClaimsForUser(user));
    console.log(`Created auth user ${email} with uid ${created.uid}`);
    return { resolvedUid: created.uid, email, role: user.role };
  } catch (error) {
    if (error?.code !== 'auth/email-already-exists') {
      throw error;
    }

    const existingByEmail = await auth.getUserByEmail(email);
    await auth.updateUser(existingByEmail.uid, { displayName, password, emailVerified: true, disabled: false });
    await auth.setCustomUserClaims(existingByEmail.uid, authClaimsForUser(user));
    console.log(`Linked existing auth email ${email} to uid ${existingByEmail.uid} and refreshed credentials/claims`);
    return { resolvedUid: existingByEmail.uid, email, role: user.role };
  }
}

async function main() {
  const now = Date.now();
  const site = { id: 'site-1', name: 'Downtown Lab', location: 'City Center', siteLeadIds: ['u-sitelead'], createdAt: now };

  const baseUsers = [
    { uid: 'u-learner', email: 'learner@scholesa.dev', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-educator', email: 'educator@scholesa.dev', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-parent', email: 'parent@scholesa.dev', role: 'parent', siteIds: [site.id], parentIds: ['u-learner'], createdAt: now, updatedAt: now },
    { uid: 'u-sitelead', email: 'site@scholesa.dev', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-hq', email: 'hq@scholesa.dev', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-partner', email: 'partner@scholesa.dev', role: 'partner', siteIds: [site.id], createdAt: now, updatedAt: now },
  ];

  const aliasUsers = [
    { uid: 'u-learner-test', email: 'learner@scholesa.test', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-educator-test', email: 'educator@scholesa.test', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-parent-test', email: 'parent@scholesa.test', role: 'parent', siteIds: [site.id], parentIds: ['u-learner-test'], createdAt: now, updatedAt: now },
    { uid: 'u-sitelead-test', email: 'site@scholesa.test', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-hq-test', email: 'hq@scholesa.test', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-partner-test', email: 'partner@scholesa.test', role: 'partner', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-learner-example', email: 'learner@example.com', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-educator-example', email: 'educator@example.com', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-parent-example', email: 'parent@example.com', role: 'parent', siteIds: [site.id], parentIds: ['u-learner-example'], createdAt: now, updatedAt: now },
    { uid: 'u-sitelead-example', email: 'sitelead@example.com', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-hq-example', email: 'hq@example.com', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
  ];

  const users = [
    ...baseUsers,
    ...aliasUsers,
    {
      uid: 'u-master-admin',
      email: 'simon.luke@impactoryinstitute.com',
      role: 'hq',
      siteIds: [site.id],
      createdAt: now,
      updatedAt: now,
      masterAdmin: true,
    },
  ];
  const pillars = [
    { code: 'tech', name: 'Future Skills', color: '#2563eb' },
    { code: 'lead', name: 'Leadership & Agency', color: '#16a34a' },
    { code: 'impact', name: 'Impact & Innovation', color: '#eab308' },
  ];
  const mission = { id: 'mission-1', title: 'Intro to Coding', description: 'Build a simple app', pillarCodes: ['tech'], difficulty: 'beginner', estimatedDurationMinutes: 60 };
  const session = { id: 'session-1', title: 'Weekly Coding', siteId: site.id, educatorIds: ['u-educator'], pillarCodes: ['tech'], startDate: now, endDate: now + 14 * 24 * 3600 * 1000 };
  const occurrence = { id: 'occ-1', sessionId: session.id, siteId: site.id, startTime: now + 24 * 3600 * 1000, endTime: now + 25 * 3600 * 1000, status: 'scheduled' };
  const enrollment = { id: 'enr-1', sessionId: session.id, learnerId: 'u-learner', siteId: site.id, enrolledAt: now, status: 'active' };

  const seededAuthUsers = [
    ...users
      .filter((user) => user.uid !== 'u-master-admin')
      .map((user) => ({
        uid: user.uid,
        email: user.email,
        displayName: `Test ${user.role.toUpperCase()} (${user.email})`,
        password: standardTestPassword,
        role: user.role,
      })),
    {
      uid: 'u-master-admin',
      email: 'simon.luke@impactoryinstitute.com',
      displayName: 'Simon Luke (Master Admin)',
      password: adminSeedPassword,
      role: 'hq',
      masterAdmin: true,
    },
  ];

  const resolvedAuthUsers = await Promise.all(seededAuthUsers.map((seededUser) => upsertAuthUser(seededUser)));
  const uidByEmail = new Map(resolvedAuthUsers.map((item) => [item.email, item.resolvedUid]));

  const resolvedUsers = users.map((user) => {
    const resolvedUid = uidByEmail.get(user.email) || user.uid;
    const resolvedParentIds = (user.parentIds || []).map((parentUid) => {
      const parentUser = users.find((candidate) => candidate.uid === parentUid);
      if (!parentUser) return parentUid;
      return uidByEmail.get(parentUser.email) || parentUid;
    });

    return {
      ...user,
      uid: resolvedUid,
      ...(resolvedParentIds.length > 0 ? { parentIds: resolvedParentIds } : {}),
      updatedAt: now,
    };
  });

  await db.collection('sites').doc(site.id).set(site);
  await Promise.all(resolvedUsers.map((u) => db.collection('users').doc(u.uid).set(u)));
  await Promise.all(pillars.map((p) => db.collection('pillars').doc(p.code).set(p)));
  await db.collection('missions').doc(mission.id).set(mission);
  await db.collection('sessions').doc(session.id).set(session);
  await db.collection('sessionOccurrences').doc(occurrence.id).set(occurrence);
  await db.collection('enrollments').doc(enrollment.id).set(enrollment);
  console.log('Test login password:', standardTestPassword);
  console.log('Primary testing accounts: learner@scholesa.dev, educator@scholesa.dev, parent@scholesa.dev, site@scholesa.dev, hq@scholesa.dev, partner@scholesa.dev');
  console.log('Seed complete');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});