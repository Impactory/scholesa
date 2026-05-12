/**
 * Firestore Rules Test Suite
 * Based on docs/67_FIRESTORE_RULES_TEST_MATRIX.md
 * 
 * Run with: firebase emulators:exec "npm test"
 */

const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
} = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'scholesa-test';

let testEnv;

// Test users
const hqUser = { uid: 'hq-user-1', email: 'hq@scholesa.com' };
const educatorUser = { uid: 'educator-1', email: 'educator@site1.com' };
const parentUser = { uid: 'parent-1', email: 'parent@example.com' };
const otherParentUser = { uid: 'parent-2', email: 'parent2@example.com' };
const learnerUser = { uid: 'learner-1', email: 'learner@example.com' };
const siteAdminUser = { uid: 'site-admin-1', email: 'siteadmin@site1.com' };
const otherSiteUser = { uid: 'other-site-user', email: 'other@site2.com' };
const partnerUser = { uid: 'partner-1', email: 'partner@example.com' };

beforeAll(async () => {
  setLogLevel('error');
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  const [host, portRaw] = emulatorHost.split(':');
  const port = Number(portRaw || '8080');

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host,
      port,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  
  // Seed test data
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    
    // Create users with roles
    await setDoc(doc(db, 'users', hqUser.uid), {
      email: hqUser.email,
      role: 'hq',
      siteIds: ['site1', 'site2'],
    });
    
    await setDoc(doc(db, 'users', educatorUser.uid), {
      email: educatorUser.email,
      role: 'educator',
      siteIds: ['site1'],
    });
    
    await setDoc(doc(db, 'users', parentUser.uid), {
      email: parentUser.email,
      role: 'parent',
      siteIds: ['site1'],
    });

    await setDoc(doc(db, 'users', otherParentUser.uid), {
      email: otherParentUser.email,
      role: 'parent',
      siteIds: ['site1'],
    });
    
    await setDoc(doc(db, 'users', learnerUser.uid), {
      email: learnerUser.email,
      role: 'learner',
      siteIds: ['site1'],
      parentIds: [parentUser.uid],
    });

    await setDoc(doc(db, 'users', siteAdminUser.uid), {
      email: siteAdminUser.email,
      role: 'site',
      siteIds: ['site1'],
      activeSiteId: 'site1',
    });
    
    await setDoc(doc(db, 'users', otherSiteUser.uid), {
      email: otherSiteUser.email,
      role: 'educator',
      siteIds: ['site2'],
    });

    await setDoc(doc(db, 'users', partnerUser.uid), {
      email: partnerUser.email,
      role: 'partner',
      siteIds: ['site1'],
    });
    
    // Create test site
    await setDoc(doc(db, 'sites', 'site1'), {
      name: 'Test School',
      status: 'active',
    });
    
    // Create test attendance record
    await setDoc(doc(db, 'attendanceRecords', 'att-1'), {
      siteId: 'site1',
      occurrenceId: 'occ-1',
      userId: learnerUser.uid,
      status: 'present',
    });

    // Create test check-in record
    await setDoc(doc(db, 'checkins', 'checkin-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      learnerName: 'Learner One',
      status: 'completed',
      type: 'checkin',
    });

    // Create test educator-learner link
    await setDoc(doc(db, 'educatorLearnerLinks', 'link-1'), {
      siteId: 'site1',
      educatorId: educatorUser.uid,
      learnerId: learnerUser.uid,
      status: 'active',
    });

    // Create test support intervention
    await setDoc(doc(db, 'supportInterventions', 'support-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      strategyType: 'autonomy',
      strategyDescription: 'Prompted learner reflection',
      context: 'individual',
      outcome: 'helped',
    });

    await setDoc(doc(db, 'autonomyInterventions', 'autonomy-intervention-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      interventionType: 'nudge',
      salience: 'medium',
      totalRiskScore: 0.62,
      reasonCodes: ['verification_gap'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'autonomyInterventions', 'autonomy-intervention-nosite'), {
      learnerId: learnerUser.uid,
      interventionType: 'nudge',
      salience: 'medium',
      totalRiskScore: 0.62,
      reasonCodes: ['verification_gap'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'autonomyInterventions', 'autonomy-intervention-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      interventionType: 'nudge',
      salience: 'medium',
      totalRiskScore: 0.62,
      reasonCodes: ['verification_gap'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'telemetryEvents', 'telemetry-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      event: 'checkpoint_submitted',
      category: 'competence',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'telemetryEvents', 'telemetry-nosite'), {
      userId: learnerUser.uid,
      event: 'checkpoint_submitted',
      category: 'competence',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'telemetryEvents', 'telemetry-site2'), {
      siteId: 'site2',
      userId: learnerUser.uid,
      event: 'checkpoint_submitted',
      category: 'competence',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'announcements', 'announcement-site1'), {
      siteId: 'site1',
      title: 'Studio update',
      body: 'Bring evidence notebooks tomorrow.',
      roles: ['learner', 'educator'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'announcements', 'announcement-nosite'), {
      title: 'Legacy announcement',
      body: 'Missing site scope.',
      roles: ['learner'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'announcements', 'announcement-site2'), {
      siteId: 'site2',
      title: 'Other studio update',
      body: 'Wrong site.',
      roles: ['learner'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityCommitments', 'commitment-site1'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      userId: learnerUser.uid,
      role: 'learner',
      statement: 'I will explain my evidence before asking for rubric review.',
      pillarCodes: ['future-skills'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityCommitments', 'commitment-nosite'), {
      cycleId: 'cycle-site1',
      userId: learnerUser.uid,
      role: 'learner',
      statement: 'Legacy commitment without site scope.',
      pillarCodes: ['future-skills'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityCommitments', 'commitment-site2'), {
      siteId: 'site2',
      cycleId: 'cycle-site2',
      userId: learnerUser.uid,
      role: 'learner',
      statement: 'Other site commitment.',
      pillarCodes: ['future-skills'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityReviews', 'review-site1'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      reviewerId: educatorUser.uid,
      revieweeId: learnerUser.uid,
      notes: 'Evidence explanation improved.',
      rating: 3,
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityReviews', 'review-nosite'), {
      cycleId: 'cycle-site1',
      reviewerId: educatorUser.uid,
      revieweeId: learnerUser.uid,
      notes: 'Legacy review without site scope.',
      rating: 3,
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityReviews', 'review-site2'), {
      siteId: 'site2',
      cycleId: 'cycle-site2',
      reviewerId: educatorUser.uid,
      revieweeId: learnerUser.uid,
      notes: 'Other site review.',
      rating: 3,
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'presenceRecords', 'presence-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      status: 'online',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'presenceRecords', 'presence-nosite'), {
      userId: learnerUser.uid,
      status: 'online',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'presenceRecords', 'presence-site2'), {
      siteId: 'site2',
      userId: learnerUser.uid,
      status: 'online',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'drafts', 'draft-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      title: 'Site-scoped draft',
      body: 'A learner-owned draft.',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'drafts', 'draft-nosite'), {
      userId: learnerUser.uid,
      title: 'Legacy draft',
      body: 'Missing site scope.',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'drafts', 'draft-site2'), {
      siteId: 'site2',
      userId: learnerUser.uid,
      title: 'Wrong-site draft',
      body: 'Wrong site scope.',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'offlineDemoActions', 'offline-action-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      actionType: 'queued_reflection',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'offlineDemoActions', 'offline-action-nosite'), {
      userId: learnerUser.uid,
      actionType: 'queued_reflection',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'offlineDemoActions', 'offline-action-site2'), {
      siteId: 'site2',
      userId: learnerUser.uid,
      actionType: 'queued_reflection',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'analyticsEvents', 'analytics-event-site1'), {
      siteId: 'site1',
      event_id: 'analytics-event-site1',
      event_name: 'checkpoint_submitted',
      class_id: 'site1',
      student_id: learnerUser.uid,
      source_screen: 'checkpoint',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'analyticsEvents', 'analytics-event-nosite'), {
      event_id: 'analytics-event-nosite',
      event_name: 'checkpoint_submitted',
      class_id: 'site1',
      student_id: learnerUser.uid,
      source_screen: 'checkpoint',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'analyticsEvents', 'analytics-event-site2'), {
      siteId: 'site2',
      event_id: 'analytics-event-site2',
      event_name: 'checkpoint_submitted',
      class_id: 'site2',
      student_id: learnerUser.uid,
      source_screen: 'checkpoint',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerProfiles', 'learner-profile-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      preferredName: 'Learner One',
      gradeLevel: '6',
    });

    await setDoc(doc(db, 'learnerProfiles', 'learner-profile-nosite'), {
      learnerId: learnerUser.uid,
      preferredName: 'Legacy Learner',
      gradeLevel: '6',
    });

    await setDoc(doc(db, 'learnerProfiles', 'learner-profile-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      preferredName: 'Wrong Site Learner',
      gradeLevel: '6',
    });

    await setDoc(doc(db, 'parentProfiles', 'parent-profile-site1'), {
      siteId: 'site1',
      parentId: parentUser.uid,
      preferredName: 'Parent One',
    });

    await setDoc(doc(db, 'parentProfiles', 'parent-profile-nosite'), {
      parentId: parentUser.uid,
      preferredName: 'Legacy Parent',
    });

    await setDoc(doc(db, 'parentProfiles', 'parent-profile-site2'), {
      siteId: 'site2',
      parentId: parentUser.uid,
      preferredName: 'Wrong Site Parent',
    });

    await setDoc(doc(db, 'guardianLinks', 'guardian-link-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      parentId: parentUser.uid,
      relationship: 'parent',
    });

    await setDoc(doc(db, 'guardianLinks', 'guardian-link-nosite'), {
      learnerId: learnerUser.uid,
      parentId: parentUser.uid,
      relationship: 'parent',
    });

    await setDoc(doc(db, 'guardianLinks', 'guardian-link-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      parentId: parentUser.uid,
      relationship: 'parent',
    });

    await setDoc(doc(db, 'portfolioItems', 'portfolio-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Learner artifact',
      status: 'draft',
    });

    await setDoc(doc(db, 'portfolioItems', 'portfolio-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Legacy unscoped artifact',
      status: 'draft',
    });

    await setDoc(doc(db, 'missionAttempts', 'attempt-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'submitted',
      content: 'Site-scoped mission evidence',
    });

    await setDoc(doc(db, 'missionAttempts', 'attempt-nosite'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-legacy',
      status: 'submitted',
      content: 'Legacy unscoped mission evidence',
    });

    await setDoc(doc(db, 'missionAttempts', 'attempt-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      missionId: 'mission-other-site',
      status: 'submitted',
      content: 'Wrong-site mission evidence',
    });

    await setDoc(doc(db, 'checkpointHistory', 'checkpoint-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      checkpointDefinitionId: 'checkpoint-1',
      status: 'submitted',
      answer: 'Site-scoped checkpoint evidence',
    });

    await setDoc(doc(db, 'checkpointHistory', 'checkpoint-nosite'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-legacy',
      checkpointDefinitionId: 'checkpoint-legacy',
      status: 'submitted',
      answer: 'Legacy unscoped checkpoint evidence',
    });

    await setDoc(doc(db, 'checkpointHistory', 'checkpoint-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      missionId: 'mission-other-site',
      checkpointDefinitionId: 'checkpoint-other-site',
      status: 'submitted',
      answer: 'Wrong-site checkpoint evidence',
    });

    await setDoc(doc(db, 'skillEvidence', 'skill-evidence-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      microSkillId: 'skill-1',
      evidenceType: 'quiz',
      description: 'Site-scoped skill evidence',
      status: 'submitted',
    });

    await setDoc(doc(db, 'skillEvidence', 'skill-evidence-nosite'), {
      learnerId: learnerUser.uid,
      microSkillId: 'skill-legacy',
      evidenceType: 'quiz',
      description: 'Legacy unscoped skill evidence',
      status: 'submitted',
    });

    await setDoc(doc(db, 'skillEvidence', 'skill-evidence-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      microSkillId: 'skill-other-site',
      evidenceType: 'quiz',
      description: 'Wrong-site skill evidence',
      status: 'submitted',
    });

    await setDoc(doc(db, 'learnerReflections', 'reflection-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      content: 'Site-scoped learner reflection',
      portfolioItemId: 'portfolio-1',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerReflections', 'reflection-nosite'), {
      learnerId: learnerUser.uid,
      content: 'Legacy unscoped learner reflection',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerReflections', 'reflection-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      content: 'Wrong-site learner reflection',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'metacognitiveCalibrationRecords', 'calibration-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sourceType: 'checkpoint',
      sourceId: 'checkpoint-site1',
      confidenceLevel: 3,
      accuracyScore: 0.8,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'metacognitiveCalibrationRecords', 'calibration-nosite'), {
      learnerId: learnerUser.uid,
      sourceType: 'checkpoint',
      sourceId: 'checkpoint-legacy',
      confidenceLevel: 2,
      accuracyScore: 0.4,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'metacognitiveCalibrationRecords', 'calibration-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      sourceType: 'checkpoint',
      sourceId: 'checkpoint-other-site',
      confidenceLevel: 4,
      accuracyScore: 1,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'habits', 'habit-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Site-scoped learning habit',
      isActive: true,
      currentStreak: 1,
      totalCompletions: 2,
    });

    await setDoc(doc(db, 'habits', 'habit-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Legacy unscoped learning habit',
      isActive: true,
      currentStreak: 1,
      totalCompletions: 2,
    });

    await setDoc(doc(db, 'habits', 'habit-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Wrong-site learning habit',
      isActive: true,
      currentStreak: 1,
      totalCompletions: 2,
    });

    await setDoc(doc(db, 'habitLogs', 'habit-log-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      habitId: 'habit-site1',
      durationMinutes: 10,
      completedAt: Date.now(),
    });

    await setDoc(doc(db, 'habitLogs', 'habit-log-nosite'), {
      learnerId: learnerUser.uid,
      habitId: 'habit-site1',
      durationMinutes: 10,
      completedAt: Date.now(),
    });

    await setDoc(doc(db, 'habitLogs', 'habit-log-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      habitId: 'habit-site1',
      durationMinutes: 10,
      completedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerBadges', 'badge-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      badgeId: 'capability-evidence-builder',
      reason: 'Submitted reviewed evidence',
      awardedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerBadges', 'badge-nosite'), {
      learnerId: learnerUser.uid,
      badgeId: 'legacy-badge',
      reason: 'Legacy badge',
      awardedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerBadges', 'badge-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      badgeId: 'wrong-site-badge',
      reason: 'Wrong-site badge',
      awardedAt: Date.now(),
    });

    await setDoc(doc(db, 'motivationAnalytics', 'motivation-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      totalEvidenceSubmitted: 3,
      totalReflections: 2,
    });

    await setDoc(doc(db, 'motivationAnalytics', 'motivation-nosite'), {
      learnerId: learnerUser.uid,
      totalEvidenceSubmitted: 1,
      totalReflections: 1,
    });

    await setDoc(doc(db, 'motivationAnalytics', 'motivation-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      totalEvidenceSubmitted: 1,
      totalReflections: 1,
    });

    await setDoc(doc(db, 'learnerChoiceHistory', 'choice-history-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      selections: {
        'mission-1': { difficulty: 'BRONZE', reason: 'I can explain it' },
      },
    });

    await setDoc(doc(db, 'learnerChoiceHistory', 'choice-history-nosite'), {
      learnerId: learnerUser.uid,
      selections: {
        'mission-legacy': { difficulty: 'BRONZE', reason: 'Legacy choice' },
      },
    });

    await setDoc(doc(db, 'learnerChoiceHistory', 'choice-history-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      selections: {
        'mission-2': { difficulty: 'SILVER', reason: 'Wrong-site choice' },
      },
    });

    await setDoc(doc(db, 'sessionReflections', 'session-reflection-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sessionId: 'session-1',
      effortRating: 4,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'sessionReflections', 'session-reflection-nosite'), {
      learnerId: learnerUser.uid,
      sessionId: 'session-1',
      effortRating: 3,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'sessionReflections', 'session-reflection-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      sessionId: 'session-2',
      effortRating: 3,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerGoals', 'goal-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      goalType: 'skill_mastery',
      description: 'Site-scoped learner goal',
      progress: 25,
      status: 'active',
    });

    await setDoc(doc(db, 'learnerGoals', 'goal-nosite'), {
      learnerId: learnerUser.uid,
      goalType: 'skill_mastery',
      description: 'Legacy unscoped learner goal',
      progress: 10,
      status: 'active',
    });

    await setDoc(doc(db, 'learnerGoals', 'goal-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      goalType: 'skill_mastery',
      description: 'Wrong-site learner goal',
      progress: 10,
      status: 'active',
    });

    await setDoc(doc(db, 'learnerInterestProfiles', 'interest-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      interests: ['robotics'],
      preferredDifficulty: 'medium',
      preferredWorkStyle: 'crew',
    });

    await setDoc(doc(db, 'learnerInterestProfiles', 'interest-nosite'), {
      learnerId: learnerUser.uid,
      interests: ['art'],
      preferredDifficulty: 'easy',
      preferredWorkStyle: 'independent',
    });

    await setDoc(doc(db, 'learnerInterestProfiles', 'interest-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      interests: ['music'],
      preferredDifficulty: 'hard',
      preferredWorkStyle: 'paired',
    });

    await setDoc(doc(db, 'skillMastery', 'skill-mastery-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      skillId: 'skill-1',
      level: 2,
      evidenceCount: 3,
    });

    await setDoc(doc(db, 'skillMastery', 'skill-mastery-nosite'), {
      learnerId: learnerUser.uid,
      skillId: 'skill-legacy',
      level: 1,
      evidenceCount: 1,
    });

    await setDoc(doc(db, 'skillMastery', 'skill-mastery-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      skillId: 'skill-other-site',
      level: 1,
      evidenceCount: 1,
    });

    await setDoc(doc(db, 'showcaseSubmissions', 'showcase-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Site-scoped showcase artifact',
      description: 'A learner artifact shared with the school.',
      visibility: 'site',
      approvalStatus: 'pending',
    });

    await setDoc(doc(db, 'showcaseSubmissions', 'showcase-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Legacy unscoped showcase artifact',
      description: 'A legacy artifact without site scope.',
      visibility: 'site',
      approvalStatus: 'pending',
    });

    await setDoc(doc(db, 'showcaseSubmissions', 'showcase-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Wrong-site showcase artifact',
      description: 'A learner artifact from another site.',
      visibility: 'site',
      approvalStatus: 'pending',
    });

    await setDoc(doc(db, 'studentAssents', 'assent-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      assentGiven: true,
      assentVersion: 'v1',
    });

    await setDoc(doc(db, 'studentAssents', 'assent-nosite'), {
      learnerId: learnerUser.uid,
      assentGiven: true,
      assentVersion: 'legacy',
    });

    await setDoc(doc(db, 'studentAssents', 'assent-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      assentGiven: true,
      assentVersion: 'other-site',
    });

    await setDoc(doc(db, 'itemResponses', 'item-response-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      instrumentId: 'instrument-1',
      itemId: 'item-1',
      response: 'A',
      score: 1,
    });

    await setDoc(doc(db, 'itemResponses', 'item-response-nosite'), {
      learnerId: learnerUser.uid,
      instrumentId: 'instrument-legacy',
      itemId: 'item-legacy',
      response: 'B',
      score: 0,
    });

    await setDoc(doc(db, 'itemResponses', 'item-response-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      instrumentId: 'instrument-other-site',
      itemId: 'item-other-site',
      response: 'C',
      score: 1,
    });

    await setDoc(doc(db, 'learnerNextSteps', 'next-step-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      pillarCode: 'future_skills',
      stepType: 'practice',
      title: 'Site-scoped next step',
      currentLevel: 2,
      targetLevel: 3,
      status: 'active',
    });

    await setDoc(doc(db, 'learnerNextSteps', 'next-step-nosite'), {
      learnerId: learnerUser.uid,
      capabilityId: 'capability-legacy',
      pillarCode: 'future_skills',
      stepType: 'practice',
      title: 'Legacy next step',
      currentLevel: 1,
      targetLevel: 2,
      status: 'active',
    });

    await setDoc(doc(db, 'learnerNextSteps', 'next-step-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-other-site',
      pillarCode: 'leadership',
      stepType: 'reflection',
      title: 'Wrong-site next step',
      currentLevel: 1,
      targetLevel: 2,
      status: 'active',
    });

    await setDoc(doc(db, 'learnerSupportPlans', 'support-plan-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      supportType: 'Academic',
      priority: 'medium',
      notes: 'Site-scoped support plan',
    });

    await setDoc(doc(db, 'learnerSupportPlans', 'support-plan-nosite'), {
      learnerId: learnerUser.uid,
      supportType: 'Academic',
      priority: 'medium',
      notes: 'Legacy support plan',
    });

    await setDoc(doc(db, 'learnerSupportPlans', 'support-plan-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      supportType: 'Academic',
      priority: 'medium',
      notes: 'Wrong-site support plan',
    });

    await setDoc(doc(db, 'learnerDifferentiationPlans', 'differentiation-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      selectedLane: 'core',
      recommendedLane: 'core',
    });

    await setDoc(doc(db, 'learnerDifferentiationPlans', 'differentiation-nosite'), {
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      selectedLane: 'core',
      recommendedLane: 'core',
    });

    await setDoc(doc(db, 'learnerDifferentiationPlans', 'differentiation-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      selectedLane: 'stretch',
      recommendedLane: 'core',
    });

    await setDoc(doc(db, 'missionPlans', 'mission-plan-site1'), {
      siteId: 'site1',
      sessionOccurrenceId: 'occ-1',
      educatorId: educatorUser.uid,
      missionIds: ['mission-1'],
      status: 'draft',
    });

    await setDoc(doc(db, 'missionPlans', 'mission-plan-nosite'), {
      sessionOccurrenceId: 'occ-legacy',
      educatorId: educatorUser.uid,
      missionIds: ['mission-legacy'],
      status: 'draft',
    });

    await setDoc(doc(db, 'missionPlans', 'mission-plan-site2'), {
      siteId: 'site2',
      sessionOccurrenceId: 'occ-2',
      educatorId: educatorUser.uid,
      missionIds: ['mission-other-site'],
      status: 'draft',
    });

    await setDoc(doc(db, 'portfolios', 'portfolio-container-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Site-scoped learner portfolio',
    });

    await setDoc(doc(db, 'portfolios', 'portfolio-container-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Legacy learner portfolio',
    });

    await setDoc(doc(db, 'portfolios', 'portfolio-container-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Wrong-site learner portfolio',
    });

    await setDoc(doc(db, 'rubricApplications', 'rubric-application-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      rubricId: 'rubric-1',
      missionAttemptId: 'attempt-site1',
      scores: [{ criterionId: 'criterion-1', capabilityId: 'capability-1', score: 3, maxScore: 4 }],
    });

    await setDoc(doc(db, 'rubricApplications', 'rubric-application-nosite'), {
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      rubricId: 'rubric-legacy',
      missionAttemptId: 'attempt-nosite',
      scores: [{ criterionId: 'criterion-1', capabilityId: 'capability-1', score: 2, maxScore: 4 }],
    });

    await setDoc(doc(db, 'rubricApplications', 'rubric-application-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      rubricId: 'rubric-other-site',
      missionAttemptId: 'attempt-site2',
      scores: [{ criterionId: 'criterion-1', capabilityId: 'capability-2', score: 2, maxScore: 4 }],
    });

    await setDoc(doc(db, 'billingAccounts', parentUser.uid), {
      parentId: parentUser.uid,
      siteId: 'site1',
      status: 'active',
      balanceCents: 0,
    });

    await setDoc(doc(db, 'billingAccounts', otherParentUser.uid), {
      parentId: otherParentUser.uid,
      siteId: 'site1',
      status: 'active',
      balanceCents: 2500,
    });

    await setDoc(doc(db, 'payments', 'payment-parent-1'), {
      parentId: parentUser.uid,
      siteId: 'site1',
      amountCents: 1000,
      status: 'posted',
    });

    await setDoc(doc(db, 'payments', 'payment-parent-2'), {
      parentId: otherParentUser.uid,
      siteId: 'site1',
      amountCents: 2500,
      status: 'posted',
    });

    await setDoc(doc(db, 'missionAssignments', 'assignment-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      assignedBy: educatorUser.uid,
      status: 'active',
      progress: 20,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'missionAssignments', 'assignment-nosite'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-legacy',
      assignedBy: educatorUser.uid,
      status: 'active',
      progress: 10,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'missionAssignments', 'assignment-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      missionId: 'mission-other-site',
      assignedBy: educatorUser.uid,
      status: 'active',
      progress: 10,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'skillAssessments', 'skill-assessment-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      skillId: 'skill-1',
      assessorId: educatorUser.uid,
      level: 2,
      assessedAt: Date.now(),
    });

    await setDoc(doc(db, 'skillAssessments', 'skill-assessment-nosite'), {
      learnerId: learnerUser.uid,
      skillId: 'skill-legacy',
      assessorId: educatorUser.uid,
      level: 1,
      assessedAt: Date.now(),
    });

    await setDoc(doc(db, 'skillAssessments', 'skill-assessment-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      skillId: 'skill-other-site',
      assessorId: educatorUser.uid,
      level: 1,
      assessedAt: Date.now(),
    });

    await setDoc(doc(db, 'learnerProgress', learnerUser.uid), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      level: 2,
      totalXp: 120,
      missionsCompleted: 3,
    });

    await setDoc(doc(db, 'learnerProgress', 'progress-nosite'), {
      learnerId: learnerUser.uid,
      level: 2,
      totalXp: 120,
      missionsCompleted: 3,
    });

    await setDoc(doc(db, 'learnerProgress', 'progress-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      level: 2,
      totalXp: 120,
      missionsCompleted: 3,
    });

    await setDoc(doc(db, 'activities', 'activity-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Evidence submitted',
      description: 'Learner submitted proof evidence.',
      type: 'evidence',
      timestamp: Date.now(),
    });

    await setDoc(doc(db, 'activities', 'activity-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Legacy activity',
      description: 'Missing site scope.',
      type: 'activity',
      timestamp: Date.now(),
    });

    await setDoc(doc(db, 'activities', 'activity-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Other site activity',
      description: 'Wrong site scope.',
      type: 'activity',
      timestamp: Date.now(),
    });

    await setDoc(doc(db, 'events', 'event-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Studio session',
      type: 'session',
      dateTime: Date.now(),
    });

    await setDoc(doc(db, 'events', 'event-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Legacy event',
      type: 'session',
      dateTime: Date.now(),
    });

    await setDoc(doc(db, 'events', 'event-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Other site session',
      type: 'session',
      dateTime: Date.now(),
    });

    await setDoc(doc(db, 'accountabilityCycles', 'cycle-site1'), {
      siteId: 'site1',
      title: 'Cycle 1',
      status: 'active',
      ownerId: educatorUser.uid,
    });

    await setDoc(doc(db, 'accountabilityCycles', 'cycle-nosite'), {
      title: 'Legacy cycle',
      status: 'active',
      ownerId: educatorUser.uid,
    });

    await setDoc(doc(db, 'accountabilityCycles', 'cycle-site2'), {
      siteId: 'site2',
      title: 'Other site cycle',
      status: 'active',
      ownerId: educatorUser.uid,
    });

    await setDoc(doc(db, 'accountabilityKPIs', 'kpi-site1'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      title: 'Evidence coverage',
      value: 80,
    });

    await setDoc(doc(db, 'accountabilityKPIs', 'kpi-nosite'), {
      cycleId: 'cycle-site1',
      title: 'Legacy KPI',
      value: 50,
    });

    await setDoc(doc(db, 'accountabilityKPIs', 'kpi-site2'), {
      siteId: 'site2',
      cycleId: 'cycle-site2',
      title: 'Other site KPI',
      value: 50,
    });

    await setDoc(doc(db, 'mediaConsents', 'media-consent-site1'), {
      siteId: 'site1',
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      status: 'granted',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'mediaConsents', 'media-consent-nosite'), {
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      status: 'granted',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'mediaConsents', 'media-consent-site2'), {
      siteId: 'site2',
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      status: 'granted',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'pickupAuthorizations', 'pickup-site1'), {
      siteId: 'site1',
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      authorizedAdults: ['Sam Caregiver'],
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'pickupAuthorizations', 'pickup-nosite'), {
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      authorizedAdults: ['Sam Caregiver'],
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'pickupAuthorizations', 'pickup-site2'), {
      siteId: 'site2',
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      authorizedAdults: ['Sam Caregiver'],
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'incidentReports', 'incident-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      reportedBy: educatorUser.uid,
      severity: 'low',
      category: 'care',
      status: 'submitted',
      summary: 'Minor support incident',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'incidentReports', 'incident-nosite'), {
      learnerId: learnerUser.uid,
      reportedBy: educatorUser.uid,
      severity: 'low',
      category: 'care',
      status: 'submitted',
      summary: 'Legacy incident',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'incidentReports', 'incident-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      reportedBy: educatorUser.uid,
      severity: 'low',
      category: 'care',
      status: 'submitted',
      summary: 'Other site incident',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'incidents', 'runtime-incident-site1'), {
      siteId: 'site1',
      reportedBy: educatorUser.uid,
      type: 'ops',
      description: 'Runtime incident',
      status: 'open',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'incidents', 'runtime-incident-nosite'), {
      reportedBy: educatorUser.uid,
      type: 'ops',
      description: 'Legacy runtime incident',
      status: 'open',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'incidents', 'runtime-incident-site2'), {
      siteId: 'site2',
      reportedBy: educatorUser.uid,
      type: 'ops',
      description: 'Other site runtime incident',
      status: 'open',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'siteCheckInOut', 'checkin-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      date: '2026-05-11',
      checkInBy: educatorUser.uid,
      checkInAt: Date.now(),
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'siteCheckInOut', 'checkin-nosite'), {
      learnerId: learnerUser.uid,
      date: '2026-05-11',
      checkInBy: educatorUser.uid,
      checkInAt: Date.now(),
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'siteCheckInOut', 'checkin-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      date: '2026-05-11',
      checkInBy: educatorUser.uid,
      checkInAt: Date.now(),
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'orchestrationStates', 'orchestration-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      x_hat: { cognition: 0.7, engagement: 0.8, integrity: 0.9 },
      P: { trace: 0.2, confidence: 0.8 },
      lastUpdatedAt: Date.now(),
    });

    await setDoc(doc(db, 'orchestrationStates', 'orchestration-nosite'), {
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      x_hat: { cognition: 0.7, engagement: 0.8, integrity: 0.9 },
      P: { trace: 0.2, confidence: 0.8 },
      lastUpdatedAt: Date.now(),
    });

    await setDoc(doc(db, 'orchestrationStates', 'orchestration-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      x_hat: { cognition: 0.7, engagement: 0.8, integrity: 0.9 },
      P: { trace: 0.2, confidence: 0.8 },
      lastUpdatedAt: Date.now(),
    });

    await setDoc(doc(db, 'interventions', 'intervention-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      type: 'scaffold',
      reasonCodes: ['integrity_below_threshold'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'interventions', 'intervention-nosite'), {
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      type: 'scaffold',
      reasonCodes: ['legacy_missing_site'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'interventions', 'intervention-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      type: 'scaffold',
      reasonCodes: ['wrong_site'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'mvlEpisodes', 'mvl-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      triggerReason: 'policy_triggered',
      evidenceEventIds: [],
      resolution: null,
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'mvlEpisodes', 'mvl-nosite'), {
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      triggerReason: 'legacy_missing_site',
      evidenceEventIds: [],
      resolution: null,
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'mvlEpisodes', 'mvl-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      triggerReason: 'wrong_site',
      evidenceEventIds: [],
      resolution: null,
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'recognitionBadges', 'recognition-site1'), {
      siteId: 'site1',
      giverId: 'learner-peer',
      recipientId: learnerUser.uid,
      recognitionType: 'collaboration',
      message: 'Supported a peer',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'recognitionBadges', 'recognition-nosite'), {
      giverId: 'learner-peer',
      recipientId: learnerUser.uid,
      recognitionType: 'collaboration',
      message: 'Legacy recognition',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'recognitionBadges', 'recognition-site2'), {
      siteId: 'site2',
      giverId: 'learner-peer',
      recipientId: learnerUser.uid,
      recognitionType: 'collaboration',
      message: 'Wrong site recognition',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'badgeAchievements', 'badge-achievement-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      badgeId: 'badge-1',
      evidenceIds: ['evidence-1'],
      awardedAt: Date.now(),
    });

    await setDoc(doc(db, 'badgeAchievements', 'badge-achievement-user-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      badgeId: 'badge-legacy-user',
      evidenceIds: ['evidence-1'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'badgeAchievements', 'badge-achievement-nosite'), {
      learnerId: learnerUser.uid,
      badgeId: 'badge-legacy',
      evidenceIds: ['evidence-1'],
      awardedAt: Date.now(),
    });

    await setDoc(doc(db, 'badgeAchievements', 'badge-achievement-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      badgeId: 'badge-wrong-site',
      evidenceIds: ['evidence-1'],
      awardedAt: Date.now(),
    });

    await setDoc(doc(db, 'missionEnrollments', 'mission-enrollment-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'active',
      progress: 40,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'missionEnrollments', 'mission-enrollment-nosite'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-legacy',
      status: 'active',
      progress: 40,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'missionEnrollments', 'mission-enrollment-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      missionId: 'mission-wrong-site',
      status: 'active',
      progress: 40,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'reflections', 'reflection-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      prompt: 'What did you learn?',
      responseText: 'I learned to explain my process.',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'reflections', 'reflection-nosite'), {
      userId: learnerUser.uid,
      prompt: 'Legacy reflection',
      responseText: 'Missing site.',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'reflections', 'reflection-site2'), {
      siteId: 'site2',
      userId: learnerUser.uid,
      prompt: 'Wrong site reflection',
      responseText: 'Wrong site.',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'missionSubmissions', 'submission-site1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'submitted',
      artifactUrls: ['https://example.test/artifact'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'missionSubmissions', 'submission-nosite'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'submitted',
      artifactUrls: ['https://example.test/artifact'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'missionSubmissions', 'submission-site2'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'submitted',
      artifactUrls: ['https://example.test/artifact'],
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'supportRequests', 'support-request-site1'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      requestType: 'help',
      subject: 'Need help',
      status: 'open',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'supportRequests', 'support-request-nosite'), {
      userId: learnerUser.uid,
      requestType: 'help',
      subject: 'Legacy help',
      status: 'open',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'supportRequests', 'support-request-site2'), {
      siteId: 'site2',
      userId: learnerUser.uid,
      requestType: 'help',
      subject: 'Wrong site help',
      status: 'open',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'capabilityMastery', 'mastery-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      latestLevel: 3,
      currentLevel: 3,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'capabilityMastery', 'mastery-nosite'), {
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      latestLevel: 3,
      currentLevel: 3,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'capabilityGrowthEvents', 'growth-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      level: 3,
      occurredAt: Date.now(),
    });

    await setDoc(doc(db, 'capabilityGrowthEvents', 'growth-nosite'), {
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      level: 3,
      occurredAt: Date.now(),
    });

    await setDoc(doc(db, 'processDomainMastery', 'process-mastery-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      processDomainId: 'process-domain-1',
      latestLevel: 3,
      currentLevel: 3,
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'processDomainGrowthEvents', 'process-growth-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      processDomainId: 'process-domain-1',
      level: 3,
      occurredAt: Date.now(),
    });

    await setDoc(doc(db, 'proofOfLearningBundles', 'proof-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      portfolioItemId: 'portfolio-1',
      verificationStatus: 'verified',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'proofOfLearningBundles', 'proof-nosite'), {
      learnerId: learnerUser.uid,
      portfolioItemId: 'portfolio-1',
      verificationStatus: 'verified',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'aiInteractionLogs', 'ai-log-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      traceId: 'trace-1',
      taskType: 'hint',
      dataUsagePolicy: 'analytics_only_no_training',
      redactedQuestion: 'How do I improve this?',
      response: 'Try explaining the evidence.',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'aiInteractionLogs', 'ai-log-nosite'), {
      learnerId: learnerUser.uid,
      traceId: 'trace-nosite',
      taskType: 'hint',
      dataUsagePolicy: 'analytics_only_no_training',
      redactedQuestion: 'No site?',
      response: 'This should be hidden.',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'aiDrafts', 'ai-draft-site1'), {
      siteId: 'site1',
      requesterId: learnerUser.uid,
      title: 'Site-scoped AI draft',
      prompt: 'Help me revise my reflection.',
      status: 'requested',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'aiDrafts', 'ai-draft-nosite'), {
      requesterId: learnerUser.uid,
      title: 'Legacy AI draft',
      prompt: 'Missing site provenance.',
      status: 'requested',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'aiDrafts', 'ai-draft-site2'), {
      siteId: 'site2',
      requesterId: learnerUser.uid,
      title: 'Wrong-site AI draft',
      prompt: 'Wrong-site provenance.',
      status: 'requested',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'aiCoachInteractions', 'ai-coach-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      mode: 'hint',
      question: 'What should I explain?',
      response: 'Explain your revision.',
      createdAt: Date.now(),
    });

    await setDoc(doc(db, 'credentials', 'credential-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Studio Systems Badge',
      issuerId: educatorUser.uid,
      status: 'issued',
      evidenceIds: ['evidence-1'],
      portfolioItemIds: ['portfolio-1'],
      proofBundleIds: ['proof-1'],
      growthEventIds: ['growth-1'],
      rubricApplicationId: 'rubric-application-1',
    });

    await setDoc(doc(db, 'messageThreads', 'thread-1'), {
      participantIds: [educatorUser.uid, parentUser.uid],
      participantNames: ['Educator One', 'Parent One'],
      title: 'Family follow-up',
      status: 'open',
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'messages', 'message-1'), {
      threadId: 'thread-1',
      recipientId: parentUser.uid,
      senderId: educatorUser.uid,
      title: 'Schedule update',
      body: 'Please review tomorrow.',
      type: 'alert',
      isRead: false,
      status: 'sent',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'featureFlags', 'feature_fl_exp_literacy_pilot'), {
      name: 'Federated Learning Prototype: Literacy Pilot',
      enabled: true,
      status: 'enabled',
      scope: 'site',
      enabledSites: ['site1'],
      experimentId: 'fl_exp_literacy_pilot',
    });

    await setDoc(doc(db, 'federatedLearningExperiments', 'fl_exp_literacy_pilot'), {
      name: 'Literacy Pilot',
      description: 'Site-scoped literacy prototype cohort',
      runtimeTarget: 'flutter_mobile',
      status: 'pilot_ready',
      allowedSiteIds: ['site1'],
      aggregateThreshold: 25,
      rawUpdateMaxBytes: 16384,
      enablePrototypeUploads: true,
      featureFlagId: 'feature_fl_exp_literacy_pilot',
      siteId: 'site1',
    });

    await setDoc(doc(db, 'federatedLearningExperiments', 'fl_exp_other_site'), {
      name: 'Other Site Pilot',
      description: 'Other site only',
      runtimeTarget: 'flutter_mobile',
      status: 'pilot_ready',
      allowedSiteIds: ['site2'],
      aggregateThreshold: 25,
      rawUpdateMaxBytes: 16384,
      enablePrototypeUploads: true,
      featureFlagId: 'feature_fl_exp_other_site',
      siteId: 'site2',
    });

    await setDoc(doc(db, 'federatedLearningExperimentReviewRecords', 'fl_review_literacy_pilot'), {
      experimentId: 'fl_exp_literacy_pilot',
      status: 'pending',
      privacyReviewComplete: true,
      signoffChecklistComplete: false,
      rolloutRiskAcknowledged: true,
      notes: 'Awaiting final sign-off checklist completion.',
      reviewedBy: hqUser.uid,
      reviewedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningUpdateSummaries', 'fl_update_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      siteId: 'site1',
      traceId: 'trace-1',
      schemaVersion: 'v1',
      sampleCount: 18,
      vectorLength: 128,
      payloadBytes: 2048,
      updateNorm: 3.2,
      payloadDigest: 'digest-1',
      batteryState: 'charging',
      networkType: 'wifi',
      status: 'accepted',
      aggregationStatus: 'materialized',
      aggregationRunId: 'fl_agg_demo_1',
      requestedBy: siteAdminUser.uid,
    });

    await setDoc(doc(db, 'federatedLearningAggregationRuns', 'fl_agg_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      status: 'materialized',
      threshold: 25,
      thresholdMet: true,
      mergeArtifactId: 'fl_merge_demo_1',
      mergeArtifactStatus: 'generated',
      mergeStrategy: 'prototype_weighted_metadata_digest',
      boundedDigest: 'sha256:digest-1',
      triggerSummaryId: 'fl_update_1',
      summaryIds: ['fl_update_1'],
      summaryCount: 1,
      distinctSiteCount: 1,
      totalSampleCount: 18,
      maxVectorLength: 128,
      totalPayloadBytes: 2048,
      averageUpdateNorm: 3.2,
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      createdBy: siteAdminUser.uid,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningMergeArtifacts', 'fl_merge_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      aggregationRunId: 'fl_agg_demo_1',
      status: 'generated',
      mergeStrategy: 'prototype_weighted_metadata_digest',
      boundedDigest: 'sha256:digest-1',
      sampleCount: 18,
      summaryCount: 1,
      distinctSiteCount: 1,
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      maxVectorLength: 128,
      totalPayloadBytes: 2048,
      averageUpdateNorm: 3.2,
      createdBy: siteAdminUser.uid,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningCandidateModelPackages', 'fl_pkg_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      status: 'staged',
      packageFormat: 'bounded_metadata_manifest',
      rolloutStatus: 'not_distributed',
      packageDigest: 'sha256:pkg-digest-1',
      boundedDigest: 'sha256:digest-1',
      sampleCount: 18,
      summaryCount: 1,
      distinctSiteCount: 1,
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      maxVectorLength: 128,
      totalPayloadBytes: 2048,
      averageUpdateNorm: 3.2,
      createdBy: siteAdminUser.uid,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningCandidatePromotionRecords', 'fl_prom_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      status: 'approved_for_eval',
      target: 'sandbox_eval',
      rationale: 'Ready for bounded sandbox evaluation.',
      decidedBy: hqUser.uid,
      decidedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningCandidatePromotionRevocationRecords', 'fl_prom_revoke_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      candidatePromotionRecordId: 'fl_prom_demo_1',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      revokedStatus: 'approved_for_eval',
      target: 'sandbox_eval',
      rationale: 'Rollback verified in sandbox.',
      revokedBy: hqUser.uid,
      revokedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningPilotEvidenceRecords', 'fl_pilot_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      status: 'pending',
      sandboxEvalComplete: true,
      metricsSnapshotComplete: false,
      rollbackPlanVerified: true,
      notes: 'Awaiting metrics snapshot review.',
      reviewedBy: hqUser.uid,
      reviewedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningPilotApprovalRecords', 'fl_pilot_approval_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      experimentReviewRecordId: 'fl_review_literacy_pilot',
      pilotEvidenceRecordId: 'fl_pilot_demo_1',
      candidatePromotionRecordId: 'fl_prom_demo_1',
      promotionTarget: 'sandbox_eval',
      status: 'pending',
      notes: 'Awaiting bounded HQ pilot approval sign-off.',
      approvedBy: hqUser.uid,
      approvedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningPilotExecutionRecords', 'fl_pilot_execution_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      pilotApprovalRecordId: 'fl_pilot_approval_demo_1',
      status: 'planned',
      launchedSiteIds: ['site1'],
      sessionCount: 0,
      learnerCount: 0,
      notes: 'Bounded pilot launch plan captured for the approved package.',
      recordedBy: hqUser.uid,
      recordedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningRuntimeDeliveryRecords', 'fl_delivery_demo_1'), {
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      aggregationRunId: 'fl_agg_demo_1',
      mergeArtifactId: 'fl_merge_demo_1',
      pilotExecutionRecordId: 'fl_pilot_execution_demo_1',
      runtimeTarget: 'flutter_mobile',
      targetSiteIds: ['site1'],
      status: 'assigned',
      packageDigest: 'sha256:pkg-demo-1',
      manifestDigest: 'sha256:delivery-demo-1',
      notes: 'Bounded runtime-delivery manifest assigned to the approved pilot site.',
      assignedBy: hqUser.uid,
      assignedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await setDoc(doc(db, 'federatedLearningRuntimeActivationRecords', 'fl_activation_demo_1'), {
      deliveryRecordId: 'fl_delivery_demo_1',
      experimentId: 'fl_exp_literacy_pilot',
      candidateModelPackageId: 'fl_pkg_demo_1',
      siteId: 'site1',
      runtimeTarget: 'flutter_mobile',
      manifestDigest: 'sha256:delivery-demo-1',
      status: 'resolved',
      traceId: 'activation-trace-1',
      notes: 'Site runtime resolved the bounded manifest assignment for review.',
      reportedBy: siteAdminUser.uid,
      reportedAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });
  });
});

describe('Users Collection', () => {
  test('user can read their own profile', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', educatorUser.uid)));
  });

  test('user cannot read other user profile (unless educator)', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'users', learnerUser.uid)));
  });

  test('educator can read same-site profiles only', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', learnerUser.uid)));
    await assertFails(getDoc(doc(db, 'users', otherSiteUser.uid)));
  });

  test('site admin can read same-site profiles and HQ can read all profiles', async () => {
    const siteDb = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertSucceeds(getDoc(doc(siteDb, 'users', learnerUser.uid)));
    await assertFails(getDoc(doc(siteDb, 'users', otherSiteUser.uid)));
    await assertSucceeds(getDoc(doc(hqDb, 'users', otherSiteUser.uid)));
  });

  test('user can update their own profile', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', educatorUser.uid), {
      displayName: 'Updated Name',
    }));
  });

  test('user cannot update other profiles (unless HQ)', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(updateDoc(doc(db, 'users', learnerUser.uid), {
      displayName: 'Hacked Name',
    }));
  });

  test('HQ can update any user profile', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', learnerUser.uid), {
      displayName: 'HQ Updated Name',
    }));
  });
});

