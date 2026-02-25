#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const SITE_ID = process.env.DEMO_SITE_ID || 'SCH-DEMO-001';
const STUDENT_MAX = Number(process.env.DEMO_STUDENT_MAX || 25);
const PARENT_MAX = Number(process.env.DEMO_PARENT_MAX || 23);
const PASSWORD =
  process.env.DEMO_SEED_PASSWORD ||
  process.env.SEED_TEST_PASSWORD ||
  process.env.TEST_USER_PASSWORD ||
  'Test123!';

const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(__dirname, '../firebase-service-account.json'),
  path.resolve(__dirname, '../studio-service-account.json'),
].filter(Boolean);

function loadServiceAccount() {
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (!candidate) continue;
    if (!fs.existsSync(candidate)) continue;
    return {
      path: candidate,
      json: JSON.parse(fs.readFileSync(candidate, 'utf8')),
    };
  }
  throw new Error(
    `No service account JSON found. Checked: ${SERVICE_ACCOUNT_PATHS.join(', ')}`,
  );
}

function pad3(num) {
  return String(num).padStart(3, '0');
}

function nowTs() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function parentSeed(index) {
  const id = pad3(index);
  return {
    uid: `U-PAR-${id}`,
    email: `parent${id}.demo@scholesa.org`,
    displayName: `Parent${id} Demo`,
    role: 'parent',
  };
}

function studentSeed(index) {
  const id = pad3(index);
  return {
    uid: `U-STU-${id}`,
    email: `student${id}.demo@scholesa.org`,
    displayName: `Student${id} Demo`,
    role: 'learner',
  };
}

