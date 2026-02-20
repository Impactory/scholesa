import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import type { ServiceAccount } from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import type {
  Site,
  User,
  Session,
  SessionOccurrence,
  Enrollment,
  Pillar,
  Mission,
  PortfolioItem,
} from './schema.ts';

async function loadServiceAccount(): Promise<ServiceAccount> {
  const secretName = process.env.GOOGLE_SECRET_NAME;
  if (secretName) {
    const client = new SecretManagerServiceClient();
    const name = secretName.includes('/versions/') ? secretName : `${secretName}/versions/latest`;
    const [version] = await client.accessSecretVersion({ name });
    const payload = version.payload?.data?.toString();
    if (!payload) {
      throw new Error(`Secret ${name} has no payload`);
    }
    return JSON.parse(payload) as ServiceAccount;
  }

  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialsPath) {
    throw new Error('Set GOOGLE_SECRET_NAME or GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path');
  }

  return JSON.parse(readFileSync(credentialsPath, 'utf8')) as ServiceAccount;
}

const serviceAccount = await loadServiceAccount();
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
const auth = getAuth();
const now = Date.now();

const site: Site = {
  id: 'site-1',
  name: 'Downtown Lab',
  location: 'City Center',
  siteLeadIds: ['u-sitelead'],
  createdAt: now,
};

const baseUsers: User[] = [
  { uid: 'u-learner', email: 'learner@scholesa.dev', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-educator', email: 'educator@scholesa.dev', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-parent', email: 'parent@scholesa.dev', role: 'parent', siteIds: [site.id], parentIds: ['u-learner'], createdAt: now, updatedAt: now },
  { uid: 'u-sitelead', email: 'site@scholesa.dev', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-hq', email: 'hq@scholesa.dev', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-partner', email: 'partner@scholesa.dev', role: 'partner', siteIds: [site.id], createdAt: now, updatedAt: now },
];