describe('Sites Collection', () => {
  test('authenticated user can read sites', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'sites', 'site1')));
  });

  test('authenticated user cannot read unrelated site by id', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'sites', 'site1')));
  });

  test('unauthenticated cannot read sites', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'sites', 'site1')));
  });

  test('only HQ can create sites', async () => {
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(setDoc(doc(hqDb, 'sites', 'site3'), {
      name: 'New Site',
      status: 'active',
    }));

    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(setDoc(doc(educatorDb, 'sites', 'site4'), {
      name: 'Unauthorized Site',
      status: 'active',
    }));
  });
});

describe('Attendance Collection', () => {
  test('learner can read their own attendance', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'attendanceRecords', 'att-1')));
  });

  test('educator can read any attendance', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'attendanceRecords', 'att-1')));
  });

  test('parent cannot read attendance directly', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'attendanceRecords', 'att-1')));
  });

  test('only educators can write attendance', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(setDoc(doc(educatorDb, 'attendanceRecords', 'att-2'), {
      siteId: 'site1',
      occurrenceId: 'occ-1',
      userId: learnerUser.uid,
      status: 'late',
    }));

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(setDoc(doc(learnerDb, 'attendanceRecords', 'att-3'), {
      siteId: 'site1',
      occurrenceId: 'occ-1',
      userId: learnerUser.uid,
      status: 'present',
    }));
  });

  test('educator cannot write attendance without siteId', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(setDoc(doc(educatorDb, 'attendanceRecords', 'att-nosite'), {
      occurrenceId: 'occ-1',
      userId: learnerUser.uid,
      status: 'present',
    }));
  });
});