async function getOrCreateAuthUser(auth, seed) {
  try {
    const byUid = await auth.getUser(seed.uid);
    await auth.updateUser(byUid.uid, {
      email: seed.email,
      displayName: seed.displayName,
      password: PASSWORD,
      emailVerified: true,
      disabled: false,
    });
    return byUid;
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    const byEmail = await auth.getUserByEmail(seed.email);
    if (byEmail.uid !== seed.uid) {
      // Keep existing UID authoritative to avoid auth conflicts.
      await auth.updateUser(byEmail.uid, {
        displayName: seed.displayName,
        password: PASSWORD,
        emailVerified: true,
        disabled: false,
      });
      return byEmail;
    }
    await auth.updateUser(seed.uid, {
      password: PASSWORD,
      emailVerified: true,
      disabled: false,
    });
    return byEmail;
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  return auth.createUser({
    uid: seed.uid,
    email: seed.email,
    displayName: seed.displayName,
    password: PASSWORD,
    emailVerified: true,
    disabled: false,
  });
}

async function upsertStudentUserDoc(db, seed) {
  await db.collection('users').doc(seed.uid).set(
    {
      uid: seed.uid,
      email: seed.email.toLowerCase(),
      displayName: seed.displayName,
      role: seed.role,
      siteIds: admin.firestore.FieldValue.arrayUnion(SITE_ID),
      activeSiteId: SITE_ID,
      status: 'active',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function upsertParentUserDoc(db, seed, studentUid) {
  await db.collection('users').doc(seed.uid).set(
    {
      uid: seed.uid,
      email: seed.email.toLowerCase(),
      displayName: seed.displayName,
      role: seed.role,
      siteIds: admin.firestore.FieldValue.arrayUnion(SITE_ID),
      activeSiteId: SITE_ID,
      status: 'active',
      learnerIds: admin.firestore.FieldValue.arrayUnion(studentUid),
      childIds: admin.firestore.FieldValue.arrayUnion(studentUid),
      childSiteIds: admin.firestore.FieldValue.arrayUnion(SITE_ID),
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function linkParentStudent(db, parentUid, studentUid) {
  await Promise.all([
    db.collection('users').doc(studentUid).set(
      {
        parentIds: admin.firestore.FieldValue.arrayUnion(parentUid),
        updatedAt: nowTs(),
      },
      { merge: true },
    ),
    db.collection('users').doc(parentUid).set(
      {
        learnerIds: admin.firestore.FieldValue.arrayUnion(studentUid),
        childIds: admin.firestore.FieldValue.arrayUnion(studentUid),
        childSiteIds: admin.firestore.FieldValue.arrayUnion(SITE_ID),
        updatedAt: nowTs(),
      },
      { merge: true },
    ),
  ]);

  const guardianId = `${SITE_ID}_${parentUid}_${studentUid}`;
  await db.collection('guardianLinks').doc(guardianId).set(
    {
      siteId: SITE_ID,
      parentId: parentUid,
      learnerId: studentUid,
      relationship: 'Parent',
      isPrimary: true,
      createdBy: 'seed_demo_numbered_family_links',
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function ensureSiteArrays(db) {
  const parentIds = [];
  const learnerIds = [];

  for (let i = 1; i <= PARENT_MAX; i += 1) {
    parentIds.push(parentSeed(i).uid);
  }
  for (let i = 1; i <= STUDENT_MAX; i += 1) {
    learnerIds.push(studentSeed(i).uid);
  }

  await db.collection('sites').doc(SITE_ID).set(
    {
      id: SITE_ID,
      parentIds: admin.firestore.FieldValue.arrayUnion(...parentIds),
      learnerIds: admin.firestore.FieldValue.arrayUnion(...learnerIds),
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );
}

async function verifyLinks(db) {
  const failures = [];
  for (let i = 1; i <= PARENT_MAX; i += 1) {
    const parent = parentSeed(i);
    const student = studentSeed(i);
    const [parentDoc, studentDoc, guardianDoc] = await Promise.all([
      db.collection('users').doc(parent.uid).get(),
      db.collection('users').doc(student.uid).get(),
      db.collection('guardianLinks').doc(`${SITE_ID}_${parent.uid}_${student.uid}`).get(),
    ]);
    if (!parentDoc.exists) failures.push(`missing_parent_doc:${parent.uid}`);
    if (!studentDoc.exists) failures.push(`missing_student_doc:${student.uid}`);
    if (!guardianDoc.exists) failures.push(`missing_guardian_link:${parent.uid}:${student.uid}`);

    const parentData = parentDoc.data() || {};
    const studentData = studentDoc.data() || {};

    const parentLearners = Array.isArray(parentData.learnerIds) ? parentData.learnerIds : [];
    const parentChildren = Array.isArray(parentData.childIds) ? parentData.childIds : [];
    const studentParents = Array.isArray(studentData.parentIds) ? studentData.parentIds : [];
    const studentSites = Array.isArray(studentData.siteIds) ? studentData.siteIds : [];

    if (!parentLearners.includes(student.uid)) {
      failures.push(`parent_missing_learnerIds:${parent.uid}:${student.uid}`);
    }
    if (!parentChildren.includes(student.uid)) {
      failures.push(`parent_missing_childIds:${parent.uid}:${student.uid}`);
    }
    if (!studentParents.includes(parent.uid)) {
      failures.push(`student_missing_parentIds:${student.uid}:${parent.uid}`);
    }
    if (!studentSites.includes(SITE_ID)) {
      failures.push(`student_missing_site:${student.uid}:${SITE_ID}`);
    }
  }
  return failures;
}

async function main() {
  if (STUDENT_MAX < PARENT_MAX) {
    throw new Error(
      `DEMO_STUDENT_MAX (${STUDENT_MAX}) must be >= DEMO_PARENT_MAX (${PARENT_MAX}).`,
    );
  }

  const serviceAccount = loadServiceAccount();
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount.json),
      projectId: serviceAccount.json.project_id,
    });
  }

  const auth = admin.auth();
  const db = admin.firestore();

  const summary = {
    siteId: SITE_ID,
    password: PASSWORD,
    studentsEnsured: 0,
    parentsEnsured: 0,
    linksEnsured: 0,
  };

  for (let i = 1; i <= STUDENT_MAX; i += 1) {
    const seed = studentSeed(i);
    await getOrCreateAuthUser(auth, seed);
    await upsertStudentUserDoc(db, seed);
    summary.studentsEnsured += 1;
  }

  for (let i = 1; i <= PARENT_MAX; i += 1) {
    const parent = parentSeed(i);
    const student = studentSeed(i);
    await getOrCreateAuthUser(auth, parent);
    await upsertParentUserDoc(db, parent, student.uid);
    await linkParentStudent(db, parent.uid, student.uid);
    summary.parentsEnsured += 1;
    summary.linksEnsured += 1;
  }

  await ensureSiteArrays(db);

  const failures = await verifyLinks(db);

  process.stdout.write(
    JSON.stringify(
      {
        status: failures.length === 0 ? 'PASS' : 'FAIL',
        summary,
        failures,
        loginPattern: {
          parents: 'parent001.demo@scholesa.org ... parent023.demo@scholesa.org',
          students: 'student001.demo@scholesa.org ... student025.demo@scholesa.org',
          password: PASSWORD,
        },
      },
      null,
      2,
    ) + '\n',
  );

  if (failures.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  process.stderr.write(
    JSON.stringify(
      {
        status: 'FAIL',
        error: error instanceof Error ? error.message : String(error),
      },
      null,
      2,
    ) + '\n',
  );
  process.exit(1);
});
