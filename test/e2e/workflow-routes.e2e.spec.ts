import { test, expect, type Locator, type Page } from '@playwright/test';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';

type SeedUser = {
  uid: string;
  email: string;
  displayName: string;
  role: Role;
  siteIds?: string[];
  activeSiteId?: string;
  learnerIds?: string[];
  parentIds?: string[];
};

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'scholesa-e2e';
const FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const SITE_ALPHA = 'site-alpha';
const SITE_BETA = 'site-beta';
const MISSION_ID = 'mission-robotics';
const SESSION_ID = 'session-future-skills';

const USERS: Record<Role | 'otherLearner' | 'secondParent', SeedUser> = {
  learner: {
    uid: 'learner-alpha',
    email: 'learner.alpha@scholesa.test',
    displayName: 'Learner Alpha',
    role: 'learner',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
    parentIds: ['parent-alpha'],
  },
  educator: {
    uid: 'educator-alpha',
    email: 'educator.alpha@scholesa.test',
    displayName: 'Educator Alpha',
    role: 'educator',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
  },
  parent: {
    uid: 'parent-alpha',
    email: 'parent.alpha@scholesa.test',
    displayName: 'Parent Alpha',
    role: 'parent',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
    learnerIds: ['learner-alpha'],
  },
  site: {
    uid: 'site-alpha-admin',
    email: 'site.alpha@scholesa.test',
    displayName: 'Site Alpha Admin',
    role: 'site',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
  },
  partner: {
    uid: 'partner-alpha',
    email: 'partner.alpha@scholesa.test',
    displayName: 'Partner Alpha',
    role: 'partner',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
  },
  hq: {
    uid: 'hq-alpha',
    email: 'hq.alpha@scholesa.test',
    displayName: 'HQ Alpha',
    role: 'hq',
    siteIds: [SITE_ALPHA, SITE_BETA],
    activeSiteId: SITE_ALPHA,
  },
  otherLearner: {
    uid: 'learner-beta',
    email: 'learner.beta@scholesa.test',
    displayName: 'Learner Beta',
    role: 'learner',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
  },
  secondParent: {
    uid: 'parent-beta',
    email: 'parent.beta@scholesa.test',
    displayName: 'Parent Beta',
    role: 'parent',
    siteIds: [SITE_ALPHA],
    activeSiteId: SITE_ALPHA,
  },
};

if (!getApps().length) {
  initializeApp({ projectId: PROJECT_ID });
}

const adminDb = getFirestore();
const adminAuth = getAuth();

test.describe.configure({ mode: 'serial' });

test.beforeEach(async () => {
  await resetEmulators();
  await seedBaseData();
});

async function resetEmulators(): Promise<void> {
  const firestoreReset = await fetch(
    `http://${FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!firestoreReset.ok) {
    throw new Error(`Failed to clear Firestore emulator: ${firestoreReset.status}`);
  }

  const authReset = await fetch(
    `http://${FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: 'DELETE' },
  );
  if (!authReset.ok) {
    throw new Error(`Failed to clear Auth emulator: ${authReset.status}`);
  }
}

async function ensureAuthUser(user: SeedUser): Promise<void> {
  await adminAuth.createUser({
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
  });
}

async function seedUserProfile(user: SeedUser): Promise<void> {
  await adminDb.collection('users').doc(user.uid).set({
    email: user.email,
    displayName: user.displayName,
    role: user.role,
    siteIds: user.siteIds || [],
    activeSiteId: user.activeSiteId || null,
    learnerIds: user.learnerIds || [],
    parentIds: user.parentIds || [],
    isActive: true,
    preferences: {
      locale: 'en',
      timeZone: 'America/Vancouver',
      notificationsEnabled: true,
      emailNotifications: true,
      pushNotifications: true,
    },
    createdAt: Timestamp.fromDate(new Date('2026-03-07T17:00:00.000Z')),
    updatedAt: Timestamp.fromDate(new Date('2026-03-07T17:00:00.000Z')),
  });
}

