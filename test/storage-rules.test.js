/**
 * Storage Rules Test Suite
 * Covers learner media privacy boundaries below portfolio/report workflows.
 */

const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, setLogLevel } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'scholesa-test';

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