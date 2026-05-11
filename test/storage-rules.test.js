/**
 * Storage Rules Test Suite
 * Covers learner media privacy boundaries below portfolio/report workflows.
 */

const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, setLogLevel, Timestamp } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

const firebaseRc = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../.firebaserc'), 'utf8'));
const PROJECT_ID = firebaseRc.projects?.default ?? 'scholesa-test';

let testEnv;

const learnerUser = { uid: 'learner-1', email: 'learner@example.com' };
const otherLearnerUser = { uid: 'learner-2', email: 'learner2@example.com' };
const parentUser = { uid: 'parent-1', email: 'parent@example.com' };
const otherParentUser = { uid: 'parent-2', email: 'parent2@example.com' };
const educatorUser = { uid: 'educator-1', email: 'educator@site1.com' };
const otherSiteEducatorUser = { uid: 'educator-2', email: 'educator@site2.com' };
const siteAdminUser = { uid: 'site-admin-1', email: 'siteadmin@site1.com' };
const hqUser = { uid: 'hq-user-1', email: 'hq@scholesa.com' };

function emulatorEndpoint(value, fallbackPort) {
  const [host, portRaw] = (value || `127.0.0.1:${fallbackPort}`).split(':');
  return { host, port: Number(portRaw || fallbackPort) };
}

function authContext(user, token) {
  return testEnv.authenticatedContext(user.uid, {
    email: user.email,
    ...token,
  });
}

function portfolioMediaRef(context, fileName = 'artifact.png') {
  return context.storage().ref(`portfolioMedia/${learnerUser.uid}/${fileName}`);
}

function reportShareMediaRef(context, shareRequestId = 'share-active', learnerId = learnerUser.uid) {
  return context.storage().ref(`reportShareMedia/${learnerId}/${shareRequestId}/passport.pdf`);
}

beforeAll(async () => {
  setLogLevel('error');
  const firestoreEndpoint = emulatorEndpoint(process.env.FIRESTORE_EMULATOR_HOST, '8080');
  const storageEndpoint = emulatorEndpoint(process.env.FIREBASE_STORAGE_EMULATOR_HOST, '9199');

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: firestoreEndpoint.host,
      port: firestoreEndpoint.port,
    },
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, '../storage.rules'), 'utf8'),
      host: storageEndpoint.host,
      port: storageEndpoint.port,
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
  await testEnv.clearStorage();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', learnerUser.uid), {
      email: learnerUser.email,
      role: 'learner',
      siteIds: ['site1'],
      parentIds: [parentUser.uid],
    });
    await setDoc(doc(db, 'users', otherLearnerUser.uid), {
      email: otherLearnerUser.email,
      role: 'learner',
      siteIds: ['site2'],
      parentIds: [],
    });
    await setDoc(doc(db, 'users', parentUser.uid), {
      email: parentUser.email,
      role: 'parent',
      siteIds: ['site1'],
    });
    await setDoc(doc(db, 'users', otherParentUser.uid), {
      email: otherParentUser.email,
      role: 'parent',
      siteIds: ['site2'],
    });

    const storage = context.storage();
    await storage
      .ref(`portfolioMedia/${learnerUser.uid}/artifact.png`)
      .putString('seed learner media', 'raw', {
        contentType: 'image/png',
        customMetadata: { siteId: 'site1' },
      });
    await setDoc(doc(db, 'reportShareRequests', 'share-active'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      createdBy: educatorUser.uid,
      status: 'active',
      audience: 'guardian',
      visibility: 'family',
      explicitConsentId: 'consent-active',
      expiresAt: Timestamp.fromDate(new Date('2099-01-01T00:00:00.000Z')),
    });
    await setDoc(doc(db, 'reportShareRequests', 'share-revoked'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      createdBy: educatorUser.uid,
      status: 'revoked',
      audience: 'guardian',
      visibility: 'family',
      explicitConsentId: 'consent-revoked',
      expiresAt: Timestamp.fromDate(new Date('2099-01-01T00:00:00.000Z')),
    });
    await setDoc(doc(db, 'reportShareRequests', 'share-expired'), {
      siteId: 'site1',
      learnerId: learnerUser.uid,
      createdBy: educatorUser.uid,
      status: 'active',
      audience: 'guardian',
      visibility: 'family',
      explicitConsentId: 'consent-expired',
      expiresAt: Timestamp.fromDate(new Date('2000-01-01T00:00:00.000Z')),
    });
    await setDoc(doc(db, 'reportShareRequests', 'share-other-learner'), {
      siteId: 'site1',
      learnerId: otherLearnerUser.uid,
      createdBy: educatorUser.uid,
      status: 'active',
      audience: 'guardian',
      visibility: 'family',
      explicitConsentId: 'consent-other-learner',
      expiresAt: Timestamp.fromDate(new Date('2099-01-01T00:00:00.000Z')),
    });
    await storage
      .ref(`reportShareMedia/${learnerUser.uid}/share-active/passport.pdf`)
      .putString('seed report share media', 'raw', {
        contentType: 'application/pdf',
        customMetadata: { siteId: 'site1', shareRequestId: 'share-active' },
      });
    await storage
      .ref(`reportShareMedia/${learnerUser.uid}/share-revoked/passport.pdf`)
      .putString('seed revoked report share media', 'raw', {
        contentType: 'application/pdf',
        customMetadata: { siteId: 'site1', shareRequestId: 'share-revoked' },
      });
    await storage
      .ref(`reportShareMedia/${learnerUser.uid}/share-expired/passport.pdf`)
      .putString('seed expired report share media', 'raw', {
        contentType: 'application/pdf',
        customMetadata: { siteId: 'site1', shareRequestId: 'share-expired' },
      });
    await storage
      .ref(`reportShareMedia/${learnerUser.uid}/share-other-learner/passport.pdf`)
      .putString('seed mismatched learner report share media', 'raw', {
        contentType: 'application/pdf',
        customMetadata: { siteId: 'site1', shareRequestId: 'share-other-learner' },
      });
  });
});