async function seedBaseData(): Promise<void> {
  await Promise.all(Object.values(USERS).map(async (user) => {
    await ensureAuthUser(user);
    await seedUserProfile(user);
  }));

  const now = new Date('2026-03-07T18:00:00.000Z');
  const sessionStart = new Date(now.getTime() + 60 * 60 * 1000);
  const sessionEnd = new Date(now.getTime() + 2 * 60 * 60 * 1000);

  await Promise.all([
    adminDb.collection('sites').doc(SITE_ALPHA).set({
      name: 'Site Alpha Campus',
      location: 'Vancouver',
      status: 'active',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('sites').doc(SITE_BETA).set({
      name: 'Site Beta Campus',
      location: 'Burnaby',
      status: 'active',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('missions').doc(MISSION_ID).set({
      title: 'Robotics Mission',
      description: 'Build and document a robotics prototype.',
      status: 'active',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('sessions').doc(SESSION_ID).set({
      siteId: SITE_ALPHA,
      title: 'Future Skills Studio',
      description: 'Daily problem-solving block',
      educatorIds: [USERS.educator.uid],
      status: 'scheduled',
      startDate: Timestamp.fromDate(sessionStart),
      endDate: Timestamp.fromDate(sessionEnd),
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('enrollments').doc('enrollment-alpha').set({
      learnerId: USERS.learner.uid,
      userId: USERS.learner.uid,
      sessionId: SESSION_ID,
      siteId: SITE_ALPHA,
      status: 'active',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('educatorLearnerLinks').doc('educator-link-alpha').set({
      educatorId: USERS.educator.uid,
      learnerId: USERS.learner.uid,
      siteId: SITE_ALPHA,
      status: 'active',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('guardianLinks').doc('guardian-link-alpha').set({
      parentId: USERS.parent.uid,
      parentName: USERS.parent.displayName,
      learnerId: USERS.learner.uid,
      learnerName: USERS.learner.displayName,
      siteId: SITE_ALPHA,
      relationship: 'guardian',
      status: 'active',
      isPrimary: true,
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('learnerProgress').doc(USERS.learner.uid).set({
      level: 7,
      totalXp: 420,
      missionsCompleted: 5,
      currentStreak: 3,
      futureSkillsProgress: 0.72,
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('attendanceRecords').doc('attendance-parent-summary').set({
      learnerId: USERS.learner.uid,
      userId: USERS.learner.uid,
      learnerName: USERS.learner.displayName,
      siteId: SITE_ALPHA,
      sessionOccurrenceId: SESSION_ID,
      status: 'present',
      timestamp: Timestamp.fromDate(now),
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('portfolioItems').doc('portfolio-linked-alpha').set({
      learnerId: USERS.learner.uid,
      siteId: SITE_ALPHA,
      title: 'Learner Build Log',
      description: 'Documented the prototype iteration.',
      mediaType: 'document',
      status: 'published',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
    adminDb.collection('portfolioItems').doc('portfolio-unlinked-beta').set({
      learnerId: USERS.otherLearner.uid,
      siteId: SITE_ALPHA,
      title: 'Other Learner Artifact',
      description: 'Should remain hidden from unrelated parents.',
      mediaType: 'image',
      status: 'published',
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }),
  ]);
}

async function signInAs(page: Page, user: SeedUser): Promise<void> {
  const customToken = await adminAuth.createCustomToken(user.uid);
  await page.goto('/en/login');
  await page.waitForFunction(() => Boolean((window as Window & {
    __scholesaE2E?: { currentUid: () => string | null };
  }).__scholesaE2E));
  await page.evaluate(async ({ token, locale }) => {
    await (window as Window & {
      __scholesaE2E: { signInWithCustomToken: (customToken: string, locale?: string) => Promise<unknown> };
    }).__scholesaE2E.signInWithCustomToken(token, locale);
  }, { token: customToken, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: { currentUid: () => string | null };
      }).__scholesaE2E?.currentUid() === expectedUid,
    user.uid,
  );
}

async function openWorkflowCreateForm(page: Page): Promise<void> {
  await page.getByTestId('workflow-create-toggle').click();
  await expect(page.getByTestId('workflow-create-form')).toBeVisible();
}

function workflowRecord(page: Page, text: string): Locator {
  return page.getByTestId('workflow-record-list').locator('li', { hasText: text }).first();
}

test('learner workflow redirects to learner default and supports mission submit lifecycle', async ({ page }) => {
  await signInAs(page, USERS.learner);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/learner\/today$/);
  await expect(page.getByText('Future Skills Studio')).toBeVisible();

  await page.goto('/en/learner/missions');
  await expect(page).toHaveURL(/\/en\/learner\/missions$/);
  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-missionId').selectOption(MISSION_ID);
  await page.getByTestId('workflow-field-notes').fill('Prototype iteration notes');
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, 'Robotics Mission');
  await expect(record).toContainText('Status: started');
  await record.getByRole('button', { name: 'Submit attempt' }).click();
  await expect(record).toContainText('Status: submitted');
});

test('learner is denied HQ routes and returns to learner default', async ({ page }) => {
  await signInAs(page, USERS.learner);

  await page.goto('/en/hq/sites');
  await expect(page).toHaveURL(/\/en\/learner\/today$/);
  await expect(page.getByText('Future Skills Studio')).toBeVisible();
});

test('educator workflow redirects to educator default and records attendance', async ({ page }) => {
  await signInAs(page, USERS.educator);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/educator\/today$/);
  await expect(page.getByText('Future Skills Studio')).toBeVisible();

  await page.goto('/en/educator/attendance');
  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-learnerId').selectOption(USERS.learner.uid);
  await page.getByTestId('workflow-field-sessionOccurrenceId').selectOption(SESSION_ID);
  await page.getByTestId('workflow-field-status').selectOption('present');
  await page.getByTestId('workflow-field-notes').fill('Learner arrived prepared.');
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, USERS.learner.displayName);
  await expect(record).toContainText('Status: present');
});

test('educator is denied partner routes and returns to educator default', async ({ page }) => {
  await signInAs(page, USERS.educator);

  await page.goto('/en/partner/listings');
  await expect(page).toHaveURL(/\/en\/educator\/today$/);
  await expect(page.getByText('Future Skills Studio')).toBeVisible();
});

test('parent workflow redirects to parent default and only shows linked portfolio artifacts', async ({ page }) => {
  await signInAs(page, USERS.parent);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/parent\/summary$/);
  await expect(page.getByText('Learner Alpha')).toBeVisible();
  await expect(page.getByText(/Level 7/)).toBeVisible();

  await page.goto('/en/parent/portfolio');
  await expect(page.getByText('Learner Build Log')).toBeVisible();
  await expect(page.getByText('Other Learner Artifact')).toHaveCount(0);
});

test('parent is denied site routes and returns to parent default', async ({ page }) => {
  await signInAs(page, USERS.parent);

  await page.goto('/en/site/dashboard');
  await expect(page).toHaveURL(/\/en\/parent\/summary$/);
  await expect(page.getByText('Learner Alpha')).toBeVisible();
});

test('site workflow redirects to site default and provisions guardian links', async ({ page }) => {
  await signInAs(page, USERS.site);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/site\/dashboard$/);
  await expect(page.getByText('Site Alpha Campus')).toBeVisible();

  await page.goto('/en/site/provisioning');
  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-action').selectOption('guardianLink');
  await page.getByTestId('workflow-field-parentId').selectOption(USERS.secondParent.uid);
  await page.getByTestId('workflow-field-learnerId').selectOption(USERS.otherLearner.uid);
  await page.getByTestId('workflow-field-relationship').selectOption('caregiver');
  await page.getByTestId('workflow-field-isPrimary').check();
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, USERS.secondParent.uid);
  await expect.poll(async () => {
    const guardianLinks = await adminDb
      .collection('guardianLinks')
      .where('parentId', '==', USERS.secondParent.uid)
      .get();
    return guardianLinks.docs.filter((docSnap) => docSnap.data().relationship === 'caregiver').length;
  }, {
    timeout: 10_000,
  }).toBeGreaterThan(0);
  await expect(record).toContainText('Status: active');
});

test('site is denied partner routes and returns to site default', async ({ page }) => {
  await signInAs(page, USERS.site);

  await page.goto('/en/partner/listings');
  await expect(page).toHaveURL(/\/en\/site\/dashboard$/);
  await expect(page.getByText('Site Alpha Campus')).toBeVisible();
});

test('partner workflow redirects to partner default and publishes a listing', async ({ page }) => {
  await signInAs(page, USERS.partner);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/partner\/listings$/);
  await expect(page.getByTestId('workflow-route-header')).toContainText('Partner Listings');

  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-title').fill('Robotics Residency');
  await page.getByTestId('workflow-field-description').fill('Hands-on partner residency for site learners.');
  await page.getByTestId('workflow-field-category').fill('STEM');
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, 'Robotics Residency');
  await expect(record).toContainText('Status: draft');
  await record.getByRole('button', { name: 'Publish listing' }).click();
  await expect(record).toContainText('Status: published');
});

test('partner is denied site routes and returns to partner default', async ({ page }) => {
  await signInAs(page, USERS.partner);

  await page.goto('/en/site/dashboard');
  await expect(page).toHaveURL(/\/en\/partner\/listings$/);
  await expect(page.getByTestId('workflow-route-header')).toContainText('Partner Listings');
});

test('hq workflow redirects to hq default and activates a new site', async ({ page }) => {
  await signInAs(page, USERS.hq);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/hq\/sites$/);
  await expect(page.getByTestId('workflow-route-header')).toContainText('HQ Sites');

  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-name').fill('Site Gamma Campus');
  await page.getByTestId('workflow-field-location').fill('Richmond');
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, 'Site Gamma Campus');
  await expect(record).toContainText('Status: pending');
  await record.getByRole('button', { name: 'Activate site' }).click();
  await expect(record).toContainText('Status: active');
});

test('hq routes deny unauthenticated access', async ({ page }) => {
  await page.goto('/en/hq/sites');
  await expect(page).toHaveURL(/\/en\/login\?from=%2Fen%2Fhq%2Fsites$/);
});
