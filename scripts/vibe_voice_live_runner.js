#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const admin = require('firebase-admin');
const {
  getGcloudAccessToken,
  initializeFirestoreRestFallback,
  initializeFirebaseAdmin,
  isCredentialAuthError,
  resolveCloudRunServiceUrl,
  resolveProjectId,
  resolveCredentialPath,
} = require('./firebase_runtime_auth');

function parseArgs(argv = process.argv.slice(2)) {
  const initialProjectId = resolveProjectId(process.env.VOICE_LIVE_PROJECT || process.env.FIREBASE_PROJECT_ID);
  const options = {
    projectId: initialProjectId || '',
    serviceAccountPath: process.env.VOICE_LIVE_SERVICE_ACCOUNT || process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
    baseUrl: resolveCloudRunServiceUrl({
      explicitUrl: process.env.VOICE_API_BASE_URL,
      serviceName: process.env.VOICE_API_SERVICE || 'voiceapi',
      region: process.env.VOICE_API_REGION || 'us-central1',
      projectId: initialProjectId,
    }) || '',
    apiKey: process.env.VOICE_LIVE_API_KEY || '',
    strict: false,
    autoServiceAccount: false,
    seedConsent: false,
    signingServiceAccount:
      process.env.VOICE_LIVE_SIGNING_SERVICE_ACCOUNT ||
      process.env.FIREBASE_CUSTOM_TOKEN_SERVICE_ACCOUNT ||
      '',
    testPassword:
      process.env.VOICE_LIVE_TEST_PASSWORD ||
      process.env.SEED_TEST_PASSWORD ||
      process.env.TEST_USER_PASSWORD ||
      'Test123!',
  };
  for (const arg of argv) {
    if (arg === '--strict') options.strict = true;
    if (arg === '--auto-service-account') options.autoServiceAccount = true;
    if (arg === '--seed-consent') options.seedConsent = true;
    if (arg.startsWith('--project=')) options.projectId = arg.slice('--project='.length);
    if (arg.startsWith('--service-account=')) options.serviceAccountPath = arg.slice('--service-account='.length);
    if (arg.startsWith('--base-url=')) options.baseUrl = arg.slice('--base-url='.length);
    if (arg.startsWith('--api-key=')) options.apiKey = arg.slice('--api-key='.length);
    if (arg.startsWith('--signing-service-account=')) {
      options.signingServiceAccount = arg.slice('--signing-service-account='.length);
    }
    if (arg.startsWith('--test-password=')) {
      options.testPassword = arg.slice('--test-password='.length);
    }
  }
  options.projectId = resolveProjectId(options.projectId) || '';
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

async function signInWithPassword(apiKey, email, password) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(json.error?.message || json.error || `IdentityToolkit HTTP ${response.status}`);
  }
  if (!json.idToken) {
    throw new Error('IdentityToolkit password sign-in returned no idToken.');
  }
  return json.idToken;
}

function decodeJwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) {
    throw new Error('Invalid JWT token format.');
  }
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

async function mintRoleToken({ role, claims, apiKey }) {
  const uid = `voice-live-${role}-${Date.now()}`;
  const customToken = await admin.auth().createCustomToken(uid, claims);
  return signInWithCustomToken(apiKey, customToken);
}

function loginCandidatesForRole(role) {
  if (role === 'student') {
    return [
      process.env.VOICE_LIVE_STUDENT_EMAIL,
      'learner@scholesa.test',
      'learner@scholesa.dev',
      'student001.demo@scholesa.org',
    ].filter(Boolean);
  }
  if (role === 'teacher') {
    return [
      process.env.VOICE_LIVE_TEACHER_EMAIL,
      'educator@scholesa.test',
      'educator@scholesa.dev',
      'site@scholesa.test',
      'site@scholesa.dev',
    ].filter(Boolean);
  }
  return [
    process.env.VOICE_LIVE_ADMIN_EMAIL,
    'hq@scholesa.test',
    'hq@scholesa.dev',
    'site@scholesa.test',
    'site@scholesa.dev',
  ].filter(Boolean);
}

async function signInWithSeededRole(role, options) {
  const candidates = loginCandidatesForRole(role);
  let lastError = null;
  for (const email of candidates) {
    try {
      return await signInWithPassword(options.apiKey, email, options.testPassword);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError || new Error(`No sign-in candidates configured for role ${role}.`);
}

async function upsertConsentViaRest(projectId, siteId) {
  const accessToken = getGcloudAccessToken();
  const nowIso = new Date().toISOString();
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/coppaSchoolConsents/${encodeURIComponent(siteId)}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        siteId: { stringValue: siteId },
        active: { booleanValue: true },
        agreementSigned: { booleanValue: true },
        educationalUseOnly: { booleanValue: true },
        parentNoticeProvided: { booleanValue: true },
        noStudentMarketing: { booleanValue: true },
        signedBy: { stringValue: 'voice-live-runner' },
        signedAt: { timestampValue: nowIso },
        updatedAt: { timestampValue: nowIso },
      },
    }),
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(body || `Consent upsert failed with HTTP ${response.status}`);
  }
}

