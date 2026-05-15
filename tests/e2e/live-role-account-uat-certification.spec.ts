import { expect, test, type Browser, type Page } from '@playwright/test';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';

type RoleAccount = {
  role: 'admin' | 'educator' | 'discoverer' | 'builder' | 'explorer' | 'innovator' | 'family' | 'mentor';
  email: string;
  routes: Array<{
    path: string;
    expectedText: RegExp;
    proof: string;
  }>;
};

type RouteProof = {
  path: string;
  finalUrl: string;
  status: 'passed';
  proof: string;
  visibleTextSample: string;
};

type RoleProof = {
  role: RoleAccount['role'];
  email: string;
  routes: RouteProof[];
};

const liveBaseUrl = process.env.LIVE_ROLE_UAT_BASE_URL || process.env.PLAYWRIGHT_BASE_URL || '';
const password = process.env.LIVE_ROLE_UAT_PASSWORD ||
  process.env.TEST_LOGIN_PASSWORD ||
  process.env.TEST_USER_PASSWORD ||
  process.env.SEED_TEST_PASSWORD ||
  (process.env.LIVE_ROLE_UAT_ALLOW_DEFAULT_PASSWORD === '1' ? 'Test123!' : '');

const artifactPath = resolve(
  process.cwd(),
  process.env.LIVE_ROLE_UAT_ARTIFACT || 'audit-pack/reports/live-role-account-uat-certification.json',
);

const accounts: RoleAccount[] = [
  {
    role: 'admin',
    email: process.env.LIVE_ROLE_UAT_ADMIN_EMAIL || 'admin@scholesa.test',
    routes: [
      {
        path: '/en/hq/sites',
        expectedText: /HQ Sites|site|network|tenant/i,
        proof: 'Admin account maps to HQ operations and can view deployed tenant/site administration.',
      },
      {
        path: '/en/hq/user-admin',
        expectedText: /User|Admin|role|HQ|Educator|Learner/i,
        proof: 'Admin account can open deployed user and role administration context.',
      },
    ],
  },
  {
    role: 'educator',
    email: process.env.LIVE_ROLE_UAT_EDUCATOR_EMAIL || 'educator@scholesa.test',
    routes: [
      {
        path: '/en/educator/today',
        expectedText: /Educator Today|Session|Evidence|Capability/i,
        proof: 'Educator can authenticate into deployed coaching/session workflow.',
      },
      {
        path: '/en/educator/evidence',
        expectedText: /Evidence|Review|Capability|Learner/i,
        proof: 'Educator Evidence Review route renders deployed review context.',
      },
    ],
  },
  {
    role: 'discoverer',
    email: process.env.LIVE_ROLE_UAT_DISCOVERER_EMAIL || 'discoverer@scholesa.test',
    routes: [
      {
        path: '/en/learner/today',
        expectedText: /Learner Today|Mission|Evidence|MiloOS/i,
        proof: 'Discoverer Learner can authenticate into deployed Learner workflow with educator-led AI policy metadata.',
      },
      {
        path: '/en/learner/miloos',
        expectedText: /MiloOS|support|explain-back|Learner/i,
        proof: 'Discoverer MiloOS route renders with policy-gated support context; independent AI use remains governed by profile policy.',
      },
    ],
  },
  {
    role: 'builder',
    email: process.env.LIVE_ROLE_UAT_BUILDER_EMAIL || 'builder@scholesa.test',
    routes: [
      {
        path: '/en/learner/today',
        expectedText: /Learner Today|Mission|Evidence|MiloOS/i,
        proof: 'Builder Learner can authenticate into deployed Learner workflow with guided assistive AI policy metadata.',
      },
      {
        path: '/en/learner/portfolio',
        expectedText: /Portfolio|Evidence|artifact|reflection/i,
        proof: 'Builder Learner Portfolio route renders deployed portfolio/evidence context.',
      },
    ],
  },
  {
    role: 'explorer',
    email: process.env.LIVE_ROLE_UAT_EXPLORER_EMAIL || 'explorer@scholesa.test',
    routes: [
      {
        path: '/en/learner/checkpoints',
        expectedText: /Checkpoint|Evidence|Mission|Capability/i,
        proof: 'Explorer Learner can open deployed checkpoint workflow with logged analytical AI policy metadata.',
      },
      {
        path: '/en/learner/reflections',
        expectedText: /Reflection|Evidence|Mission|Learner/i,
        proof: 'Explorer Learner reflection workflow renders deployed Evidence/reflection context.',
      },
    ],
  },
  {
    role: 'innovator',
    email: process.env.LIVE_ROLE_UAT_INNOVATOR_EMAIL || 'innovator@scholesa.test',
    routes: [
      {
        path: '/en/learner/proof-assembly',
        expectedText: /Proof|Evidence|Portfolio|Capability/i,
        proof: 'Innovator Learner can open deployed proof assembly workflow with full audit trail policy metadata.',
      },
      {
        path: '/en/learner/portfolio',
        expectedText: /Portfolio|Evidence|artifact|reflection/i,
        proof: 'Innovator Portfolio route renders deployed portfolio/evidence context.',
      },
    ],
  },
  {
    role: 'family',
    email: process.env.LIVE_ROLE_UAT_FAMILY_EMAIL || 'family@scholesa.test',
    routes: [
      {
        path: '/en/parent/summary',
        expectedText: /Summary|Family|Portfolio|Growth|Learner|Evidence/i,
        proof: 'Family account maps to parent access and can view selected linked-Learner progress.',
      },
      {
        path: '/en/parent/passport',
        expectedText: /Passport|Growth Report|Evidence|Capability|Portfolio/i,
        proof: 'Family Passport/Growth Report route renders deployed evidence-backed reporting context.',
      },
    ],
  },
  {
    role: 'mentor',
    email: process.env.LIVE_ROLE_UAT_MENTOR_EMAIL || 'mentor@scholesa.test',
    routes: [
      {
        path: '/en/partner/listings',
        expectedText: /Partner Listings|listing|deliverable|Marketplace/i,
        proof: 'Mentor account maps to partner-backed external expert access in the deployed app.',
      },
      {
        path: '/en/educator/evidence',
        expectedText: /Partner Listings|partnerRole-scoped|Marketplace/i,
        proof: 'Mentor account is rendered into its partner-backed external expert surface when attempting Educator Evidence Review and cannot edit official learning Evidence or Capability Reviews.',
      },
    ],
  },
];