describe('Cross-Site Access Denial', () => {
  test('educator from site2 cannot access site1 attendance', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'attendanceRecords', 'att-1')));
  });

  test('educator from site2 cannot access site1 checkins', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'checkins', 'checkin-1')));
  });

  test('educator from site2 cannot access site1 support interventions', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'supportInterventions', 'support-1')));
  });
});

describe('Checkins Collection', () => {
  test('educator can create checkin in accessible site', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'checkins', 'checkin-2'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      learnerName: 'Learner One',
      status: 'completed',
      type: 'checkin',
    }));
  });

  test('learner cannot create checkin directly', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'checkins', 'checkin-3'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      learnerName: 'Learner One',
      status: 'completed',
      type: 'checkin',
    }));
  });

  test('learner can read own checkin record', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'checkins', 'checkin-1')));
  });
});

describe('Educator Learner Links Collection', () => {
  test('educator can read own link', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'educatorLearnerLinks', 'link-1')));
  });

  test('other educator cannot read link they do not own', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'educatorLearnerLinks', 'link-1')));
  });

  test('hq can read educator learner links', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'educatorLearnerLinks', 'link-1')));
  });

  test('educator can create own link', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'educatorLearnerLinks', 'link-2'), {
      siteId: 'site1',
      educatorId: educatorUser.uid,
      learnerId: learnerUser.uid,
      status: 'active',
    }));
  });

  test('educator cannot create link for different educator id', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'educatorLearnerLinks', 'link-3'), {
      siteId: 'site1',
      educatorId: otherSiteUser.uid,
      learnerId: learnerUser.uid,
      status: 'active',
    }));
  });

  test('educator learner links require site scope for read and write', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertFails(setDoc(doc(educatorDb, 'educatorLearnerLinks', 'link-missing-site'), {
      educatorId: educatorUser.uid,
      learnerId: learnerUser.uid,
      status: 'active',
    }));
    await assertFails(setDoc(doc(educatorDb, 'educatorLearnerLinks', 'link-wrong-site'), {
      siteId: 'site2',
      educatorId: educatorUser.uid,
      learnerId: learnerUser.uid,
      status: 'active',
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'educatorLearnerLinks', 'link-1'), {
      status: 'inactive',
    }));
  });
});

describe('Learner and Guardian Profile Collections', () => {
  test('learner profiles require site scope for read and writes', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerProfiles', 'learner-profile-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerProfiles', 'learner-profile-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'learnerProfiles', 'learner-profile-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerProfiles', 'learner-profile-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerProfiles', 'learner-profile-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerProfiles', 'learner-profile-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'learnerProfiles', 'learner-profile-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      preferredName: 'New Learner Profile',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerProfiles', 'learner-profile-missing-site'), {
      learnerId: learnerUser.uid,
      preferredName: 'Missing Site Learner Profile',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'learnerProfiles', 'learner-profile-site1'), {
      siteId: 'site2',
    }));
  });

  test('parent profiles require site scope for read and writes', async () => {
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(parentDb, 'parentProfiles', 'parent-profile-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'parentProfiles', 'parent-profile-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'parentProfiles', 'parent-profile-site1')));
    await assertFails(getDoc(doc(parentDb, 'parentProfiles', 'parent-profile-nosite')));
    await assertFails(getDoc(doc(parentDb, 'parentProfiles', 'parent-profile-site2')));

    await assertSucceeds(setDoc(doc(parentDb, 'parentProfiles', 'parent-profile-new'), {
      siteId: 'site1',
      parentId: parentUser.uid,
      preferredName: 'New Parent Profile',
    }));
    await assertFails(setDoc(doc(parentDb, 'parentProfiles', 'parent-profile-missing-site'), {
      parentId: parentUser.uid,
      preferredName: 'Missing Site Parent Profile',
    }));
    await assertFails(updateDoc(doc(parentDb, 'parentProfiles', 'parent-profile-site1'), {
      siteId: 'site2',
    }));
  });

  test('guardian links require site scope for read and writes', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'guardianLinks', 'guardian-link-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'guardianLinks', 'guardian-link-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'guardianLinks', 'guardian-link-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'guardianLinks', 'guardian-link-site1')));
    await assertFails(getDoc(doc(parentDb, 'guardianLinks', 'guardian-link-nosite')));
    await assertFails(getDoc(doc(parentDb, 'guardianLinks', 'guardian-link-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'guardianLinks', 'guardian-link-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      parentId: parentUser.uid,
      relationship: 'parent',
    }));
    await assertFails(setDoc(doc(educatorDb, 'guardianLinks', 'guardian-link-missing-site'), {
      learnerId: learnerUser.uid,
      parentId: parentUser.uid,
      relationship: 'parent',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'guardianLinks', 'guardian-link-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Support Interventions Collection', () => {
  test('educator can read site-scoped support interventions', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'supportInterventions', 'support-1')));
  });

  test('hq can read support interventions', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'supportInterventions', 'support-1')));
  });

  test('educator cannot write support interventions directly', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'supportInterventions', 'support-2'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      strategyType: 'autonomy',
      strategyDescription: 'Direct write attempt',
      context: 'individual',
      outcome: 'helped',
    }));
  });
});

