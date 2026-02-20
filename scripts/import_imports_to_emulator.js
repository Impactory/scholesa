/*
 * Import the CSV demo dataset into Firestore + Auth (production by default).
 * Usage (production):
 *   GOOGLE_APPLICATION_CREDENTIALS=./path/to/service-account.json \
 *   node scripts/import_imports_to_emulator.js
 *
 * This script no longer forces emulator hosts. If you truly want emulators, set
 * FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST yourself before running.
 */

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'studio-3328096157-e3f79';
const IMPORT_DIR = path.join(__dirname, '..', 'apps', 'empire_flutter', 'imports');
const DEFAULT_PASSWORD = process.env.SEED_TEST_PASSWORD || 'Test123!';

if (admin.apps.length === 0) {
  const options = process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? { credential: admin.credential.applicationDefault(), projectId: PROJECT_ID }
    : { projectId: PROJECT_ID };
  admin.initializeApp(options);
}

const db = admin.firestore();
const auth = admin.auth();
const now = Date.now();

function parseCsv(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8').replace(/\r\n?/g, '\n');
  const lines = raw.split('\n').filter((line) => line.trim() !== '');
  if (lines.length === 0) return [];
  const headers = splitCsvLine(lines[0]);
  return lines.slice(1).map((line) => {
    const cols = splitCsvLine(line);
    const entry = {};
    headers.forEach((key, idx) => {
      entry[key] = cols[idx] ?? '';
    });
    return entry;
  });
}

function splitCsvLine(line) {
  const cols = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char === ',' && !inQuotes) {
      cols.push(current);
      current = '';
      continue;
    }
    current += char;
  }
  cols.push(current);
  return cols.map((c) => c.trim());
}

function toMillis(dateStr) {
  if (!dateStr) return null;
  const dt = new Date(`${dateStr}T00:00:00Z`);
  return Number.isNaN(dt.getTime()) ? null : dt.getTime();
}

function derivePillars(tags) {
  const tagList = (tags || '')
    .split(',')
    .map((t) => t.trim().toLowerCase())
    .filter(Boolean);
  const pillars = new Set();
  for (const tag of tagList) {
    if (['ai', 'science', 'data', 'technology', 'tech'].some((k) => tag.includes(k))) {
      pillars.add('tech');
    }
    if (['leadership', 'communication', 'collaboration', 'agency'].some((k) => tag.includes(k))) {
      pillars.add('lead');
    }
    if (['ethics', 'impact', 'community', 'entrepreneurship', 'city'].some((k) => tag.includes(k))) {
      pillars.add('impact');
    }
  }
  return pillars.size ? Array.from(pillars) : ['tech'];
}

async function upsertAuthUser({ uid, email, displayName, role }) {
  const claims = { role, roles: [role] };
  try {
    await auth.updateUser(uid, {
      email,
      displayName,
      password: DEFAULT_PASSWORD,
      emailVerified: true,
      disabled: false,
    });
    await auth.setCustomUserClaims(uid, claims);
    return 'updated';
  } catch (err) {
    if (err?.errorInfo?.code !== 'auth/user-not-found') {
      throw err;
    }
  }
  await auth.createUser({
    uid,
    email,
    displayName,
    password: DEFAULT_PASSWORD,
    emailVerified: true,
    disabled: false,
  });
  await auth.setCustomUserClaims(uid, claims);
  return 'created';
}

