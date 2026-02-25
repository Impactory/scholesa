#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const {
  buildCanonicalReport,
  resolveEnv,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const CORE_ROLES = ['learner', 'parent', 'educator', 'site'];
const ROLE_SITE_ARRAY_FIELD = {
  learner: 'learnerIds',
  parent: 'parentIds',
  educator: 'educatorIds',
  site: 'siteLeadIds',
};
const DEFAULT_SITE_IDS = [
  '6h9gugxtiSwFIPsHTvJM',
  'Rr6jCLp4BqYwEq7TE1n3',
  'gQgNvqfLgf6wOMANubX1',
  'lXvd5x50mDXbjlM5Av9Z',
  'pilot-site-001',
  'rSYp3MS0wU1IQPtPC59V',
];

function parseArgs(argv) {
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'prod'),
    strict: false,
    apply: false,
    siteIds: [...DEFAULT_SITE_IDS],
    project: process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (arg === '--apply') {
      args.apply = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = resolveEnv(rawValue);
    if (rawKey === 'site-ids' || rawKey === 'siteIds') {
      args.siteIds = rawValue
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
    }
    if (rawKey === 'project') args.project = rawValue.trim();
    if (rawKey === 'credentials') args.credentials = rawValue.trim();
  }

  args.siteIds = Array.from(new Set(args.siteIds));
  return args;
}

function resolveCredentialPath(explicitPath) {
  const candidates = [
    explicitPath,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.resolve(process.cwd(), 'firebase-service-account.json'),
    path.resolve(process.cwd(), 'studio-service-account.json'),
  ]
    .filter((candidate) => typeof candidate === 'string' && candidate.trim().length > 0)
    .map((candidate) => path.resolve(process.cwd(), candidate));

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function resolveProjectId(argsProjectId, credentialPath) {
  if (typeof argsProjectId === 'string' && argsProjectId.trim().length > 0) {
    return argsProjectId.trim();
  }
  if (!credentialPath || !fs.existsSync(credentialPath)) {
    return undefined;
  }
  try {
    const payload = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
    if (typeof payload.project_id === 'string' && payload.project_id.trim().length > 0) {
      return payload.project_id.trim();
    }
  } catch {
    return undefined;
  }
  return undefined;
}

function initializeAdmin(args) {
  const credentialPath = resolveCredentialPath(args.credentials);
  const projectId = resolveProjectId(args.project, credentialPath);

  if (!admin.apps.length) {
    if (credentialPath) {
      const serviceAccount = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: projectId || serviceAccount.project_id,
      });
    } else {
      admin.initializeApp({ projectId });
    }
  }

  return {
    db: admin.firestore(),
    projectId: projectId || admin.app().options.projectId || null,
    credentialPath: credentialPath ? path.relative(process.cwd(), credentialPath) : null,
  };
}