describe('portfolio media learner access', () => {
  test('learner owner can read and upload allowed media', async () => {
    const context = authContext(learnerUser, { role: 'learner', siteIds: ['site1'] });

    await assertSucceeds(portfolioMediaRef(context).getMetadata());
    await assertSucceeds(
      portfolioMediaRef(context, 'new-artifact.png').putString('image', 'raw', {
        contentType: 'image/png',
        customMetadata: { siteId: 'site1' },
      })
    );
  });

  test('learner cannot upload without site metadata, disallowed type, or another learner media', async () => {
    const context = authContext(learnerUser, { role: 'learner', siteIds: ['site1'] });

    await assertFails(
      portfolioMediaRef(context, 'missing-site.png').putString('image', 'raw', {
        contentType: 'image/png',
      })
    );
    await assertFails(
      portfolioMediaRef(context, 'script.js').putString('alert(1)', 'raw', {
        contentType: 'application/javascript',
        customMetadata: { siteId: 'site1' },
      })
    );
    await assertFails(
      context
        .storage()
        .ref(`portfolioMedia/${otherLearnerUser.uid}/cross-site.png`)
        .putString('image', 'raw', {
          contentType: 'image/png',
          customMetadata: { siteId: 'site1' },
        })
    );
  });
});

describe('portfolio media guardian and staff reads', () => {
  test('linked guardian can read learner media', async () => {
    const context = authContext(parentUser, {
      role: 'parent',
      siteIds: ['site1'],
      linkedLearnerIds: [learnerUser.uid],
    });
    await assertSucceeds(portfolioMediaRef(context).getMetadata());
  });

  test('unlinked guardian cannot read learner media', async () => {
    const context = authContext(otherParentUser, { role: 'parent', siteIds: ['site2'] });
    await assertFails(portfolioMediaRef(context).getMetadata());
  });

  test('same-site educator can read learner media', async () => {
    const educatorContext = authContext(educatorUser, { role: 'educator', siteIds: ['site1'] });

    await assertSucceeds(portfolioMediaRef(educatorContext).getMetadata());
  });

  test('same-site site admin can read learner media', async () => {
    const siteContext = authContext(siteAdminUser, { role: 'site', siteIds: ['site1'] });

    await assertSucceeds(portfolioMediaRef(siteContext).getMetadata());
  });

  test('HQ can read learner media', async () => {
    const hqContext = authContext(hqUser, { role: 'hq', siteIds: ['site1', 'site2'] });

    await assertSucceeds(portfolioMediaRef(hqContext).getMetadata());
  });

  test('other-site educator and unauthenticated users cannot read learner media', async () => {
    const otherSiteContext = authContext(otherSiteEducatorUser, {
      role: 'educator',
      siteIds: ['site2'],
    });
    const unauthenticatedContext = testEnv.unauthenticatedContext();

    await assertFails(portfolioMediaRef(otherSiteContext).getMetadata());
    await assertFails(portfolioMediaRef(unauthenticatedContext).getMetadata());
  });
});