async function main() {
  const writer = db.bulkWriter();

  const sites = parseCsv(path.join(IMPORT_DIR, '01_sites.csv'));
  const roles = parseCsv(path.join(IMPORT_DIR, '02_roles.csv'));
  const users = parseCsv(path.join(IMPORT_DIR, '03_users.csv'));
  const courses = parseCsv(path.join(IMPORT_DIR, '04_courses.csv'));
  const sections = parseCsv(path.join(IMPORT_DIR, '05_sections.csv'));
  const enrollments = parseCsv(path.join(IMPORT_DIR, '06_enrollments.csv'));
  const parentLinks = parseCsv(path.join(IMPORT_DIR, '07_parent_links.csv'));
  const courseSessions = parseCsv(path.join(IMPORT_DIR, '08_sessions.csv'));
  const missions = parseCsv(path.join(IMPORT_DIR, '09_missions.csv'));
  const missionPlans = parseCsv(path.join(IMPORT_DIR, '10_mission_plans.csv'));
  const checkpoints = parseCsv(path.join(IMPORT_DIR, '11_checkpoints.csv'));
  const rubrics = parseCsv(path.join(IMPORT_DIR, '12_rubrics.csv'));
  const rubricCriteria = parseCsv(path.join(IMPORT_DIR, '13_rubric_criteria.csv'));
  const policies = parseCsv(path.join(IMPORT_DIR, '14_policies.csv'));
  const aiSettings = parseCsv(path.join(IMPORT_DIR, '15_ai_settings.csv'));
  const portfolioTemplates = parseCsv(path.join(IMPORT_DIR, '16_portfolio_templates.csv'));

  const roleMap = Object.fromEntries(roles.map((r) => [r.role_id, r.role_name]));
  const siteIds = sites.map((s) => s.site_id);
  const primarySiteId = siteIds[0] || 'SITE-UNKNOWN';

  for (const site of sites) {
    writer.set(db.collection('sites').doc(site.site_id), {
      name: site.site_name,
      timezone: site.timezone,
      country: site.country,
      term: {
        id: site.term_id,
        name: site.term_name,
        startDate: toMillis(site.term_start_date),
        endDate: toMillis(site.term_end_date),
      },
      createdAt: now,
    });
  }

  const sectionById = new Map();
  for (const section of sections) {
    const pillars = derivePillars(courses.find((c) => c.course_id === section.course_id)?.subject_tags);
    const startDate = toMillis(section.start_date);
    const endDate = toMillis(section.end_date);
    const sessionDoc = {
      id: section.section_id,
      title: section.section_name,
      description: courses.find((c) => c.course_id === section.course_id)?.course_name,
      siteId: section.site_id,
      educatorIds: [section.teacher_user_id],
      pillarCodes: pillars,
      startDate,
      endDate,
      termId: section.term_id,
      courseId: section.course_id,
      status: section.status,
    };
    sectionById.set(section.section_id, sessionDoc);
    writer.set(db.collection('sessions').doc(section.section_id), sessionDoc);
  }

  const courseById = new Map();
  for (const course of courses) {
    const pillars = derivePillars(course.subject_tags);
    const doc = {
      name: course.course_name,
      gradeBand: course.grade_band,
      subjectTags: course.subject_tags.split(',').map((t) => t.trim()).filter(Boolean),
      unitSessions: Number(course.unit_sessions) || 0,
      status: course.status,
      siteId: course.site_id,
      pillarCodes: pillars,
    };
    courseById.set(course.course_id, doc);
    writer.set(db.collection('courses').doc(course.course_id), doc);
  }

  const parentIdsByLearner = new Map();
  const childIdsByParent = new Map();
  for (const link of parentLinks) {
    if (!parentIdsByLearner.has(link.student_user_id)) parentIdsByLearner.set(link.student_user_id, []);
    parentIdsByLearner.get(link.student_user_id).push(link.parent_user_id);
    if (!childIdsByParent.has(link.parent_user_id)) childIdsByParent.set(link.parent_user_id, []);
    childIdsByParent.get(link.parent_user_id).push(link.student_user_id);
    writer.set(db.collection('parentLinks').doc(link.parent_link_id), {
      parentUserId: link.parent_user_id,
      studentUserId: link.student_user_id,
      relationship: link.relationship,
      visibility: link.visibility,
      createdAt: now,
    });
  }

  const educatorSessions = new Map();
  const educatorSiteIds = new Map();
  const educatorCourseIds = new Map();
  for (const section of sectionById.values()) {
    for (const eduId of section.educatorIds || []) {
      if (!educatorSessions.has(eduId)) educatorSessions.set(eduId, new Set());
      educatorSessions.get(eduId).add(section.id);
      if (!educatorSiteIds.has(eduId)) educatorSiteIds.set(eduId, new Set());
      if (section.siteId) educatorSiteIds.get(eduId).add(section.siteId);
      if (!educatorCourseIds.has(eduId)) educatorCourseIds.set(eduId, new Set());
      if (section.courseId) educatorCourseIds.get(eduId).add(section.courseId);
    }
  }

  const learnerSessions = new Map();
  const learnerSiteIds = new Map();
  const learnerCourseIds = new Map();
  const educatorLearners = new Map();
  for (const enr of enrollments) {
    if (!learnerSessions.has(enr.user_id)) learnerSessions.set(enr.user_id, new Set());
    learnerSessions.get(enr.user_id).add(enr.section_id);
    const session = sectionById.get(enr.section_id);
    if (session?.siteId) {
      if (!learnerSiteIds.has(enr.user_id)) learnerSiteIds.set(enr.user_id, new Set());
      learnerSiteIds.get(enr.user_id).add(session.siteId);
    }
    if (session?.courseId) {
      if (!learnerCourseIds.has(enr.user_id)) learnerCourseIds.set(enr.user_id, new Set());
      learnerCourseIds.get(enr.user_id).add(session.courseId);
    }
    (session?.educatorIds || []).forEach((eduId) => {
      if (!educatorLearners.has(eduId)) educatorLearners.set(eduId, new Set());
      educatorLearners.get(eduId).add(enr.user_id);
    });
  }

  const parentSessionIds = new Map();
  const parentSiteIds = new Map();
  const parentCourseIds = new Map();
  const missionIdsByCourseId = new Map();
  for (const mission of missions) {
    const courseId = courseSessions.find((s) => s.session_id === mission.session_id)?.course_id;
    if (!courseId) continue;
    if (!missionIdsByCourseId.has(courseId)) missionIdsByCourseId.set(courseId, new Set());
    missionIdsByCourseId.get(courseId).add(mission.mission_id);
  }
  const parentMissionIds = new Map();
  const educatorMissionIds = new Map();
  for (const [educatorId, courseIds] of educatorCourseIds.entries()) {
    const missionIds = new Set();
    for (const courseId of courseIds) {
      (missionIdsByCourseId.get(courseId) || []).forEach((missionId) => missionIds.add(missionId));
    }
    educatorMissionIds.set(educatorId, missionIds);
  }

  for (const [parentId, childIds] of childIdsByParent.entries()) {
    const sessions = new Set();
    const sites = new Set();
    const courses = new Set();
    const missionIds = new Set();
    for (const childId of childIds) {
      (learnerSessions.get(childId) || []).forEach((sid) => sessions.add(sid));
      (learnerSiteIds.get(childId) || []).forEach((site) => sites.add(site));
      (learnerCourseIds.get(childId) || []).forEach((courseId) => {
        courses.add(courseId);
        (missionIdsByCourseId.get(courseId) || []).forEach((missionId) => missionIds.add(missionId));
      });
    }
    parentSessionIds.set(parentId, sessions);
    parentSiteIds.set(parentId, sites);
    parentCourseIds.set(parentId, courses);
    parentMissionIds.set(parentId, missionIds);
  }

  for (const user of users) {
    const roleName = roleMap[user.role_id] || 'Unknown';
    const role = (() => {
      if (roleName.toLowerCase().includes('admin')) return 'hq';
      if (roleName.toLowerCase().includes('teacher')) return 'educator';
      if (roleName.toLowerCase().includes('student')) return 'learner';
      if (roleName.toLowerCase().includes('parent')) return 'parent';
      return 'hq';
    })();
    const parentIds = parentIdsByLearner.get(user.user_id) || [];
    const defaultSiteIds = siteIds.length ? siteIds : [primarySiteId];
    const roleSiteIds = (() => {
      if (role === 'learner') return Array.from(learnerSiteIds.get(user.user_id) || []);
      if (role === 'parent') return Array.from(parentSiteIds.get(user.user_id) || []);
      if (role === 'educator') return Array.from(educatorSiteIds.get(user.user_id) || []);
      return defaultSiteIds;
    })();
    const userDoc = {
      uid: user.user_id,
      email: user.email,
      displayName: `${user.first_name} ${user.last_name}`.trim() || user.email,
      role,
      siteIds: roleSiteIds.length ? roleSiteIds : defaultSiteIds,
      createdAt: now,
      updatedAt: now,
      status: user.status,
    };
    if (role === 'learner') {
      userDoc.parentIds = parentIds.length ? parentIds : [];
      userDoc.enrolledSessionIds = Array.from(learnerSessions.get(user.user_id) || []);
    }
    if (role === 'parent') {
      userDoc.childIds = Array.from(childIdsByParent.get(user.user_id) || []);
      userDoc.childSessionIds = Array.from(parentSessionIds.get(user.user_id) || []);
      userDoc.childSiteIds = Array.from(parentSiteIds.get(user.user_id) || []);
      userDoc.childCourseIds = Array.from(parentCourseIds.get(user.user_id) || []);
      userDoc.childMissionIds = Array.from(parentMissionIds.get(user.user_id) || []);
    }
    if (role === 'educator') {
      userDoc.taughtSessionIds = Array.from(educatorSessions.get(user.user_id) || []);
      userDoc.learnerIds = Array.from(educatorLearners.get(user.user_id) || []);
      userDoc.taughtSiteIds = Array.from(educatorSiteIds.get(user.user_id) || []);
      userDoc.courseIds = Array.from(educatorCourseIds.get(user.user_id) || []);
      userDoc.missionIds = Array.from(educatorMissionIds.get(user.user_id) || []);
    }
    writer.set(db.collection('users').doc(user.user_id), userDoc);
    await upsertAuthUser({
      uid: user.user_id,
      email: user.email,
      displayName: `${user.first_name} ${user.last_name}`.trim(),
      role,
    });
  }

  for (const enr of enrollments) {
    const session = sectionById.get(enr.section_id);
    writer.set(db.collection('enrollments').doc(enr.enrollment_id), {
      id: enr.enrollment_id,
      sessionId: enr.section_id,
      learnerId: enr.user_id,
      siteId: session?.siteId || primarySiteId,
      enrolledAt: now,
      status: enr.status,
      role: enr.role_in_section,
    });
  }

  for (const session of courseSessions) {
    writer.set(db.collection('courseSessions').doc(session.session_id), {
      id: session.session_id,
      courseId: session.course_id,
      number: Number(session.session_number) || 0,
      title: session.session_title,
      overview: session.overview,
      estimatedMinutes: Number(session.estimated_minutes) || null,
      status: session.status,
    });
  }

  for (const mission of missions) {
    const courseId = courseSessions.find((s) => s.session_id === mission.session_id)?.course_id;
    const siteId = courseId ? courseById.get(courseId)?.siteId : primarySiteId;
    const pillarCodes = courseId ? courseById.get(courseId)?.pillarCodes || ['tech'] : ['tech'];
    writer.set(db.collection('missions').doc(mission.mission_id), {
      id: mission.mission_id,
      sessionId: mission.session_id,
      missionNumber: Number(mission.mission_number) || 0,
      title: mission.mission_title,
      description: mission.mission_description,
      type: mission.mission_type,
      estimatedMinutes: Number(mission.estimated_minutes) || null,
      requiresSubmission: mission.requires_submission === 'yes',
      submissionType: mission.submission_type || null,
      aiAllowed: mission.ai_allowed === 'yes',
      status: mission.status,
      siteId,
      pillarCodes,
    });
  }

  for (const plan of missionPlans) {
    writer.set(db.collection('missionPlans').doc(plan.mission_plan_id), {
      id: plan.mission_plan_id,
      missionId: plan.mission_id,
      tier: plan.tier,
      udlSupports: (plan.udl_supports || '').split(';').filter(Boolean),
      successCriteria: plan.success_criteria,
    });
  }

  for (const cp of checkpoints) {
    writer.set(db.collection('checkpoints').doc(cp.checkpoint_id), {
      id: cp.checkpoint_id,
      missionId: cp.mission_id,
      checkpointType: cp.checkpoint_type,
      required: cp.required === 'yes',
      visibility: cp.visibility,
    });
  }

  for (const rubric of rubrics) {
    writer.set(db.collection('rubrics').doc(rubric.rubric_id), {
      id: rubric.rubric_id,
      courseId: rubric.course_id,
      title: rubric.rubric_title,
      scaleMin: Number(rubric.scale_min) || 0,
      scaleMax: Number(rubric.scale_max) || 0,
      status: rubric.status,
    });
  }

  for (const criterion of rubricCriteria) {
    writer.set(db.collection('rubricCriteria').doc(criterion.criterion_id), {
      id: criterion.criterion_id,
      rubricId: criterion.rubric_id,
      name: criterion.criterion_name,
      description: criterion.criterion_description,
      weight: Number(criterion.weight) || 0,
    });
  }

  for (const policy of policies) {
    let parsed = null;
    try {
      parsed = JSON.parse(policy.value_json);
    } catch {
      parsed = { raw: policy.value_json };
    }
    writer.set(db.collection('policies').doc(policy.policy_id), {
      id: policy.policy_id,
      siteId: policy.site_id,
      name: policy.policy_name,
      value: parsed,
    });
  }

  for (const ai of aiSettings) {
    writer.set(db.collection('aiSettings').doc(ai.ai_setting_id), {
      id: ai.ai_setting_id,
      siteId: ai.site_id,
      gradeBand: ai.grade_band,
      mode: ai.mode,
      allowedTools: (ai.allowed_tools || '').split(',').map((t) => t.trim()).filter(Boolean),
      logPrompts: ai.log_prompts?.toLowerCase() === 'yes',
    });
  }

  for (const tpl of portfolioTemplates) {
    writer.set(db.collection('portfolioTemplates').doc(tpl.template_id), {
      id: tpl.template_id,
      courseId: tpl.course_id,
      title: tpl.title,
      artifactTypes: (tpl.artifact_types || '').split(',').map((t) => t.trim()).filter(Boolean),
    });
  }

  await writer.close();
  console.log('Import complete. Users created:', users.length);
  console.log('Collections written: sites, roles, users, courses, sessions, enrollments, parentLinks, courseSessions, missions, missionPlans, checkpoints, rubrics, rubricCriteria, policies, aiSettings, portfolioTemplates.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
