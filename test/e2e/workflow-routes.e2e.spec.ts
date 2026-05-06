import { test, expect, type Locator, type Page } from '@playwright/test';

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

type CollectionRecord = Record<string, unknown>;

type E2EWindowApi = {
  signInAs: (uid: string, locale?: string) => Promise<{ uid: string | null }>;
  reset: (locale?: string) => Promise<void>;
  signOut: (locale?: string) => Promise<void>;
  currentUid: () => string | null;
  getCollection: (collectionName: string) => CollectionRecord[];
};

test.describe.configure({ mode: 'serial' });

async function signInAs(page: Page, user: SeedUser): Promise<void> {
  await page.goto('/en/login');
  await page.waitForFunction(() => Boolean((window as Window & {
    __scholesaE2E?: E2EWindowApi;
  }).__scholesaE2E));
  await page.evaluate(async ({ uid, locale }) => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.signInAs(uid, locale);
  }, { uid: user.uid, locale: 'en' });
  await page.waitForFunction(
    (expectedUid) =>
      (window as Window & {
        __scholesaE2E?: E2EWindowApi;
      }).__scholesaE2E?.currentUid() === expectedUid,
    user.uid,
  );
}

test.beforeEach(async ({ page }) => {
  await page.goto('/en/login');
  await page.waitForFunction(() => Boolean((window as Window & {
    __scholesaE2E?: E2EWindowApi;
  }).__scholesaE2E));
  await page.evaluate(async () => {
    await (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.reset('en');
  });
});

async function openWorkflowCreateForm(page: Page): Promise<void> {
  await page.getByTestId('workflow-create-toggle').click();
  await expect(page.getByTestId('workflow-create-form')).toBeVisible();
}

function workflowRecord(page: Page, text: string): Locator {
  return page.getByTestId('workflow-record-list').locator('li', { hasText: text }).first();
}

async function getCollection(page: Page, collectionName: string): Promise<CollectionRecord[]> {
  return page.evaluate((name) => {
    return (window as Window & {
      __scholesaE2E: E2EWindowApi;
    }).__scholesaE2E.getCollection(name);
  }, collectionName);
}

test('learner workflow redirects to learner default and supports mission submit lifecycle', async ({ page }) => {
  await signInAs(page, USERS.learner);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/learner\/today$/);
  // /learner/today uses LearnerProgressReportRenderer (custom renderer, not generic card list)
  await expect(page.getByText('My Progress')).toBeVisible();

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
  await expect.poll(async () => {
    const attempts = await getCollection(page, 'missionAttempts');
    return attempts.some((entry) => (
      entry.learnerId === USERS.learner.uid &&
      entry.missionId === MISSION_ID &&
      entry.status === 'submitted'
    ));
  }, {
    timeout: 10_000,
  }).toBe(true);
});

test('learner is denied HQ routes and returns to learner default', async ({ page }) => {
  await signInAs(page, USERS.learner);

  await page.goto('/en/hq/sites');
  await expect(page).toHaveURL(/\/en\/learner\/today$/);
  await expect(page.getByText('My Progress')).toBeVisible();
});

test('educator workflow redirects to educator default and records attendance', async ({ page }) => {
  await signInAs(page, USERS.educator);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/educator\/today$/);
  await expect(page.getByText('Educator Dashboard')).toBeVisible();

  await page.goto('/en/educator/attendance');
  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-learnerId').selectOption(USERS.learner.uid);
  await page.getByTestId('workflow-field-sessionOccurrenceId').selectOption(SESSION_ID);
  await page.getByTestId('workflow-field-status').selectOption('present');
  await page.getByTestId('workflow-field-notes').fill('Learner arrived prepared.');
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, USERS.learner.displayName);
  await expect(record).toContainText('Status: present');
  await expect.poll(async () => {
    const attendance = await getCollection(page, 'attendanceRecords');
    return attendance.some((entry) => (
      entry.learnerId === USERS.learner.uid &&
      entry.sessionOccurrenceId === SESSION_ID &&
      entry.status === 'present' &&
      entry.recordedBy === USERS.educator.uid &&
      entry.notes === 'Learner arrived prepared.'
    ));
  }, {
    timeout: 10_000,
  }).toBe(true);
});

test('educator is denied partner routes and returns to educator default', async ({ page }) => {
  await signInAs(page, USERS.educator);

  await page.goto('/en/partner/listings');
  await expect(page).toHaveURL(/\/en\/educator\/today$/);
  await expect(page.getByText('Educator Dashboard')).toBeVisible();
});