async function ensureConsentForSeededTokens(tokens, projectId) {
  const rest = initializeFirestoreRestFallback(projectId);
  const siteIds = new Set();

  for (const token of Object.values(tokens)) {
    const payload = decodeJwtPayload(token);
    const uid = payload.user_id || payload.sub;
    if (!uid) continue;
    const userSnap = await rest.db.collection('users').doc(uid).get();
    if (!userSnap.exists) continue;
    const userData = userSnap.data() || {};
    const activeSiteId = typeof userData.activeSiteId === 'string' ? userData.activeSiteId.trim() : '';
    if (activeSiteId) {
      siteIds.add(activeSiteId);
    }
    const userSiteIds = Array.isArray(userData.siteIds) ? userData.siteIds : [];
    for (const siteId of userSiteIds) {
      if (typeof siteId === 'string' && siteId.trim()) {
        siteIds.add(siteId.trim());
      }
    }
  }

  for (const siteId of siteIds) {
    await upsertConsentViaRest(projectId, siteId);
  }
}

async function resolveLiveTokens(options) {
  const envTokens = {
    student: process.env.VOICE_API_TOKEN_STUDENT || '',
    teacher: process.env.VOICE_API_TOKEN_TEACHER || '',
    admin: process.env.VOICE_API_TOKEN_ADMIN || '',
  };
  if (envTokens.student && envTokens.teacher && envTokens.admin) {
    return envTokens;
  }

  const siteId = 'voice-vibe-site-live';
  const resolvedCredentialPath = resolveCredentialPath(options.serviceAccountPath, [
    path.resolve('firebase-service-account.json'),
    path.resolve('studio-service-account.json'),
  ]);
  const signingServiceAccount =
    options.signingServiceAccount || `${options.projectId}@appspot.gserviceaccount.com`;

  try {
    if (!admin.apps.length) {
      initializeFirebaseAdmin(admin, {
        credentialPath: resolvedCredentialPath || undefined,
        projectId: options.projectId,
        serviceAccountId: signingServiceAccount,
        extraCredentialPaths: [
          path.resolve('firebase-service-account.json'),
          path.resolve('studio-service-account.json'),
        ],
      });
    }

    if (options.seedConsent) {
      await ensureLiveSiteConsent(siteId);
    }
    return {
      student: await mintRoleToken({
        role: 'student',
        apiKey: options.apiKey,
        claims: {
          role: 'learner',
          siteId,
          siteIds: [siteId],
          gradeBand: 'K-5',
          grade: 4,
        },
      }),
      teacher: await mintRoleToken({
        role: 'teacher',
        apiKey: options.apiKey,
        claims: {
          role: 'educator',
          siteId,
          siteIds: [siteId],
          gradeBand: '6-8',
          grade: 7,
        },
      }),
      admin: await mintRoleToken({
        role: 'admin',
        apiKey: options.apiKey,
        claims: {
          role: 'hq',
          siteId,
          siteIds: [siteId],
          gradeBand: '9-12',
          grade: 10,
        },
      }),
    };
  } catch (error) {
    if (!isCredentialAuthError(error)) {
      throw error;
    }
    const tokens = {
      student: envTokens.student || await signInWithSeededRole('student', options),
      teacher: envTokens.teacher || await signInWithSeededRole('teacher', options),
      admin: envTokens.admin || await signInWithSeededRole('admin', options),
    };
    await ensureConsentForSeededTokens(tokens, options.projectId);
    return tokens;
  }
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

  const tokens = await resolveLiveTokens(options);

  const childArgs = ['scripts/vibe_voice_all.js', '--live', `--base-url=${options.baseUrl}`];
  if (options.strict) childArgs.push('--strict');

  const child = cp.spawnSync('node', childArgs, {
    stdio: 'inherit',
    env: {
      ...process.env,
      VOICE_API_BASE_URL: options.baseUrl,
      VOICE_API_TOKEN_STUDENT: tokens.student,
      VOICE_API_TOKEN_TEACHER: tokens.teacher,
      VOICE_API_TOKEN_ADMIN: tokens.admin,
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
