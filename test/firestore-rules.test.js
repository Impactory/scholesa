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

  test('educator can read other profiles', async () => {
    const db = testEnv.authenticatedContext(educatorUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', learnerUser.uid)));
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

describe('Partner Ownership Rules', () => {
  test('partner can create own marketplace listing', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'marketplaceListings', 'listing-1'), {
      partnerId: partnerUser.uid,
      siteId: 'site1',
      title: 'STEM Residency',
      status: 'draft',
    }));
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

  test('partner can create own contract', async () => {
    const db = testEnv.authenticatedContext(partnerUser.uid).firestore();
    await assertSucceeds(setDoc(doc(db, 'partnerContracts', 'contract-1'), {
      partnerId: partnerUser.uid,
      status: 'pending',
      siteId: 'site1',
      title: 'Pilot Contract',
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
});

describe('Default Deny', () => {
  test('unknown collections are denied', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'unknownCollection', 'doc1')));
  });
});