describe('Legacy Operational User Boundary Collections', () => {
  test('accountability commitments require site scope and preserve learner cycle identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'accountabilityCommitments', 'commitment-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'accountabilityCommitments', 'commitment-site1')));
    await assertFails(getDoc(doc(learnerDb, 'accountabilityCommitments', 'commitment-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'accountabilityCommitments', 'commitment-site2')));
    await assertSucceeds(setDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-new'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      userId: learnerUser.uid,
      role: 'learner',
      statement: 'I will collect evidence before reflection.',
      pillarCodes: ['future-skills'],
    }));
    await assertFails(setDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-missing-site'), {
      cycleId: 'cycle-site1',
      userId: learnerUser.uid,
      role: 'learner',
      statement: 'Missing site commitment.',
      pillarCodes: ['future-skills'],
    }));
    await assertFails(setDoc(doc(learnerDb, 'accountabilityCommitments', 'commitment-learner-write'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      userId: learnerUser.uid,
      role: 'learner',
      statement: 'Learner direct write.',
      pillarCodes: ['future-skills'],
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-site1'), {
      statement: 'Updated commitment statement.',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-site1'), {
      siteId: 'site2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-site1'), {
      cycleId: 'cycle-site2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityCommitments', 'commitment-site1'), {
      userId: educatorUser.uid,
    }));
  });

  test('accountability reviews require site scope and preserve reviewer provenance', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'accountabilityReviews', 'review-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'accountabilityReviews', 'review-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'accountabilityReviews', 'review-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'accountabilityReviews', 'review-site1')));
    await assertFails(getDoc(doc(learnerDb, 'accountabilityReviews', 'review-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'accountabilityReviews', 'review-site2')));
    await assertSucceeds(setDoc(doc(educatorDb, 'accountabilityReviews', 'review-new'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      reviewerId: educatorUser.uid,
      revieweeId: learnerUser.uid,
      notes: 'New review.',
      rating: 3,
    }));
    await assertFails(setDoc(doc(educatorDb, 'accountabilityReviews', 'review-missing-site'), {
      cycleId: 'cycle-site1',
      reviewerId: educatorUser.uid,
      revieweeId: learnerUser.uid,
      notes: 'Missing site review.',
      rating: 3,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'accountabilityReviews', 'review-site1'), {
      notes: 'Updated review notes.',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityReviews', 'review-site1'), {
      siteId: 'site2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityReviews', 'review-site1'), {
      cycleId: 'cycle-site2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityReviews', 'review-site1'), {
      reviewerId: hqUser.uid,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityReviews', 'review-site1'), {
      revieweeId: educatorUser.uid,
    }));
  });

  test('autonomy interventions require site scope and educator ownership', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'autonomyInterventions', 'autonomy-intervention-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'autonomyInterventions', 'autonomy-intervention-site1')));
    await assertFails(getDoc(doc(learnerDb, 'autonomyInterventions', 'autonomy-intervention-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'autonomyInterventions', 'autonomy-intervention-site1')));
    await assertFails(getDoc(doc(educatorDb, 'autonomyInterventions', 'autonomy-intervention-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'autonomyInterventions', 'autonomy-intervention-site2')));
    await assertSucceeds(setDoc(doc(educatorDb, 'autonomyInterventions', 'autonomy-intervention-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      interventionType: 'scaffold',
      salience: 'medium',
      totalRiskScore: 0.7,
      reasonCodes: ['repeated_hints_no_attempt'],
    }));
    await assertFails(setDoc(doc(learnerDb, 'autonomyInterventions', 'autonomy-intervention-learner'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      interventionType: 'scaffold',
      salience: 'medium',
      totalRiskScore: 0.7,
      reasonCodes: ['repeated_hints_no_attempt'],
    }));
    await assertFails(setDoc(doc(educatorDb, 'autonomyInterventions', 'autonomy-intervention-missing-site'), {
      learnerId: learnerUser.uid,
      interventionType: 'scaffold',
      salience: 'medium',
      totalRiskScore: 0.7,
      reasonCodes: ['repeated_hints_no_attempt'],
    }));
    await assertFails(updateDoc(doc(educatorDb, 'autonomyInterventions', 'autonomy-intervention-site1'), {
      salience: 'high',
    }));
  });

  test('announcements require site scope and preserve site identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'announcements', 'announcement-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'announcements', 'announcement-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'announcements', 'announcement-site1')));
    await assertFails(getDoc(doc(learnerDb, 'announcements', 'announcement-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'announcements', 'announcement-site2')));
    await assertSucceeds(setDoc(doc(educatorDb, 'announcements', 'announcement-new'), {
      siteId: 'site1',
      title: 'New studio update',
      body: 'Bring portfolio evidence.',
      roles: ['learner'],
    }));
    await assertFails(setDoc(doc(educatorDb, 'announcements', 'announcement-missing-site'), {
      title: 'Missing site update',
      body: 'No site scope.',
      roles: ['learner'],
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'announcements', 'announcement-site1'), {
      body: 'Updated announcement.',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'announcements', 'announcement-site1'), {
      siteId: 'site2',
    }));
    await assertSucceeds(deleteDoc(doc(hqDb, 'announcements', 'announcement-site1')));
  });

  test('direct telemetry events require site scope and learner event ownership', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'telemetryEvents', 'telemetry-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'telemetryEvents', 'telemetry-site1')));
    await assertFails(getDoc(doc(learnerDb, 'telemetryEvents', 'telemetry-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'telemetryEvents', 'telemetry-site1')));
    await assertFails(getDoc(doc(educatorDb, 'telemetryEvents', 'telemetry-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'telemetryEvents', 'telemetry-site2')));
    await assertSucceeds(setDoc(doc(learnerDb, 'telemetryEvents', 'telemetry-new'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      event: 'checkpoint_submitted',
      category: 'competence',
    }));
    await assertFails(setDoc(doc(learnerDb, 'telemetryEvents', 'telemetry-missing-site'), {
      userId: learnerUser.uid,
      event: 'checkpoint_submitted',
      category: 'competence',
    }));
    await assertFails(setDoc(doc(learnerDb, 'telemetryEvents', 'telemetry-spoof-user'), {
      siteId: 'site1',
      userId: educatorUser.uid,
      event: 'checkpoint_submitted',
      category: 'competence',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'telemetryEvents', 'telemetry-site1'), {
      event: 'checkpoint_graded',
    }));
  });

  test('presence records require site scope and preserve user identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'presenceRecords', 'presence-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'presenceRecords', 'presence-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'presenceRecords', 'presence-site1')));
    await assertFails(getDoc(doc(learnerDb, 'presenceRecords', 'presence-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'presenceRecords', 'presence-site2')));
    await assertSucceeds(setDoc(doc(learnerDb, 'presenceRecords', 'presence-new'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      status: 'online',
    }));
    await assertFails(setDoc(doc(learnerDb, 'presenceRecords', 'presence-missing-site'), {
      userId: learnerUser.uid,
      status: 'online',
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'presenceRecords', 'presence-site1'), {
      status: 'away',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'presenceRecords', 'presence-site1'), {
      userId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'presenceRecords', 'presence-site1'), {
      siteId: 'site2',
    }));
  });

  test('drafts require site scope and preserve user identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'drafts', 'draft-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'drafts', 'draft-site1')));
    await assertFails(getDoc(doc(learnerDb, 'drafts', 'draft-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'drafts', 'draft-site2')));
    await assertSucceeds(setDoc(doc(learnerDb, 'drafts', 'draft-new'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      title: 'New draft',
      body: 'Draft body',
    }));
    await assertFails(setDoc(doc(learnerDb, 'drafts', 'draft-missing-site'), {
      userId: learnerUser.uid,
      title: 'Missing site draft',
      body: 'Draft body',
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'drafts', 'draft-site1'), {
      body: 'Updated draft body',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'drafts', 'draft-site1'), {
      userId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'drafts', 'draft-site1'), {
      siteId: 'site2',
    }));
    await assertSucceeds(deleteDoc(doc(learnerDb, 'drafts', 'draft-site1')));
  });

  test('offline demo actions require site scope and preserve user identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'offlineDemoActions', 'offline-action-site1')));
    await assertFails(getDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-site2')));
    await assertSucceeds(setDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-new'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      actionType: 'queued_reflection',
    }));
    await assertFails(setDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-missing-site'), {
      userId: learnerUser.uid,
      actionType: 'queued_reflection',
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-site1'), {
      actionType: 'synced_reflection',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-site1'), {
      userId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'offlineDemoActions', 'offline-action-site1'), {
      siteId: 'site2',
    }));
  });

  test('analytics events require site scope and learner event ownership', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'analyticsEvents', 'analytics-event-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'analyticsEvents', 'analytics-event-site1')));
    await assertFails(getDoc(doc(learnerDb, 'analyticsEvents', 'analytics-event-site1')));
    await assertFails(getDoc(doc(educatorDb, 'analyticsEvents', 'analytics-event-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'analyticsEvents', 'analytics-event-site2')));
    await assertSucceeds(setDoc(doc(learnerDb, 'analyticsEvents', 'analytics-event-new'), {
      siteId: 'site1',
      event_id: 'analytics-event-new',
      event_name: 'checkpoint_submitted',
      class_id: 'site1',
      student_id: learnerUser.uid,
      source_screen: 'checkpoint',
    }));
    await assertFails(setDoc(doc(learnerDb, 'analyticsEvents', 'analytics-event-missing-site'), {
      event_id: 'analytics-event-missing-site',
      event_name: 'checkpoint_submitted',
      class_id: 'site1',
      student_id: learnerUser.uid,
      source_screen: 'checkpoint',
    }));
    await assertFails(setDoc(doc(learnerDb, 'analyticsEvents', 'analytics-event-other-student'), {
      siteId: 'site1',
      event_id: 'analytics-event-other-student',
      event_name: 'checkpoint_submitted',
      class_id: 'site1',
      student_id: 'learner-2',
      source_screen: 'checkpoint',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'analyticsEvents', 'analytics-event-site1'), {
      event_name: 'changed',
    }));
  });
});

describe('Interaction Events Collection', () => {
  async function seedInteractionEvents() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'interactionEvents', 'event-site1'), {
        siteId: 'site1',
        actorId: learnerUser.uid,
        eventType: 'ai_help_opened',
        createdAt: Date.now(),
      });
      await setDoc(doc(db, 'interactionEvents', 'event-site2'), {
        siteId: 'site2',
        actorId: 'learner-site2',
        eventType: 'ai_help_opened',
        createdAt: Date.now(),
      });
      await setDoc(doc(db, 'interactionEvents', 'event-nosite'), {
        actorId: learnerUser.uid,
        eventType: 'ai_help_opened',
        createdAt: Date.now(),
      });
    });
  }

  test('educator can read same-site MiloOS support events', async () => {
    await seedInteractionEvents();
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'interactionEvents', 'event-site1')));
    await assertSucceeds(
      getDocs(query(collection(db, 'interactionEvents'), where('siteId', '==', 'site1')))
    );
  });

  test('site admin can read same-site MiloOS support events for implementation health', async () => {
    await seedInteractionEvents();
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'interactionEvents', 'event-site1')));
    await assertSucceeds(
      getDocs(query(collection(db, 'interactionEvents'), where('siteId', '==', 'site1')))
    );
  });

  test('educator cannot read other-site or missing-site interaction events', async () => {
    await seedInteractionEvents();
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'interactionEvents', 'event-site2')));
    await assertFails(getDoc(doc(db, 'interactionEvents', 'event-nosite')));
  });

  test('site admin cannot read other-site or missing-site interaction events', async () => {
    await seedInteractionEvents();
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'interactionEvents', 'event-site2')));
    await assertFails(getDoc(doc(db, 'interactionEvents', 'event-nosite')));
  });

  test('linked parent cannot read raw MiloOS interaction events directly', async () => {
    await seedInteractionEvents();
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'interactionEvents', 'event-site1')));
    await assertFails(
      getDocs(query(collection(db, 'interactionEvents'), where('siteId', '==', 'site1')))
    );
  });

  test('unlinked parent cannot read raw MiloOS interaction events directly', async () => {
    await seedInteractionEvents();
    const db = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'interactionEvents', 'event-site1')));
    await assertFails(
      getDocs(query(collection(db, 'interactionEvents'), where('siteId', '==', 'site1')))
    );
  });
});

describe('Federated Learning Prototype Collections', () => {
  test('HQ can read federated learning experiments', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningExperiments', 'fl_exp_literacy_pilot')),
    );
  });

  test('site admin can read enrolled federated learning experiments', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningExperiments', 'fl_exp_literacy_pilot')),
    );
  });

  test('site admin can query enrolled federated learning experiments by cohort', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningExperiments'),
          where('allowedSiteIds', 'array-contains', 'site1'),
        ),
      ),
    );
  });

  test('site admin cannot query all federated learning experiments across sites', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDocs(collection(db, 'federatedLearningExperiments')),
    );
  });

  test('site admin cannot read other site federated learning experiments', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningExperiments', 'fl_exp_other_site')),
    );
  });

  test('HQ can read federated learning experiment review records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningExperimentReviewRecords', 'fl_review_literacy_pilot')),
    );
  });

  test('HQ can query federated learning experiment review records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningExperimentReviewRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read federated learning experiment review records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningExperimentReviewRecords', 'fl_review_literacy_pilot')),
    );
  });

  test('site admins cannot query federated learning experiment review records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDocs(collection(db, 'federatedLearningExperimentReviewRecords')),
    );
  });

  test('site admin can read prototype update summaries for their site', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningUpdateSummaries', 'fl_update_1')),
    );
  });

  test('site admin can query prototype update summaries for their site', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningUpdateSummaries'),
          where('siteId', '==', 'site1'),
        ),
      ),
    );
  });

  test('parents cannot read federated learning update summaries', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningUpdateSummaries', 'fl_update_1')),
    );
  });

  test('site admins cannot write federated learning update summaries directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      setDoc(doc(db, 'federatedLearningUpdateSummaries', 'fl_update_2'), {
        experimentId: 'fl_exp_literacy_pilot',
        siteId: 'site1',
        traceId: 'trace-2',
        schemaVersion: 'v1',
        sampleCount: 12,
        vectorLength: 64,
        payloadBytes: 1024,
        updateNorm: 2.4,
        payloadDigest: 'digest-2',
        batteryState: 'ok',
        networkType: 'wifi',
      }),
    );
  });

  test('HQ can read materialized federated aggregation runs', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningAggregationRuns', 'fl_agg_demo_1')),
    );
  });

  test('HQ can query materialized federated aggregation runs', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningAggregationRuns'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read cross-site aggregation runs directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningAggregationRuns', 'fl_agg_demo_1')),
    );
  });

  test('site admins cannot query aggregation runs directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDocs(collection(db, 'federatedLearningAggregationRuns')));
  });

  test('HQ can read bounded merge artifacts', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningMergeArtifacts', 'fl_merge_demo_1')),
    );
  });

  test('HQ can query bounded merge artifacts', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningMergeArtifacts'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read merge artifacts directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningMergeArtifacts', 'fl_merge_demo_1')),
    );
  });

  test('site admins cannot query merge artifacts directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDocs(collection(db, 'federatedLearningMergeArtifacts')));
  });

  test('HQ can read bounded candidate model packages', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningCandidateModelPackages', 'fl_pkg_demo_1')),
    );
  });

  test('HQ can query bounded candidate model packages', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningCandidateModelPackages'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read candidate model packages directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningCandidateModelPackages', 'fl_pkg_demo_1')),
    );
  });

  test('site admins cannot query candidate model packages directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDocs(collection(db, 'federatedLearningCandidateModelPackages')),
    );
  });

  test('HQ can read candidate promotion records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningCandidatePromotionRecords', 'fl_prom_demo_1')),
    );
  });

  test('HQ can query candidate promotion records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningCandidatePromotionRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read candidate promotion records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningCandidatePromotionRecords', 'fl_prom_demo_1')),
    );
  });

  test('site admins cannot query candidate promotion records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDocs(collection(db, 'federatedLearningCandidatePromotionRecords')),
    );
  });

  test('HQ can read candidate promotion revocation records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningCandidatePromotionRevocationRecords', 'fl_prom_revoke_demo_1')),
    );
  });

  test('HQ can query candidate promotion revocation records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningCandidatePromotionRevocationRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read candidate promotion revocation records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningCandidatePromotionRevocationRecords', 'fl_prom_revoke_demo_1')),
    );
  });

  test('site admins cannot query candidate promotion revocation records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDocs(collection(db, 'federatedLearningCandidatePromotionRevocationRecords')),
    );
  });

  test('HQ can read pilot evidence records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningPilotEvidenceRecords', 'fl_pilot_demo_1')),
    );
  });

  test('HQ can query pilot evidence records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningPilotEvidenceRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read pilot evidence records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningPilotEvidenceRecords', 'fl_pilot_demo_1')),
    );
  });

  test('site admins cannot query pilot evidence records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDocs(collection(db, 'federatedLearningPilotEvidenceRecords')));
  });

  test('HQ can read pilot approval records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningPilotApprovalRecords', 'fl_pilot_approval_demo_1')),
    );
  });

  test('HQ can query pilot approval records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningPilotApprovalRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read pilot approval records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningPilotApprovalRecords', 'fl_pilot_approval_demo_1')),
    );
  });

  test('site admins cannot query pilot approval records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDocs(collection(db, 'federatedLearningPilotApprovalRecords')));
  });

  test('HQ can read pilot execution records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningPilotExecutionRecords', 'fl_pilot_execution_demo_1')),
    );
  });

  test('HQ can query pilot execution records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningPilotExecutionRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read pilot execution records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningPilotExecutionRecords', 'fl_pilot_execution_demo_1')),
    );
  });

  test('site admins cannot query pilot execution records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDocs(collection(db, 'federatedLearningPilotExecutionRecords')));
  });

  test('HQ can read runtime delivery records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningRuntimeDeliveryRecords', 'fl_delivery_demo_1')),
    );
  });

  test('HQ can query runtime delivery records newest-first', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningRuntimeDeliveryRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('updatedAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read runtime delivery records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningRuntimeDeliveryRecords', 'fl_delivery_demo_1')),
    );
  });

  test('site admins cannot query runtime delivery records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDocs(collection(db, 'federatedLearningRuntimeDeliveryRecords')),
    );
  });

  test('HQ can read runtime activation records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningRuntimeActivationRecords', 'fl_activation_demo_1')),
    );
  });

  test('HQ can query runtime activation records', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'federatedLearningRuntimeActivationRecords'),
          where('experimentId', '==', 'fl_exp_literacy_pilot'),
          orderBy('updatedAt', 'desc'),
        ),
      ),
    );
  });

  test('site admins cannot read runtime activation records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningRuntimeActivationRecords', 'fl_activation_demo_1')),
    );
  });

  test('site admins cannot query runtime activation records directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(getDocs(collection(db, 'federatedLearningRuntimeActivationRecords')));
  });
});

