#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, applicationDefault, cert, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const ROOT = path.resolve(__dirname, '..');
const { enqueueLearnerGoalReminders } = require(path.join(ROOT, 'functions/lib/notificationPipeline.js'));

const TELEMETRY_COLLECTION = 'telemetryEvents';
const PREFS_COLLECTION = 'learnerReminderPreferences';
const REQUESTS_COLLECTION = 'notificationRequests';
const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(ROOT, 'firebase-service-account.json'),
  path.resolve(ROOT, 'studio-service-account.json'),
].filter(Boolean);

function isServiceAccountCredentialPath(candidate) {
  if (typeof candidate !== 'string' || !candidate.trim()) return false;
  const credentialPath = path.isAbsolute(candidate)
    ? candidate
    : path.resolve(ROOT, candidate);
  if (!fs.existsSync(credentialPath)) return false;
  try {
    const payload = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
    return payload &&
      typeof payload === 'object' &&
      payload.type === 'service_account' &&
      typeof payload.private_key === 'string' &&
      typeof payload.project_id === 'string';
  } catch {
    return false;
  }
}

function resolveCredentialPath(explicitPath) {
  if (isServiceAccountCredentialPath(explicitPath)) {
    return path.isAbsolute(explicitPath)
      ? explicitPath
      : path.resolve(ROOT, explicitPath);
  }
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (isServiceAccountCredentialPath(candidate)) {
      return path.isAbsolute(candidate)
        ? candidate
        : path.resolve(ROOT, candidate);
    }
  }
  return undefined;
}

function parseArgs(argv) {
  const args = {
    project: process.env.FIREBASE_PROJECT_ID,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS,
    site: undefined,
    learner: `canary-learner-reminder-${Date.now()}`,
    strict: false,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) {
      continue;
    }
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (!rawValue) {
      continue;
    }
    if (rawKey === 'project') args.project = rawValue.trim();
    if (rawKey === 'credentials') args.credentials = rawValue.trim();
    if (rawKey === 'site') args.site = rawValue.trim();
    if (rawKey === 'learner') args.learner = rawValue.trim();
  }

  return args;
}

function initializeAdmin(args) {
  const appOptions = {};
  if (args.project) {
    appOptions.projectId = args.project;
  }
  const credentialPath = resolveCredentialPath(args.credentials);
  if (credentialPath) {
    appOptions.credential = cert(require(credentialPath));
  } else {
    appOptions.credential = applicationDefault();
  }

  if (!getApps().length) {
    initializeApp(appOptions);
  }
  return getFirestore();
}

async function pickSiteId(db, explicitSite) {
  if (explicitSite) {
    return explicitSite;
  }

  const learnerProfileSnap = await db.collection('learnerProfiles').limit(1).get();
  if (!learnerProfileSnap.empty) {
    const siteId = learnerProfileSnap.docs[0].data().siteId;
    if (typeof siteId === 'string' && siteId) {
      return siteId;
    }
  }

  const telemetrySnap = await db.collection(TELEMETRY_COLLECTION).limit(20).get();
  for (const doc of telemetrySnap.docs) {
    const siteId = doc.data().siteId;
    if (typeof siteId === 'string' && siteId) {
      return siteId;
    }
  }

  return 'seed-site';
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const db = initializeAdmin(args);
  const siteId = await pickSiteId(db, args.site);
  const learnerId = args.learner;
  const preferenceId = `${siteId}_${learnerId}`;
  const now = new Date();

  await db.collection(PREFS_COLLECTION).doc(preferenceId).set({
    learnerId,
    siteId,
    schedule: 'daily',
    weeklyTargetMinutes: 90,
    localeCode: 'en',
    timeZone: 'UTC',
    valuePrompt: 'canary reminder path',
    enabled: true,
    updatedAt: Timestamp.now(),
    createdAt: Timestamp.now(),
  }, { merge: true });

  const result = await enqueueLearnerGoalReminders({
    db,
    reminderPreferencesCollection: PREFS_COLLECTION,
    notificationRequestsCollection: REQUESTS_COLLECTION,
    now,
    persistTelemetryEvent: async (payload) => {
      await db.collection(TELEMETRY_COLLECTION).add({
        ...payload,
        createdAt: Timestamp.now(),
        metadata: {
          ...(payload.metadata || {}),
          syntheticCoverageSeed: true,
          canary: 'learner_reminder_live_canary',
        },
      });
    },
  });

  const dayKey = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);

  const requestSnap = await db.collection(REQUESTS_COLLECTION)
    .where('userId', '==', learnerId)
    .where('type', '==', 'learner_goal_reminder')
    .limit(10)
    .get();
  const matchingRequest = requestSnap.docs.find((doc) => {
    const data = doc.data();
    return data.data && data.data.localDayKey === dayKey;
  });

  const telemetrySnap = await db.collection(TELEMETRY_COLLECTION)
    .where('event', '==', 'notification.requested')
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();
  const matchingTelemetry = telemetrySnap.docs.find((doc) => {
    const data = doc.data();
    return data.userId === learnerId &&
      data.metadata &&
      data.metadata.type === 'learner_goal_reminder';
  });

  console.log('Learner Reminder Live Canary');
  console.log(`siteId=${siteId}`);
  console.log(`learnerId=${learnerId}`);
  console.log(`queued=${result.queued}`);
  console.log(`requestFound=${Boolean(matchingRequest)}`);
  console.log(`telemetryFound=${Boolean(matchingTelemetry)}`);

  if ((!matchingRequest || !matchingTelemetry) && args.strict) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});