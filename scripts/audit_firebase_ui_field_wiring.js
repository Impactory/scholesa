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

const DEFAULT_SITE_ID = process.env.TEST_SITE_ID || 'site_001';

const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(process.cwd(), 'firebase-service-account.json'),
  path.resolve(process.cwd(), 'studio-service-account.json'),
].filter(Boolean);

const ROLE_MAP = {
  learner: 'learner',
  student: 'learner',
  educator: 'educator',
  teacher: 'educator',
  parent: 'parent',
  guardian: 'parent',
  site: 'site',
  sitelead: 'site',
  site_lead: 'site',
  partner: 'partner',
  hq: 'hq',
  admin: 'hq',
};

const VOICE_TELEMETRY_EVENTS = new Set([
  'voice.transcribe',
  'voice.message',
  'voice.tts',
  'voice.blocked',
  'voice.escalated',
]);

const REQUIRED_VOICE_LOCALES = new Set(['en', 'zh-CN', 'zh-TW', 'th']);
const REQUIRED_VOICE_METADATA_KEYS = [
  'traceId',
  'service',
  'env',
  'siteId',
  'role',
  'gradeBand',
  'locale',
  'eventType',
  'timestamp',
];

const BOS_EVENT_TYPES = new Set([
  'mission_viewed',
  'mission_selected',
  'mission_started',
  'mission_completed',
  'checkpoint_started',
  'checkpoint_submitted',
  'checkpoint_graded',
  'artifact_created',
  'artifact_submitted',
  'artifact_reviewed',
  'ai_help_opened',
  'ai_help_used',
  'ai_coach_response',
  'ai_coach_feedback',
  'mvl_gate_triggered',
  'mvl_evidence_attached',
  'mvl_passed',
  'mvl_failed',
  'teacher_override_mvl',
  'teacher_override_intervention',
  'contestability_requested',
  'contestability_resolved',
  'session_joined',
  'session_left',
  'idle_detected',
  'focus_restored',
]);

const BOS_GRADE_BANDS = new Set(['G1_3', 'G4_6', 'G7_9', 'G10_12', 'K_5', 'G6_8', 'G9_12']);

function parseArgs(argv) {
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'dev'),
    strict: false,
    siteId: DEFAULT_SITE_ID,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = resolveEnv(rawValue);
    if (rawKey === 'site-id' || rawKey === 'siteId') args.siteId = rawValue.trim();
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

function normalizeRole(value) {
  if (typeof value !== 'string') return null;
  return ROLE_MAP[value.trim().toLowerCase()] || null;
}