function normalizeRole(rawRole) {
  if (typeof rawRole !== 'string') return null;
  const normalized = rawRole.trim().toLowerCase();
  if (normalized === 'learner' || normalized === 'student') return 'learner';
  if (normalized === 'parent' || normalized === 'guardian') return 'parent';
  if (normalized === 'educator' || normalized === 'teacher') return 'educator';
  if (normalized === 'site' || normalized === 'sitelead' || normalized === 'site_lead') return 'site';
  if (normalized === 'partner') return 'partner';
  if (normalized === 'hq' || normalized === 'admin') return 'hq';
  return null;
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

function cleanSiteSegment(siteId) {
  return String(siteId || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
}

function buildSeedUserDoc(siteId, role) {
  const siteSegment = cleanSiteSegment(siteId);
  const email = `seed.${siteSegment}.${role}@scholesa.local`;
  const userDoc = {
    email,
    displayName: `Seed ${role} ${siteId}`,
    role,
    siteIds: [siteId],
    activeSiteId: siteId,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (role === 'learner') {
    userDoc.parentIds = [];
    userDoc.educatorIds = [];
    userDoc.teacherIds = [];
    userDoc.gradeBand = 'k5';
  } else if (role === 'parent') {
    userDoc.learnerIds = [];
  } else if (role === 'educator') {
    userDoc.learnerIds = [];
    userDoc.studentIds = [];
  }

  return userDoc;
}

async function loadUsersBySite(db, siteId) {
  const snapshot = await db.collection('users').where('siteIds', 'array-contains', siteId).get();
  const users = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    users.push({
      id: doc.id,
      role: normalizeRole(data.role),
      rawRole: data.role,
      data,
    });
  }
  return users;
}

function countRoles(users) {
  const roleCounts = {
    learner: 0,
    parent: 0,
    educator: 0,
    site: 0,
    partner: 0,
    hq: 0,
  };
  for (const user of users) {
    if (user.role && Object.prototype.hasOwnProperty.call(roleCounts, user.role)) {
      roleCounts[user.role] += 1;
    }
  }
  return roleCounts;
}

async function ensureSeedUser(db, siteId, role) {
  const userId = `seed_${cleanSiteSegment(siteId)}_${role}_001`;
  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  const payload = buildSeedUserDoc(siteId, role);

  if (!userSnap.exists) {
    await userRef.set(payload, { merge: true });
    return { userId, created: true };
  }

  const current = userSnap.data() || {};
  const currentSiteIds = toStringArray(current.siteIds);
  const patch = {
    role,
    email: typeof current.email === 'string' && current.email.trim() ? current.email : payload.email,
    displayName:
      typeof current.displayName === 'string' && current.displayName.trim()
        ? current.displayName
        : payload.displayName,
    activeSiteId: siteId,
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (!currentSiteIds.includes(siteId)) {
    patch.siteIds = admin.firestore.FieldValue.arrayUnion(siteId);
  }

  await userRef.set(patch, { merge: true });
  return { userId, created: false };
}

async function ensureSiteArrays(db, siteId, roleToUserIds) {
  const siteRef = db.collection('sites').doc(siteId);
  const patch = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  for (const role of CORE_ROLES) {
    const field = ROLE_SITE_ARRAY_FIELD[role];
    const ids = Array.from(new Set(roleToUserIds[role] || []));
    if (ids.length > 0) {
      patch[field] = admin.firestore.FieldValue.arrayUnion(...ids);
    }
  }

  await siteRef.set(patch, { merge: true });
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const { db, projectId, credentialPath } = initializeAdmin(args);
  const checks = [];

  for (const siteId of args.siteIds) {
    const siteRef = db.collection('sites').doc(siteId);
    const siteSnap = await siteRef.get();
    if (!siteSnap.exists) {
      checks.push({
        id: `seed_core_roles_${siteId}`,
        pass: false,
        details: {
          siteId,
          reason: 'site_not_found',
        },
      });
      continue;
    }

    const beforeUsers = await loadUsersBySite(db, siteId);
    const beforeRoleCounts = countRoles(beforeUsers);
    const missingBefore = CORE_ROLES.filter((role) => beforeRoleCounts[role] === 0);
    const seeded = [];

    if (args.apply) {
      for (const role of missingBefore) {
        const result = await ensureSeedUser(db, siteId, role);
        seeded.push({
          role,
          userId: result.userId,
          created: result.created,
        });
      }

      const afterSeedUsers = await loadUsersBySite(db, siteId);
      const roleToUserIds = {
        learner: afterSeedUsers.filter((user) => user.role === 'learner').map((user) => user.id),
        parent: afterSeedUsers.filter((user) => user.role === 'parent').map((user) => user.id),
        educator: afterSeedUsers.filter((user) => user.role === 'educator').map((user) => user.id),
        site: afterSeedUsers.filter((user) => user.role === 'site').map((user) => user.id),
      };
      await ensureSiteArrays(db, siteId, roleToUserIds);
    }

    const afterUsers = await loadUsersBySite(db, siteId);
    const afterRoleCounts = countRoles(afterUsers);
    const missingAfter = CORE_ROLES.filter((role) => afterRoleCounts[role] === 0);

    checks.push({
      id: `seed_core_roles_${siteId}`,
      pass: missingAfter.length === 0,
      details: {
        siteId,
        applied: args.apply,
        beforeRoleCounts,
        afterRoleCounts,
        missingBefore,
        missingAfter,
        seeded,
      },
    });
  }

  const pass = checks.every((check) => check.pass === true);
  const report = buildCanonicalReport({
    reportName: 'seed-core-roles-sites',
    env: args.env,
    pass,
    checks,
    metadata: {
      siteIds: args.siteIds,
      apply: args.apply,
      projectId,
      credentialPath,
    },
  });

  const outputPath = writeCanonicalReport('seed-core-roles-sites', report);
  const output = {
    status: pass ? 'PASS' : 'FAIL',
    env: args.env,
    apply: args.apply,
    report: path.relative(process.cwd(), outputPath),
    failedSites: checks.filter((check) => check.pass !== true).map((check) => check.details?.siteId),
  };
  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if ((!pass || !args.apply) && args.strict) {
    process.exitCode = 1;
  }
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