describe('Mission Attempts', () => {
  test('learner can create their own attempt', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'missionAttempts', 'attempt-1'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'draft',
    }));
  });

  test('learner cannot create attempt for another learner', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'missionAttempts', 'attempt-2'), {
      learnerId: 'other-learner',
      missionId: 'mission-1',
      status: 'draft',
    }));
  });

  test('mission attempts require site scope for read and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'missionAttempts', 'attempt-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'missionAttempts', 'attempt-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'missionAttempts', 'attempt-site1')));
    await assertFails(getDoc(doc(learnerDb, 'missionAttempts', 'attempt-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'missionAttempts', 'attempt-site2')));

    await assertFails(setDoc(doc(learnerDb, 'missionAttempts', 'attempt-missing-site'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'draft',
    }));
    await assertFails(setDoc(doc(learnerDb, 'missionAttempts', 'attempt-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      missionId: 'mission-1',
      status: 'draft',
    }));
  });

  test('mission attempt updates cannot cross or remove site scope', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'missionAttempts', 'attempt-site1'), {
      status: 'revised',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'missionAttempts', 'attempt-site1'), {
      feedback: 'Reviewed by same-site educator.',
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'missionAttempts', 'attempt-site1'), {
      feedback: 'Wrong site review.',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'missionAttempts', 'attempt-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Checkpoint History', () => {
  test('checkpoint history requires site scope for read and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'checkpointHistory', 'checkpoint-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'checkpointHistory', 'checkpoint-site1')));
    await assertFails(getDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      checkpointDefinitionId: 'checkpoint-2',
      status: 'submitted',
    }));
    await assertFails(setDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-missing-site'), {
      learnerId: learnerUser.uid,
      checkpointDefinitionId: 'checkpoint-2',
      status: 'submitted',
    }));
    await assertFails(setDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      checkpointDefinitionId: 'checkpoint-2',
      status: 'submitted',
    }));
  });

  test('checkpoint history updates stay same-site educator owned', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(educatorDb, 'checkpointHistory', 'checkpoint-site1'), {
      feedback: 'Reviewed by same-site educator.',
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'checkpointHistory', 'checkpoint-site1'), {
      feedback: 'Wrong site review.',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'checkpointHistory', 'checkpoint-site1'), {
      feedback: 'Learner cannot self-review.',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'checkpointHistory', 'checkpoint-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Skill Evidence', () => {
  test('skill evidence requires site scope for read and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'skillEvidence', 'skill-evidence-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'skillEvidence', 'skill-evidence-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'skillEvidence', 'skill-evidence-site1')));
    await assertFails(getDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      microSkillId: 'skill-2',
      evidenceType: 'quiz',
      status: 'submitted',
    }));
    await assertFails(setDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-missing-site'), {
      learnerId: learnerUser.uid,
      microSkillId: 'skill-2',
      evidenceType: 'quiz',
      status: 'submitted',
    }));
    await assertFails(setDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      microSkillId: 'skill-2',
      evidenceType: 'quiz',
      status: 'submitted',
    }));
  });

  test('skill evidence updates stay same-site educator owned', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(educatorDb, 'skillEvidence', 'skill-evidence-site1'), {
      status: 'reviewed',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'skillEvidence', 'skill-evidence-site1'), {
      status: 'self-reviewed',
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'skillEvidence', 'skill-evidence-site1'), {
      status: 'wrong-site-reviewed',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'skillEvidence', 'skill-evidence-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Learner Reflections', () => {
  test('learner reflections require site scope for read and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerReflections', 'reflection-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerReflections', 'reflection-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerReflections', 'reflection-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerReflections', 'reflection-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerReflections', 'reflection-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'learnerReflections', 'reflection-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      content: 'New site-scoped reflection',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerReflections', 'reflection-missing-site'), {
      learnerId: learnerUser.uid,
      content: 'Missing site reflection',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerReflections', 'reflection-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      content: 'Wrong-site reflection',
    }));
  });

  test('learner reflection updates cannot cross or remove site scope', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'learnerReflections', 'reflection-site1'), {
      content: 'Revised reflection',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerReflections', 'reflection-site1'), {
      content: 'Educator cannot edit learner reflection',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'learnerReflections', 'reflection-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Metacognitive Calibration Records', () => {
  test('calibration records require site scope for read and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'metacognitiveCalibrationRecords', 'calibration-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'metacognitiveCalibrationRecords', 'calibration-site1')));
    await assertFails(getDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sourceType: 'checkpoint',
      sourceId: 'checkpoint-new',
      confidenceLevel: 3,
    }));
    await assertFails(setDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-missing-site'), {
      learnerId: learnerUser.uid,
      sourceType: 'checkpoint',
      sourceId: 'checkpoint-new',
      confidenceLevel: 3,
    }));
    await assertFails(setDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      sourceType: 'checkpoint',
      sourceId: 'checkpoint-new',
      confidenceLevel: 3,
    }));
  });

  test('calibration record updates cannot cross or remove site scope', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-site1'), {
      confidenceLevel: 4,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'metacognitiveCalibrationRecords', 'calibration-site1'), {
      educatorNote: 'Reviewed calibration.',
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'metacognitiveCalibrationRecords', 'calibration-site1'), {
      educatorNote: 'Wrong site review.',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'metacognitiveCalibrationRecords', 'calibration-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Habits Collection', () => {
  test('habits require site scope for read and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'habits', 'habit-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'habits', 'habit-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'habits', 'habit-site1')));
    await assertFails(getDoc(doc(learnerDb, 'habits', 'habit-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'habits', 'habit-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'habits', 'habit-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'New learning habit',
      isActive: true,
    }));
    await assertFails(setDoc(doc(learnerDb, 'habits', 'habit-missing-site'), {
      learnerId: learnerUser.uid,
      title: 'Missing site learning habit',
      isActive: true,
    }));
    await assertFails(setDoc(doc(learnerDb, 'habits', 'habit-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Wrong-site learning habit',
      isActive: true,
    }));
  });

  test('habit updates cannot cross or remove site scope', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'habits', 'habit-site1'), {
      currentStreak: 2,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'habits', 'habit-site1'), {
      reviewedBy: educatorUser.uid,
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'habits', 'habit-site1'), {
      reviewedBy: otherSiteUser.uid,
    }));
    await assertFails(updateDoc(doc(learnerDb, 'habits', 'habit-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Motivation Learner Boundary Collections', () => {
  test('habit logs require site scope and preserve learner habit identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'habitLogs', 'habit-log-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'habitLogs', 'habit-log-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'habitLogs', 'habit-log-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'habitLogs', 'habit-log-site1')));
    await assertFails(getDoc(doc(learnerDb, 'habitLogs', 'habit-log-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'habitLogs', 'habit-log-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'habitLogs', 'habit-log-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      habitId: 'habit-site1',
      durationMinutes: 10,
    }));
    await assertFails(setDoc(doc(learnerDb, 'habitLogs', 'habit-log-missing-site'), {
      learnerId: learnerUser.uid,
      habitId: 'habit-site1',
      durationMinutes: 10,
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'habitLogs', 'habit-log-site1'), {
      durationMinutes: 15,
    }));
    await assertFails(updateDoc(doc(learnerDb, 'habitLogs', 'habit-log-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'habitLogs', 'habit-log-site1'), {
      habitId: 'habit-site2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'habitLogs', 'habit-log-site1'), {
      siteId: 'site2',
    }));
  });

  test('learner badges require site scope and educator awarding', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerBadges', 'badge-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerBadges', 'badge-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'learnerBadges', 'badge-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerBadges', 'badge-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerBadges', 'badge-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerBadges', 'badge-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'learnerBadges', 'badge-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      badgeId: 'capability-evidence-review',
      reason: 'Reviewed evidence milestone',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerBadges', 'badge-self-awarded'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      badgeId: 'self-awarded',
      reason: 'I gave this to myself',
    }));
    await assertFails(setDoc(doc(educatorDb, 'learnerBadges', 'badge-missing-site'), {
      learnerId: learnerUser.uid,
      badgeId: 'missing-site',
      reason: 'Missing site badge',
    }));
  });

  test('motivation analytics require site scope and remain server-owned', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'motivationAnalytics', 'motivation-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'motivationAnalytics', 'motivation-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'motivationAnalytics', 'motivation-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'motivationAnalytics', 'motivation-site1')));
    await assertFails(getDoc(doc(learnerDb, 'motivationAnalytics', 'motivation-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'motivationAnalytics', 'motivation-site2')));
    await assertFails(setDoc(doc(learnerDb, 'motivationAnalytics', 'motivation-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      totalEvidenceSubmitted: 1,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'motivationAnalytics', 'motivation-site1'), {
      totalEvidenceSubmitted: 4,
    }));
  });

  test('learner choice history requires site scope and preserves learner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerChoiceHistory', 'choice-history-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'learnerChoiceHistory', 'choice-history-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerChoiceHistory', 'choice-history-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      selections: { 'mission-2': { difficulty: 'SILVER' } },
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-missing-site'), {
      learnerId: learnerUser.uid,
      selections: { 'mission-2': { difficulty: 'SILVER' } },
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-site1'), {
      selections: { 'mission-1': { difficulty: 'SILVER', reason: 'Updated choice' } },
    }));
    await assertFails(updateDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'learnerChoiceHistory', 'choice-history-site1'), {
      siteId: 'site2',
    }));
  });

  test('session reflections require site scope and preserve session identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'sessionReflections', 'session-reflection-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'sessionReflections', 'session-reflection-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'sessionReflections', 'session-reflection-site1')));
    await assertFails(getDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sessionId: 'session-1',
      effortRating: 4,
    }));
    await assertFails(setDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-missing-site'), {
      learnerId: learnerUser.uid,
      sessionId: 'session-1',
      effortRating: 4,
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-site1'), {
      effortRating: 5,
    }));
    await assertFails(updateDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-site1'), {
      sessionId: 'session-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'sessionReflections', 'session-reflection-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Learner Motivation Profile Collections', () => {
  test('learner goals require site scope for read, query, and create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerGoals', 'goal-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerGoals', 'goal-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'learnerGoals', 'goal-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerGoals', 'goal-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerGoals', 'goal-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerGoals', 'goal-site2')));

    await assertSucceeds(getDocs(query(
      collection(learnerDb, 'learnerGoals'),
      where('learnerId', '==', learnerUser.uid),
      where('siteId', '==', 'site1')
    )));

    await assertSucceeds(setDoc(doc(learnerDb, 'learnerGoals', 'goal-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      goalType: 'skill_mastery',
      description: 'New site-scoped learner goal',
      progress: 0,
      status: 'active',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerGoals', 'goal-missing-site'), {
      learnerId: learnerUser.uid,
      goalType: 'skill_mastery',
      description: 'Missing site learner goal',
      progress: 0,
      status: 'active',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerGoals', 'goal-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      goalType: 'skill_mastery',
      description: 'Wrong-site learner goal',
      progress: 0,
      status: 'active',
    }));
  });

  test('learner goal updates cannot cross or remove site scope', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'learnerGoals', 'goal-site1'), {
      progress: 40,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerGoals', 'goal-site1'), {
      progress: 50,
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'learnerGoals', 'goal-site1'), {
      progress: 50,
    }));
    await assertFails(updateDoc(doc(learnerDb, 'learnerGoals', 'goal-site1'), {
      siteId: 'site2',
    }));
  });

  test('learner interest profiles require site scope for read and writes', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerInterestProfiles', 'interest-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerInterestProfiles', 'interest-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'learnerInterestProfiles', 'interest-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerInterestProfiles', 'interest-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerInterestProfiles', 'interest-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerInterestProfiles', 'interest-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'learnerInterestProfiles', 'interest-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      interests: ['design'],
      preferredDifficulty: 'medium',
      preferredWorkStyle: 'paired',
    }));
    await assertFails(setDoc(doc(learnerDb, 'learnerInterestProfiles', 'interest-missing-site'), {
      learnerId: learnerUser.uid,
      interests: ['design'],
      preferredDifficulty: 'medium',
      preferredWorkStyle: 'paired',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'learnerInterestProfiles', 'interest-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Skill Mastery Collection', () => {
  test('skill mastery requires site scope for read and educator create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'skillMastery', 'skill-mastery-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'skillMastery', 'skill-mastery-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'skillMastery', 'skill-mastery-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'skillMastery', 'skill-mastery-site1')));
    await assertFails(getDoc(doc(learnerDb, 'skillMastery', 'skill-mastery-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'skillMastery', 'skill-mastery-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'skillMastery', 'skill-mastery-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      skillId: 'skill-2',
      level: 2,
    }));
    await assertFails(setDoc(doc(educatorDb, 'skillMastery', 'skill-mastery-missing-site'), {
      learnerId: learnerUser.uid,
      skillId: 'skill-2',
      level: 2,
    }));
    await assertFails(setDoc(doc(otherSiteDb, 'skillMastery', 'skill-mastery-wrong-site'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      skillId: 'skill-2',
      level: 2,
    }));
  });

  test('skill mastery updates cannot cross or remove site scope', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(educatorDb, 'skillMastery', 'skill-mastery-site1'), {
      evidenceCount: 4,
    }));
    await assertFails(updateDoc(doc(learnerDb, 'skillMastery', 'skill-mastery-site1'), {
      evidenceCount: 5,
    }));
    await assertFails(updateDoc(doc(otherSiteDb, 'skillMastery', 'skill-mastery-site1'), {
      evidenceCount: 5,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'skillMastery', 'skill-mastery-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Showcase Submissions Collection', () => {
  test('showcase submissions require site scope for read and learner create', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'showcaseSubmissions', 'showcase-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'showcaseSubmissions', 'showcase-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'showcaseSubmissions', 'showcase-site1')));
    await assertFails(getDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'New site-scoped showcase artifact',
      description: 'A new artifact shared with the school.',
      visibility: 'site',
      approvalStatus: 'pending',
    }));
    await assertFails(setDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-missing-site'), {
      learnerId: learnerUser.uid,
      title: 'Missing site showcase artifact',
      description: 'This should fail closed.',
      visibility: 'site',
      approvalStatus: 'pending',
    }));
    await assertFails(setDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      title: 'Wrong-site showcase artifact',
      description: 'This should fail closed.',
      visibility: 'site',
      approvalStatus: 'pending',
    }));
  });

  test('showcase submission updates cannot cross or remove site scope', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-site1'), {
      description: 'Learner revised the showcase description.',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'showcaseSubmissions', 'showcase-site1'), {
      approvalStatus: 'approved',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'showcaseSubmissions', 'showcase-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Learner Support and Assessment Boundary Collections', () => {
  test('student assents require site scope for learner create and read', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'studentAssents', 'assent-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'studentAssents', 'assent-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'studentAssents', 'assent-site1')));
    await assertFails(getDoc(doc(learnerDb, 'studentAssents', 'assent-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'studentAssents', 'assent-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'studentAssents', 'assent-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      assentGiven: true,
      assentVersion: 'v2',
    }));
    await assertFails(setDoc(doc(learnerDb, 'studentAssents', 'assent-missing-site'), {
      learnerId: learnerUser.uid,
      assentGiven: true,
      assentVersion: 'v2',
    }));
    await assertFails(setDoc(doc(learnerDb, 'studentAssents', 'assent-wrong-site'), {
      siteId: 'site2',
      learnerId: learnerUser.uid,
      assentGiven: true,
      assentVersion: 'v2',
    }));
  });

  test('item responses require site scope and remain immutable', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'itemResponses', 'item-response-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'itemResponses', 'item-response-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'itemResponses', 'item-response-site1')));
    await assertFails(getDoc(doc(learnerDb, 'itemResponses', 'item-response-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'itemResponses', 'item-response-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'itemResponses', 'item-response-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      instrumentId: 'instrument-1',
      itemId: 'item-2',
      response: 'D',
      score: 1,
    }));
    await assertFails(setDoc(doc(learnerDb, 'itemResponses', 'item-response-missing-site'), {
      learnerId: learnerUser.uid,
      instrumentId: 'instrument-1',
      itemId: 'item-2',
      response: 'D',
      score: 1,
    }));
    await assertFails(updateDoc(doc(learnerDb, 'itemResponses', 'item-response-site1'), {
      score: 0,
    }));
  });

  test('learner next steps require site scope and preserve identity fields', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerNextSteps', 'next-step-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerNextSteps', 'next-step-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerNextSteps', 'next-step-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerNextSteps', 'next-step-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerNextSteps', 'next-step-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'learnerNextSteps', 'next-step-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-2',
      pillarCode: 'impact',
      stepType: 'artifact',
      title: 'New site-scoped next step',
      currentLevel: 2,
      targetLevel: 3,
      status: 'active',
    }));
    await assertFails(setDoc(doc(educatorDb, 'learnerNextSteps', 'next-step-missing-site'), {
      learnerId: learnerUser.uid,
      capabilityId: 'capability-2',
      pillarCode: 'impact',
      stepType: 'artifact',
      title: 'Missing site next step',
      currentLevel: 2,
      targetLevel: 3,
      status: 'active',
    }));
    await assertFails(setDoc(doc(otherSiteDb, 'learnerNextSteps', 'next-step-wrong-site'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-2',
      pillarCode: 'impact',
      stepType: 'artifact',
      title: 'Wrong actor next step',
      currentLevel: 2,
      targetLevel: 3,
      status: 'active',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'learnerNextSteps', 'next-step-site1'), {
      status: 'completed',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerNextSteps', 'next-step-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerNextSteps', 'next-step-site1'), {
      siteId: 'site2',
    }));
  });

  test('learner support plans require site scope and preserve learner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerSupportPlans', 'support-plan-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerSupportPlans', 'support-plan-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerSupportPlans', 'support-plan-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerSupportPlans', 'support-plan-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerSupportPlans', 'support-plan-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'learnerSupportPlans', 'support-plan-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      supportType: 'Academic',
      priority: 'high',
      notes: 'New support plan',
    }));
    await assertFails(setDoc(doc(educatorDb, 'learnerSupportPlans', 'support-plan-missing-site'), {
      learnerId: learnerUser.uid,
      supportType: 'Academic',
      priority: 'high',
      notes: 'Missing site support plan',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'learnerSupportPlans', 'support-plan-site1'), {
      priority: 'high',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerSupportPlans', 'support-plan-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerSupportPlans', 'support-plan-site1'), {
      siteId: 'site2',
    }));
  });

  test('learner differentiation plans require site scope and preserve learner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerDifferentiationPlans', 'differentiation-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerDifferentiationPlans', 'differentiation-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerDifferentiationPlans', 'differentiation-site1')));
    await assertFails(getDoc(doc(learnerDb, 'learnerDifferentiationPlans', 'differentiation-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerDifferentiationPlans', 'differentiation-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'learnerDifferentiationPlans', 'differentiation-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      selectedLane: 'scaffolded',
      recommendedLane: 'core',
    }));
    await assertFails(setDoc(doc(educatorDb, 'learnerDifferentiationPlans', 'differentiation-missing-site'), {
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      selectedLane: 'scaffolded',
      recommendedLane: 'core',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'learnerDifferentiationPlans', 'differentiation-site1'), {
      selectedLane: 'stretch',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerDifferentiationPlans', 'differentiation-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerDifferentiationPlans', 'differentiation-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Mission Portfolio and Rubric Boundary Collections', () => {
  test('mission plans require site scope and preserve educator identity', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'missionPlans', 'mission-plan-site1')));
    await assertSucceeds(getDoc(doc(learnerDb, 'missionPlans', 'mission-plan-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'missionPlans', 'mission-plan-site1')));
    await assertFails(getDoc(doc(educatorDb, 'missionPlans', 'mission-plan-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'missionPlans', 'mission-plan-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'missionPlans', 'mission-plan-new'), {
      siteId: 'site1',
      sessionOccurrenceId: 'occ-1',
      educatorId: educatorUser.uid,
      missionIds: ['mission-2'],
      status: 'draft',
    }));
    await assertFails(setDoc(doc(educatorDb, 'missionPlans', 'mission-plan-missing-site'), {
      sessionOccurrenceId: 'occ-1',
      educatorId: educatorUser.uid,
      missionIds: ['mission-2'],
      status: 'draft',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'missionPlans', 'mission-plan-site1'), {
      status: 'active',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionPlans', 'mission-plan-site1'), {
      educatorId: 'educator-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionPlans', 'mission-plan-site1'), {
      siteId: 'site2',
    }));
  });

  test('portfolio containers require site scope and preserve learner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'portfolios', 'portfolio-container-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'portfolios', 'portfolio-container-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'portfolios', 'portfolio-container-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'portfolios', 'portfolio-container-site1')));
    await assertFails(getDoc(doc(learnerDb, 'portfolios', 'portfolio-container-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'portfolios', 'portfolio-container-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'portfolios', 'portfolio-container-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'New learner portfolio',
    }));
    await assertFails(setDoc(doc(learnerDb, 'portfolios', 'portfolio-container-missing-site'), {
      learnerId: learnerUser.uid,
      title: 'Missing site learner portfolio',
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'portfolios', 'portfolio-container-site1'), {
      title: 'Updated learner portfolio',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'portfolios', 'portfolio-container-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'portfolios', 'portfolio-container-site1'), {
      siteId: 'site2',
    }));
  });

  test('rubric applications are site-scoped reads and server-owned writes', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'rubricApplications', 'rubric-application-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'rubricApplications', 'rubric-application-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'rubricApplications', 'rubric-application-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'rubricApplications', 'rubric-application-site1')));
    await assertFails(getDoc(doc(learnerDb, 'rubricApplications', 'rubric-application-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'rubricApplications', 'rubric-application-site2')));

    await assertFails(setDoc(doc(educatorDb, 'rubricApplications', 'rubric-application-client-write'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      educatorId: educatorUser.uid,
      rubricId: 'rubric-2',
      missionAttemptId: 'attempt-site1',
      scores: [{ criterionId: 'criterion-1', capabilityId: 'capability-1', score: 3, maxScore: 4 }],
    }));
    await assertFails(updateDoc(doc(educatorDb, 'rubricApplications', 'rubric-application-site1'), {
      status: 'growth-recorded',
    }));
  });
});

describe('Billing Boundary Collections', () => {
  test('billing accounts and payments are owner or HQ readable only', async () => {
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherParentDb = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertSucceeds(getDoc(doc(parentDb, 'billingAccounts', parentUser.uid)));
    await assertSucceeds(getDoc(doc(hqDb, 'billingAccounts', parentUser.uid)));
    await assertFails(getDoc(doc(otherParentDb, 'billingAccounts', parentUser.uid)));
    await assertFails(getDoc(doc(educatorDb, 'billingAccounts', parentUser.uid)));

    await assertSucceeds(getDoc(doc(parentDb, 'payments', 'payment-parent-1')));
    await assertSucceeds(getDoc(doc(hqDb, 'payments', 'payment-parent-1')));
    await assertFails(getDoc(doc(otherParentDb, 'payments', 'payment-parent-1')));
    await assertFails(getDoc(doc(educatorDb, 'payments', 'payment-parent-1')));
  });

  test('billing accounts and payments remain server-owned', async () => {
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertFails(setDoc(doc(parentDb, 'billingAccounts', 'billing-client-write'), {
      parentId: parentUser.uid,
      siteId: 'site1',
      status: 'active',
    }));
    await assertFails(updateDoc(doc(hqDb, 'billingAccounts', parentUser.uid), {
      balanceCents: 500,
    }));
    await assertFails(setDoc(doc(parentDb, 'payments', 'payment-client-write'), {
      parentId: parentUser.uid,
      siteId: 'site1',
      amountCents: 1000,
      status: 'posted',
    }));
  });
});

