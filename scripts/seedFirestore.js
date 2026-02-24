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
  const siteId = 'site-1';
  const siteName = 'Downtown Lab';

  const baseUsers = [
    {
      uid: 'u-learner',
      email: 'learner@scholesa.dev',
      role: 'learner',
      siteIds: [siteId],
      educatorIds: ['u-educator'],
      parentIds: ['u-parent'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-educator',
      email: 'educator@scholesa.dev',
      role: 'educator',
      siteIds: [siteId],
      learnerIds: ['u-learner'],
      studentIds: ['u-learner'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-parent',
      email: 'parent@scholesa.dev',
      role: 'parent',
      siteIds: [siteId],
      parentIds: ['u-learner'],
      learnerIds: ['u-learner'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-sitelead',
      email: 'site@scholesa.dev',
      role: 'site',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-hq',
      email: 'hq@scholesa.dev',
      role: 'hq',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-partner',
      email: 'partner@scholesa.dev',
      role: 'partner',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
  ];

  const aliasUsers = [
    {
      uid: 'u-learner-test',
      email: 'learner@scholesa.test',
      role: 'learner',
      siteIds: [siteId],
      educatorIds: ['u-educator-test'],
      parentIds: ['u-parent-test'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-educator-test',
      email: 'educator@scholesa.test',
      role: 'educator',
      siteIds: [siteId],
      learnerIds: ['u-learner-test'],
      studentIds: ['u-learner-test'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-parent-test',
      email: 'parent@scholesa.test',
      role: 'parent',
      siteIds: [siteId],
      parentIds: ['u-learner-test'],
      learnerIds: ['u-learner-test'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-sitelead-test',
      email: 'site@scholesa.test',
      role: 'site',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-hq-test',
      email: 'hq@scholesa.test',
      role: 'hq',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-partner-test',
      email: 'partner@scholesa.test',
      role: 'partner',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-learner-example',
      email: 'learner@example.com',
      role: 'learner',
      siteIds: [siteId],
      educatorIds: ['u-educator-example'],
      parentIds: ['u-parent-example'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-educator-example',
      email: 'educator@example.com',
      role: 'educator',
      siteIds: [siteId],
      learnerIds: ['u-learner-example'],
      studentIds: ['u-learner-example'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-parent-example',
      email: 'parent@example.com',
      role: 'parent',
      siteIds: [siteId],
      parentIds: ['u-learner-example'],
      learnerIds: ['u-learner-example'],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-sitelead-example',
      email: 'sitelead@example.com',
      role: 'site',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
    {
      uid: 'u-hq-example',
      email: 'hq@example.com',
      role: 'hq',
      siteIds: [siteId],
      createdAt: now,
      updatedAt: now,
    },
  ];

  const users = [
    ...baseUsers,
    ...aliasUsers,
    {
      uid: 'u-master-admin',
      email: 'simon.luke@impactoryinstitute.com',
      role: 'hq',
      siteIds: [siteId],
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

  const resolvedAuthUsers = await Promise.all(
    seededAuthUsers.map((seededUser) => upsertAuthUser(seededUser)),
  );
  const uidByEmail = new Map(
    resolvedAuthUsers.map((item) => [item.email, item.resolvedUid]),
  );
  const templateUidToEmail = new Map(users.map((user) => [user.uid, user.email]));
  const resolveTemplateUid = (templateUid) => {
    const email = templateUidToEmail.get(templateUid);
    if (!email) return templateUid;
    return uidByEmail.get(email) || templateUid;
  };
  const resolveTemplateUidArray = (values) =>
    (values || []).map((value) => resolveTemplateUid(value));

  const resolvedUsers = users.map((user) => {
    const resolvedUid = uidByEmail.get(user.email) || user.uid;
    const resolvedParentIds = resolveTemplateUidArray(user.parentIds);
    const resolvedLearnerIds = resolveTemplateUidArray(user.learnerIds);
    const resolvedEducatorIds = resolveTemplateUidArray(user.educatorIds);
    const resolvedStudentIds = resolveTemplateUidArray(user.studentIds);

    return {
      ...user,
      uid: resolvedUid,
      siteIds: [siteId],
      activeSiteId: siteId,
      ...(resolvedParentIds.length > 0 ? { parentIds: resolvedParentIds } : {}),
      ...(resolvedLearnerIds.length > 0 ? { learnerIds: resolvedLearnerIds } : {}),
      ...(resolvedEducatorIds.length > 0 ? { educatorIds: resolvedEducatorIds } : {}),
      ...(resolvedStudentIds.length > 0 ? { studentIds: resolvedStudentIds } : {}),
      updatedAt: now,
    };
  });

  const learnerUid = uidByEmail.get('learner@scholesa.dev') || 'u-learner';
  const educatorUid = uidByEmail.get('educator@scholesa.dev') || 'u-educator';
  const parentUid = uidByEmail.get('parent@scholesa.dev') || 'u-parent';
  const siteLeadUid = uidByEmail.get('site@scholesa.dev') || 'u-sitelead';
  const hqUid = uidByEmail.get('hq@scholesa.dev') || 'u-hq';
  const partnerUid = uidByEmail.get('partner@scholesa.dev') || 'u-partner';

  const site = {
    id: siteId,
    name: siteName,
    location: 'City Center',
    status: 'active',
    siteLeadIds: [siteLeadUid],
    educatorIds: [educatorUid, siteLeadUid],
    learnerIds: [learnerUid],
    parentIds: [parentUid],
    hqIds: [hqUid],
    partnerIds: [partnerUid],
    createdAt: now,
    updatedAt: now,
  };

  const mission = {
    id: 'mission-1',
    title: 'Intro to Coding',
    description: 'Build a simple app',
    pillarCodes: ['tech'],
    difficulty: 'beginner',
    estimatedDurationMinutes: 60,
    siteId,
    educatorId: educatorUid,
    educatorIds: [educatorUid],
    learnerIds: [learnerUid],
    createdBy: educatorUid,
    createdAt: now,
    updatedAt: now,
  };
  const session = {
    id: 'session-1',
    title: 'Weekly Coding',
    siteId,
    educatorId: educatorUid,
    educatorIds: [educatorUid],
    teacherId: educatorUid,
    teacherIds: [educatorUid],
    learnerIds: [learnerUid],
    pillarCodes: ['tech'],
    roomName: 'Lab A',
    location: 'Lab A',
    startDate: now,
    endDate: now + 14 * 24 * 3600 * 1000,
    startTime: now,
    endTime: now + 14 * 24 * 3600 * 1000,
    status: 'scheduled',
    createdAt: now,
    updatedAt: now,
  };
  const occurrence = {
    id: 'occ-1',
    sessionId: session.id,
    siteId,
    title: session.title,
    educatorId: educatorUid,
    educatorIds: [educatorUid],
    teacherId: educatorUid,
    teacherIds: [educatorUid],
    learnerIds: [learnerUid],
    date: now + 24 * 3600 * 1000,
    startTime: now + 24 * 3600 * 1000,
    endTime: now + 25 * 3600 * 1000,
    status: 'scheduled',
    enrolledCount: 1,
    presentCount: 0,
    createdAt: now,
    updatedAt: now,
  };
  const enrollment = {
    id: 'enr-1',
    sessionId: session.id,
    sessionOccurrenceId: occurrence.id,
    learnerId: learnerUid,
    userId: learnerUid,
    siteId,
    educatorId: educatorUid,
    educatorIds: [educatorUid],
    teacherId: educatorUid,
    teacherIds: [educatorUid],
    enrolledAt: now,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  };
  const missionAssignment = {
    id: `mission-1_${learnerUid}`,
    missionId: mission.id,
    learnerId: learnerUid,
    siteId,
    educatorId: educatorUid,
    educatorIds: [educatorUid],
    assignedBy: educatorUid,
    status: 'not_started',
    progress: 0,
    createdAt: now,
    updatedAt: now,
  };
  const guardianLink = {
    id: `${siteId}_${parentUid}_${learnerUid}`,
    siteId,
    parentId: parentUid,
    learnerId: learnerUid,
    relationship: 'Parent',
    isPrimary: true,
    createdBy: siteLeadUid,
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('sites').doc(site.id).set(site);
  await Promise.all(
    resolvedUsers.map((user) => db.collection('users').doc(user.uid).set(user)),
  );
  await Promise.all(
    pillars.map((pillar) => db.collection('pillars').doc(pillar.code).set(pillar)),
  );
  await db.collection('missions').doc(mission.id).set(mission);
  await db.collection('sessions').doc(session.id).set(session);
  await db.collection('sessionOccurrences').doc(occurrence.id).set(occurrence);
  await db.collection('enrollments').doc(enrollment.id).set(enrollment);
  await db
    .collection('missionAssignments')
    .doc(missionAssignment.id)
    .set(missionAssignment);
  await db.collection('guardianLinks').doc(guardianLink.id).set(guardianLink);

  console.log('Test login password:', standardTestPassword);
  console.log(
    'Primary testing accounts: learner@scholesa.dev, educator@scholesa.dev, parent@scholesa.dev, site@scholesa.dev, hq@scholesa.dev, partner@scholesa.dev',
  );
  console.log('Seed complete');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