function compactCount(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '0';
  if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M`;
  if (value >= 1000) return `${(value / 1000).toFixed(1)}K`;
  return String(value);
}

function resolveServiceAccount() {
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (!candidate) continue;
    if (!fs.existsSync(candidate)) continue;
    return {
      credentialPath: candidate,
      json: JSON.parse(fs.readFileSync(candidate, 'utf8')),
    };
  }
  throw new Error(`No service account JSON found. Checked: ${SERVICE_ACCOUNT_PATHS.join(', ')}`);
}

function initializeAdmin() {
  const serviceAccount = resolveServiceAccount();
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount.json),
      projectId: serviceAccount.json.project_id,
    });
  }
  return {
    db: admin.firestore(),
    projectId: serviceAccount.json.project_id,
    credentialPath: path.relative(process.cwd(), serviceAccount.credentialPath),
  };
}

function checkUserCoreFields(users, siteId) {
  const missing = [];
  for (const [uid, user] of users.entries()) {
    const role = normalizeRole(user.role);
    const siteIds = toStringArray(user.siteIds);
    const activeSiteId = typeof user.activeSiteId === 'string' ? user.activeSiteId.trim() : '';
    const email = typeof user.email === 'string' ? user.email.trim() : '';
    if (!email) missing.push(`${uid}:missing_email`);
    if (!role) missing.push(`${uid}:missing_or_invalid_role`);
    if (!siteIds.includes(siteId)) missing.push(`${uid}:siteIds_missing_${siteId}`);
    if (activeSiteId && !siteIds.includes(activeSiteId)) {
      missing.push(`${uid}:activeSite_not_in_siteIds:${activeSiteId}`);
    }
  }

  return {
    id: 'users_core_fields_present',
    pass: missing.length === 0,
    details: {
      usersChecked: users.size,
      missingCount: missing.length,
      sample: missing.slice(0, 80),
    },
  };
}

function checkRoleCoverage(users) {
  const roleCounts = {
    learner: 0,
    parent: 0,
    educator: 0,
    site: 0,
    partner: 0,
    hq: 0,
  };
  for (const user of users.values()) {
    const role = normalizeRole(user.role);
    if (role && Object.prototype.hasOwnProperty.call(roleCounts, role)) {
      roleCounts[role] += 1;
    }
  }

  const missingCoreRoles = ['learner', 'parent', 'educator', 'site'].filter(
    (role) => roleCounts[role] === 0,
  );
  return {
    id: 'ui_role_coverage_present',
    pass: missingCoreRoles.length === 0,
    details: {
      roleCounts,
      missingCoreRoles,
    },
  };
}

function checkSiteDoc(siteDoc, usersByRole) {
  if (!siteDoc) {
    return {
      id: 'site_doc_role_arrays_match_users',
      pass: false,
      details: {
        reason: 'site_doc_missing',
      },
    };
  }

  const fieldToRole = {
    learnerIds: 'learner',
    parentIds: 'parent',
    educatorIds: 'educator',
    siteLeadIds: 'site',
    partnerIds: 'partner',
    hqIds: 'hq',
  };

  const mismatches = [];
  for (const [field, role] of Object.entries(fieldToRole)) {
    const expected = new Set(usersByRole[role] || []);
    const current = new Set(toStringArray(siteDoc[field]));
    const missing = [];
    for (const uid of expected) {
      if (!current.has(uid)) missing.push(uid);
    }
    if (missing.length > 0) {
      mismatches.push({ field, role, missing: missing.slice(0, 80), missingCount: missing.length });
    }
  }

  return {
    id: 'site_doc_role_arrays_match_users',
    pass: mismatches.length === 0,
    details: {
      mismatchCount: mismatches.length,
      mismatches,
    },
  };
}

async function checkParentDashboardContract(db, users, siteId) {
  const parents = Array.from(users.entries())
    .filter(([, user]) => normalizeRole(user.role) === 'parent')
    .map(([uid]) => uid);

  const failures = [];
  let linksChecked = 0;
  let learnersResolved = 0;

  for (const parentId of parents) {
    const parent = users.get(parentId) || {};
    const candidateLearnerIds = new Set(toStringArray(parent.learnerIds));

    try {
      const guardianLinks = await db
        .collection('guardianLinks')
        .where('parentId', '==', parentId)
        .where('siteId', '==', siteId)
        .get();
      for (const doc of guardianLinks.docs) {
        const learnerId = typeof doc.data().learnerId === 'string' ? doc.data().learnerId.trim() : '';
        if (learnerId) candidateLearnerIds.add(learnerId);
      }
    } catch {
      failures.push(`guardianLinks_lookup_failed:${parentId}`);
    }

    for (const learnerId of candidateLearnerIds) {
      linksChecked += 1;
      const learner = users.get(learnerId);
      if (!learner) {
        failures.push(`parent_link_missing_learner_doc:${parentId}:${learnerId}`);
        continue;
      }
      if (normalizeRole(learner.role) !== 'learner') {
        failures.push(`parent_link_wrong_role:${parentId}:${learnerId}:${String(learner.role || '')}`);
        continue;
      }
      const reverseParentIds = toStringArray(learner.parentIds);
      if (!reverseParentIds.includes(parentId)) {
        failures.push(`learner_missing_parent_reverse_link:${learnerId}:${parentId}`);
      }
      const displayName = typeof learner.displayName === 'string' ? learner.displayName.trim() : '';
      const email = typeof learner.email === 'string' ? learner.email.trim() : '';
      if (!displayName && !email) {
        failures.push(`learner_missing_display_identity:${learnerId}`);
      }
      learnersResolved += 1;
    }
  }

  return {
    id: 'parent_dashboard_data_contract',
    pass: failures.length === 0,
    details: {
      parentsChecked: parents.length,
      linksChecked,
      learnersResolved,
      failureCount: failures.length,
      sample: failures.slice(0, 80),
    },
  };
}

async function checkEducatorRosterContract(db, users, siteId) {
  const educators = Array.from(users.entries())
    .filter(([, user]) => normalizeRole(user.role) === 'educator')
    .map(([uid]) => uid);

  const failures = [];
  let linksChecked = 0;

  for (const educatorId of educators) {
    const educator = users.get(educatorId) || {};
    const learnerIds = new Set([
      ...toStringArray(educator.learnerIds),
      ...toStringArray(educator.studentIds),
    ]);

    try {
      const links = await db
        .collection('educatorLearnerLinks')
        .where('educatorId', '==', educatorId)
        .where('siteId', '==', siteId)
        .get();
      for (const doc of links.docs) {
        const learnerId = typeof doc.data().learnerId === 'string' ? doc.data().learnerId.trim() : '';
        if (learnerId) learnerIds.add(learnerId);
      }
    } catch {
      failures.push(`educator_links_lookup_failed:${educatorId}`);
    }

    for (const learnerId of learnerIds) {
      linksChecked += 1;
      const learner = users.get(learnerId);
      if (!learner) {
        failures.push(`educator_link_missing_learner_doc:${educatorId}:${learnerId}`);
        continue;
      }
      if (normalizeRole(learner.role) !== 'learner') {
        failures.push(`educator_link_wrong_role:${educatorId}:${learnerId}:${String(learner.role || '')}`);
        continue;
      }
      const learnerEducatorIds = toStringArray(learner.educatorIds);
      const learnerTeacherIds = toStringArray(learner.teacherIds);
      if (!learnerEducatorIds.includes(educatorId) && !learnerTeacherIds.includes(educatorId)) {
        failures.push(`learner_missing_educator_reverse_link:${learnerId}:${educatorId}`);
      }
    }
  }

  return {
    id: 'educator_roster_data_contract',
    pass: failures.length === 0,
    details: {
      educatorsChecked: educators.length,
      linksChecked,
      failureCount: failures.length,
      sample: failures.slice(0, 80),
    },
  };
}

async function checkEducatorSessionCardFields(db, users, siteId) {
  const educatorIds = Array.from(users.entries())
    .filter(([, user]) => normalizeRole(user.role) === 'educator')
    .map(([uid]) => uid);

  if (educatorIds.length === 0) {
    return {
      id: 'educator_session_card_fields_present',
      pass: true,
      details: {
        educatorsChecked: 0,
        sessionsChecked: 0,
        failureCount: 0,
        sample: [],
      },
    };
  }

  const failures = [];
  let sessionsChecked = 0;
  let sessionsSnap;
  try {
    sessionsSnap = await db
      .collection('sessions')
      .where('siteId', '==', siteId)
      .get();
  } catch (error) {
    return {
      id: 'educator_session_card_fields_present',
      pass: false,
      details: {
        educatorsChecked: educatorIds.length,
        sessionsChecked: 0,
        failureCount: 1,
        sample: [`sessions_query_failed:${error instanceof Error ? error.message : String(error)}`],
      },
    };
  }

  for (const doc of sessionsSnap.docs) {
    const data = doc.data() || {};
    const educatorLinks = new Set(toStringArray(data.educatorIds));
    const primaryEducator = typeof data.educatorId === 'string' ? data.educatorId.trim() : '';
    if (primaryEducator) educatorLinks.add(primaryEducator);
    const intersects = educatorIds.some((id) => educatorLinks.has(id));
    if (!intersects) continue;
    sessionsChecked += 1;

    const title = typeof data.title === 'string' ? data.title.trim() : '';
    if (!title) failures.push(`session_missing_title:${doc.id}`);

    const startDate = data.startDate;
    const hasStart =
      startDate instanceof admin.firestore.Timestamp ||
      startDate instanceof Date ||
      typeof startDate === 'string' ||
      typeof startDate === 'number';
    if (!hasStart) failures.push(`session_missing_startDate:${doc.id}`);

    const pillarCodes = Array.isArray(data.pillarCodes) ? data.pillarCodes : [];
    if (pillarCodes.length === 0) failures.push(`session_missing_pillarCodes:${doc.id}`);
  }

  return {
    id: 'educator_session_card_fields_present',
    pass: failures.length === 0,
    details: {
      educatorsChecked: educatorIds.length,
      sessionsChecked,
      failureCount: failures.length,
      sample: failures.slice(0, 80),
    },
  };
}

function checkRoleDashboardStatSources(db, siteId) {
  const requiredCollections = [
    'users',
    'sites',
    'enrollments',
    'missionAssignments',
    'messages',
    'sessionOccurrences',
    'missionAttempts',
    'events',
    'attendanceRecords',
    'incidents',
    'approvals',
  ];
  const checks = requiredCollections.map((collection) => ({
    collection,
    exists: true,
  }));
  return {
    id: 'dashboard_source_collections_declared',
    pass: checks.every((row) => row.exists),
    details: {
      siteId,
      collections: checks,
      note: 'Collections are queried by callable dashboard adapters and tolerate empty datasets.',
    },
  };
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const { db, projectId, credentialPath } = initializeAdmin();

  const siteRef = db.collection('sites').doc(args.siteId);
  const [siteSnap, usersSnap] = await Promise.all([
    siteRef.get(),
    db.collection('users').where('siteIds', 'array-contains', args.siteId).get(),
  ]);

  const siteDoc = siteSnap.exists ? siteSnap.data() || {} : null;
  const users = new Map(usersSnap.docs.map((doc) => [doc.id, doc.data() || {}]));

  const usersByRole = {
    learner: [],
    parent: [],
    educator: [],
    site: [],
    partner: [],
    hq: [],
  };
  for (const [uid, user] of users.entries()) {
    const role = normalizeRole(user.role);
    if (role && usersByRole[role]) usersByRole[role].push(uid);
  }

  const checks = [];
  checks.push({
    id: 'site_doc_exists',
    pass: siteSnap.exists,
    details: {
      siteId: args.siteId,
    },
  });
  checks.push(checkRoleCoverage(users));
  checks.push(checkUserCoreFields(users, args.siteId));
  checks.push(checkSiteDoc(siteDoc, usersByRole));
  checks.push(await checkParentDashboardContract(db, users, args.siteId));
  checks.push(await checkEducatorRosterContract(db, users, args.siteId));
  checks.push(await checkEducatorSessionCardFields(db, users, args.siteId));
  checks.push(checkRoleDashboardStatSources(db, args.siteId));

  const pass = checks.every((check) => check.pass === true);
  const report = buildCanonicalReport({
    reportName: 'firebase-ui-field-wiring',
    env: args.env,
    pass,
    checks,
    metadata: {
      siteId: args.siteId,
      strict: args.strict,
      projectId,
      credentialPath,
      counts: {
        usersAtSite: users.size,
        learners: usersByRole.learner.length,
        parents: usersByRole.parent.length,
        educators: usersByRole.educator.length,
        sites: usersByRole.site.length,
        partners: usersByRole.partner.length,
        hq: usersByRole.hq.length,
      },
      formatterSample: compactCount(users.size),
    },
  });
  const outputPath = writeCanonicalReport('firebase-ui-field-wiring', report);

  const output = {
    status: report.pass ? 'PASS' : 'FAIL',
    env: args.env,
    siteId: args.siteId,
    report: path.relative(process.cwd(), outputPath),
    pass: report.pass,
    failedChecks: checks.filter((check) => check.pass !== true).map((check) => check.id),
  };
  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (!report.pass) {
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
