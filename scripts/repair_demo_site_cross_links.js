#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const DEFAULT_SITE_ID = process.env.DEMO_SITE_ID || 'SCH-DEMO-001';
const DEFAULT_SITE_USER_ID = process.env.DEMO_SITE_USER_ID || 'U-SITE-001';
const DEFAULT_SITE_USER_EMAIL = process.env.DEMO_SITE_USER_EMAIL || 'site001.demo@scholesa.org';
const DEFAULT_SITE_USER_NAME = process.env.DEMO_SITE_USER_NAME || 'Site001 Demo';
const DEFAULT_PASSWORD =
  process.env.DEMO_SEED_PASSWORD ||
  process.env.SEED_TEST_PASSWORD ||
  process.env.TEST_USER_PASSWORD ||
  'Test123!';

const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(__dirname, '../firebase-service-account.json'),
  path.resolve(__dirname, '../studio-service-account.json'),
].filter(Boolean);

function parseArgs(argv) {
  const args = {
    siteId: DEFAULT_SITE_ID,
    apply: false,
    strict: false,
    siteUserId: DEFAULT_SITE_USER_ID,
    siteUserEmail: DEFAULT_SITE_USER_EMAIL,
    siteUserName: DEFAULT_SITE_USER_NAME,
  };

  for (const arg of argv) {
    if (arg === '--apply') {
      args.apply = true;
      continue;
    }
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'site-id' || rawKey === 'siteId') args.siteId = rawValue.trim();
    if (rawKey === 'site-user-id' || rawKey === 'siteUserId') args.siteUserId = rawValue.trim();
    if (rawKey === 'site-user-email' || rawKey === 'siteUserEmail') args.siteUserEmail = rawValue.trim();
    if (rawKey === 'site-user-name' || rawKey === 'siteUserName') args.siteUserName = rawValue.trim();
  }

  return args;
}

function toStringArray(value) {
  if (!Array.isArray(value)) return [];
  return Array.from(
    new Set(
      value
        .filter((entry) => typeof entry === 'string')
        .map((entry) => entry.trim())
        .filter(Boolean),
    ),
  );
}

function normalizeRole(role) {
  if (typeof role !== 'string') return null;
  const normalized = role.trim().toLowerCase();
  if (normalized === 'learner' || normalized === 'student') return 'learner';
  if (normalized === 'educator' || normalized === 'teacher') return 'educator';
  if (normalized === 'parent' || normalized === 'guardian') return 'parent';
  if (normalized === 'site' || normalized === 'sitelead' || normalized === 'site_lead') return 'site';
  if (normalized === 'partner') return 'partner';
  if (normalized === 'hq' || normalized === 'admin') return 'hq';
  return null;
}

function nowTs() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function loadServiceAccount() {
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (!candidate) continue;
    if (!fs.existsSync(candidate)) continue;
    return {
      path: candidate,
      json: JSON.parse(fs.readFileSync(candidate, 'utf8')),
    };
  }
  throw new Error(`No service account JSON found. Checked: ${SERVICE_ACCOUNT_PATHS.join(', ')}`);
}