describe('Mission Assignment and Skill Assessment Boundary Collections', () => {
  test('mission assignments require site scope and preserve learner and mission identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'missionAssignments', 'assignment-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'missionAssignments', 'assignment-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'missionAssignments', 'assignment-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'missionAssignments', 'assignment-site1')));
    await assertFails(getDoc(doc(learnerDb, 'missionAssignments', 'assignment-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'missionAssignments', 'assignment-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'missionAssignments', 'assignment-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-2',
      assignedBy: educatorUser.uid,
      status: 'active',
      progress: 0,
    }));
    await assertFails(setDoc(doc(educatorDb, 'missionAssignments', 'assignment-missing-site'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-2',
      assignedBy: educatorUser.uid,
      status: 'active',
      progress: 0,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'missionAssignments', 'assignment-site1'), {
      progress: 35,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionAssignments', 'assignment-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionAssignments', 'assignment-site1'), {
      missionId: 'mission-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionAssignments', 'assignment-site1'), {
      siteId: 'site2',
    }));
  });

  test('skill assessments require site scope and preserve learner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'skillAssessments', 'skill-assessment-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'skillAssessments', 'skill-assessment-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'skillAssessments', 'skill-assessment-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'skillAssessments', 'skill-assessment-site1')));
    await assertFails(getDoc(doc(learnerDb, 'skillAssessments', 'skill-assessment-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'skillAssessments', 'skill-assessment-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'skillAssessments', 'skill-assessment-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      skillId: 'skill-2',
      assessorId: educatorUser.uid,
      level: 2,
      assessedAt: Date.now(),
    }));
    await assertFails(setDoc(doc(educatorDb, 'skillAssessments', 'skill-assessment-missing-site'), {
      learnerId: learnerUser.uid,
      skillId: 'skill-2',
      assessorId: educatorUser.uid,
      level: 2,
      assessedAt: Date.now(),
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'skillAssessments', 'skill-assessment-site1'), {
      level: 3,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'skillAssessments', 'skill-assessment-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'skillAssessments', 'skill-assessment-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Learner Progress and Activity Boundary Collections', () => {
  test('learner progress is server-owned and readable only through same-site learner links', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherParentDb = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'learnerProgress', learnerUser.uid)));
    await assertSucceeds(getDoc(doc(educatorDb, 'learnerProgress', learnerUser.uid)));
    await assertSucceeds(getDoc(doc(parentDb, 'learnerProgress', learnerUser.uid)));
    await assertFails(getDoc(doc(otherParentDb, 'learnerProgress', learnerUser.uid)));
    await assertFails(getDoc(doc(otherSiteDb, 'learnerProgress', learnerUser.uid)));
    await assertFails(getDoc(doc(learnerDb, 'learnerProgress', 'progress-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'learnerProgress', 'progress-site2')));

    await assertFails(setDoc(doc(educatorDb, 'learnerProgress', 'progress-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      level: 3,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'learnerProgress', learnerUser.uid), {
      level: 4,
    }));
  });

  test('activities are server-owned and readable only through same-site learner links', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherParentDb = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'activities', 'activity-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'activities', 'activity-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'activities', 'activity-site1')));
    await assertFails(getDoc(doc(otherParentDb, 'activities', 'activity-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'activities', 'activity-site1')));
    await assertFails(getDoc(doc(learnerDb, 'activities', 'activity-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'activities', 'activity-site2')));

    await assertFails(setDoc(doc(educatorDb, 'activities', 'activity-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Manual activity',
      type: 'activity',
      timestamp: Date.now(),
    }));
    await assertFails(updateDoc(doc(educatorDb, 'activities', 'activity-site1'), {
      title: 'Changed activity',
    }));
  });
});

describe('Legacy Events Boundary Collection', () => {
  test('events require site scope and preserve site identity on educator updates', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'events', 'event-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'events', 'event-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'events', 'event-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'events', 'event-site1')));
    await assertFails(getDoc(doc(learnerDb, 'events', 'event-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'events', 'event-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'events', 'event-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'New studio event',
      type: 'session',
      dateTime: Date.now(),
    }));
    await assertFails(setDoc(doc(educatorDb, 'events', 'event-missing-site'), {
      learnerId: learnerUser.uid,
      title: 'Missing site event',
      type: 'session',
      dateTime: Date.now(),
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'events', 'event-site1'), {
      title: 'Updated studio session',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'events', 'event-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Legacy Accountability Boundary Collections', () => {
  test('accountability cycles require site scope and preserve site identity', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'accountabilityCycles', 'cycle-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'accountabilityCycles', 'cycle-site1')));
    await assertFails(getDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-new'), {
      siteId: 'site1',
      title: 'New cycle',
      status: 'active',
      ownerId: educatorUser.uid,
    }));
    await assertFails(setDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-missing-site'), {
      title: 'Missing site cycle',
      status: 'active',
      ownerId: educatorUser.uid,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-site1'), {
      status: 'closed',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityCycles', 'cycle-site1'), {
      siteId: 'site2',
    }));
  });

  test('accountability KPIs require site scope and preserve site identity', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'accountabilityKPIs', 'kpi-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'accountabilityKPIs', 'kpi-site1')));
    await assertFails(getDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-new'), {
      siteId: 'site1',
      cycleId: 'cycle-site1',
      title: 'New KPI',
      value: 75,
    }));
    await assertFails(setDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-missing-site'), {
      cycleId: 'cycle-site1',
      title: 'Missing site KPI',
      value: 75,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-site1'), {
      value: 85,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'accountabilityKPIs', 'kpi-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Safeguarding Boundary Collections', () => {
  test('media consents require site scope and preserve parent learner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(parentDb, 'mediaConsents', 'media-consent-site1')));
    await assertSucceeds(getDoc(doc(learnerDb, 'mediaConsents', 'media-consent-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'mediaConsents', 'media-consent-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'mediaConsents', 'media-consent-site1')));
    await assertFails(getDoc(doc(parentDb, 'mediaConsents', 'media-consent-nosite')));
    await assertFails(getDoc(doc(parentDb, 'mediaConsents', 'media-consent-site2')));

    await assertSucceeds(setDoc(doc(parentDb, 'mediaConsents', 'media-consent-new'), {
      siteId: 'site1',
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      status: 'granted',
    }));
    await assertFails(setDoc(doc(parentDb, 'mediaConsents', 'media-consent-missing-site'), {
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      status: 'granted',
    }));
    await assertSucceeds(updateDoc(doc(parentDb, 'mediaConsents', 'media-consent-site1'), {
      status: 'revoked',
    }));
    await assertFails(updateDoc(doc(parentDb, 'mediaConsents', 'media-consent-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(parentDb, 'mediaConsents', 'media-consent-site1'), {
      siteId: 'site2',
    }));
  });

  test('pickup authorizations require site scope and preserve parent learner identity', async () => {
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'pickupAuthorizations', 'pickup-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'pickupAuthorizations', 'pickup-site1')));
    await assertFails(getDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-nosite')));
    await assertFails(getDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-site2')));

    await assertSucceeds(setDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-new'), {
      siteId: 'site1',
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      authorizedAdults: ['Asha Caregiver'],
    }));
    await assertFails(setDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-missing-site'), {
      parentId: parentUser.uid,
      learnerId: learnerUser.uid,
      authorizedAdults: ['Asha Caregiver'],
    }));
    await assertSucceeds(updateDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-site1'), {
      authorizedAdults: ['Sam Caregiver', 'Asha Caregiver'],
    }));
    await assertFails(updateDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(parentDb, 'pickupAuthorizations', 'pickup-site1'), {
      siteId: 'site2',
    }));
  });

  test('incident reports require site scope and preserve site identity on HQ updates', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'incidentReports', 'incident-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'incidentReports', 'incident-site1')));
    await assertFails(getDoc(doc(parentDb, 'incidentReports', 'incident-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'incidentReports', 'incident-site1')));
    await assertFails(getDoc(doc(educatorDb, 'incidentReports', 'incident-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'incidentReports', 'incident-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'incidentReports', 'incident-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      reportedBy: educatorUser.uid,
      severity: 'low',
      category: 'care',
      status: 'submitted',
      summary: 'New incident',
    }));
    await assertFails(setDoc(doc(educatorDb, 'incidentReports', 'incident-missing-site'), {
      learnerId: learnerUser.uid,
      reportedBy: educatorUser.uid,
      severity: 'low',
      category: 'care',
      status: 'submitted',
      summary: 'Missing site incident',
    }));
    await assertSucceeds(updateDoc(doc(hqDb, 'incidentReports', 'incident-site1'), {
      status: 'reviewed',
    }));
    await assertFails(updateDoc(doc(hqDb, 'incidentReports', 'incident-site1'), {
      siteId: 'site2',
    }));
  });

  test('runtime incidents require site scope and preserve reporting provenance', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'incidents', 'runtime-incident-site1')));
    await assertSucceeds(getDoc(doc(learnerDb, 'incidents', 'runtime-incident-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'incidents', 'runtime-incident-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'incidents', 'runtime-incident-site1')));
    await assertFails(getDoc(doc(educatorDb, 'incidents', 'runtime-incident-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'incidents', 'runtime-incident-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'incidents', 'runtime-incident-new'), {
      siteId: 'site1',
      reportedBy: learnerUser.uid,
      type: 'ops',
      description: 'Learner runtime incident',
      status: 'open',
    }));
    await assertFails(setDoc(doc(learnerDb, 'incidents', 'runtime-incident-missing-site'), {
      reportedBy: learnerUser.uid,
      type: 'ops',
      description: 'Missing site runtime incident',
      status: 'open',
    }));
    await assertFails(setDoc(doc(learnerDb, 'incidents', 'runtime-incident-spoofed-reporter'), {
      siteId: 'site1',
      reportedBy: educatorUser.uid,
      type: 'ops',
      description: 'Spoofed reporter runtime incident',
      status: 'open',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'incidents', 'runtime-incident-site1'), {
      status: 'reviewed',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'incidents', 'runtime-incident-site1'), {
      siteId: 'site2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'incidents', 'runtime-incident-site1'), {
      reportedBy: learnerUser.uid,
    }));
  });

  test('site check-in-out records require site scope and preserve learner date identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'siteCheckInOut', 'checkin-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-site1')));
    await assertFails(getDoc(doc(parentDb, 'siteCheckInOut', 'checkin-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'siteCheckInOut', 'checkin-site1')));
    await assertFails(getDoc(doc(learnerDb, 'siteCheckInOut', 'checkin-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'siteCheckInOut', 'checkin-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      date: '2026-05-12',
      checkInBy: educatorUser.uid,
      checkInAt: Date.now(),
    }));
    await assertFails(setDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-missing-site'), {
      learnerId: learnerUser.uid,
      date: '2026-05-12',
      checkInBy: educatorUser.uid,
      checkInAt: Date.now(),
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-site1'), {
      checkOutBy: educatorUser.uid,
      checkOutAt: Date.now(),
    }));
    await assertFails(updateDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-site1'), {
      date: '2026-05-12',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'siteCheckInOut', 'checkin-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('AI Runtime Boundary Collections', () => {
  test('orchestration states are server-owned and require same-site learner links', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'orchestrationStates', 'orchestration-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'orchestrationStates', 'orchestration-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'orchestrationStates', 'orchestration-site1')));
    await assertFails(getDoc(doc(parentDb, 'orchestrationStates', 'orchestration-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'orchestrationStates', 'orchestration-site1')));
    await assertFails(getDoc(doc(learnerDb, 'orchestrationStates', 'orchestration-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'orchestrationStates', 'orchestration-site2')));

    await assertFails(setDoc(doc(learnerDb, 'orchestrationStates', 'orchestration-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      sessionOccurrenceId: 'occurrence-1',
      x_hat: { cognition: 0.7, engagement: 0.8, integrity: 0.9 },
    }));
  });

  test('interventions are server-owned and require same-site learner links', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'interventions', 'intervention-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'interventions', 'intervention-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'interventions', 'intervention-site1')));
    await assertFails(getDoc(doc(parentDb, 'interventions', 'intervention-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'interventions', 'intervention-site1')));
    await assertFails(getDoc(doc(learnerDb, 'interventions', 'intervention-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'interventions', 'intervention-site2')));

    await assertFails(updateDoc(doc(educatorDb, 'interventions', 'intervention-site1'), {
      type: 'changed',
    }));
  });

  test('MVL episodes require same-site learner links and preserve identity on evidence updates', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'mvlEpisodes', 'mvl-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'mvlEpisodes', 'mvl-site1')));
    await assertFails(getDoc(doc(parentDb, 'mvlEpisodes', 'mvl-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'mvlEpisodes', 'mvl-site1')));
    await assertFails(getDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-site2')));

    await assertSucceeds(updateDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-site1'), {
      evidenceEventIds: ['evidence-1'],
    }));
    await assertFails(updateDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-site1'), {
      siteId: 'site2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'mvlEpisodes', 'mvl-site1'), {
      sessionOccurrenceId: 'occurrence-2',
    }));
    await assertFails(updateDoc(doc(parentDb, 'mvlEpisodes', 'mvl-site1'), {
      evidenceEventIds: ['evidence-2'],
    }));
  });
});

describe('Learner Recognition and Mission Enrollment Boundary Collections', () => {
  test('recognition badges require site scope and learner links', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'recognitionBadges', 'recognition-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'recognitionBadges', 'recognition-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'recognitionBadges', 'recognition-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'recognitionBadges', 'recognition-site1')));
    await assertFails(getDoc(doc(learnerDb, 'recognitionBadges', 'recognition-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'recognitionBadges', 'recognition-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'recognitionBadges', 'recognition-new'), {
      siteId: 'site1',
      giverId: 'learner-peer',
      recipientId: learnerUser.uid,
      recognitionType: 'collaboration',
      message: 'New recognition',
    }));
    await assertFails(setDoc(doc(educatorDb, 'recognitionBadges', 'recognition-missing-site'), {
      giverId: 'learner-peer',
      recipientId: learnerUser.uid,
      recognitionType: 'collaboration',
      message: 'Missing site recognition',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'recognitionBadges', 'recognition-site1'), {
      message: 'Changed recognition',
    }));
  });

  test('badge achievements require site scope and learner links', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'badgeAchievements', 'badge-achievement-site1')));
    await assertSucceeds(getDoc(doc(learnerDb, 'badgeAchievements', 'badge-achievement-user-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'badgeAchievements', 'badge-achievement-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'badgeAchievements', 'badge-achievement-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'badgeAchievements', 'badge-achievement-site1')));
    await assertFails(getDoc(doc(learnerDb, 'badgeAchievements', 'badge-achievement-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'badgeAchievements', 'badge-achievement-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'badgeAchievements', 'badge-achievement-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      badgeId: 'badge-new',
      evidenceIds: ['evidence-1'],
    }));
    await assertFails(setDoc(doc(educatorDb, 'badgeAchievements', 'badge-achievement-missing-site'), {
      learnerId: learnerUser.uid,
      badgeId: 'badge-missing-site',
      evidenceIds: ['evidence-1'],
    }));
    await assertFails(updateDoc(doc(educatorDb, 'badgeAchievements', 'badge-achievement-site1'), {
      badgeId: 'badge-2',
    }));
  });

  test('mission enrollments require site scope and preserve learner mission identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'missionEnrollments', 'mission-enrollment-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'missionEnrollments', 'mission-enrollment-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'missionEnrollments', 'mission-enrollment-site1')));
    await assertFails(getDoc(doc(learnerDb, 'missionEnrollments', 'mission-enrollment-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'missionEnrollments', 'mission-enrollment-site2')));

    await assertSucceeds(setDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-2',
      status: 'active',
      progress: 0,
    }));
    await assertFails(setDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-missing-site'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-2',
      status: 'active',
      progress: 0,
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-site1'), {
      progress: 55,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-site1'), {
      missionId: 'mission-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionEnrollments', 'mission-enrollment-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Legacy Learner Submission Boundary Collections', () => {
  test('legacy reflections require site scope and preserve owner identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'reflections', 'reflection-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'reflections', 'reflection-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'reflections', 'reflection-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'reflections', 'reflection-site1')));
    await assertFails(getDoc(doc(learnerDb, 'reflections', 'reflection-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'reflections', 'reflection-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'reflections', 'reflection-new'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      prompt: 'New reflection',
      responseText: 'I can explain this now.',
    }));
    await assertFails(setDoc(doc(learnerDb, 'reflections', 'reflection-missing-site'), {
      userId: learnerUser.uid,
      prompt: 'Missing site reflection',
      responseText: 'Missing site.',
    }));
    await assertSucceeds(updateDoc(doc(learnerDb, 'reflections', 'reflection-site1'), {
      responseText: 'Updated reflection',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'reflections', 'reflection-site1'), {
      userId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(learnerDb, 'reflections', 'reflection-site1'), {
      siteId: 'site2',
    }));
  });

  test('mission submissions require site scope and preserve learner mission identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'missionSubmissions', 'submission-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'missionSubmissions', 'submission-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'missionSubmissions', 'submission-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'missionSubmissions', 'submission-site1')));
    await assertFails(getDoc(doc(learnerDb, 'missionSubmissions', 'submission-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'missionSubmissions', 'submission-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'missionSubmissions', 'submission-new'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      missionId: 'mission-2',
      status: 'submitted',
      artifactUrls: ['https://example.test/new-artifact'],
    }));
    await assertFails(setDoc(doc(learnerDb, 'missionSubmissions', 'submission-missing-site'), {
      learnerId: learnerUser.uid,
      missionId: 'mission-2',
      status: 'submitted',
      artifactUrls: ['https://example.test/new-artifact'],
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'missionSubmissions', 'submission-site1'), {
      status: 'reviewed',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionSubmissions', 'submission-site1'), {
      learnerId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionSubmissions', 'submission-site1'), {
      missionId: 'mission-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionSubmissions', 'submission-site1'), {
      siteId: 'site2',
    }));
  });

  test('support requests require site scope and preserve requester identity', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'supportRequests', 'support-request-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'supportRequests', 'support-request-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'supportRequests', 'support-request-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'supportRequests', 'support-request-site1')));
    await assertFails(getDoc(doc(learnerDb, 'supportRequests', 'support-request-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'supportRequests', 'support-request-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'supportRequests', 'support-request-new'), {
      siteId: 'site1',
      userId: learnerUser.uid,
      requestType: 'help',
      subject: 'New help request',
      status: 'open',
    }));
    await assertFails(setDoc(doc(learnerDb, 'supportRequests', 'support-request-missing-site'), {
      userId: learnerUser.uid,
      requestType: 'help',
      subject: 'Missing site help',
      status: 'open',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'supportRequests', 'support-request-site1'), {
      status: 'closed',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'supportRequests', 'support-request-site1'), {
      userId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'supportRequests', 'support-request-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Peer Feedback Collection', () => {
  async function seedPeerFeedback() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'peerFeedback', 'feedback-site1'), {
        siteId: 'site1',
        authorId: learnerUser.uid,
        fromLearnerId: learnerUser.uid,
        toLearnerId: 'learner-2',
        missionAttemptId: 'attempt-1',
        rating: 4,
      });
      await setDoc(doc(db, 'peerFeedback', 'feedback-site2'), {
        siteId: 'site2',
        authorId: 'learner-site2',
        fromLearnerId: 'learner-site2',
        toLearnerId: learnerUser.uid,
        missionAttemptId: 'attempt-site2',
        rating: 5,
      });
      await setDoc(doc(db, 'peerFeedback', 'feedback-nosite'), {
        authorId: learnerUser.uid,
        fromLearnerId: learnerUser.uid,
        toLearnerId: 'learner-2',
        missionAttemptId: 'attempt-nosite',
        rating: 3,
      });
    });
  }

  test('learner can read same-site peer feedback', async () => {
    await seedPeerFeedback();
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'peerFeedback', 'feedback-site1')));
    await assertSucceeds(
      getDocs(query(collection(db, 'peerFeedback'), where('siteId', '==', 'site1')))
    );
  });

  test('learner cannot read other-site or missing-site peer feedback', async () => {
    await seedPeerFeedback();
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'peerFeedback', 'feedback-site2')));
    await assertFails(getDoc(doc(db, 'peerFeedback', 'feedback-nosite')));
  });

  test('learner can create own same-site peer feedback', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'peerFeedback', 'feedback-new'), {
      siteId: 'site1',
      authorId: learnerUser.uid,
      fromLearnerId: learnerUser.uid,
      toLearnerId: 'learner-2',
      missionAttemptId: 'attempt-1',
      rating: 4,
    }));
  });

  test('learner cannot create peer feedback for another author or without siteId', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'peerFeedback', 'feedback-wrong-author'), {
      siteId: 'site1',
      authorId: 'learner-2',
      fromLearnerId: learnerUser.uid,
      toLearnerId: 'learner-2',
      missionAttemptId: 'attempt-1',
      rating: 4,
    }));
    await assertFails(setDoc(doc(db, 'peerFeedback', 'feedback-missing-site'), {
      authorId: learnerUser.uid,
      fromLearnerId: learnerUser.uid,
      toLearnerId: 'learner-2',
      missionAttemptId: 'attempt-1',
      rating: 4,
    }));
  });
});

describe('Portfolio Access', () => {
  test('linked parent can read learner portfolio item', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'portfolioItems', 'portfolio-1')));
  });

  test('unlinked parent cannot read learner portfolio item', async () => {
    const db = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'portfolioItems', 'portfolio-1')));
  });

  test('other-site educator and missing-site records cannot read learner portfolio item', async () => {
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(otherSiteDb, 'portfolioItems', 'portfolio-1')));

    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(getDoc(doc(educatorDb, 'portfolioItems', 'portfolio-nosite')));
  });

  test('learner cannot create portfolio item without siteId', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'portfolioItems', 'portfolio-created-nosite'), {
      learnerId: learnerUser.uid,
      title: 'Unscoped learner artifact',
      status: 'draft',
    }));
  });
});

