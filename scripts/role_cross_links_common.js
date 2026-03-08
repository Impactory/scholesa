#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const {
  buildCanonicalReport,
  resolveEnv,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');
const {
  initializeFirebaseAdmin,
} = require('./firebase_runtime_auth');

const ROLE_FIELD_MAP = {
  learner: 'learnerIds',
  parent: 'parentIds',
  educator: 'educatorIds',
  site: 'siteLeadIds',
  partner: 'partnerIds',
  hq: 'hqIds',
};

const DEFAULT_SITE_ID = process.env.TEST_SITE_ID || 'site_001';

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

function includesId(value, target) {
  return toStringArray(value).includes(target);
}

function parseArgs(argv, options = {}) {
  const allowApply = options.allowApply === true;
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'dev'),
    strict: false,
    apply: false,
    siteId: process.env.TEST_SITE_ID || DEFAULT_SITE_ID,
    project:
      process.env.FIREBASE_PROJECT_ID ||
      process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (allowApply && arg === '--apply') {
      args.apply = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = resolveEnv(rawValue);
    if (rawKey === 'site-id' || rawKey === 'siteId') args.siteId = rawValue.trim();
    if (rawKey === 'project') args.project = rawValue.trim();
    if (rawKey === 'credentials') args.credentials = rawValue.trim();
  }

  if (!allowApply) {
    args.apply = false;
  }

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
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