async function ensureSiteRoleIdentity({ auth, db, siteId, uid, email, displayName, apply }) {
  const outcome = {
    uid,
    createdAuth: false,
    updatedAuth: false,
    createdUserDoc: false,
    updatedUserDoc: false,
  };

  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.data() || {};
  const hasSiteRole = normalizeRole(userData.role) === 'site';
  const hasSiteId = toStringArray(userData.siteIds).includes(siteId);

  if (!hasSiteRole || !hasSiteId) {
    outcome.updatedUserDoc = true;
    if (apply) {
      await db.collection('users').doc(uid).set(
        {
          uid,
          email: email.toLowerCase(),
          displayName,
          role: 'site',
          siteIds: admin.firestore.FieldValue.arrayUnion(siteId),
          activeSiteId: siteId,
          status: 'active',
          updatedAt: nowTs(),
          createdAt: nowTs(),
        },
        { merge: true },
      );
      outcome.createdUserDoc = !userDoc.exists;
    }
  }

  try {
    const authUser = await auth.getUser(uid);
    const needsUpdate =
      authUser.email?.toLowerCase() !== email.toLowerCase() ||
      (authUser.displayName || '') !== displayName ||
      authUser.disabled === true;
    if (needsUpdate) {
      outcome.updatedAuth = true;
      if (apply) {
        await auth.updateUser(uid, {
          email,
          displayName,
          password: DEFAULT_PASSWORD,
          emailVerified: true,
          disabled: false,
        });
      }
    }
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
    outcome.createdAuth = true;
    if (apply) {
      await auth.createUser({
        uid,
        email,
        displayName,
        password: DEFAULT_PASSWORD,
        emailVerified: true,
        disabled: false,
      });
    }
  }

  return outcome;
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const serviceAccount = loadServiceAccount();

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount.json),
      projectId: serviceAccount.json.project_id,
    });
  }

  const db = admin.firestore();
  const auth = admin.auth();

  const siteIdentity = await ensureSiteRoleIdentity({
    auth,
    db,
    siteId: args.siteId,
    uid: args.siteUserId,
    email: args.siteUserEmail,
    displayName: args.siteUserName,
    apply: args.apply,
  });

  const usersSnap = await db.collection('users').where('siteIds', 'array-contains', args.siteId).get();
  const users = new Map();
  const roleBuckets = {
    learner: new Set(),
    parent: new Set(),
    educator: new Set(),
    site: new Set(),
    partner: new Set(),
    hq: new Set(),
  };

  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const role = normalizeRole(data.role);
    users.set(doc.id, { id: doc.id, ...data, role });
    if (role && roleBuckets[role]) {
      roleBuckets[role].add(doc.id);
    }
  }

  const learnerIds = new Set(roleBuckets.learner);

  const summary = {
    siteId: args.siteId,
    apply: args.apply,
    strict: args.strict,
    credentialPath: path.relative(process.cwd(), serviceAccount.path),
    projectId: serviceAccount.json.project_id,
    siteIdentity,
    educatorDocsRewritten: 0,
    educatorSelfLinksRemoved: 0,
    educatorAliasBackfilled: 0,
    invalidEducatorLinksDeleted: 0,
    invalidEnrollmentsDeleted: 0,
    sessionsRewritten: 0,
    siteDocUpdated: false,
    roleCounts: {
      learner: roleBuckets.learner.size,
      parent: roleBuckets.parent.size,
      educator: roleBuckets.educator.size,
      site: roleBuckets.site.size,
      partner: roleBuckets.partner.size,
      hq: roleBuckets.hq.size,
    },
    findings: [],
  };

  if (!roleBuckets.site.has(args.siteUserId)) {
    roleBuckets.site.add(args.siteUserId);
    users.set(args.siteUserId, {
      id: args.siteUserId,
      role: 'site',
      siteIds: [args.siteId],
    });
  }

  let batch = db.batch();
  let pendingWrites = 0;
  async function flushBatch() {
    if (pendingWrites === 0) return;
    if (args.apply) {
      await batch.commit();
    }
    batch = db.batch();
    pendingWrites = 0;
  }
  function queueSet(ref, data, options = { merge: true }) {
    batch.set(ref, data, options);
    pendingWrites += 1;
  }
  function queueDelete(ref) {
    batch.delete(ref);
    pendingWrites += 1;
  }

  for (const educatorId of roleBuckets.educator) {
    const user = users.get(educatorId) || {};
    const rawLearnerIds = toStringArray(user.learnerIds);
    const rawStudentIds = toStringArray(user.studentIds);
    const filteredLearnerIds = rawLearnerIds.filter((id) => learnerIds.has(id));
    const filteredStudentIds = Array.from(new Set([...rawStudentIds.filter((id) => learnerIds.has(id)), ...filteredLearnerIds]));

    const removedSelf = rawLearnerIds.includes(educatorId) || rawStudentIds.includes(educatorId);
    const changed =
      removedSelf ||
      filteredLearnerIds.length !== rawLearnerIds.length ||
      filteredStudentIds.length !== rawStudentIds.length ||
      filteredLearnerIds.some((id, idx) => id !== rawLearnerIds[idx]) ||
      filteredStudentIds.some((id, idx) => id !== rawStudentIds[idx]);

    if (!changed) continue;

    summary.educatorDocsRewritten += 1;
    if (removedSelf) summary.educatorSelfLinksRemoved += 1;
    if (filteredStudentIds.length > rawStudentIds.length || rawStudentIds.length === 0) {
      summary.educatorAliasBackfilled += 1;
    }

    queueSet(
      db.collection('users').doc(educatorId),
      {
        learnerIds: filteredLearnerIds,
        studentIds: filteredStudentIds,
        updatedAt: nowTs(),
      },
      { merge: true },
    );
    if (pendingWrites >= 350) await flushBatch();
  }

  const educatorLinksSnap = await db.collection('educatorLearnerLinks').where('siteId', '==', args.siteId).get();
  for (const doc of educatorLinksSnap.docs) {
    const data = doc.data() || {};
    const educatorId = typeof data.educatorId === 'string' ? data.educatorId.trim() : '';
    const learnerId = typeof data.learnerId === 'string' ? data.learnerId.trim() : '';
    const educatorRole = normalizeRole(users.get(educatorId)?.role);
    const learnerRole = normalizeRole(users.get(learnerId)?.role);
    const invalid = educatorRole !== 'educator' || learnerRole !== 'learner';
    if (!invalid) continue;
    summary.invalidEducatorLinksDeleted += 1;
    summary.findings.push(`invalid_educator_link_deleted:${doc.id}`);
    queueDelete(doc.ref);
    if (pendingWrites >= 350) await flushBatch();
  }

  const enrollmentsSnap = await db.collection('enrollments').where('siteId', '==', args.siteId).get();
  for (const doc of enrollmentsSnap.docs) {
    const data = doc.data() || {};
    const learnerId = typeof data.learnerId === 'string' ? data.learnerId.trim() : '';
    const learnerRole = normalizeRole(users.get(learnerId)?.role);
    if (learnerRole === 'learner') continue;
    summary.invalidEnrollmentsDeleted += 1;
    summary.findings.push(`invalid_enrollment_deleted:${doc.id}`);
    queueDelete(doc.ref);
    if (pendingWrites >= 350) await flushBatch();
  }

  const sessionsSnap = await db.collection('sessions').where('siteId', '==', args.siteId).get();
  for (const doc of sessionsSnap.docs) {
    const data = doc.data() || {};
    const rawLearnerIds = toStringArray(data.learnerIds);
    const filteredLearnerIds = rawLearnerIds.filter((id) => learnerIds.has(id));
    const changed = rawLearnerIds.length !== filteredLearnerIds.length;
    if (!changed) continue;
    summary.sessionsRewritten += 1;
    queueSet(
      doc.ref,
      {
        learnerIds: filteredLearnerIds,
        updatedAt: nowTs(),
      },
      { merge: true },
    );
    if (pendingWrites >= 350) await flushBatch();
  }

  const siteDocRef = db.collection('sites').doc(args.siteId);
  const siteArrays = {
    learnerIds: Array.from(roleBuckets.learner).sort(),
    parentIds: Array.from(roleBuckets.parent).sort(),
    educatorIds: Array.from(roleBuckets.educator).sort(),
    siteLeadIds: Array.from(roleBuckets.site).sort(),
    partnerIds: Array.from(roleBuckets.partner).sort(),
    hqIds: Array.from(roleBuckets.hq).sort(),
  };
  summary.siteDocUpdated = true;
  queueSet(
    siteDocRef,
    {
      id: args.siteId,
      ...siteArrays,
      updatedAt: nowTs(),
      createdAt: nowTs(),
    },
    { merge: true },
  );

  await flushBatch();

  if (args.strict && !args.apply) {
    summary.findings.push('strict_mode_warning:dry_run_only');
  }

  process.stdout.write(
    JSON.stringify(
      {
        status: 'PASS',
        summary,
      },
      null,
      2,
    ) + '\n',
  );
}

run().catch((error) => {
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