describe('report share media consent lifecycle access', () => {
  test('active report share media is readable by the learner, linked guardian, creator, same-site staff, and HQ', async () => {
    const learnerContext = authContext(learnerUser, { role: 'learner', siteIds: ['site1'] });
    const guardianContext = authContext(parentUser, {
      role: 'parent',
      siteIds: ['site1'],
      linkedLearnerIds: [learnerUser.uid],
    });
    const creatorContext = authContext(educatorUser, { role: 'educator', siteIds: ['site1'] });
    const siteContext = authContext(siteAdminUser, { role: 'site', siteIds: ['site1'] });
    const hqContext = authContext(hqUser, { role: 'hq', siteIds: ['site1', 'site2'] });

    await assertSucceeds(reportShareMediaRef(learnerContext).getMetadata());
    await assertSucceeds(reportShareMediaRef(guardianContext).getMetadata());
    await assertSucceeds(reportShareMediaRef(creatorContext).getMetadata());
    await assertSucceeds(reportShareMediaRef(siteContext).getMetadata());
    await assertSucceeds(reportShareMediaRef(hqContext).getMetadata());
  });

  test('report share media denies revoked, expired, missing, wrong-learner, and wrong-site access', async () => {
    const guardianContext = authContext(parentUser, {
      role: 'parent',
      siteIds: ['site1'],
      linkedLearnerIds: [learnerUser.uid],
    });
    const otherGuardianContext = authContext(otherParentUser, {
      role: 'parent',
      siteIds: ['site2'],
      linkedLearnerIds: [otherLearnerUser.uid],
    });
    const otherSiteContext = authContext(otherSiteEducatorUser, {
      role: 'educator',
      siteIds: ['site2'],
    });
    const unauthenticatedContext = testEnv.unauthenticatedContext();

    await assertFails(reportShareMediaRef(guardianContext, 'share-revoked').getMetadata());
    await assertFails(reportShareMediaRef(guardianContext, 'share-expired').getMetadata());
    await assertFails(reportShareMediaRef(guardianContext, 'share-missing').getMetadata());
    await assertFails(reportShareMediaRef(guardianContext, 'share-other-learner').getMetadata());
    await assertFails(reportShareMediaRef(otherGuardianContext).getMetadata());
    await assertFails(reportShareMediaRef(otherSiteContext).getMetadata());
    await assertFails(reportShareMediaRef(unauthenticatedContext).getMetadata());
  });

  test('report share media is server-owned and cannot be uploaded by clients', async () => {
    const learnerContext = authContext(learnerUser, { role: 'learner', siteIds: ['site1'] });
    const educatorContext = authContext(educatorUser, { role: 'educator', siteIds: ['site1'] });

    await assertFails(
      reportShareMediaRef(learnerContext, 'share-active', learnerUser.uid).putString('pdf', 'raw', {
        contentType: 'application/pdf',
        customMetadata: { siteId: 'site1', shareRequestId: 'share-active' },
      })
    );
    await assertFails(
      reportShareMediaRef(educatorContext, 'share-active', learnerUser.uid).putString('pdf', 'raw', {
        contentType: 'application/pdf',
        customMetadata: { siteId: 'site1', shareRequestId: 'share-active' },
      })
    );
  });
});