describe('Passport evidence chain access', () => {
  test('learner can read their own capability mastery', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'capabilityMastery', 'mastery-1')));
  });

  test('linked parent can read learner capability mastery', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'capabilityMastery', 'mastery-1')));
  });

  test('unlinked parent cannot read learner capability mastery', async () => {
    const db = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'capabilityMastery', 'mastery-1')));
  });

  test('linked parent can read learner growth provenance', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'capabilityGrowthEvents', 'growth-1')));
  });

  test('linked parent can read learner process-domain provenance', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'processDomainMastery', 'process-mastery-1')));
    await assertSucceeds(getDoc(doc(db, 'processDomainGrowthEvents', 'process-growth-1')));
  });

  test('unlinked parent cannot read learner growth provenance', async () => {
    const db = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'capabilityGrowthEvents', 'growth-1')));
  });

  test('linked parent can read learner proof bundle provenance', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'proofOfLearningBundles', 'proof-1')));
  });

  test('unlinked parent cannot read learner proof bundle provenance', async () => {
    const db = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'proofOfLearningBundles', 'proof-1')));
  });

  test('other-site educator cannot read learner Passport provenance', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'capabilityMastery', 'mastery-1')));
    await assertFails(getDoc(doc(db, 'capabilityGrowthEvents', 'growth-1')));
    await assertFails(getDoc(doc(db, 'processDomainMastery', 'process-mastery-1')));
    await assertFails(getDoc(doc(db, 'processDomainGrowthEvents', 'process-growth-1')));
    await assertFails(getDoc(doc(db, 'proofOfLearningBundles', 'proof-1')));
  });

  test('educator cannot directly write server-owned growth or mastery state', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'capabilityMastery', 'mastery-direct'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      latestLevel: 4,
      currentLevel: 4,
    }));
    await assertFails(updateDoc(doc(db, 'capabilityMastery', 'mastery-1'), {
      latestLevel: 4,
    }));
    await assertFails(setDoc(doc(db, 'capabilityGrowthEvents', 'growth-direct'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      capabilityId: 'capability-1',
      level: 4,
    }));
    await assertFails(setDoc(doc(db, 'processDomainMastery', 'process-mastery-direct'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      processDomainId: 'process-domain-1',
      latestLevel: 4,
      currentLevel: 4,
    }));
    await assertFails(setDoc(doc(db, 'processDomainGrowthEvents', 'process-growth-direct'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      processDomainId: 'process-domain-1',
      level: 4,
    }));
  });

  test('missing-site Passport provenance is denied even to same-site actors', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(getDoc(doc(educatorDb, 'capabilityMastery', 'mastery-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'capabilityGrowthEvents', 'growth-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'proofOfLearningBundles', 'proof-nosite')));

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertFails(getDoc(doc(learnerDb, 'capabilityMastery', 'mastery-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'capabilityGrowthEvents', 'growth-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'proofOfLearningBundles', 'proof-nosite')));
  });

  test('learner can assemble proof but cannot verify it or spoof educator verification', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();

    await assertSucceeds(setDoc(doc(learnerDb, 'proofOfLearningBundles', 'proof-learner-assembly'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      portfolioItemId: 'portfolio-1',
      hasExplainItBack: true,
      hasOralCheck: false,
      hasMiniRebuild: false,
      verificationStatus: 'partial',
      version: 1,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    }));

    await assertSucceeds(updateDoc(doc(learnerDb, 'proofOfLearningBundles', 'proof-learner-assembly'), {
      hasOralCheck: true,
      hasMiniRebuild: true,
      oralCheckExcerpt: 'I explained the decision aloud.',
      miniRebuildExcerpt: 'I can rebuild it from scratch.',
      verificationStatus: 'pending_review',
      updatedAt: Date.now(),
    }));

    await assertFails(setDoc(doc(learnerDb, 'proofOfLearningBundles', 'proof-learner-verified'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      portfolioItemId: 'portfolio-1',
      hasExplainItBack: true,
      hasOralCheck: true,
      hasMiniRebuild: true,
      verificationStatus: 'verified',
      version: 1,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    }));

    await assertFails(updateDoc(doc(learnerDb, 'proofOfLearningBundles', 'proof-learner-assembly'), {
      verificationStatus: 'verified',
      educatorVerifierId: educatorUser.uid,
      updatedAt: Date.now(),
    }));
  });

  test('educator cannot verify proof bundles directly through client rules', async () => {
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();

    await assertFails(updateDoc(doc(educatorDb, 'proofOfLearningBundles', 'proof-1'), {
      verificationStatus: 'verified',
      educatorVerifierId: educatorUser.uid,
      updatedAt: Date.now(),
    }));
  });
});

describe('AI audit access', () => {
  test('learner and same-site educator can read site-scoped AI audit records', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'aiInteractionLogs', 'ai-log-1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'aiCoachInteractions', 'ai-coach-1')));
  });

  test('wrong-site and missing-site AI audit records are denied', async () => {
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();

    await assertFails(getDoc(doc(otherSiteDb, 'aiInteractionLogs', 'ai-log-1')));
    await assertFails(getDoc(doc(otherSiteDb, 'aiCoachInteractions', 'ai-coach-1')));
    await assertFails(getDoc(doc(learnerDb, 'aiInteractionLogs', 'ai-log-nosite')));
  });

  test('AI audit creates require site scope and learner or same-site educator ownership', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(setDoc(doc(learnerDb, 'aiInteractionLogs', 'ai-log-owned'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      traceId: 'trace-owned',
      taskType: 'hint',
      dataUsagePolicy: 'analytics_only_no_training',
      redactedQuestion: 'How should I explain this?',
      response: 'Use your evidence.',
      createdAt: Date.now(),
    }));
    await assertSucceeds(setDoc(doc(educatorDb, 'aiCoachInteractions', 'ai-coach-educator'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      mode: 'verify',
      question: 'Can the learner explain it?',
      response: 'Ask for an explain-back.',
      createdAt: Date.now(),
    }));
    await assertFails(setDoc(doc(learnerDb, 'aiInteractionLogs', 'ai-log-nosite-create'), {
      learnerId: learnerUser.uid,
      traceId: 'trace-nosite-create',
      taskType: 'hint',
      dataUsagePolicy: 'analytics_only_no_training',
      redactedQuestion: 'Missing site',
      response: 'Denied.',
      createdAt: Date.now(),
    }));
    await assertFails(setDoc(doc(learnerDb, 'aiCoachInteractions', 'ai-coach-other-learner'), {
      siteId: 'site1',
      learnerId: 'learner-2',
      mode: 'hint',
      question: 'Other learner?',
      response: 'Denied.',
      createdAt: Date.now(),
    }));
    await assertFails(setDoc(doc(otherSiteDb, 'aiInteractionLogs', 'ai-log-other-site'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      traceId: 'trace-other-site',
      taskType: 'hint',
      dataUsagePolicy: 'analytics_only_no_training',
      redactedQuestion: 'Wrong site educator?',
      response: 'Denied.',
      createdAt: Date.now(),
    }));
  });

  test('AI interaction updates are limited to outcomes', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(learnerDb, 'aiInteractionLogs', 'ai-log-1'), {
      outcome: { wasHelpful: true },
      updatedAt: Date.now(),
    }));
    await assertFails(updateDoc(doc(educatorDb, 'aiInteractionLogs', 'ai-log-1'), {
      response: 'Changed the audit trail.',
      updatedAt: Date.now(),
    }));
    await assertFails(updateDoc(doc(educatorDb, 'aiCoachInteractions', 'ai-coach-1'), {
      response: 'Changed native audit response.',
    }));
  });

  test('AI drafts require site scope and preserve requester provenance', async () => {
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'aiDrafts', 'ai-draft-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'aiDrafts', 'ai-draft-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'aiDrafts', 'ai-draft-site1')));
    await assertFails(getDoc(doc(learnerDb, 'aiDrafts', 'ai-draft-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'aiDrafts', 'ai-draft-site2')));

    await assertSucceeds(setDoc(doc(learnerDb, 'aiDrafts', 'ai-draft-new'), {
      siteId: 'site1',
      requesterId: learnerUser.uid,
      title: 'New AI draft',
      prompt: 'Help me explain my evidence.',
      status: 'requested',
    }));
    await assertFails(setDoc(doc(learnerDb, 'aiDrafts', 'ai-draft-missing-site'), {
      requesterId: learnerUser.uid,
      title: 'Missing-site AI draft',
      prompt: 'No site provenance.',
      status: 'requested',
    }));
    await assertFails(setDoc(doc(learnerDb, 'aiDrafts', 'ai-draft-other-requester'), {
      siteId: 'site1',
      requesterId: 'learner-2',
      title: 'Other requester AI draft',
      prompt: 'Wrong requester.',
      status: 'requested',
    }));
    await assertSucceeds(updateDoc(doc(educatorDb, 'aiDrafts', 'ai-draft-site1'), {
      status: 'reviewed',
      reviewerId: educatorUser.uid,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'aiDrafts', 'ai-draft-site1'), {
      requesterId: 'learner-2',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'aiDrafts', 'ai-draft-site1'), {
      siteId: 'site2',
    }));
  });
});

describe('Report audit access', () => {
  test('site admin can create scoped operational audit logs', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();

    await assertSucceeds(setDoc(doc(db, 'auditLogs', 'site-ops-audit'), {
      siteId: 'site1',
      actorId: siteAdminUser.uid,
      userId: siteAdminUser.uid,
      action: 'site_ops.event_resolved',
      entityType: 'siteOpsEvent',
      entityId: 'event-1',
      createdAt: Date.now(),
    }));
  });

  test('clients cannot spoof report delivery audit rows', async () => {
    const siteDb = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertFails(setDoc(doc(siteDb, 'auditLogs', 'report-delivery-spoof'), {
      siteId: 'site1',
      actorId: siteAdminUser.uid,
      userId: siteAdminUser.uid,
      action: 'report.delivery_recorded',
      entityType: 'learnerReport',
      entityId: learnerUser.uid,
      targetType: 'learner',
      targetId: learnerUser.uid,
      details: {
        learnerId: learnerUser.uid,
        reportAction: 'export_pdf',
        reportDelivery: 'downloaded',
      },
      createdAt: Date.now(),
    }));

    await assertFails(setDoc(doc(hqDb, 'auditLogs', 'report-blocked-spoof'), {
      siteId: 'site1',
      actorId: hqUser.uid,
      userId: hqUser.uid,
      action: 'report.delivery_blocked',
      entityType: 'learnerReport',
      entityId: learnerUser.uid,
      targetType: 'learner',
      targetId: learnerUser.uid,
      details: {
        learnerId: learnerUser.uid,
        reportAction: 'share',
        reportDelivery: 'contract-failed',
      },
      createdAt: Date.now(),
    }));
  });

  test('site audit client writes require site scope', async () => {
    const siteDb = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertFails(setDoc(doc(siteDb, 'auditLogs', 'site-ops-nosite'), {
      actorId: siteAdminUser.uid,
      userId: siteAdminUser.uid,
      action: 'site_ops.event_resolved',
      entityType: 'siteOpsEvent',
      entityId: 'event-1',
      createdAt: Date.now(),
    }));

    await assertFails(setDoc(doc(otherSiteDb, 'auditLogs', 'site-ops-wrong-site'), {
      siteId: 'site1',
      actorId: otherSiteUser.uid,
      userId: otherSiteUser.uid,
      action: 'site_ops.event_resolved',
      entityType: 'siteOpsEvent',
      entityId: 'event-1',
      createdAt: Date.now(),
    }));
  });
});

describe('Credentials Access', () => {
  test('learner can read their own credential', async () => {
    const db = testEnv.authenticatedContext(learnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'credentials', 'credential-1')));
  });

  test('educator can read learner credential', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'credentials', 'credential-1')));
  });

  test('educator can issue credential for learner', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'credentials', 'credential-2'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Capability Evidence Verified',
      issuerId: educatorUser.uid,
      status: 'issued',
      evidenceIds: ['evidence-1'],
      portfolioItemIds: ['portfolio-1'],
      proofBundleIds: ['proof-1'],
      growthEventIds: ['growth-1'],
      rubricApplicationId: 'rubric-application-1',
    }));
  });

  test('educator cannot issue credential without evidence provenance or as another issuer', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'credentials', 'credential-no-evidence'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Unsupported Credential',
      issuerId: educatorUser.uid,
      status: 'issued',
      evidenceIds: [],
    }));
    await assertFails(setDoc(doc(db, 'credentials', 'credential-wrong-issuer'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Wrong Issuer Credential',
      issuerId: 'educator-2',
      status: 'issued',
      evidenceIds: ['evidence-1'],
    }));
  });

  test('other-site educator cannot read or issue site1 learner credential', async () => {
    const db = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'credentials', 'credential-1')));
    await assertFails(setDoc(doc(db, 'credentials', 'credential-other-site'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      title: 'Cross Site Credential',
      issuerId: otherSiteUser.uid,
      status: 'issued',
      evidenceIds: ['evidence-1'],
    }));
  });

  test('parent cannot read learner credential', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'credentials', 'credential-1')));
  });

  test('hq can read learner credential directly', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'credentials', 'credential-1')));
  });
});

describe('Messaging Rules', () => {
  test('recipient can mark message as read', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(updateDoc(doc(db, 'messages', 'message-1'), {
      isRead: true,
      readAt: Date.now(),
      updatedAt: Date.now(),
    }));
  });

  test('sender cannot mark recipient message as read', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertFails(updateDoc(doc(db, 'messages', 'message-1'), {
      isRead: true,
      readAt: Date.now(),
      updatedAt: Date.now(),
    }));
  });

  test('recipient can delete delivered message', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'messages', 'message-delete'), {
        recipientId: parentUser.uid,
        senderId: educatorUser.uid,
        title: 'Delete me',
        body: 'Body',
        type: 'alert',
        isRead: false,
      });
    });

    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(deleteDoc(doc(db, 'messages', 'message-delete')));
  });
});

describe('Mission Step Governance Rules', () => {
  test('mission steps are readable reference content but only HQ can manage them', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'missions', 'mission-governed', 'steps', 'step-1'), {
        title: 'Launch challenge',
        order: 1,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'missions', 'mission-governed', 'steps', 'step-1')));
    await assertSucceeds(setDoc(doc(hqDb, 'missions', 'mission-governed', 'steps', 'step-hq'), {
      title: 'HQ-authored step',
      order: 2,
    }));
    await assertSucceeds(updateDoc(doc(hqDb, 'missions', 'mission-governed', 'steps', 'step-1'), {
      title: 'Updated launch challenge',
    }));
    await assertFails(setDoc(doc(educatorDb, 'missions', 'mission-governed', 'steps', 'step-educator'), {
      title: 'Educator-authored global step',
      order: 3,
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missions', 'mission-governed', 'steps', 'step-1'), {
      title: 'Educator global edit',
    }));
    await assertFails(deleteDoc(doc(educatorDb, 'missions', 'mission-governed', 'steps', 'step-1')));
  });
});

