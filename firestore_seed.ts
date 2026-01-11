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

const site: Site = {
  id: 'site-1',
  name: 'Downtown Lab',
  location: 'City Center',
  siteLeadIds: ['u-sitelead'],
  createdAt: Date.now(),
};

const users: User[] = [
  { uid: 'u-learner', email: 'learner@example.com', role: 'learner', siteIds: [site.id], createdAt: Date.now(), updatedAt: Date.now() },
  { uid: 'u-educator', email: 'educator@example.com', role: 'educator', siteIds: [site.id], createdAt: Date.now(), updatedAt: Date.now() },
  { uid: 'u-parent', email: 'parent@example.com', role: 'parent', siteIds: [site.id], parentIds: ['u-learner'], createdAt: Date.now(), updatedAt: Date.now() },
  { uid: 'u-sitelead', email: 'sitelead@example.com', role: 'site', siteIds: [site.id], createdAt: Date.now(), updatedAt: Date.now() },
  { uid: 'u-hq', email: 'hq@example.com', role: 'hq', siteIds: [site.id], createdAt: Date.now(), updatedAt: Date.now() },
  {
    uid: 'u-master-admin',
    email: 'simon.luke@impactoryinstitute.com',
    role: 'hq',
    siteIds: [site.id],
    createdAt: Date.now(),
    updatedAt: Date.now(),
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
    createdAt: Date.now(),
  },
];

async function ensureAuthUser(opts: { uid: string; email: string; displayName: string; passwordEnv: string }): Promise<void> {
  const { uid, email, displayName, passwordEnv } = opts;
  const password = process.env[passwordEnv];
  try {
    await auth.getUser(uid);
    return;
  } catch (error) {
    // falls through to creation
  }

  if (!password) {
    console.warn(`Skipping auth user ${email}; set ${passwordEnv} to seed password.`);
    return;
  }

  await auth.createUser({ uid, email, displayName, password, emailVerified: true, disabled: false });
  await auth.setCustomUserClaims(uid, { role: 'hq', masterAdmin: true, superuser: true, roles: ['hq', 'superuser'] });
  console.log(`Created auth user ${email} with uid ${uid} (claims role=hq, masterAdmin=true, superuser=true)`);
}

async function main() {
  await ensureAuthUser({
    uid: 'u-master-admin',
    email: 'simon.luke@impactoryinstitute.com',
    displayName: 'Simon Luke (Master Admin)',
    passwordEnv: 'ADMIN_SEED_PASSWORD',
  });
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
  console.log('Seed complete');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});