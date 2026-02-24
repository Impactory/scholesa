// Create test users and required cross-links for pre-RC3 validation.
// Run: node scripts/create-test-users.js

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID || 'studio-3328096157-e3f79';
const TEST_SITE_ID = process.env.TEST_SITE_ID || 'site_001';
const TEST_SITE_NAME = process.env.TEST_SITE_NAME || 'RC3 Test Site';
const TEST_MISSION_ID = process.env.TEST_MISSION_ID || 'mission_rc3_intro';
const TEST_SESSION_ID = process.env.TEST_SESSION_ID || 'session_rc3_intro';
const TEST_OCCURRENCE_ID =
  process.env.TEST_OCCURRENCE_ID || `${TEST_SESSION_ID}_occ_001`;
const DEFAULT_PASSWORD = process.env.TEST_USER_PASSWORD || 'Test123!';

const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(__dirname, '../firebase-service-account.json'),
  path.resolve(__dirname, '../studio-service-account.json'),
].filter(Boolean);

const TEST_USERS = [
  {
    email: 'learner@scholesa.test',
    role: 'learner',
    displayName: 'Test Learner',
  },
  {
    email: 'educator@scholesa.test',
    role: 'educator',
    displayName: 'Test Educator',
  },
  {
    email: 'parent@scholesa.test',
    role: 'parent',
    displayName: 'Test Parent',
  },
  {
    email: 'site@scholesa.test',
    role: 'site',
    displayName: 'Test Site Lead',
  },
  {
    email: 'hq@scholesa.test',
    role: 'hq',
    displayName: 'Test HQ Admin',
  },
  {
    email: 'partner@scholesa.test',
    role: 'partner',
    displayName: 'Test Partner',
  },
];

function loadServiceAccount() {
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (!candidate) continue;
    if (!fs.existsSync(candidate)) continue;
    return {
      path: candidate,
      json: require(candidate),
    };
  }
  throw new Error(
    `No service account JSON found. Checked: ${SERVICE_ACCOUNT_PATHS.join(', ')}`,
  );
}

function nowTs() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function compactStrings(values) {
  return Array.from(
    new Set(
      values
        .filter((value) => typeof value === 'string')
        .map((value) => value.trim())
        .filter(Boolean),
    ),
  );
}

function occurrenceWindow() {
  const start = new Date();
  start.setHours(9, 0, 0, 0);
  if (start.getTime() < Date.now()) {
    start.setDate(start.getDate() + 1);
  }
  const end = new Date(start.getTime() + 60 * 60 * 1000);
  return { start, end };
}