function resolveProjectId(argsProjectId, credentialPath) {
  if (typeof argsProjectId === 'string' && argsProjectId.trim().length > 0) {
    return argsProjectId.trim();
  }
  if (credentialPath && fs.existsSync(credentialPath)) {
    try {
      const payload = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
      if (typeof payload.project_id === 'string' && payload.project_id.trim().length > 0) {
        return payload.project_id.trim();
      }
      if (typeof payload.client_email === 'string') {
        const match = payload.client_email.match(/@([a-z0-9-]+)\.iam\.gserviceaccount\.com$/i);
        if (match && match[1]) {
          return match[1];
        }
      }
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function initializeAdmin(args) {
  const credentialPath = resolveCredentialPath(args.credentials);
  const projectId = resolveProjectId(args.project, credentialPath);
  const runtime = initializeFirebaseAdmin(admin, {
    credentialPath: credentialPath || undefined,
    projectId,
    extraCredentialPaths: [
      path.resolve(process.cwd(), 'firebase-service-account.json'),
      path.resolve(process.cwd(), 'studio-service-account.json'),
    ],
  });

  return {
    db: admin.firestore(),
    credentialPath: runtime.credentialPath,
    projectId: runtime.projectId,
  };
}

function parsePairKey(pairKey) {
  const [left, right] = pairKey.split('|');
  return { left, right };
}

function addPair(pairSet, leftId, rightId) {
  if (!leftId || !rightId) return;
  pairSet.add(`${leftId}|${rightId}`);
}

async function queryBySite(collectionRef, siteId) {
  try {
    return await collectionRef.where('siteId', '==', siteId).get();
  } catch {
    return {
      docs: [],
      size: 0,
    };
  }
}

async function loadCrossLinkState(db, siteId) {
  const usersSnap = await db.collection('users').where('siteIds', 'array-contains', siteId).get();
  const siteDocSnap = await db.collection('sites').doc(siteId).get();

  const [guardianLinksSnap, educatorLinksSnap, sessionsSnap, enrollmentsSnap, missionAssignmentsSnap, missionsSnap] =
    await Promise.all([
      queryBySite(db.collection('guardianLinks'), siteId),
      queryBySite(db.collection('educatorLearnerLinks'), siteId),
      queryBySite(db.collection('sessions'), siteId),
      queryBySite(db.collection('enrollments'), siteId),
      queryBySite(db.collection('missionAssignments'), siteId),
      queryBySite(db.collection('missions'), siteId),
    ]);

  const users = new Map();
  const roleBuckets = {
    learner: [],
    parent: [],
    educator: [],
    site: [],
    partner: [],
    hq: [],
    unknown: [],
  };

  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const role = normalizeRole(data.role);
    users.set(doc.id, { id: doc.id, ...data, role });
    if (role) {
      roleBuckets[role].push(doc.id);
    } else {
      roleBuckets.unknown.push(doc.id);
    }
  }

  const sessions = new Map();
  for (const doc of sessionsSnap.docs) {
    sessions.set(doc.id, { id: doc.id, ...doc.data() });
  }

  const missions = new Map();
  for (const doc of missionsSnap.docs) {
    missions.set(doc.id, { id: doc.id, ...doc.data() });
  }

  return {
    siteId,
    siteDoc: siteDocSnap.exists ? siteDocSnap.data() || {} : null,
    users,
    roleBuckets,
    guardianLinks: guardianLinksSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    educatorLinks: educatorLinksSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    sessions,
    enrollments: enrollmentsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    missionAssignments: missionAssignmentsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    missions,
  };
}

function analyzeCrossLinks(state) {
  const { siteId, siteDoc, users, roleBuckets, guardianLinks, educatorLinks, sessions, enrollments, missionAssignments, missions } =
    state;

  const checks = [];
  const findings = [];
  const arrayUnionFixMap = new Map();
  const setFixMap = new Map();

  function addArrayUnionFix(collection, docId, field, values) {
    const cleanValues = toStringArray(values);
    if (cleanValues.length === 0) return;
    const key = `${collection}/${docId}/${field}`;
    const valueSet = arrayUnionFixMap.get(key) || new Set();
    for (const value of cleanValues) {
      valueSet.add(value);
    }
    arrayUnionFixMap.set(key, valueSet);
  }

  function addSetFix(collection, docId, data, merge = true) {
    const key = `${collection}/${docId}`;
    const existing = setFixMap.get(key);
    if (!existing) {
      setFixMap.set(key, { collection, docId, merge, data: { ...data } });
      return;
    }
    setFixMap.set(key, {
      collection,
      docId,
      merge: merge || existing.merge,
      data: {
        ...existing.data,
        ...data,
      },
    });
  }

  const siteExists = Boolean(siteDoc);
  checks.push({
    id: 'site_doc_exists',
    pass: siteExists,
    details: { siteId },
  });
  if (!siteExists) {
    findings.push(`missing_site_doc:${siteId}`);
  }

  const coreRoles = ['learner', 'parent', 'educator', 'site'];
  const missingCoreRoles = coreRoles.filter((role) => roleBuckets[role].length === 0);
  checks.push({
    id: 'core_roles_present',
    pass: missingCoreRoles.length === 0,
    details: {
      roleCounts: {
        learner: roleBuckets.learner.length,
        parent: roleBuckets.parent.length,
        educator: roleBuckets.educator.length,
        site: roleBuckets.site.length,
        partner: roleBuckets.partner.length,
        hq: roleBuckets.hq.length,
      },
      missingCoreRoles,
    },
  });
  for (const role of missingCoreRoles) {
    findings.push(`missing_core_role:${role}`);
  }

  const usersMissingSiteLink = [];
  for (const [userId, userData] of users.entries()) {
    if (!includesId(userData.siteIds, siteId)) {
      usersMissingSiteLink.push(userId);
      addArrayUnionFix('users', userId, 'siteIds', [siteId]);
    }
  }
  checks.push({
    id: 'user_site_links_complete',
    pass: usersMissingSiteLink.length === 0,
    details: { missingUserSiteLinks: usersMissingSiteLink },
  });
  for (const userId of usersMissingSiteLink) {
    findings.push(`user_missing_site_link:${userId}`);
  }

  const siteArrayMismatches = [];
  if (siteDoc) {
    for (const [role, field] of Object.entries(ROLE_FIELD_MAP)) {
      const expected = toStringArray(roleBuckets[role]);
      const current = toStringArray(siteDoc[field]);
      const missing = expected.filter((id) => !current.includes(id));
      if (missing.length > 0) {
        siteArrayMismatches.push({ role, field, missing });
        addArrayUnionFix('sites', siteId, field, missing);
      }
    }
  }
  checks.push({
    id: 'site_role_arrays_complete',
    pass: siteExists && siteArrayMismatches.length === 0,
    details: { mismatches: siteArrayMismatches },
  });
  for (const mismatch of siteArrayMismatches) {
    for (const missingId of mismatch.missing) {
      findings.push(`site_missing_${mismatch.field}:${missingId}`);
    }
  }

  const parentLearnerPairSet = new Set();
  const guardianLinkPairSet = new Set();
  for (const link of guardianLinks) {
    const parentId = typeof link.parentId === 'string' ? link.parentId.trim() : '';
    const learnerId = typeof link.learnerId === 'string' ? link.learnerId.trim() : '';
    if (!parentId || !learnerId) continue;
    addPair(parentLearnerPairSet, parentId, learnerId);
    addPair(guardianLinkPairSet, parentId, learnerId);
  }
  for (const parentId of roleBuckets.parent) {
    const parentUser = users.get(parentId) || {};
    for (const learnerId of toStringArray(parentUser.learnerIds)) {
      addPair(parentLearnerPairSet, parentId, learnerId);
    }
  }
  for (const learnerId of roleBuckets.learner) {
    const learnerUser = users.get(learnerId) || {};
    for (const parentId of toStringArray(learnerUser.parentIds)) {
      addPair(parentLearnerPairSet, parentId, learnerId);
    }
  }

  const invalidParentLearnerPairs = [];
  for (const pairKey of parentLearnerPairSet) {
    const { left: parentId, right: learnerId } = parsePairKey(pairKey);
    const parent = users.get(parentId);
    const learner = users.get(learnerId);
    if (!parent || parent.role !== 'parent') {
      invalidParentLearnerPairs.push({ parentId, learnerId, reason: 'parent_missing_or_wrong_role' });
      findings.push(`invalid_parent_learner_pair:${parentId}:${learnerId}`);
      continue;
    }
    if (!learner || learner.role !== 'learner') {
      invalidParentLearnerPairs.push({ parentId, learnerId, reason: 'learner_missing_or_wrong_role' });
      findings.push(`invalid_parent_learner_pair:${parentId}:${learnerId}`);
      continue;
    }
    if (!includesId(parent.learnerIds, learnerId)) {
      addArrayUnionFix('users', parentId, 'learnerIds', [learnerId]);
      findings.push(`parent_missing_learner_link:${parentId}:${learnerId}`);
    }
    if (!includesId(learner.parentIds, parentId)) {
      addArrayUnionFix('users', learnerId, 'parentIds', [parentId]);
      findings.push(`learner_missing_parent_link:${learnerId}:${parentId}`);
    }
    if (!guardianLinkPairSet.has(pairKey)) {
      const guardianDocId = `${siteId}_${parentId}_${learnerId}`;
      addSetFix('guardianLinks', guardianDocId, {
        siteId,
        parentId,
        learnerId,
        relationship: 'Parent',
        isPrimary: true,
      });
      findings.push(`missing_guardian_link_doc:${guardianDocId}`);
    }
  }
  checks.push({
    id: 'parent_learner_links_bidirectional',
    pass: invalidParentLearnerPairs.length === 0,
    details: {
      pairCount: parentLearnerPairSet.size,
      invalidPairs: invalidParentLearnerPairs,
    },
  });

  const educatorLearnerPairSet = new Set();
  const educatorLinkPairSet = new Set();
  for (const link of educatorLinks) {
    const educatorId = typeof link.educatorId === 'string' ? link.educatorId.trim() : '';
    const learnerId = typeof link.learnerId === 'string' ? link.learnerId.trim() : '';
    if (!educatorId || !learnerId) continue;
    addPair(educatorLearnerPairSet, educatorId, learnerId);
    addPair(educatorLinkPairSet, educatorId, learnerId);
  }
  for (const educatorId of roleBuckets.educator) {
    const educator = users.get(educatorId) || {};
    const linkedLearners = [
      ...toStringArray(educator.learnerIds),
      ...toStringArray(educator.studentIds),
    ];
    for (const learnerId of linkedLearners) {
      addPair(educatorLearnerPairSet, educatorId, learnerId);
    }
  }
  for (const learnerId of roleBuckets.learner) {
    const learner = users.get(learnerId) || {};
    const linkedEducators = [
      ...toStringArray(learner.educatorIds),
      ...toStringArray(learner.teacherIds),
    ];
    for (const educatorId of linkedEducators) {
      addPair(educatorLearnerPairSet, educatorId, learnerId);
    }
  }

  const invalidEducatorLearnerPairs = [];
  for (const pairKey of educatorLearnerPairSet) {
    const { left: educatorId, right: learnerId } = parsePairKey(pairKey);
    const educator = users.get(educatorId);
    const learner = users.get(learnerId);

    if (!educator || educator.role !== 'educator') {
      invalidEducatorLearnerPairs.push({ educatorId, learnerId, reason: 'educator_missing_or_wrong_role' });
      findings.push(`invalid_educator_learner_pair:${educatorId}:${learnerId}`);
      continue;
    }
    if (!learner || learner.role !== 'learner') {
      invalidEducatorLearnerPairs.push({ educatorId, learnerId, reason: 'learner_missing_or_wrong_role' });
      findings.push(`invalid_educator_learner_pair:${educatorId}:${learnerId}`);
      continue;
    }

    if (!includesId(educator.learnerIds, learnerId)) {
      addArrayUnionFix('users', educatorId, 'learnerIds', [learnerId]);
      findings.push(`educator_missing_learner_link:${educatorId}:${learnerId}`);
    }
    if (!includesId(educator.studentIds, learnerId)) {
      addArrayUnionFix('users', educatorId, 'studentIds', [learnerId]);
      findings.push(`educator_missing_student_alias:${educatorId}:${learnerId}`);
    }
    if (!includesId(learner.educatorIds, educatorId)) {
      addArrayUnionFix('users', learnerId, 'educatorIds', [educatorId]);
      findings.push(`learner_missing_educator_link:${learnerId}:${educatorId}`);
    }
    if (!includesId(learner.teacherIds, educatorId)) {
      addArrayUnionFix('users', learnerId, 'teacherIds', [educatorId]);
      findings.push(`learner_missing_teacher_alias:${learnerId}:${educatorId}`);
    }
    if (!educatorLinkPairSet.has(pairKey)) {
      const linkDocId = `${siteId}_${educatorId}_${learnerId}`;
      addSetFix('educatorLearnerLinks', linkDocId, {
        id: linkDocId,
        siteId,
        educatorId,
        learnerId,
        status: 'active',
      });
      findings.push(`missing_educator_learner_link_doc:${linkDocId}`);
    }
  }
  checks.push({
    id: 'educator_learner_links_bidirectional',
    pass: invalidEducatorLearnerPairs.length === 0,
    details: {
      pairCount: educatorLearnerPairSet.size,
      invalidPairs: invalidEducatorLearnerPairs,
    },
  });

  const sessionEnrollmentErrors = [];
  for (const enrollment of enrollments) {
    const sessionId = typeof enrollment.sessionId === 'string' ? enrollment.sessionId.trim() : '';
    const learnerId = typeof enrollment.learnerId === 'string' ? enrollment.learnerId.trim() : '';
    const educatorId = typeof enrollment.educatorId === 'string' ? enrollment.educatorId.trim() : '';

    const session = sessionId ? sessions.get(sessionId) : null;
    const learner = learnerId ? users.get(learnerId) : null;
    const educator = educatorId ? users.get(educatorId) : null;

    if (!session) {
      sessionEnrollmentErrors.push({ enrollmentId: enrollment.id, reason: 'missing_session', sessionId });
      findings.push(`enrollment_missing_session:${enrollment.id}`);
      continue;
    }
    if (!learner || learner.role !== 'learner') {
      sessionEnrollmentErrors.push({ enrollmentId: enrollment.id, reason: 'missing_learner', learnerId });
      findings.push(`enrollment_missing_learner:${enrollment.id}`);
      continue;
    }
    if (educatorId && (!educator || educator.role !== 'educator')) {
      sessionEnrollmentErrors.push({ enrollmentId: enrollment.id, reason: 'missing_educator', educatorId });
      findings.push(`enrollment_missing_educator:${enrollment.id}`);
    }

    if (!includesId(session.learnerIds, learnerId)) {
      addArrayUnionFix('sessions', session.id, 'learnerIds', [learnerId]);
      findings.push(`session_missing_learner_link:${session.id}:${learnerId}`);
    }
    if (educatorId && !includesId(session.educatorIds, educatorId)) {
      addArrayUnionFix('sessions', session.id, 'educatorIds', [educatorId]);
      findings.push(`session_missing_educator_link:${session.id}:${educatorId}`);
    }
    if (educatorId && !session.educatorId) {
      addSetFix('sessions', session.id, { educatorId });
      findings.push(`session_missing_primary_educator:${session.id}`);
    }
    if (!includesId(learner.enrolledSessionIds, session.id)) {
      addArrayUnionFix('users', learner.id, 'enrolledSessionIds', [session.id]);
      findings.push(`learner_missing_enrolled_session:${learner.id}:${session.id}`);
    }
  }
  checks.push({
    id: 'session_enrollment_links_consistent',
    pass: sessionEnrollmentErrors.length === 0,
    details: {
      enrollmentCount: enrollments.length,
      errors: sessionEnrollmentErrors,
    },
  });

  const missionErrors = [];
  for (const assignment of missionAssignments) {
    const missionId = typeof assignment.missionId === 'string' ? assignment.missionId.trim() : '';
    const learnerId = typeof assignment.learnerId === 'string' ? assignment.learnerId.trim() : '';
    const educatorId = typeof assignment.educatorId === 'string' ? assignment.educatorId.trim() : '';
    const mission = missionId ? missions.get(missionId) : null;
    if (!mission) {
      missionErrors.push({ assignmentId: assignment.id, reason: 'missing_mission', missionId });
      findings.push(`assignment_missing_mission:${assignment.id}`);
      continue;
    }
    if (learnerId && !includesId(mission.learnerIds, learnerId)) {
      addArrayUnionFix('missions', mission.id, 'learnerIds', [learnerId]);
      findings.push(`mission_missing_learner_link:${mission.id}:${learnerId}`);
    }
    if (educatorId && !includesId(mission.educatorIds, educatorId)) {
      addArrayUnionFix('missions', mission.id, 'educatorIds', [educatorId]);
      findings.push(`mission_missing_educator_link:${mission.id}:${educatorId}`);
    }
    if (educatorId && !mission.educatorId) {
      addSetFix('missions', mission.id, { educatorId });
      findings.push(`mission_missing_primary_educator:${mission.id}`);
    }
    if (educatorId && !includesId(assignment.educatorIds, educatorId)) {
      addArrayUnionFix('missionAssignments', assignment.id, 'educatorIds', [educatorId]);
      findings.push(`assignment_missing_educator_alias:${assignment.id}:${educatorId}`);
    }
  }
  checks.push({
    id: 'mission_assignment_links_consistent',
    pass: missionErrors.length === 0,
    details: {
      assignmentCount: missionAssignments.length,
      errors: missionErrors,
    },
  });

  const arrayUnionFixes = Array.from(arrayUnionFixMap.entries())
    .map(([key, valueSet]) => {
      const [collection, docId, field] = key.split('/');
      return {
        type: 'arrayUnion',
        collection,
        docId,
        field,
        values: Array.from(valueSet).sort(),
      };
    })
    .sort((a, b) =>
      `${a.collection}/${a.docId}/${a.field}`.localeCompare(`${b.collection}/${b.docId}/${b.field}`),
    );

  const setFixes = Array.from(setFixMap.values())
    .map((fix) => ({
      type: 'set',
      collection: fix.collection,
      docId: fix.docId,
      merge: fix.merge !== false,
      data: fix.data,
    }))
    .sort((a, b) => `${a.collection}/${a.docId}`.localeCompare(`${b.collection}/${b.docId}`));

  const proposedFixes = [...arrayUnionFixes, ...setFixes];
  const pass = checks.every((check) => check.pass === true) && findings.length === 0;

  return {
    pass,
    checks,
    findings: Array.from(new Set(findings)).sort(),
    proposedFixes,
    metrics: {
      usersAtSite: users.size,
      learnerCount: roleBuckets.learner.length,
      parentCount: roleBuckets.parent.length,
      educatorCount: roleBuckets.educator.length,
      siteCount: roleBuckets.site.length,
      partnerCount: roleBuckets.partner.length,
      hqCount: roleBuckets.hq.length,
      guardianLinkCount: guardianLinks.length,
      educatorLinkCount: educatorLinks.length,
      enrollmentCount: enrollments.length,
      missionAssignmentCount: missionAssignments.length,
      proposedFixCount: proposedFixes.length,
    },
  };
}

async function applyProposedFixes(db, proposedFixes) {
  if (!Array.isArray(proposedFixes) || proposedFixes.length === 0) {
    return { writes: 0 };
  }

  let batch = db.batch();
  let writes = 0;
  let pendingWrites = 0;

  async function commitBatch() {
    if (pendingWrites === 0) return;
    await batch.commit();
    writes += pendingWrites;
    pendingWrites = 0;
    batch = db.batch();
  }

  for (const fix of proposedFixes) {
    const ref = db.collection(fix.collection).doc(fix.docId);
    if (fix.type === 'arrayUnion') {
      if (!Array.isArray(fix.values) || fix.values.length === 0) continue;
      batch.set(
        ref,
        {
          [fix.field]: admin.firestore.FieldValue.arrayUnion(...fix.values),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      pendingWrites += 1;
    } else if (fix.type === 'set') {
      const payload = {
        ...(fix.data || {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (fix.collection === 'guardianLinks' || fix.collection === 'educatorLearnerLinks') {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      batch.set(
        ref,
        payload,
        { merge: fix.merge !== false },
      );
      pendingWrites += 1;
    }

    if (pendingWrites >= 400) {
      await commitBatch();
    }
  }

  await commitBatch();
  return { writes };
}

function buildRoleCrossLinksReport(args, analysis, metadata = {}) {
  return buildCanonicalReport({
    reportName: 'role-cross-links',
    env: args.env,
    pass: analysis.pass,
    checks: [
      ...analysis.checks,
      {
        id: 'no_unresolved_findings',
        pass: analysis.findings.length === 0,
        details: {
          findingCount: analysis.findings.length,
          findings: analysis.findings.slice(0, 200),
        },
      },
    ],
    metadata: {
      siteId: args.siteId,
      apply: args.apply === true,
      metrics: analysis.metrics,
      proposedFixes: analysis.proposedFixes,
      ...metadata,
    },
  });
}

function writeRoleCrossLinksReport(report) {
  return writeCanonicalReport('role-cross-links', report);
}

module.exports = {
  DEFAULT_SITE_ID,
  analyzeCrossLinks,
  applyProposedFixes,
  buildRoleCrossLinksReport,
  initializeAdmin,
  loadCrossLinkState,
  parseArgs,
  writeRoleCrossLinksReport,
};