describe('Partner Ownership Rules', () => {
  test('partner can create and read own organization only', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'partnerOrgs', 'partner-org-1'), {
      ownerId: partnerUser.uid,
      name: 'Partner Studio',
      contactEmail: 'partner@example.com',
    }));
    await assertFails(setDoc(doc(db, 'partnerOrgs', 'partner-org-foreign'), {
      ownerId: 'partner-2',
      name: 'Foreign Partner Studio',
      contactEmail: 'partner2@example.com',
    }));
    await assertSucceeds(getDoc(doc(db, 'partnerOrgs', 'partner-org-1')));
  });

  test('partner cannot retarget organization ownership', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'partnerOrgs', 'partner-org-owned'), {
        ownerId: partnerUser.uid,
        name: 'Owned Partner Studio',
        contactEmail: 'partner@example.com',
      });
      await setDoc(doc(adminDb, 'partnerOrgs', 'partner-org-other'), {
        ownerId: 'partner-2',
        name: 'Other Partner Studio',
        contactEmail: 'partner2@example.com',
      });
    });

    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(updateDoc(doc(db, 'partnerOrgs', 'partner-org-owned'), {
      contactEmail: 'new-partner@example.com',
    }));
    await assertFails(updateDoc(doc(db, 'partnerOrgs', 'partner-org-owned'), {
      ownerId: 'partner-2',
    }));
    await assertFails(updateDoc(doc(db, 'partnerOrgs', 'partner-org-other'), {
      contactEmail: 'takeover@example.com',
    }));
    await assertFails(getDoc(doc(db, 'partnerOrgs', 'partner-org-other')));
  });

  test('partner can create own marketplace listing', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'marketplaceListings', 'listing-1'), {
      partnerId: partnerUser.uid,
      siteId: 'site1',
      title: 'STEM Residency',
      status: 'draft',
    }));
  });

  test('marketplace listing drafts are owner or HQ visible and published listings are catalog visible', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'marketplaceListings', 'listing-draft-owned'), {
        partnerId: partnerUser.uid,
        siteId: 'site1',
        title: 'Draft Listing',
        status: 'draft',
      });
      await setDoc(doc(adminDb, 'marketplaceListings', 'listing-draft-other'), {
        partnerId: 'partner-2',
        siteId: 'site1',
        title: 'Other Draft Listing',
        status: 'draft',
      });
      await setDoc(doc(adminDb, 'marketplaceListings', 'listing-published'), {
        partnerId: 'partner-2',
        siteId: 'site1',
        title: 'Published Listing',
        status: 'published',
      });
    });

    const partnerDb = testEnv.authenticatedContext(partnerUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertSucceeds(getDoc(doc(partnerDb, 'marketplaceListings', 'listing-draft-owned')));
    await assertSucceeds(getDoc(doc(hqDb, 'marketplaceListings', 'listing-draft-other')));
    await assertFails(getDoc(doc(learnerDb, 'marketplaceListings', 'listing-draft-other')));
    await assertSucceeds(getDoc(doc(learnerDb, 'marketplaceListings', 'listing-published')));
  });

  test('partner cannot create marketplace listing for different partner', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'marketplaceListings', 'listing-2'), {
      partnerId: 'partner-2',
      siteId: 'site1',
      title: 'Unauthorized Listing',
      status: 'draft',
    }));
  });

  test('partner marketplace listing create rejects legacy owner and governance fields', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'marketplaceListings', 'listing-legacy-owner'), {
      partnerOrgId: partnerUser.uid,
      siteId: 'site1',
      title: 'Legacy Owner Listing',
      status: 'draft',
    }));
    await assertFails(setDoc(doc(db, 'marketplaceListings', 'listing-with-governance'), {
      partnerId: partnerUser.uid,
      siteId: 'site1',
      title: 'Governance Pollution Listing',
      status: 'draft',
      approvedBy: partnerUser.uid,
      publishedAt: new Date(),
    }));
  });

  test('partner can create own contract', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'partnerContracts', 'contract-1'), {
      partnerId: partnerUser.uid,
      status: 'pending',
      siteId: 'site1',
      title: 'Pilot Contract',
    }));
  });

  test('partner contract writes cannot use legacy ownership or self-approve', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'partnerContracts', 'contract-owned'), {
        partnerId: partnerUser.uid,
        status: 'pending',
        siteId: 'site1',
        title: 'Owned Contract',
      });
    });

    const partnerDb = testEnv.authenticatedContext(partnerUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertFails(setDoc(doc(partnerDb, 'partnerContracts', 'contract-legacy-owner'), {
      partnerOrgId: partnerUser.uid,
      status: 'pending',
      siteId: 'site1',
      title: 'Legacy Owner Contract',
    }));
    await assertFails(updateDoc(doc(partnerDb, 'partnerContracts', 'contract-owned'), {
      status: 'approved',
      approvedBy: partnerUser.uid,
      approvedAt: new Date(),
    }));
    await assertSucceeds(updateDoc(doc(partnerDb, 'partnerContracts', 'contract-owned'), {
      title: 'Partner Updated Contract Title',
      updatedAt: new Date(),
    }));
    await assertSucceeds(updateDoc(doc(hqDb, 'partnerContracts', 'contract-owned'), {
      status: 'approved',
      approvedBy: hqUser.uid,
      approvedAt: new Date(),
    }));
  });

  test('partner cannot update listing owned by another partner', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'marketplaceListings', 'listing-foreign'), {
        partnerId: 'partner-2',
        siteId: 'site1',
        title: 'Foreign Listing',
        status: 'published',
      });
    });

    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertFails(updateDoc(doc(db, 'marketplaceListings', 'listing-foreign'), {
      status: 'archived',
    }));
  });

  test('partner cannot self-publish marketplace listing or edit governance fields', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'marketplaceListings', 'listing-owned-draft'), {
        partnerId: partnerUser.uid,
        siteId: 'site1',
        title: 'Owned Draft Listing',
        description: 'Partner-owned draft.',
        status: 'draft',
      });
      await setDoc(doc(adminDb, 'marketplaceListings', 'listing-owned-published'), {
        partnerId: partnerUser.uid,
        siteId: 'site1',
        title: 'Owned Published Listing',
        description: 'Partner-owned published listing.',
        status: 'published',
        publishedAt: new Date(),
      });
    });

    const partnerDb = testEnv.authenticatedContext(partnerUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertSucceeds(updateDoc(doc(partnerDb, 'marketplaceListings', 'listing-owned-draft'), {
      title: 'Edited Draft Listing',
      updatedAt: new Date(),
    }));
    await assertSucceeds(updateDoc(doc(partnerDb, 'marketplaceListings', 'listing-owned-published'), {
      title: 'Edited Published Listing',
      description: 'Partner-maintained published listing.',
      updatedAt: new Date(),
    }));
    await assertFails(updateDoc(doc(partnerDb, 'marketplaceListings', 'listing-owned-draft'), {
      status: 'published',
      publishedAt: new Date(),
    }));
    await assertFails(updateDoc(doc(partnerDb, 'marketplaceListings', 'listing-owned-draft'), {
      partnerId: 'partner-2',
    }));
    await assertSucceeds(updateDoc(doc(hqDb, 'marketplaceListings', 'listing-owned-draft'), {
      status: 'published',
      publishedAt: new Date(),
    }));
  });

  test('partner can create own evidence-backed deliverable for a contract', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'partnerDeliverables', 'deliverable-1'), {
      partnerId: partnerUser.uid,
      submittedBy: partnerUser.uid,
      contractId: 'contract-1',
      siteId: 'site1',
      title: 'Evidence Pack',
      evidenceUrl: 'https://files.scholesa.test/evidence-pack.pdf',
      status: 'submitted',
    }));
  });

  test('partner cannot create deliverable for another partner or accept it directly', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'partnerDeliverables', 'deliverable-owned'), {
        partnerId: partnerUser.uid,
        submittedBy: partnerUser.uid,
        contractId: 'contract-1',
        siteId: 'site1',
        title: 'Evidence Pack',
        status: 'submitted',
      });
    });

    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertFails(setDoc(doc(db, 'partnerDeliverables', 'deliverable-foreign'), {
      partnerId: 'partner-2',
      submittedBy: partnerUser.uid,
      contractId: 'contract-1',
      siteId: 'site1',
      title: 'Unauthorized Evidence Pack',
      status: 'submitted',
    }));
    await assertFails(updateDoc(doc(db, 'partnerDeliverables', 'deliverable-owned'), {
      status: 'accepted',
      acceptedBy: partnerUser.uid,
    }));
  });

  test('partner can read only owned integration connections', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'integrationConnections', 'owned-connection'), {
        ownerUserId: partnerUser.uid,
        provider: 'clever',
        status: 'connected',
        createdAt: new Date('2026-05-08T00:00:00.000Z'),
      });
      await setDoc(doc(adminDb, 'integrationConnections', 'foreign-connection'), {
        ownerUserId: 'partner-2',
        provider: 'google-classroom',
        status: 'connected',
        createdAt: new Date('2026-05-08T00:01:00.000Z'),
      });
    });

    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'integrationConnections', 'owned-connection')));
    await assertFails(getDoc(doc(db, 'integrationConnections', 'foreign-connection')));
    await assertSucceeds(getDocs(query(
      collection(db, 'integrationConnections'),
      where('ownerUserId', '==', partnerUser.uid),
      orderBy('createdAt', 'desc'),
    )));
  });

  test('external integration links require same-site educator or HQ reads', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'externalCourseLinks', 'course-link-site1'), {
        siteId: 'site1',
        provider: 'google_classroom',
        providerCourseId: 'course-1',
        ownerUserId: educatorUser.uid,
        sessionId: 'session-1',
      });
      await setDoc(doc(adminDb, 'externalCourseLinks', 'course-link-nosite'), {
        provider: 'google_classroom',
        providerCourseId: 'course-nosite',
        ownerUserId: educatorUser.uid,
        sessionId: 'session-1',
      });
      await setDoc(doc(adminDb, 'externalCourseLinks', 'course-link-site2'), {
        siteId: 'site2',
        provider: 'google_classroom',
        providerCourseId: 'course-2',
        ownerUserId: educatorUser.uid,
        sessionId: 'session-2',
      });
      await setDoc(doc(adminDb, 'externalCourseworkLinks', 'coursework-link-site1'), {
        siteId: 'site1',
        provider: 'google_classroom',
        providerCourseId: 'course-1',
        providerCourseWorkId: 'coursework-1',
        missionId: 'mission-1',
        publishedBy: educatorUser.uid,
      });
      await setDoc(doc(adminDb, 'externalRepoLinks', 'repo-link-site1'), {
        siteId: 'site1',
        repoFullName: 'scholesa/learner-project',
        repoUrl: 'https://github.com/scholesa/learner-project',
        learnerId: learnerUser.uid,
      });
      await setDoc(doc(adminDb, 'externalPullRequestLinks', 'pr-link-site1'), {
        siteId: 'site1',
        repoFullName: 'scholesa/learner-project',
        prNumber: 7,
        prUrl: 'https://github.com/scholesa/learner-project/pull/7',
        learnerId: learnerUser.uid,
      });
      await setDoc(doc(adminDb, 'externalPullRequestLinks', 'pr-link-nosite'), {
        repoFullName: 'scholesa/learner-project',
        prNumber: 8,
        prUrl: 'https://github.com/scholesa/learner-project/pull/8',
        learnerId: learnerUser.uid,
      });
      await setDoc(doc(adminDb, 'externalPullRequestLinks', 'pr-link-site2'), {
        siteId: 'site2',
        repoFullName: 'scholesa/learner-project',
        prNumber: 9,
        prUrl: 'https://github.com/scholesa/learner-project/pull/9',
        learnerId: learnerUser.uid,
      });
    });

    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(educatorDb, 'externalCourseLinks', 'course-link-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'externalCourseLinks', 'course-link-site1')));
    await assertFails(getDoc(doc(learnerDb, 'externalCourseLinks', 'course-link-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'externalCourseLinks', 'course-link-site1')));
    await assertFails(getDoc(doc(educatorDb, 'externalCourseLinks', 'course-link-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'externalCourseLinks', 'course-link-site2')));
    await assertSucceeds(getDoc(doc(educatorDb, 'externalCourseworkLinks', 'coursework-link-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'externalRepoLinks', 'repo-link-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'externalPullRequestLinks', 'pr-link-site1')));
    await assertFails(getDoc(doc(educatorDb, 'externalPullRequestLinks', 'pr-link-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'externalPullRequestLinks', 'pr-link-site2')));
    await assertFails(setDoc(doc(educatorDb, 'externalCourseLinks', 'course-link-client-write'), {
      siteId: 'site1',
      provider: 'google_classroom',
      providerCourseId: 'course-client',
      ownerUserId: educatorUser.uid,
      sessionId: 'session-1',
    }));
  });
});

describe('Artifact Rules', () => {
  test('approved exemplar artifacts are readable by authenticated users for AI coaching', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'artifacts', 'artifact-exemplar-approved'), {
        siteId: 'site1',
        learnerId: learnerUser.uid,
        title: 'Approved Exemplar',
        status: 'approved',
        isExemplar: true,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'artifacts', 'artifact-exemplar-approved')));
    await assertSucceeds(getDoc(doc(otherSiteDb, 'artifacts', 'artifact-exemplar-approved')));
  });

  test('learner artifacts require site-scoped learner, linked parent, educator, or HQ access', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'artifacts', 'artifact-learner-site1'), {
        siteId: 'site1',
        learnerId: learnerUser.uid,
        title: 'Learner Draft Artifact',
        status: 'draft',
        isExemplar: false,
      });
      await setDoc(doc(adminDb, 'artifacts', 'artifact-learner-nosite'), {
        learnerId: learnerUser.uid,
        title: 'Legacy Unscoped Artifact',
        status: 'draft',
        isExemplar: false,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const parentDb = testEnv.authenticatedContext(parentUser.uid).firestore();
    const otherParentDb = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'artifacts', 'artifact-learner-site1')));
    await assertSucceeds(getDoc(doc(parentDb, 'artifacts', 'artifact-learner-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'artifacts', 'artifact-learner-site1')));
    await assertFails(getDoc(doc(otherParentDb, 'artifacts', 'artifact-learner-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'artifacts', 'artifact-learner-site1')));
    await assertFails(getDoc(doc(learnerDb, 'artifacts', 'artifact-learner-nosite')));
    await assertSucceeds(getDoc(doc(hqDb, 'artifacts', 'artifact-learner-nosite')));
  });
});

describe('Rubric Governance Rules', () => {
  test('only HQ can manage rubric definitions', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'rubrics', 'rubric-1'), {
        title: 'Systems Thinking L1-L4',
        capabilityId: 'capability-systems-thinking',
        levelCount: 4,
        status: 'draft',
        createdBy: hqUser.uid,
      });
      await setDoc(doc(adminDb, 'assessmentRubrics', 'assessment-rubric-1'), {
        title: 'Evidence Reasoning',
        capabilityIds: ['capability-evidence-reasoning'],
        status: 'published',
        createdBy: hqUser.uid,
      });
      await setDoc(doc(adminDb, 'rubricTemplates', 'rubric-template-site1'), {
        siteId: 'site1',
        title: 'Evidence Reasoning Template',
        capabilityIds: ['capability-evidence-reasoning'],
        criteria: [],
        status: 'published',
        createdBy: hqUser.uid,
      });
      await setDoc(doc(adminDb, 'rubricTemplates', 'rubric-template-nosite'), {
        title: 'Legacy Template',
        capabilityIds: ['capability-evidence-reasoning'],
        criteria: [],
        status: 'published',
        createdBy: hqUser.uid,
      });
      await setDoc(doc(adminDb, 'rubricTemplates', 'rubric-template-site2'), {
        siteId: 'site2',
        title: 'Other Site Template',
        capabilityIds: ['capability-evidence-reasoning'],
        criteria: [],
        status: 'published',
        createdBy: hqUser.uid,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'rubrics', 'rubric-1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'assessmentRubrics', 'assessment-rubric-1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'rubricTemplates', 'rubric-template-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'rubricTemplates', 'rubric-template-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'rubricTemplates', 'rubric-template-site1')));
    await assertFails(getDoc(doc(educatorDb, 'rubricTemplates', 'rubric-template-nosite')));
    await assertFails(getDoc(doc(educatorDb, 'rubricTemplates', 'rubric-template-site2')));
    await assertSucceeds(setDoc(doc(hqDb, 'rubrics', 'rubric-hq-new'), {
      title: 'Capability Reasoning L1-L4',
      capabilityId: 'capability-reasoning',
      levelCount: 4,
      status: 'draft',
      createdBy: hqUser.uid,
    }));
    await assertFails(setDoc(doc(educatorDb, 'rubrics', 'rubric-educator-new'), {
      title: 'Educator-created rubric',
      capabilityId: 'capability-reasoning',
      levelCount: 4,
      status: 'draft',
      createdBy: educatorUser.uid,
    }));
    await assertSucceeds(updateDoc(doc(hqDb, 'rubrics', 'rubric-1'), {
      status: 'published',
    }));
    await assertFails(updateDoc(doc(educatorDb, 'rubrics', 'rubric-1'), {
      status: 'published',
    }));
    await assertSucceeds(setDoc(doc(hqDb, 'assessmentRubrics', 'assessment-rubric-hq-new'), {
      title: 'HQ assessment rubric',
      capabilityIds: ['capability-evidence-reasoning'],
      status: 'draft',
      createdBy: hqUser.uid,
    }));
    await assertSucceeds(setDoc(doc(hqDb, 'rubricTemplates', 'rubric-template-hq-new'), {
      siteId: 'site1',
      title: 'HQ rubric template',
      capabilityIds: ['capability-evidence-reasoning'],
      criteria: [],
      status: 'draft',
      createdBy: hqUser.uid,
    }));
    await assertFails(setDoc(doc(educatorDb, 'rubricTemplates', 'rubric-template-educator-new'), {
      siteId: 'site1',
      title: 'Educator rubric template',
      capabilityIds: ['capability-evidence-reasoning'],
      criteria: [],
      status: 'draft',
      createdBy: educatorUser.uid,
    }));
    await assertFails(setDoc(doc(educatorDb, 'assessmentRubrics', 'assessment-rubric-educator-new'), {
      title: 'Educator assessment rubric',
      capabilityIds: ['capability-evidence-reasoning'],
      status: 'draft',
      createdBy: educatorUser.uid,
    }));
    await assertSucceeds(deleteDoc(doc(hqDb, 'rubrics', 'rubric-1')));
    await assertFails(deleteDoc(doc(educatorDb, 'assessmentRubrics', 'assessment-rubric-1')));
  });
});

describe('Fulfillment Boundary Rules', () => {
  test('fulfillments require owner or HQ access within site scope', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'fulfillments', 'fulfillment-site1'), {
        siteId: 'site1',
        orderId: 'order-1',
        listingId: 'listing-1',
        userId: learnerUser.uid,
        status: 'pending',
        note: 'Awaiting partner fulfillment',
      });
      await setDoc(doc(adminDb, 'fulfillments', 'fulfillment-nosite'), {
        orderId: 'order-legacy',
        listingId: 'listing-1',
        userId: learnerUser.uid,
        status: 'pending',
        note: 'Legacy fulfillment without site scope',
      });
      await setDoc(doc(adminDb, 'fulfillments', 'fulfillment-site2'), {
        siteId: 'site2',
        orderId: 'order-2',
        listingId: 'listing-2',
        userId: learnerUser.uid,
        status: 'pending',
        note: 'Other site fulfillment',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'fulfillments', 'fulfillment-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'fulfillments', 'fulfillment-site1')));
    await assertFails(getDoc(doc(educatorDb, 'fulfillments', 'fulfillment-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'fulfillments', 'fulfillment-site1')));
    await assertFails(getDoc(doc(learnerDb, 'fulfillments', 'fulfillment-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'fulfillments', 'fulfillment-site2')));
    await assertFails(setDoc(doc(learnerDb, 'fulfillments', 'fulfillment-client-write'), {
      siteId: 'site1',
      orderId: 'order-client',
      listingId: 'listing-1',
      userId: learnerUser.uid,
      status: 'pending',
    }));
  });
});

describe('Mission Snapshot Boundary Rules', () => {
  test('mission snapshots require site scope and HQ or educator create', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'missionSnapshots', 'snapshot-site1'), {
        siteId: 'site1',
        missionId: 'mission-1',
        contentHash: 'hash-site1',
        title: 'Mission Snapshot',
        description: 'Versioned mission content.',
        pillarCodes: ['future-skills'],
      });
      await setDoc(doc(adminDb, 'missionSnapshots', 'snapshot-nosite'), {
        missionId: 'mission-legacy',
        contentHash: 'hash-nosite',
        title: 'Legacy Mission Snapshot',
        description: 'Missing site scope.',
        pillarCodes: ['future-skills'],
      });
      await setDoc(doc(adminDb, 'missionSnapshots', 'snapshot-site2'), {
        siteId: 'site2',
        missionId: 'mission-2',
        contentHash: 'hash-site2',
        title: 'Other Site Mission Snapshot',
        description: 'Wrong site.',
        pillarCodes: ['future-skills'],
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerUser.uid).firestore();
    const educatorDb = testEnv.authenticatedContext(educatorUser.uid).firestore();
    const hqDb = testEnv.authenticatedContext(hqUser.uid).firestore();
    const otherSiteDb = testEnv.authenticatedContext(otherSiteUser.uid).firestore();

    await assertSucceeds(getDoc(doc(learnerDb, 'missionSnapshots', 'snapshot-site1')));
    await assertSucceeds(getDoc(doc(educatorDb, 'missionSnapshots', 'snapshot-site1')));
    await assertSucceeds(getDoc(doc(hqDb, 'missionSnapshots', 'snapshot-site1')));
    await assertFails(getDoc(doc(otherSiteDb, 'missionSnapshots', 'snapshot-site1')));
    await assertFails(getDoc(doc(learnerDb, 'missionSnapshots', 'snapshot-nosite')));
    await assertFails(getDoc(doc(learnerDb, 'missionSnapshots', 'snapshot-site2')));
    await assertSucceeds(setDoc(doc(hqDb, 'missionSnapshots', 'snapshot-hq-new'), {
      siteId: 'site1',
      missionId: 'mission-1',
      contentHash: 'hash-hq-new',
      title: 'HQ Mission Snapshot',
      description: 'HQ-created snapshot.',
      pillarCodes: ['future-skills'],
    }));
    await assertSucceeds(setDoc(doc(educatorDb, 'missionSnapshots', 'snapshot-educator-new'), {
      siteId: 'site1',
      missionId: 'mission-1',
      contentHash: 'hash-educator-new',
      title: 'Educator Mission Snapshot',
      description: 'Educator-created snapshot.',
      pillarCodes: ['future-skills'],
    }));
    await assertFails(setDoc(doc(learnerDb, 'missionSnapshots', 'snapshot-learner-new'), {
      siteId: 'site1',
      missionId: 'mission-1',
      contentHash: 'hash-learner-new',
      title: 'Learner Mission Snapshot',
      description: 'Learner-created snapshot.',
      pillarCodes: ['future-skills'],
    }));
    await assertFails(setDoc(doc(educatorDb, 'missionSnapshots', 'snapshot-missing-site'), {
      missionId: 'mission-1',
      contentHash: 'hash-missing-site',
      title: 'Missing Site Mission Snapshot',
      description: 'Missing site scope.',
      pillarCodes: ['future-skills'],
    }));
    await assertFails(updateDoc(doc(educatorDb, 'missionSnapshots', 'snapshot-site1'), {
      title: 'Updated snapshot',
    }));
  });
});

describe('Default Deny', () => {
  test('unknown collections are denied', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'unknownCollection', 'doc1')));
  });
});
