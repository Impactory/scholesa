/**
 * Firestore Rules Test Suite
 * Based on docs/67_FIRESTORE_RULES_TEST_MATRIX.md
 * 
 * Run with: firebase emulators:exec "npm test"
 */

const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { deleteDoc, doc, getDoc, setDoc, updateDoc, setLogLevel } = require('firebase/firestore');
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

  test('site admin cannot read other site federated learning experiments', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningExperiments', 'fl_exp_other_site')),
    );
  });

  test('site admin can read prototype update summaries for their site', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningUpdateSummaries', 'fl_update_1')),
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

  test('site admins cannot read cross-site aggregation runs directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningAggregationRuns', 'fl_agg_demo_1')),
    );
  });

  test('HQ can read bounded merge artifacts', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningMergeArtifacts', 'fl_merge_demo_1')),
    );
  });

  test('site admins cannot read merge artifacts directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningMergeArtifacts', 'fl_merge_demo_1')),
    );
  });

  test('HQ can read bounded candidate model packages', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertSucceeds(
      getDoc(doc(db, 'federatedLearningCandidateModelPackages', 'fl_pkg_demo_1')),
    );
  });

  test('site admins cannot read candidate model packages directly', async () => {
    const db = testEnv.authenticatedContext(siteAdminUser.uid).firestore();
    await assertFails(
      getDoc(doc(db, 'federatedLearningCandidateModelPackages', 'fl_pkg_demo_1')),
    );
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

describe('Portfolio Access', () => {
  test('linked parent can read learner portfolio item', async () => {
    const db = testEnv.authenticatedContext(parentUser.uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'portfolioItems', 'portfolio-1')));
  });

  test('unlinked parent cannot read learner portfolio item', async () => {
    const db = testEnv.authenticatedContext(otherParentUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'portfolioItems', 'portfolio-1')));
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
});

describe('Default Deny', () => {
  test('unknown collections are denied', async () => {
    const db = testEnv.authenticatedContext(hqUser.uid).firestore();
    await assertFails(getDoc(doc(db, 'unknownCollection', 'doc1')));
  });
});
