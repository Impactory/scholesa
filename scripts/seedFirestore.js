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
    { code: 'tech', name: 'Think, Make & Navigate AI', color: '#2563eb' },
    { code: 'lead', name: 'Communicate & Lead', color: '#16a34a' },
    { code: 'impact', name: 'Build for the World', color: '#eab308' },
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

  // =========================================================================
  // EVIDENCE CHAIN SEED DATA
  // =========================================================================
  console.log('Seeding evidence chain data...');

  // --- Capabilities ---
  const capabilities = [
    {
      id: 'cap-computational-thinking',
      title: 'Computational Thinking',
      normalizedTitle: 'computational thinking',
      pillarCode: 'FUTURE_SKILLS',
      descriptor: 'Ability to decompose problems, identify patterns, and design algorithmic solutions.',
      progressionLevels: [
        { level: 1, label: 'Emerging', description: 'Can follow step-by-step instructions to solve a structured problem.' },
        { level: 2, label: 'Developing', description: 'Can decompose a problem into smaller parts with guidance.' },
        { level: 3, label: 'Proficient', description: 'Independently decomposes problems, identifies patterns, and designs solutions.' },
        { level: 4, label: 'Advanced', description: 'Creates elegant abstractions and evaluates algorithmic trade-offs.' },
      ],
      siteId: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'cap-creative-problem-solving',
      title: 'Creative Problem Solving',
      normalizedTitle: 'creative problem solving',
      pillarCode: 'FUTURE_SKILLS',
      descriptor: 'Generating novel approaches to open-ended challenges.',
      progressionLevels: [
        { level: 1, label: 'Emerging', description: 'Tries one approach when stuck.' },
        { level: 2, label: 'Developing', description: 'Generates multiple approaches with prompting.' },
        { level: 3, label: 'Proficient', description: 'Independently generates and evaluates multiple approaches.' },
        { level: 4, label: 'Advanced', description: 'Combines ideas from different domains to create original solutions.' },
      ],
      siteId: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'cap-team-leadership',
      title: 'Team Leadership',
      normalizedTitle: 'team leadership',
      pillarCode: 'LEADERSHIP_AGENCY',
      descriptor: 'Guiding a team toward shared goals while supporting individual growth.',
      progressionLevels: [
        { level: 1, label: 'Emerging', description: 'Participates in team tasks when directed.' },
        { level: 2, label: 'Developing', description: 'Takes initiative on specific tasks within a team.' },
        { level: 3, label: 'Proficient', description: 'Coordinates team efforts and supports peers effectively.' },
        { level: 4, label: 'Advanced', description: 'Inspires and empowers team members while managing conflict constructively.' },
      ],
      siteId: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'cap-community-impact',
      title: 'Community Impact',
      normalizedTitle: 'community impact',
      pillarCode: 'IMPACT_INNOVATION',
      descriptor: 'Creating projects that address real needs in the community.',
      progressionLevels: [
        { level: 1, label: 'Emerging', description: 'Identifies a community need with guidance.' },
        { level: 2, label: 'Developing', description: 'Proposes a solution to a community need.' },
        { level: 3, label: 'Proficient', description: 'Designs and implements a project addressing a real community need.' },
        { level: 4, label: 'Advanced', description: 'Leads a sustained initiative with measurable community outcomes.' },
      ],
      siteId: null,
      createdAt: now,
      updatedAt: now,
    },
  ];

  await Promise.all(
    capabilities.map((cap) => db.collection('capabilities').doc(cap.id).set(cap)),
  );
  console.log(`  Seeded ${capabilities.length} capabilities`);

  // --- Assessment Rubrics ---
  const rubrics = [
    {
      id: 'rubric-evidence-quality-k3',
      name: 'K-3 Evidence Quality Rubric',
      description: 'Evaluates evidence quality for K-3 learners across all pillars.',
      version: 1,
      status: 'active',
      siteId: '*',
      pillarId: 'FUTURE_SKILLS',
      criteria: [
        {
          name: 'Evidence Quality',
          description: 'Depth and authenticity of evidence provided.',
          weight: 0.5,
          levels: [
            { name: 'Emerging', description: 'Minimal evidence, mostly prompted responses.', score: 1 },
            { name: 'Developing', description: 'Some original work with guided evidence.', score: 2 },
            { name: 'Proficient', description: 'Clear, authentic evidence of independent work.', score: 3 },
            { name: 'Advanced', description: 'Rich, multi-source evidence showing deep engagement.', score: 4 },
          ],
        },
        {
          name: 'Capability Demonstration',
          description: 'How well the work demonstrates the target capability.',
          weight: 0.5,
          levels: [
            { name: 'Emerging', description: 'Capability not clearly demonstrated.', score: 1 },
            { name: 'Developing', description: 'Capability partially demonstrated with support.', score: 2 },
            { name: 'Proficient', description: 'Capability clearly demonstrated independently.', score: 3 },
            { name: 'Advanced', description: 'Capability demonstrated at an exceptional level with transfer to new contexts.', score: 4 },
          ],
        },
      ],
      tags: ['k3', 'evidence', 'future_skills'],
      createdBy: hqUid,
      createdAt: now,
    },
  ];

  await Promise.all(
    rubrics.map((r) => db.collection('assessmentRubrics').doc(r.id).set(r)),
  );
  console.log(`  Seeded ${rubrics.length} legacy rubrics (assessmentRubrics)`);

  // --- HQ Rubric Templates (new primary system) ---
  const rubricTemplates = [
    {
      id: 'tpl-evidence-quality-k3',
      title: 'K-3 Evidence Quality Template',
      siteId: '*',
      status: 'published',
      capabilityIds: capabilities.map((c) => c.id),
      criteria: [
        {
          id: 'criterion-0-evidence',
          label: 'Evidence Quality',
          capabilityId: 'cap-critical-thinking',
          pillarCode: 'FUTURE_SKILLS',
          maxScore: 4,
          descriptors: {
            beginning: 'Minimal evidence, mostly prompted responses.',
            developing: 'Some original work with guided evidence.',
            proficient: 'Clear, authentic evidence of independent work.',
            advanced: 'Rich, multi-source evidence showing deep engagement.',
          },
        },
        {
          id: 'criterion-1-capability',
          label: 'Capability Demonstration',
          capabilityId: 'cap-community-impact',
          pillarCode: 'IMPACT_INNOVATION',
          maxScore: 4,
          descriptors: {
            beginning: 'Capability not clearly demonstrated.',
            developing: 'Capability partially demonstrated with support.',
            proficient: 'Capability clearly demonstrated independently.',
            advanced: 'Capability demonstrated at an exceptional level with transfer to new contexts.',
          },
        },
      ],
      createdBy: hqUid,
      createdAt: now,
      updatedAt: now,
    },
  ];

  await Promise.all(
    rubricTemplates.map((t) => db.collection('rubricTemplates').doc(t.id).set(t)),
  );
  console.log(`  Seeded ${rubricTemplates.length} HQ rubric templates (rubricTemplates)`);

  // --- Mission Attempt (submitted, with evidence) ---
  const missionAttemptId = 'attempt-1';
  const missionAttempt = {
    id: missionAttemptId,
    learnerId: learnerUid,
    missionId: mission.id,
    sessionOccurrenceId: occurrence.id,
    siteId,
    status: 'reviewed',
    reviewStatus: 'approved',
    reviewedBy: educatorUid,
    reviewedAt: now,
    content: 'I built a number guessing game using loops and conditionals. The program generates a random number and gives hints.',
    attachmentUrls: [],
    aiAssistanceUsed: true,
    aiAssistanceDetails: 'Used AI coach for debugging a loop issue. I changed the approach after understanding the hint.',
    proofBundleId: 'proof-bundle-1',
    proofBundleSummary: {
      hasExplainItBack: true,
      hasOralCheck: true,
      hasMiniRebuild: false,
      checkpointCount: 2,
      hasLearnerAiDisclosure: true,
      aiAssistanceUsed: true,
    },
    rubricTotalScore: 3,
    rubricMaxScore: 4,
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('missionAttempts').doc(missionAttemptId).set(missionAttempt);
  console.log('  Seeded mission attempt');

  // --- Proof of Learning Bundle ---
  const proofBundle = {
    id: 'proof-bundle-1',
    learnerId: learnerUid,
    siteId,
    missionAttemptId,
    explainItBack: 'I used a while loop to keep asking for guesses. The condition checks if the guess matches the random number. I added a counter to track attempts.',
    oralCheckResponse: 'Student explained the difference between while and for loops and why while was better here.',
    miniRebuildPlan: null,
    versionHistory: [
      { id: 'v1', summary: 'Initial submission with basic loop', createdAt: now - 3600000 },
      { id: 'v2', summary: 'Added hint system after checkpoint feedback', createdAt: now - 1800000 },
    ],
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('proofOfLearningBundles').doc(proofBundle.id).set(proofBundle);
  console.log('  Seeded proof-of-learning bundle');

  // --- Evidence Records ---
  const evidenceRecords = [
    {
      id: 'evidence-1',
      learnerId: learnerUid,
      siteId,
      capabilityId: 'cap-computational-thinking',
      capabilityLabel: 'Computational Thinking',
      pillarCode: 'FUTURE_SKILLS',
      observedAt: now,
      observedBy: educatorUid,
      rubricStatus: 'linked',
      growthStatus: 'updated',
      linkedPortfolioItemId: 'portfolio-1',
      portfolioStatus: 'linked',
      nextVerificationPrompt: 'Can you explain why you chose a while loop instead of a for loop?',
      createdAt: now,
    },
    {
      id: 'evidence-2',
      learnerId: learnerUid,
      siteId,
      capabilityId: 'cap-creative-problem-solving',
      capabilityLabel: 'Creative Problem Solving',
      pillarCode: 'FUTURE_SKILLS',
      observedAt: now,
      observedBy: educatorUid,
      rubricStatus: 'linked',
      growthStatus: 'updated',
      linkedPortfolioItemId: 'portfolio-1',
      portfolioStatus: 'linked',
      createdAt: now,
    },
  ];

  await Promise.all(
    evidenceRecords.map((r) => db.collection('evidenceRecords').doc(r.id).set(r)),
  );
  console.log(`  Seeded ${evidenceRecords.length} evidence records`);

  // --- Capability Mastery ---
  const masteryRecords = [
    {
      id: `mastery-${learnerUid}-cap-computational-thinking`,
      learnerId: learnerUid,
      capabilityId: 'cap-computational-thinking',
      siteId,
      pillarCode: 'FUTURE_SKILLS',
      currentLevel: 'proficient',
      latestLevel: 3,
      previousLevel: 2,
      highestLevel: 3,
      latestEvidenceId: 'evidence-1',
      latestMissionAttemptId: missionAttemptId,
      evidenceIds: ['evidence-1'],
      updatedAt: now,
      createdAt: now,
    },
    {
      id: `mastery-${learnerUid}-cap-creative-problem-solving`,
      learnerId: learnerUid,
      capabilityId: 'cap-creative-problem-solving',
      siteId,
      pillarCode: 'FUTURE_SKILLS',
      currentLevel: 'developing',
      latestLevel: 2,
      previousLevel: 1,
      highestLevel: 2,
      latestEvidenceId: 'evidence-2',
      latestMissionAttemptId: missionAttemptId,
      evidenceIds: ['evidence-2'],
      updatedAt: now,
      createdAt: now,
    },
    {
      id: `mastery-${learnerUid}-cap-team-leadership`,
      learnerId: learnerUid,
      capabilityId: 'cap-team-leadership',
      siteId,
      pillarCode: 'LEADERSHIP_AGENCY',
      currentLevel: 'developing',
      latestLevel: 2,
      previousLevel: 1,
      highestLevel: 2,
      latestEvidenceId: null,
      evidenceIds: [],
      updatedAt: now,
      createdAt: now,
    },
  ];

  await Promise.all(
    masteryRecords.map((r) => db.collection('capabilityMastery').doc(r.id).set(r)),
  );
  console.log(`  Seeded ${masteryRecords.length} capability mastery records`);

  // --- Capability Growth Events ---
  const growthEvents = [
    {
      id: 'growth-1',
      learnerId: learnerUid,
      capabilityId: 'cap-computational-thinking',
      siteId,
      pillarCode: 'FUTURE_SKILLS',
      level: 2,
      rawScore: 2,
      maxScore: 4,
      evidenceId: 'evidence-1',
      missionAttemptId,
      educatorId: educatorUid,
      linkedEvidenceRecordIds: ['evidence-1'],
      linkedPortfolioItemIds: ['portfolio-1'],
      proofOfLearningStatus: 'partial',
      createdAt: now - 604800000, // 1 week ago
    },
    {
      id: 'growth-2',
      learnerId: learnerUid,
      capabilityId: 'cap-computational-thinking',
      siteId,
      pillarCode: 'FUTURE_SKILLS',
      level: 3,
      rawScore: 3,
      maxScore: 4,
      evidenceId: 'evidence-1',
      missionAttemptId,
      rubricApplicationId: 'rubric-app-1',
      educatorId: educatorUid,
      linkedEvidenceRecordIds: ['evidence-1'],
      linkedPortfolioItemIds: ['portfolio-1'],
      proofOfLearningStatus: 'verified',
      createdAt: now,
    },
    {
      id: 'growth-3',
      learnerId: learnerUid,
      capabilityId: 'cap-creative-problem-solving',
      siteId,
      pillarCode: 'FUTURE_SKILLS',
      level: 2,
      rawScore: 2,
      maxScore: 4,
      evidenceId: 'evidence-2',
      missionAttemptId,
      educatorId: educatorUid,
      linkedEvidenceRecordIds: ['evidence-2'],
      proofOfLearningStatus: 'partial',
      createdAt: now,
    },
  ];

  await Promise.all(
    growthEvents.map((e) => db.collection('capabilityGrowthEvents').doc(e.id).set(e)),
  );
  console.log(`  Seeded ${growthEvents.length} growth events`);

  // --- Rubric Application ---
  const rubricApplication = {
    id: 'rubric-app-1',
    rubricId: 'rubric-evidence-quality-k3',
    learnerId: learnerUid,
    siteId,
    missionAttemptId,
    capabilityId: 'cap-computational-thinking',
    educatorId: educatorUid,
    criterionScores: [
      { criterionName: 'Evidence Quality', score: 3, maxScore: 4 },
      { criterionName: 'Capability Demonstration', score: 3, maxScore: 4 },
    ],
    totalScore: 3,
    maxScore: 4,
    level: 3,
    feedback: 'Strong demonstration of computational thinking. The loop logic is correct and the hint system shows creative problem decomposition.',
    createdAt: now,
  };

  await db.collection('rubricApplications').doc(rubricApplication.id).set(rubricApplication);
  console.log('  Seeded rubric application');

  // --- Portfolio Items ---
  const portfolioItems = [
    {
      id: 'portfolio-1',
      learnerId: learnerUid,
      title: 'Number Guessing Game',
      description: 'A Python program that generates a random number and gives progressive hints to the player.',
      pillarCodes: ['FUTURE_SKILLS'],
      artifacts: [],
      evidenceRecordIds: ['evidence-1', 'evidence-2'],
      capabilityIds: ['cap-computational-thinking', 'cap-creative-problem-solving'],
      capabilityTitles: ['Computational Thinking', 'Creative Problem Solving'],
      growthEventIds: ['growth-2', 'growth-3'],
      missionAttemptId,
      rubricApplicationId: 'rubric-app-1',
      proofBundleId: 'proof-bundle-1',
      proofOfLearningStatus: 'verified',
      aiAssistanceUsed: true,
      aiAssistanceDetails: 'Used AI coach for debugging. Changed approach after understanding hint.',
      aiDisclosureStatus: 'learner-ai-verified',
      educatorId: educatorUid,
      verificationStatus: 'verified',
      source: 'mission',
      createdAt: now,
    },
    {
      id: 'portfolio-2',
      learnerId: learnerUid,
      title: 'Team Presentation on Climate Data',
      description: 'Led a group presentation analyzing local temperature trends using spreadsheet data.',
      pillarCodes: ['LEADERSHIP_AGENCY', 'IMPACT_INNOVATION'],
      artifacts: [],
      evidenceRecordIds: [],
      capabilityIds: ['cap-team-leadership', 'cap-community-impact'],
      capabilityTitles: ['Team Leadership', 'Community Impact'],
      growthEventIds: [],
      proofOfLearningStatus: 'partial',
      aiAssistanceUsed: false,
      aiDisclosureStatus: 'learner-ai-not-used',
      verificationStatus: 'pending',
      source: 'session',
      createdAt: now - 86400000, // 1 day ago
    },
  ];

  await Promise.all(
    portfolioItems.map((item) => db.collection('portfolioItems').doc(item.id).set(item)),
  );
  console.log(`  Seeded ${portfolioItems.length} portfolio items`);

  // --- Learner Reflections ---
  const reflections = [
    {
      id: 'reflection-1',
      learnerId: learnerUid,
      siteId,
      sprintSessionId: null,
      missionId: mission.id,
      proudOf: 'I figured out the loop logic by myself after the AI gave me a hint about while vs for.',
      nextIWill: 'Try to add difficulty levels to the game.',
      effortLevel: 4,
      enjoymentLevel: 5,
      effectiveStrategy: 'Breaking the problem into smaller steps',
      reflectionType: 'mission_reflection',
      createdAt: now,
    },
  ];

  await Promise.all(
    reflections.map((r) => db.collection('learnerReflections').doc(r.id).set(r)),
  );
  console.log(`  Seeded ${reflections.length} reflections`);

  // --- Learner Progress ---
  const learnerProgress = {
    totalXp: 150,
    missionsCompleted: 3,
    currentStreak: 5,
    pillarProgress: {
      futureSkills: 0.625,
      leadership: 0.5,
      impact: 0,
    },
    updatedAt: now,
  };

  await db.collection('learnerProgress').doc(learnerUid).set(learnerProgress);
  console.log('  Seeded learner progress');

  // --- Checkpoints (S4-4) ---
  const checkpoints = [
    {
      id: 'checkpoint-1',
      sprintSessionId: 'sprint-session-1',
      learnerId: learnerUid,
      siteId,
      checkpointNumber: 1,
      explainItBack: 'I used a while loop because I did not know how many guesses the player would need.',
      feedbackGivenBy: 'ai',
      feedback: 'Good explanation of why while is appropriate here.',
      status: 'passed',
      attemptNumber: 1,
      createdAt: now - 7200000,
    },
    {
      id: 'checkpoint-2',
      sprintSessionId: 'sprint-session-1',
      learnerId: learnerUid,
      siteId,
      checkpointNumber: 2,
      explainItBack: 'I added a counter variable that increments each time through the loop to track attempts.',
      feedbackGivenBy: 'teacher',
      feedbackGivenByUserId: educatorUid,
      feedback: 'Excellent understanding of counter pattern.',
      status: 'passed',
      attemptNumber: 1,
      createdAt: now - 3600000,
    },
  ];

  await Promise.all(
    checkpoints.map((c) => db.collection('checkpointHistory').doc(c.id).set(c)),
  );
  console.log(`  Seeded ${checkpoints.length} checkpoints`);

  // --- Skill Evidence (S4-4) ---
  const skillEvidenceItems = [
    {
      id: 'skill-evidence-1',
      learnerId: learnerUid,
      siteId,
      microSkillId: 'loops-while',
      evidenceType: 'quiz',
      description: 'Checkpoint 1: Demonstrated while loop understanding',
      selfScore: 'proficient',
      teacherScore: 'proficient',
      teacherFeedback: 'Strong understanding of loop control flow.',
      teacherFeedbackBy: educatorUid,
      teacherFeedbackAt: now,
      status: 'approved',
      submittedAt: now - 7200000,
      updatedAt: now,
    },
    {
      id: 'skill-evidence-2',
      learnerId: learnerUid,
      siteId,
      microSkillId: 'variables-counter',
      evidenceType: 'quiz',
      description: 'Checkpoint 2: Counter variable pattern',
      selfScore: 'developing',
      status: 'submitted',
      submittedAt: now - 3600000,
      updatedAt: now - 3600000,
    },
  ];

  await Promise.all(
    skillEvidenceItems.map((s) => db.collection('skillEvidence').doc(s.id).set(s)),
  );
  console.log(`  Seeded ${skillEvidenceItems.length} skill evidence records`);

  // --- AI Coach Interactions (S4-4) ---
  const aiInteractions = [
    {
      id: 'ai-interaction-1',
      learnerId: learnerUid,
      siteId,
      sessionId: 'sprint-session-1',
      mode: 'hint',
      question: 'How do I make the game keep going until they guess right?',
      response: 'Think about which loop type continues until a condition is true. What condition would stop the game?',
      explainItBackRequired: true,
      modelUsed: 'internal',
      createdAt: now - 7200000,
    },
    {
      id: 'ai-interaction-2',
      learnerId: learnerUid,
      siteId,
      sessionId: 'sprint-session-1',
      mode: 'debug',
      question: 'My counter is not going up',
      response: 'Check where your counter increment is placed. Is it inside the loop body?',
      explainItBackRequired: false,
      modelUsed: 'internal',
      createdAt: now - 5400000,
    },
  ];

  await Promise.all(
    aiInteractions.map((a) => db.collection('aiInteractionLogs').doc(a.id).set(a)),
  );
  console.log(`  Seeded ${aiInteractions.length} AI coach interactions`);

  // --- Peer Feedback (S4-4) ---
  const peerFeedback = [
    {
      id: 'peer-feedback-1',
      targetId: 'portfolio-1',
      targetType: 'portfolio',
      fromLearnerId: 'peer-learner-1',
      fromLearnerName: 'Alex',
      siteId,
      iLike: 'The hint system is really creative and makes the game more fun.',
      iWonder: 'Could you add difficulty levels?',
      nextStep: 'Maybe add a timer to make it more challenging.',
      flagged: false,
      createdAt: now - 1800000,
    },
  ];

  await Promise.all(
    peerFeedback.map((p) => db.collection('peerFeedback').doc(p.id).set(p)),
  );
  console.log(`  Seeded ${peerFeedback.length} peer feedback entries`);

  // --- Badges & Awards (S4-4) ---
  const badges = [
    {
      id: 'badge-loop-master',
      siteId,
      name: 'Loop Master',
      description: 'Demonstrated proficiency in loop constructs',
      requiredMicroSkillIds: ['loops-while'],
      requiredEvidenceCount: 1,
      requiredCapabilityId: 'cap-computational-thinking',
      requiredMasteryLevel: 'proficient',
      pillarCode: 'FUTURE_SKILLS',
      createdAt: now,
    },
  ];

  const badgeAwards = [
    {
      id: 'badge-award-1',
      badgeId: 'badge-loop-master',
      learnerId: learnerUid,
      siteId,
      evidenceIds: ['skill-evidence-1'],
      awardedAt: now,
      awardedBy: 'system',
    },
  ];

  await Promise.all(badges.map((b) => db.collection('recognitionBadges').doc(b.id).set(b)));
  await Promise.all(badgeAwards.map((a) => db.collection('badgeAchievements').doc(a.id).set(a)));
  console.log(`  Seeded ${badges.length} badges and ${badgeAwards.length} badge achievements`);

  // --- Process Domains (HQ-managed) ---
  const processDomains = [
    {
      id: 'pd-design-thinking',
      title: 'Design Thinking',
      descriptor: 'Iterative problem-solving through empathy, ideation, prototyping, and testing.',
      siteId: '*',
      pillarCode: 'FUTURE_SKILLS',
      progressionDescriptors: {
        beginning: 'Follows a design process with heavy guidance.',
        developing: 'Applies design steps independently but may skip iteration.',
        proficient: 'Uses full design cycle with genuine user empathy and iteration.',
        advanced: 'Leads design sprints, mentors peers, and adapts process to context.',
      },
      sortOrder: 1,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'pd-scientific-inquiry',
      title: 'Scientific Inquiry',
      descriptor: 'Forming hypotheses, designing experiments, and drawing evidence-based conclusions.',
      siteId: '*',
      pillarCode: 'FUTURE_SKILLS',
      progressionDescriptors: {
        beginning: 'Asks questions about observations with prompting.',
        developing: 'Forms simple hypotheses and follows guided experiments.',
        proficient: 'Designs fair experiments, collects data, and draws supported conclusions.',
        advanced: 'Critiques experimental design, identifies confounds, and connects findings to broader theory.',
      },
      sortOrder: 2,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    },
  ];

  await Promise.all(
    processDomains.map((pd) => db.collection('processDomains').doc(pd.id).set(pd)),
  );
  console.log(`  Seeded ${processDomains.length} process domains`);

  // --- Additional Rubric Templates (HQ-managed, with process domain links) ---
  const additionalRubricTemplates = [
    {
      id: 'rt-computational-thinking-k3',
      title: 'Computational Thinking Assessment (K-3)',
      siteId: '*',
      capabilityIds: ['cap-computational-thinking'],
      criteria: [
        {
          id: 'rtc-decomposition',
          label: 'Problem Decomposition',
          capabilityId: 'cap-computational-thinking',
          pillarCode: 'FUTURE_SKILLS',
          maxScore: 4,
          descriptors: {
            beginning: 'Cannot break a problem into parts without direct instruction.',
            developing: 'Breaks a problem into 2-3 parts with guidance.',
            proficient: 'Independently decomposes problems into logical sub-tasks.',
            advanced: 'Decomposes complex problems and identifies reusable patterns across tasks.',
          },
          processDomainId: 'pd-design-thinking',
        },
        {
          id: 'rtc-algorithmic',
          label: 'Algorithmic Thinking',
          capabilityId: 'cap-computational-thinking',
          pillarCode: 'FUTURE_SKILLS',
          maxScore: 4,
          descriptors: {
            beginning: 'Follows step-by-step instructions but cannot create them.',
            developing: 'Creates simple step-by-step procedures for familiar problems.',
            proficient: 'Designs efficient algorithms with conditionals and loops.',
            advanced: 'Evaluates algorithm efficiency and selects optimal approaches.',
          },
        },
      ],
      status: 'published',
      createdBy: hqUid,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'rt-leadership-k6',
      title: 'Team Leadership Assessment (K-6)',
      siteId: '*',
      capabilityIds: ['cap-team-leadership'],
      criteria: [
        {
          id: 'rtc-collaboration',
          label: 'Collaborative Facilitation',
          capabilityId: 'cap-team-leadership',
          pillarCode: 'LEADERSHIP_AGENCY',
          maxScore: 4,
          descriptors: {
            beginning: 'Participates when asked but does not initiate collaboration.',
            developing: 'Takes turns leading and following in group work.',
            proficient: 'Actively facilitates group discussions and ensures all voices are heard.',
            advanced: 'Adapts leadership style to team needs and resolves conflicts constructively.',
          },
        },
      ],
      status: 'published',
      createdBy: hqUid,
      createdAt: now,
      updatedAt: now,
    },
  ];

  await Promise.all(
    additionalRubricTemplates.map((rt) => db.collection('rubricTemplates').doc(rt.id).set(rt)),
  );
  console.log(`  Seeded ${additionalRubricTemplates.length} additional rubric templates`);

  // --- Showcase Submissions ---
  const showcaseSubmissions = [
    {
      id: 'showcase-1',
      learnerId: learnerUid,
      siteId,
      title: 'Number Guessing Game - Final Version',
      artifactType: 'code',
      artifactUrl: '',
      description: 'My Python number guessing game with difficulty levels and a hint system. I used loops and conditionals to make it interactive.',
      microSkillIds: ['loops-while', 'variables-counter'],
      recognitions: [],
      visibleToCrew: true,
      visibleToSite: true,
      aiAssistanceUsed: true,
      aiAssistanceDetails: 'Used AI coach for debugging a loop issue. Changed approach after understanding the hint.',
      createdAt: now - 86400000,
      updatedAt: now - 86400000,
    },
  ];

  await Promise.all(
    showcaseSubmissions.map((s) => db.collection('showcaseSubmissions').doc(s.id).set(s)),
  );
  console.log(`  Seeded ${showcaseSubmissions.length} showcase submissions`);

  // --- Skill Mastery (feeds getLearnerMissionPath for mission progression) ---
  const skillMasteryRecords = [
    {
      id: `${learnerUid}_loops-while`,
      learnerId: learnerUid,
      microSkillId: 'loops-while',
      capabilityId: 'cap-computational-thinking',
      level: 3,
      siteId,
      updatedAt: now,
    },
    {
      id: `${learnerUid}_variables-counter`,
      learnerId: learnerUid,
      microSkillId: 'variables-counter',
      capabilityId: 'cap-computational-thinking',
      level: 2,
      siteId,
      updatedAt: now,
    },
  ];

  await Promise.all(
    skillMasteryRecords.map((sm) => db.collection('skillMastery').doc(sm.id).set(sm)),
  );
  console.log(`  Seeded ${skillMasteryRecords.length} skill mastery records`);

  // --- Process Domain Mastery ---
  const pdMasteryRecords = [
    {
      id: `${learnerUid}_pd-design-thinking`,
      learnerId: learnerUid,
      processDomainId: 'pd-design-thinking',
      siteId,
      currentLevel: 'developing',
      latestLevel: 2,
      previousLevel: 1,
      highestLevel: 2,
      evidenceCount: 1,
      evidenceIds: ['evidence-1'],
      lastAssessedBy: educatorUid,
      lastAssessedAt: now,
      createdAt: now,
      updatedAt: now,
    },
  ];

  await Promise.all(
    pdMasteryRecords.map((pd) => db.collection('processDomainMastery').doc(pd.id).set(pd)),
  );
  console.log(`  Seeded ${pdMasteryRecords.length} process domain mastery records`);

  // --- Process Domain Growth Events ---
  const pdGrowthEvents = [
    {
      id: 'pd-growth-1',
      learnerId: learnerUid,
      processDomainId: 'pd-design-thinking',
      siteId,
      fromLevel: 1,
      toLevel: 2,
      rawScore: 2,
      maxScore: 4,
      evidenceId: 'evidence-1',
      educatorId: educatorUid,
      createdAt: now,
    },
  ];

  await Promise.all(
    pdGrowthEvents.map((e) => db.collection('processDomainGrowthEvents').doc(e.id).set(e)),
  );
  console.log(`  Seeded ${pdGrowthEvents.length} process domain growth events`);

  console.log('Evidence chain seed complete.');
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