async function getOrCreateAuthUser(auth, seed) {
  try {
    const existing = await auth.getUserByEmail(seed.email);
    await auth.updateUser(existing.uid, {
      displayName: seed.displayName,
      emailVerified: true,
    });
    return existing;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  return auth.createUser({
    email: seed.email,
    password: DEFAULT_PASSWORD,
    displayName: seed.displayName,
    emailVerified: true,
  });
}

async function ensureUserSiteLink(db, userId) {
  await db.collection('users').doc(userId).set(
    {
      siteIds: admin.firestore.FieldValue.arrayUnion(TEST_SITE_ID),
      activeSiteId: TEST_SITE_ID,
      updatedAt: nowTs(),
    },
    { merge: true },
  );
}

async function upsertUserDoc(db, record, seed) {
  await db.collection('users').doc(record.uid).set(
    {
      uid: record.uid,
      email: seed.email.toLowerCase(),
      displayName: seed.displayName,
      role: seed.role,
      siteIds: admin.firestore.FieldValue.arrayUnion(TEST_SITE_ID),
      activeSiteId: TEST_SITE_ID,
      isActive: true,
      status: 'active',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function ensureSiteDoc(db, userIds) {
  const educatorUids = compactStrings([userIds.educator?.uid, userIds.site?.uid]);
  const learnerUids = compactStrings([userIds.learner?.uid]);
  const parentUids = compactStrings([userIds.parent?.uid]);
  const siteLeadUids = compactStrings([userIds.site?.uid]);
  const hqUids = compactStrings([userIds.hq?.uid]);
  const partnerUids = compactStrings([userIds.partner?.uid]);

  await db.collection('sites').doc(TEST_SITE_ID).set(
    {
      id: TEST_SITE_ID,
      name: TEST_SITE_NAME,
      status: 'active',
      siteLeadIds: siteLeadUids,
      educatorIds: educatorUids,
      learnerIds: learnerUids,
      parentIds: parentUids,
      hqIds: hqUids,
      partnerIds: partnerUids,
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function ensureParentLearnerLinks(db, userIds) {
  const learner = userIds.learner;
  const parent = userIds.parent;
  const siteLead = userIds.site;
  if (!learner || !parent) {
    throw new Error('Missing learner/parent user for cross-link setup');
  }

  await Promise.all([
    ensureUserSiteLink(db, learner.uid),
    ensureUserSiteLink(db, parent.uid),
  ]);

  await db.collection('users').doc(learner.uid).set(
    {
      parentIds: admin.firestore.FieldValue.arrayUnion(parent.uid),
      updatedAt: nowTs(),
    },
    { merge: true },
  );

  await db.collection('users').doc(parent.uid).set(
    {
      learnerIds: admin.firestore.FieldValue.arrayUnion(learner.uid),
      updatedAt: nowTs(),
    },
    { merge: true },
  );

  await db.collection('learnerProfiles').doc(learner.uid).set(
    {
      learnerId: learner.uid,
      userId: learner.uid,
      siteId: TEST_SITE_ID,
      displayName: learner.displayName || 'Test Learner',
      email: learner.email?.toLowerCase() || 'learner@scholesa.test',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  await db.collection('parentProfiles').doc(parent.uid).set(
    {
      parentId: parent.uid,
      userId: parent.uid,
      siteId: TEST_SITE_ID,
      displayName: parent.displayName || 'Test Parent',
      email: parent.email?.toLowerCase() || 'parent@scholesa.test',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  const guardianLinkId = `${TEST_SITE_ID}_${parent.uid}_${learner.uid}`;
  await db.collection('guardianLinks').doc(guardianLinkId).set(
    {
      siteId: TEST_SITE_ID,
      parentId: parent.uid,
      learnerId: learner.uid,
      relationship: 'Parent',
      isPrimary: true,
      createdBy: siteLead?.uid || 'system',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function ensureEducatorLearnerLinks(db, userIds) {
  const learner = userIds.learner;
  const educator = userIds.educator || userIds.site;
  if (!learner || !educator) {
    throw new Error('Missing learner/educator user for teacher cross-link setup');
  }

  await Promise.all([
    ensureUserSiteLink(db, learner.uid),
    ensureUserSiteLink(db, educator.uid),
  ]);

  await db.collection('users').doc(educator.uid).set(
    {
      learnerIds: admin.firestore.FieldValue.arrayUnion(learner.uid),
      studentIds: admin.firestore.FieldValue.arrayUnion(learner.uid),
      updatedAt: nowTs(),
    },
    { merge: true },
  );

  await db.collection('users').doc(learner.uid).set(
    {
      educatorIds: admin.firestore.FieldValue.arrayUnion(educator.uid),
      teacherIds: admin.firestore.FieldValue.arrayUnion(educator.uid),
      assignedEducatorId: educator.uid,
      updatedAt: nowTs(),
    },
    { merge: true },
  );

  const linkId = `${TEST_SITE_ID}_${educator.uid}_${learner.uid}`;
  await db.collection('educatorLearnerLinks').doc(linkId).set(
    {
      id: linkId,
      siteId: TEST_SITE_ID,
      educatorId: educator.uid,
      learnerId: learner.uid,
      status: 'active',
      linkedBy: userIds.site?.uid || educator.uid,
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function ensureMissionCrossLinks(db, userIds) {
  const learner = userIds.learner;
  const educator = userIds.educator || userIds.site;
  if (!learner || !educator) {
    throw new Error('Missing learner/educator user for mission cross-link setup');
  }

  await db.collection('missions').doc(TEST_MISSION_ID).set(
    {
      id: TEST_MISSION_ID,
      title: 'RC3 Intro Mission',
      description: 'Mission used to validate RC3 cross-link integrity.',
      pillarCode: 'future_skills',
      difficulty: 'beginner',
      xpReward: 120,
      siteId: TEST_SITE_ID,
      educatorId: educator.uid,
      educatorIds: [educator.uid],
      learnerIds: [learner.uid],
      createdBy: educator.uid,
      status: 'active',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  const assignmentId = `${TEST_MISSION_ID}_${learner.uid}`;
  await db.collection('missionAssignments').doc(assignmentId).set(
    {
      id: assignmentId,
      missionId: TEST_MISSION_ID,
      learnerId: learner.uid,
      siteId: TEST_SITE_ID,
      status: 'not_started',
      progress: 0,
      assignedBy: educator.uid,
      educatorId: educator.uid,
      educatorIds: [educator.uid],
      assignedAt: nowTs(),
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  const missionPlanId = `${TEST_SITE_ID}_${TEST_MISSION_ID}_${learner.uid}`;
  await db.collection('missionPlans').doc(missionPlanId).set(
    {
      id: missionPlanId,
      missionId: TEST_MISSION_ID,
      learnerId: learner.uid,
      siteId: TEST_SITE_ID,
      createdBy: educator.uid,
      educatorId: educator.uid,
      educatorIds: [educator.uid],
      status: 'active',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function ensureEnrollmentCrossLinks(db, userIds) {
  const learner = userIds.learner;
  const educator = userIds.educator || userIds.site;
  if (!learner || !educator) {
    throw new Error('Missing learner/educator user for enrollment setup');
  }

  const { start, end } = occurrenceWindow();

  await db.collection('sessions').doc(TEST_SESSION_ID).set(
    {
      id: TEST_SESSION_ID,
      title: 'RC3 Validation Session',
      siteId: TEST_SITE_ID,
      educatorId: educator.uid,
      educatorIds: [educator.uid],
      teacherId: educator.uid,
      teacherIds: [educator.uid],
      learnerIds: [learner.uid],
      pillarCodes: ['future_skills'],
      roomName: 'Lab A',
      location: 'Lab A',
      startTime: start.getTime(),
      endTime: end.getTime(),
      startDate: start.getTime(),
      endDate: end.getTime(),
      status: 'scheduled',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  await db.collection('sessionOccurrences').doc(TEST_OCCURRENCE_ID).set(
    {
      id: TEST_OCCURRENCE_ID,
      sessionId: TEST_SESSION_ID,
      siteId: TEST_SITE_ID,
      title: 'RC3 Validation Session',
      educatorId: educator.uid,
      educatorIds: [educator.uid],
      teacherId: educator.uid,
      teacherIds: [educator.uid],
      learnerIds: [learner.uid],
      roomName: 'Lab A',
      location: 'Lab A',
      date: start.getTime(),
      startTime: start.getTime(),
      endTime: end.getTime(),
      status: 'scheduled',
      enrolledCount: 1,
      presentCount: 0,
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  const enrollmentId = `${TEST_SESSION_ID}_${learner.uid}`;
  await db.collection('enrollments').doc(enrollmentId).set(
    {
      id: enrollmentId,
      sessionId: TEST_SESSION_ID,
      learnerId: learner.uid,
      userId: learner.uid,
      siteId: TEST_SITE_ID,
      educatorId: educator.uid,
      educatorIds: [educator.uid],
      teacherId: educator.uid,
      teacherIds: [educator.uid],
      sessionOccurrenceId: TEST_OCCURRENCE_ID,
      status: 'active',
      enrolledAt: nowTs(),
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  await db.collection('users').doc(learner.uid).set(
    {
      enrolledSessionIds: admin.firestore.FieldValue.arrayUnion(TEST_SESSION_ID),
      updatedAt: nowTs(),
    },
    { merge: true },
  );
}

async function verifyCrossLinks(db, userIds) {
  const learner = userIds.learner;
  const educator = userIds.educator || userIds.site;
  const parent = userIds.parent;
  const siteLead = userIds.site;
  if (!learner || !educator || !parent || !siteLead) {
    throw new Error('Cannot verify cross-links: required users missing');
  }

  const [
    learnerDoc,
    parentDoc,
    educatorDoc,
    siteDoc,
    sessionDoc,
    occurrenceDoc,
  ] = await Promise.all([
    db.collection('users').doc(learner.uid).get(),
    db.collection('users').doc(parent.uid).get(),
    db.collection('users').doc(educator.uid).get(),
    db.collection('sites').doc(TEST_SITE_ID).get(),
    db.collection('sessions').doc(TEST_SESSION_ID).get(),
    db.collection('sessionOccurrences').doc(TEST_OCCURRENCE_ID).get(),
  ]);

  const failures = [];

  const learnerData = learnerDoc.data() || {};
  const parentData = parentDoc.data() || {};
  const educatorData = educatorDoc.data() || {};
  const siteData = siteDoc.data() || {};
  const sessionData = sessionDoc.data() || {};
  const occurrenceData = occurrenceDoc.data() || {};

  const includes = (value, target) =>
    Array.isArray(value) &&
    value.some((entry) => String(entry).trim() === target);

  if (!includes(learnerData.siteIds, TEST_SITE_ID)) {
    failures.push('learner missing site link');
  }
  if (!includes(parentData.siteIds, TEST_SITE_ID)) {
    failures.push('parent missing site link');
  }
  if (!includes(educatorData.siteIds, TEST_SITE_ID)) {
    failures.push('educator missing site link');
  }
  if (!includes(learnerData.parentIds, parent.uid)) {
    failures.push('learner missing parentIds link');
  }
  if (!includes(parentData.learnerIds, learner.uid)) {
    failures.push('parent missing learnerIds link');
  }
  if (!includes(educatorData.learnerIds, learner.uid)) {
    failures.push('educator missing learnerIds link');
  }
  if (!includes(learnerData.educatorIds, educator.uid)) {
    failures.push('learner missing educatorIds link');
  }
  if (!includes(siteData.siteLeadIds, siteLead.uid)) {
    failures.push('site missing siteLeadIds link');
  }
  if (!includes(siteData.educatorIds, educator.uid)) {
    failures.push('site missing educatorIds link');
  }
  if (!includes(siteData.learnerIds, learner.uid)) {
    failures.push('site missing learnerIds link');
  }
  if (String(sessionData.educatorId || '').trim() !== educator.uid) {
    failures.push('session missing educatorId');
  }
  if (!includes(sessionData.educatorIds, educator.uid)) {
    failures.push('session missing educatorIds link');
  }
  if (!includes(sessionData.learnerIds, learner.uid)) {
    failures.push('session missing learnerIds link');
  }
  if (String(occurrenceData.educatorId || '').trim() !== educator.uid) {
    failures.push('session occurrence missing educatorId');
  }
  if (!includes(occurrenceData.educatorIds, educator.uid)) {
    failures.push('session occurrence missing educatorIds link');
  }

  const assignmentId = `${TEST_MISSION_ID}_${learner.uid}`;
  const enrollmentId = `${TEST_SESSION_ID}_${learner.uid}`;
  const [assignmentDoc, enrollmentDoc, guardianDoc] = await Promise.all([
    db.collection('missionAssignments').doc(assignmentId).get(),
    db.collection('enrollments').doc(enrollmentId).get(),
    db
      .collection('guardianLinks')
      .doc(`${TEST_SITE_ID}_${parent.uid}_${learner.uid}`)
      .get(),
  ]);

  if (!assignmentDoc.exists) {
    failures.push('mission assignment missing');
  } else {
    const assignmentData = assignmentDoc.data() || {};
    if (String(assignmentData.educatorId || '').trim() !== educator.uid) {
      failures.push('mission assignment missing educatorId');
    }
  }

  if (!enrollmentDoc.exists) {
    failures.push('enrollment missing');
  } else {
    const enrollmentData = enrollmentDoc.data() || {};
    if (String(enrollmentData.educatorId || '').trim() !== educator.uid) {
      failures.push('enrollment missing educatorId');
    }
  }

  if (!guardianDoc.exists) {
    failures.push('guardian link missing');
  }

  if (failures.length > 0) {
    throw new Error(`Cross-link verification failed: ${failures.join('; ')}`);
  }
}

async function createTestUsers() {
  const serviceAccount = loadServiceAccount();
  console.log(`Using service account: ${serviceAccount.path}`);

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount.json),
      projectId: PROJECT_ID,
    });
  }

  const auth = admin.auth();
  const db = admin.firestore();

  console.log('Creating/upserting RC3 test users and cross-links...\n');

  const userIds = {};
  for (const user of TEST_USERS) {
    const record = await getOrCreateAuthUser(auth, user);
    await upsertUserDoc(db, record, user);
    userIds[user.role] = record;
    console.log(`✅ ${user.role.padEnd(8)} ${user.email} (${record.uid})`);
  }

  await ensureSiteDoc(db, userIds);
  await ensureParentLearnerLinks(db, userIds);
  await ensureEducatorLearnerLinks(db, userIds);
  await ensureMissionCrossLinks(db, userIds);
  await ensureEnrollmentCrossLinks(db, userIds);
  await verifyCrossLinks(db, userIds);

  console.log('\n✅ RC3 pre-seed complete with cross-links:');
  console.log(`- Site: ${TEST_SITE_ID}`);
  console.log(`- Mission: ${TEST_MISSION_ID}`);
  console.log(`- Session: ${TEST_SESSION_ID}`);
  console.log(`- Session occurrence: ${TEST_OCCURRENCE_ID}`);
  console.log('- Teacher↔Site link: created');
  console.log('- Teacher↔Learner link: created');
  console.log('- Parent↔Learner link: created');
  console.log('- Learner↔Mission assignment: created');
  console.log('- Learner↔Session enrollment: created');
  console.log('\nLogin credentials:');
  console.log(`- Password for all test users: ${DEFAULT_PASSWORD}`);
  for (const user of TEST_USERS) {
    console.log(`- ${user.role}: ${user.email}`);
  }
}

createTestUsers()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Failed to create RC3 test users/cross-links:', error);
    process.exit(1);
  });