const aliasUsers: User[] = [
  { uid: 'u-learner-test', email: 'learner@scholesa.test', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-educator-test', email: 'educator@scholesa.test', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-parent-test', email: 'parent@scholesa.test', role: 'parent', siteIds: [site.id], parentIds: ['u-learner-test'], createdAt: now, updatedAt: now },
  { uid: 'u-sitelead-test', email: 'site@scholesa.test', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-hq-test', email: 'hq@scholesa.test', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-partner-test', email: 'partner@scholesa.test', role: 'partner', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-learner-example', email: 'learner@example.com', role: 'learner', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-educator-example', email: 'educator@example.com', role: 'educator', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-parent-example', email: 'parent@example.com', role: 'parent', siteIds: [site.id], parentIds: ['u-learner-example'], createdAt: now, updatedAt: now },
  { uid: 'u-sitelead-example', email: 'sitelead@example.com', role: 'site', siteIds: [site.id], createdAt: now, updatedAt: now },
  { uid: 'u-hq-example', email: 'hq@example.com', role: 'hq', siteIds: [site.id], createdAt: now, updatedAt: now },
];

const users: User[] = [
  ...baseUsers,
  ...aliasUsers,
  {
    uid: 'u-master-admin',
    email: 'simon.luke@impactoryinstitute.com',
    role: 'hq',
    siteIds: [site.id],
    createdAt: now,
    updatedAt: now,
    // Marks the platform master account for downstream role checks.
    masterAdmin: true,
  },
];

const pillars: Pillar[] = [
  { code: 'tech', name: 'Future Skills', color: '#2563eb' },
  { code: 'lead', name: 'Leadership & Agency', color: '#16a34a' },
  { code: 'impact', name: 'Impact & Innovation', color: '#eab308' },
];

const mission: Mission = {
  id: 'mission-1',
  title: 'Intro to Coding',
  description: 'Build a simple app',
  pillarCodes: ['tech'],
  difficulty: 'beginner',
  estimatedDurationMinutes: 60,
};

const mission2: Mission = {
  id: 'mission-2',
  title: 'Community Impact Pitch',
  description: 'Design a pitch to solve a local problem',
  pillarCodes: ['impact', 'lead'],
  difficulty: 'intermediate',
  estimatedDurationMinutes: 90,
};

const session: Session = {
  id: 'session-1',
  title: 'Weekly Coding',
  siteId: site.id,
  educatorIds: ['u-educator'],
  pillarCodes: ['tech'],
  startDate: Date.now(),
  endDate: Date.now() + 14 * 24 * 3600 * 1000,
};

const session2: Session = {
  id: 'session-2',
  title: 'Leadership Circle',
  siteId: site.id,
  educatorIds: ['u-educator'],
  pillarCodes: ['lead'],
  startDate: Date.now(),
  endDate: Date.now() + 7 * 24 * 3600 * 1000,
};

const occurrence: SessionOccurrence = {
  id: 'occ-1',
  sessionId: session.id,
  siteId: site.id,
  startTime: Date.now() + 24 * 3600 * 1000,
  endTime: Date.now() + 25 * 3600 * 1000,
  status: 'scheduled',
};

const enrollment: Enrollment = {
  id: 'enr-1',
  sessionId: session.id,
  learnerId: 'u-learner',
  siteId: site.id,
  enrolledAt: Date.now(),
  status: 'active',
};

const portfolioItems: PortfolioItem[] = [
  {
    id: 'pitem-1',
    portfolioId: 'portfolio-learner',
    title: 'Robot build',
    description: 'Arduino line follower robot',
    mediaUrl: 'https://example.com/robot.jpg',
    mediaType: 'image',
    relatedSkillIds: [],
    createdAt: Date.now(),
  },
  {
    id: 'pitem-2',
    portfolioId: 'portfolio-learner',
    title: 'Impact pitch deck',
    description: 'Slides for community problem pitch',
    mediaUrl: 'https://example.com/pitch.pdf',
    mediaType: 'document',
    relatedSkillIds: [],
    createdAt: Date.now(),
  },
];

const contracts = [
  {
    id: 'contract-1',
    title: 'After-school partnership',
    siteId: site.id,
    status: 'active',
    createdAt: now,
  },
];

const standardTestPassword = process.env.SEED_TEST_PASSWORD ?? process.env.TEST_LOGIN_PASSWORD ?? 'Test123!';
const adminSeedPassword = process.env.ADMIN_SEED_PASSWORD ?? standardTestPassword;

  if (!process.env.SEED_TEST_PASSWORD && !process.env.TEST_LOGIN_PASSWORD) {
    console.warn('Using default test password for seeded accounts. Set SEED_TEST_PASSWORD to override.');
  }

  type SeedAuthUser = {
    uid: string;
    email: string;
    displayName: string;
    password: string;
    role: User['role'];
    masterAdmin?: boolean;
  };

  function authClaimsForUser(user: SeedAuthUser): Record<string, unknown> {
    if (user.masterAdmin) {
      return { role: 'hq', masterAdmin: true, superuser: true, roles: ['hq', 'superuser'] };
    }

    return { role: user.role, roles: [user.role] };
  }

  async function upsertAuthUser(user: SeedAuthUser): Promise<void> {
    const { uid, email, displayName, password } = user;

  try {
      await auth.getUser(uid);
      await auth.updateUser(uid, { email, displayName, password, emailVerified: true, disabled: false });
      await auth.setCustomUserClaims(uid, authClaimsForUser(user));
      console.log(`Updated auth user ${email} with uid ${uid}`);
      return;
    } catch {
      // falls through to create
  }

  await auth.createUser({ uid, email, displayName, password, emailVerified: true, disabled: false });
    await auth.setCustomUserClaims(uid, authClaimsForUser(user));
    console.log(`Created auth user ${email} with uid ${uid}`);
}

async function main() {
  const seededAuthUsers: SeedAuthUser[] = [
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

  await Promise.all(seededAuthUsers.map((seededUser) => upsertAuthUser(seededUser)));
  await db.collection('sites').doc(site.id).set(site);
  await Promise.all(users.map((u) => db.collection('users').doc(u.uid).set(u)));
  await Promise.all(pillars.map((p) => db.collection('pillars').doc(p.code).set(p)));
  await db.collection('missions').doc(mission.id).set(mission);
  await db.collection('missions').doc(mission2.id).set(mission2);
  await db.collection('sessions').doc(session.id).set(session);
  await db.collection('sessions').doc(session2.id).set(session2);
  await db.collection('sessionOccurrences').doc(occurrence.id).set(occurrence);
  await db.collection('enrollments').doc(enrollment.id).set(enrollment);
  await Promise.all(portfolioItems.map((item) => db.collection('portfolioItems').doc(item.id).set(item)));
  await Promise.all(contracts.map((c) => db.collection('contracts').doc(c.id).set(c)));
  console.log('Test login password:', standardTestPassword);
  console.log('Primary testing accounts: learner@scholesa.dev, educator@scholesa.dev, parent@scholesa.dev, site@scholesa.dev, hq@scholesa.dev, partner@scholesa.dev');
  console.log('Seed complete');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});