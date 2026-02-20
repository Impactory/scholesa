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

const standardTestPassword = process.env.SEED_TEST_PASSWORD || process.env.TEST_LOGIN_PASSWORD || 'Scholesa123!';

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
    await auth.getUser(uid);
    await auth.updateUser(uid, { email, displayName, password, emailVerified: true, disabled: false });
    await auth.setCustomUserClaims(uid, authClaimsForUser(user));
    console.log(`Updated auth user ${email} with uid ${uid}`);
    return;
  } catch (_) {
    // falls through to create
  }

  await auth.createUser({ uid, email, displayName, password, emailVerified: true, disabled: false });
  await auth.setCustomUserClaims(uid, authClaimsForUser(user));
  console.log(`Created auth user ${email} with uid ${uid}`);
}

async function main() {
  const now = Date.now();
  const site = { id: 'site-1', name: 'Downtown Lab', location: 'City Center', siteLeadIds: ['u-sitelead'], createdAt: now };
  const users = [
    { uid: 'u-learner', email: 'learner@example.com', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-educator', email: 'educator@example.com', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-parent', email: 'parent@example.com', role: 'parent', siteIds: [site.id], parentIds: ['u-learner'], createdAt: now, updatedAt: now },
    { uid: 'u-sitelead', email: 'sitelead@example.com', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
    { uid: 'u-hq', email: 'hq@example.com', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
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
    { uid: 'u-learner', email: 'learner@example.com', displayName: 'Learner User', password: standardTestPassword, role: 'learner' },
    { uid: 'u-educator', email: 'educator@example.com', displayName: 'Educator User', password: standardTestPassword, role: 'educator' },
    { uid: 'u-parent', email: 'parent@example.com', displayName: 'Parent User', password: standardTestPassword, role: 'parent' },
    { uid: 'u-sitelead', email: 'sitelead@example.com', displayName: 'Site Lead User', password: standardTestPassword, role: 'site' },
    { uid: 'u-hq', email: 'hq@example.com', displayName: 'HQ User', password: standardTestPassword, role: 'hq' },
    {
      uid: 'u-master-admin',
      email: 'simon.luke@impactoryinstitute.com',
      displayName: 'Simon Luke (Master Admin)',
      password: process.env.ADMIN_SEED_PASSWORD || standardTestPassword,
      role: 'hq',
      masterAdmin: true,
    },
  ];

  await Promise.all(seededAuthUsers.map((seededUser) => upsertAuthUser(seededUser)));

  await db.collection('sites').doc(site.id).set(site);
  await Promise.all(users.map((u) => db.collection('users').doc(u.uid).set(u)));
  await Promise.all(pillars.map((p) => db.collection('pillars').doc(p.code).set(p)));
  await db.collection('missions').doc(mission.id).set(mission);
  await db.collection('sessions').doc(session.id).set(session);
  await db.collection('sessionOccurrences').doc(occurrence.id).set(occurrence);
  await db.collection('enrollments').doc(enrollment.id).set(enrollment);
  console.log('Seed complete');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});