test('parent workflow redirects to parent default and only shows linked portfolio artifacts', async ({ page }) => {
  await signInAs(page, USERS.parent);

  await page.goto('/en/dashboard');
  await expect(page).toHaveURL(/\/en\/parent\/summary$/);
  await expect(page.getByText('Learner Alpha')).toBeVisible();
  // Custom renderer shows band label (Developing/Strong/Emerging), not raw numeric level
  await expect(page.getByText(/Developing|Strong|Emerging/)).toBeVisible();

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
    const guardianLinks = await getCollection(page, 'guardianLinks');
    return guardianLinks.filter((entry) => entry.parentId === USERS.secondParent.uid && entry.relationship === 'caregiver').length;
  }, {
    timeout: 10_000,
  }).toBeGreaterThan(0);
  await expect(record).toContainText('Status: active');
});

test('site ops workflow logs and resolves operator events with audit proof', async ({ page }) => {
  await signInAs(page, USERS.site);

  await page.goto('/en/site/ops');
  await expect(page.getByTestId('workflow-route-header')).toContainText('Site Operations');
  await openWorkflowCreateForm(page);
  await page.getByTestId('workflow-field-eventType').fill('release-cutover-drill');
  await page.getByTestId('workflow-field-details').fill('Operator verified site ops event lifecycle during route smoke.');
  await page.getByTestId('workflow-create-submit').click();

  const record = workflowRecord(page, 'release-cutover-drill');
  await expect(record).toContainText('Status: open');
  await expect(record).toContainText('Operator Proof');
  await expect.poll(async () => {
    const events = await getCollection(page, 'siteOpsEvents');
    return events.some((entry) => (
      entry.siteId === SITE_ALPHA &&
      entry.eventType === 'release-cutover-drill' &&
      entry.status === 'open' &&
      entry.createdBy === USERS.site.uid
    ));
  }, {
    timeout: 10_000,
  }).toBe(true);

  await record.getByRole('button', { name: 'Resolve event' }).click();
  await expect(record).toContainText('Status: resolved');
  await page.reload();
  await expect(workflowRecord(page, 'release-cutover-drill')).toContainText('Status: resolved');

  await expect.poll(async () => {
    const [events, auditLogs] = await Promise.all([
      getCollection(page, 'siteOpsEvents'),
      getCollection(page, 'auditLogs'),
    ]);
    const resolvedEvent = events.find((entry) => (
      entry.siteId === SITE_ALPHA &&
      entry.eventType === 'release-cutover-drill' &&
      entry.status === 'resolved' &&
      entry.resolvedBy === USERS.site.uid
    ));
    return Boolean(resolvedEvent) && auditLogs.some((entry) => (
      entry.action === 'site_ops.event_resolved' &&
      entry.documentId === resolvedEvent?.id &&
      entry.siteId === SITE_ALPHA
    ));
  }, {
    timeout: 10_000,
  }).toBe(true);
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
  await expect.poll(async () => {
    const listings = await getCollection(page, 'marketplaceListings');
    return listings.some((entry) => (
      entry.partnerId === USERS.partner.uid &&
      entry.title === 'Robotics Residency' &&
      entry.status === 'published' &&
      entry.category === 'STEM'
    ));
  }, {
    timeout: 10_000,
  }).toBe(true);
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
  await expect.poll(async () => {
    const sites = await getCollection(page, 'sites');
    return sites.some((entry) => (
      entry.name === 'Site Gamma Campus' &&
      entry.status === 'active' &&
      entry.location === 'Richmond'
    ));
  }, {
    timeout: 10_000,
  }).toBe(true);
});

test('hq routes deny unauthenticated access', async ({ page }) => {
  await page.goto('/en/hq/sites');
  await expect(page).toHaveURL(/\/en\/login\?from=%2Fen%2Fhq%2Fsites$/);
});

test('zh-CN landing and login render localized copy', async ({ page }) => {
  await page.goto('/zh-CN');
  await expect(page.getByText('Scholesa – 未来技能学院')).toBeVisible();
  await expect(page.getByRole('link', { name: '登录' })).toBeVisible();
  await expect(page.getByRole('link', { name: '注册 →' })).toBeVisible();

  await page.goto('/zh-CN/login');
  await expect(page.getByRole('heading', { name: '欢迎回来' })).toBeVisible();
  await expect(page.getByRole('button', { name: '登录' })).toBeVisible();
});

test('zh-TW protected routes keep locale on unauthenticated redirect', async ({ page }) => {
  await page.goto('/zh-TW/hq/sites');
  await expect(page).toHaveURL(/\/zh-TW\/login\?from=%2Fzh-TW%2Fhq%2Fsites$/);
  await expect(page.getByRole('heading', { name: '歡迎回來' })).toBeVisible();
  await expect(page.getByRole('button', { name: '登入' })).toBeVisible();
});