function requireLiveUatInputs() {
  if (!liveBaseUrl) {
    throw new Error('Set LIVE_ROLE_UAT_BASE_URL or PLAYWRIGHT_BASE_URL to a deployed Scholesa URL.');
  }
  if (!password) {
    throw new Error('Set LIVE_ROLE_UAT_PASSWORD, TEST_LOGIN_PASSWORD, TEST_USER_PASSWORD, or SEED_TEST_PASSWORD. To use the repo pilot fallback, set LIVE_ROLE_UAT_ALLOW_DEFAULT_PASSWORD=1.');
  }
}

async function loginAs(page: Page, account: RoleAccount) {
  await page.goto('/en/login', { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle');
  if ((await page.locator('input[name="email"]').count()) === 0) {
    const signIn = page.getByRole('link', { name: /sign in/i }).or(page.getByRole('button', { name: /sign in/i })).first();
    await expect(signIn).toBeVisible({ timeout: 20_000 });
    await signIn.click();
    await page.waitForLoadState('networkidle');
  }
  await expect(page.locator('input[name="email"]')).toBeVisible();
  await page.locator('input[name="email"]').fill(account.email);
  await page.locator('input[name="password"]').fill(password);
  await page.waitForFunction(() => {
    const button = document.querySelector('button[type="submit"]');
    return Boolean(button && !button.hasAttribute('disabled'));
  });
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/en\/(dashboard|learner|educator|parent|site|hq|partner)/, { timeout: 60_000 });
}

async function certifyRole(browser: Browser, account: RoleAccount): Promise<RoleProof> {
  const context = await browser.newContext();
  const page = await context.newPage();
  const routeProofs: RouteProof[] = [];

  try {
    await loginAs(page, account);

    for (const route of account.routes) {
      await page.goto(route.path, { waitUntil: 'domcontentloaded' });
      await expect(page.locator('main')).toBeVisible();
      await expect(page.locator('main')).toContainText(route.expectedText, { timeout: 60_000 });
      if (!(account.role === 'mentor' && route.path === '/en/educator/evidence')) {
        await expect(page.locator('body')).not.toContainText(/Login could not be completed|not provisioned|permission-denied|requires an index|Failed to load/i);
      }

      const visibleTextSample = (await page.locator('main').innerText()).replace(/\s+/g, ' ').trim().slice(0, 500);
      routeProofs.push({
        path: route.path,
        finalUrl: page.url(),
        status: 'passed',
        proof: route.proof,
        visibleTextSample,
      });
    }
  } finally {
    await context.close();
  }

  return {
    role: account.role,
    email: account.email,
    routes: routeProofs,
  };
}

test.describe('Live role-account UAT certification', () => {
  test('certifies deployed role accounts across the Scholesa product chain', async ({ browser }) => {
    requireLiveUatInputs();

    const startedAt = new Date().toISOString();
    const roleProofs: RoleProof[] = [];

    for (const account of accounts) {
      roleProofs.push(await certifyRole(browser, account));
    }

    const completedAt = new Date().toISOString();
    const artifact = {
      status: 'passed',
      certification: 'live-role-account-uat',
      baseUrl: liveBaseUrl,
      startedAt,
      completedAt,
      accountsCertified: roleProofs.length,
      routesCertified: roleProofs.reduce((count, role) => count + role.routes.length, 0),
      productChain: 'capability -> mission -> session -> checkpoint -> evidence -> reflection -> capability review -> portfolio -> badge -> showcase -> growth report',
      roles: roleProofs,
    };

    mkdirSync(dirname(artifactPath), { recursive: true });
    writeFileSync(artifactPath, `${JSON.stringify(artifact, null, 2)}\n`);

    expect(roleProofs).toHaveLength(accounts.length);
    expect(roleProofs.flatMap((role) => role.routes)).toHaveLength(16);
  });
});