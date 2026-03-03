#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const admin = require('firebase-admin');

function parseArgs(argv = process.argv.slice(2)) {
  const options = {
    projectId: process.env.VOICE_LIVE_PROJECT || 'studio-3328096157-e3f79',
    serviceAccountPath: process.env.VOICE_LIVE_SERVICE_ACCOUNT || 'firebase-service-account.json',
    baseUrl: process.env.VOICE_API_BASE_URL || '',
    apiKey: process.env.VOICE_LIVE_API_KEY || '',
    strict: false,
    autoServiceAccount: false,
    seedConsent: false,
  };
  for (const arg of argv) {
    if (arg === '--strict') options.strict = true;
    if (arg === '--auto-service-account') options.autoServiceAccount = true;
    if (arg === '--seed-consent') options.seedConsent = true;
    if (arg.startsWith('--project=')) options.projectId = arg.slice('--project='.length);
    if (arg.startsWith('--service-account=')) options.serviceAccountPath = arg.slice('--service-account='.length);
    if (arg.startsWith('--base-url=')) options.baseUrl = arg.slice('--base-url='.length);
    if (arg.startsWith('--api-key=')) options.apiKey = arg.slice('--api-key='.length);
  }
  options.baseUrl = options.baseUrl.replace(/\/+$/g, '');
  return options;
}

function extractApiKeyFromFlutterOptions() {
  const optionsPath = path.resolve('apps/empire_flutter/app/lib/firebase_options.dart');
  if (!fs.existsSync(optionsPath)) return '';
  const source = fs.readFileSync(optionsPath, 'utf8');
  const match = source.match(/apiKey:\s*'([^']+)'/);
  return match ? match[1] : '';
}

function discoverServiceAccountPath(projectId) {
  const byProject = path.resolve(`.idx/${projectId}-firebase-adminsdk-fbsvc-9d9be1eb80.json`);
  const fallbackCandidates = [
    byProject,
    path.resolve(`.idx/${projectId}-firebase-adminsdk-fbsvc.json`),
    path.resolve(`${projectId}.json`),
    path.resolve('scholesa-10cfaceb0561.json'),
    path.resolve('firebase-service-account.json'),
  ];

  for (const candidate of fallbackCandidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  const idxDir = path.resolve('.idx');
  if (fs.existsSync(idxDir)) {
    const idxMatch = fs.readdirSync(idxDir)
      .find((entry) => entry.startsWith(`${projectId}-`) && entry.endsWith('.json'));
    if (idxMatch) {
      return path.join(idxDir, idxMatch);
    }
  }

  return null;
}

async function ensureLiveSiteConsent(siteId) {
  await admin.firestore().collection('coppaSchoolConsents').doc(siteId).set({
    siteId,
    active: true,
    agreementSigned: true,
    educationalUseOnly: true,
    parentNoticeProvided: true,
    noStudentMarketing: true,
    signedBy: 'voice-live-runner',
    signedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function signInWithCustomToken(apiKey, customToken) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      token: customToken,
      returnSecureToken: true,
    }),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(json.error?.message || json.error || `IdentityToolkit HTTP ${response.status}`);
  }
  if (!json.idToken) {
    throw new Error('IdentityToolkit returned no idToken.');
  }
  return json.idToken;
}

async function mintRoleToken({ role, claims, apiKey }) {
  const uid = `voice-live-${role}-${Date.now()}`;
  const customToken = await admin.auth().createCustomToken(uid, claims);
  return signInWithCustomToken(apiKey, customToken);
}

async function main() {
  const options = parseArgs();
  if (!options.baseUrl) {
    options.baseUrl = `https://us-central1-${options.projectId}.cloudfunctions.net/voiceApi`;
  }
  if (!options.apiKey) {
    options.apiKey = extractApiKeyFromFlutterOptions();
  }
  if (!options.apiKey) {
    throw new Error('Missing API key. Set --api-key or VOICE_LIVE_API_KEY.');
  }

  if (options.autoServiceAccount) {
    const discovered = discoverServiceAccountPath(options.projectId);
    if (discovered) {
      options.serviceAccountPath = discovered;
    }
  }

  const serviceAccountPath = path.resolve(options.serviceAccountPath);
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(`Service account file not found: ${serviceAccountPath}`);
  }
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: options.projectId,
    });
  }

  const siteId = 'voice-vibe-site-live';
  if (options.seedConsent) {
    await ensureLiveSiteConsent(siteId);
  }
  const studentToken = await mintRoleToken({
    role: 'student',
    apiKey: options.apiKey,
    claims: {
      role: 'learner',
      siteId,
      siteIds: [siteId],
      gradeBand: 'K-5',
      grade: 4,
    },
  });
  const teacherToken = await mintRoleToken({
    role: 'teacher',
    apiKey: options.apiKey,
    claims: {
      role: 'educator',
      siteId,
      siteIds: [siteId],
      gradeBand: '6-8',
      grade: 7,
    },
  });
  const adminToken = await mintRoleToken({
    role: 'admin',
    apiKey: options.apiKey,
    claims: {
      role: 'hq',
      siteId,
      siteIds: [siteId],
      gradeBand: '9-12',
      grade: 10,
    },
  });

  const childArgs = ['scripts/vibe_voice_all.js', '--live', `--base-url=${options.baseUrl}`];
  if (options.strict) childArgs.push('--strict');

  const child = cp.spawnSync('node', childArgs, {
    stdio: 'inherit',
    env: {
      ...process.env,
      VOICE_API_BASE_URL: options.baseUrl,
      VOICE_API_TOKEN_STUDENT: studentToken,
      VOICE_API_TOKEN_TEACHER: teacherToken,
      VOICE_API_TOKEN_ADMIN: adminToken,
    },
  });

  if (child.status !== 0) {
    process.exit(child.status || 1);
  }
}

main().catch((error) => {
  console.error('Voice live runner failed:', error.message || error);
  process.exit(1);
});

