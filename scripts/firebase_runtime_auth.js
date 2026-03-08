'use strict';

const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');

function readJsonFileSafe(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function isServiceAccountPayload(payload) {
  return Boolean(
    payload &&
      typeof payload === 'object' &&
      payload.type === 'service_account' &&
      typeof payload.private_key === 'string' &&
      payload.private_key.trim().length > 0,
  );
}

function resolveCredentialPath(explicitPath, extraCandidates = []) {
  const candidates = [
    explicitPath,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    ...extraCandidates,
  ]
    .filter((candidate) => typeof candidate === 'string' && candidate.trim().length > 0)
    .map((candidate) => path.resolve(process.cwd(), candidate));

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

function isServiceAccountCredentialPath(candidate) {
  if (typeof candidate !== 'string' || !candidate.trim()) return false;
  const credentialPath = path.resolve(process.cwd(), candidate);
  if (!fs.existsSync(credentialPath)) return false;
  return isServiceAccountPayload(readJsonFileSafe(credentialPath));
}

function resolveProjectId(explicitProjectId, credentialPath) {
  if (typeof explicitProjectId === 'string' && explicitProjectId.trim().length > 0) {
    return explicitProjectId.trim();
  }

  const envProjectId = [
    process.env.FIREBASE_PROJECT_ID,
    process.env.GOOGLE_CLOUD_PROJECT,
    process.env.GCLOUD_PROJECT,
  ].find((value) => typeof value === 'string' && value.trim().length > 0);
  if (envProjectId) {
    return envProjectId.trim();
  }

  if (credentialPath && fs.existsSync(credentialPath)) {
    const payload = readJsonFileSafe(credentialPath);
    if (payload && typeof payload.project_id === 'string' && payload.project_id.trim().length > 0) {
      return payload.project_id.trim();
    }
    if (payload && typeof payload.client_email === 'string') {
      const match = payload.client_email.match(/@([a-z0-9-]+)\.iam\.gserviceaccount\.com$/i);
      if (match && match[1]) {
        return match[1];
      }
    }
  }

  try {
    const gcloudProject = cp.execSync('gcloud config get-value project', {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    });
    const normalized = String(gcloudProject || '').trim();
    if (normalized && normalized !== '(unset)') {
      return normalized;
    }
  } catch {
    return undefined;
  }

  return undefined;
}

function isCredentialAuthError(error) {
  const message = error instanceof Error ? error.message : String(error || '');
  return (
    /unable to impersonate/i.test(message) ||
    /Could not refresh access token/i.test(message) ||
    /invalid_grant/i.test(message) ||
    /invalid_rapt/i.test(message) ||
    /reauth related error/i.test(message) ||
    /iam\.serviceAccounts\.getAccessToken/i.test(message) ||
    /iam\.serviceAccounts\.signBlob/i.test(message) ||
    /Failed to determine service account/i.test(message) ||
    /\bUNAUTHENTICATED\b/i.test(message) ||
    /invalid authentication credentials/i.test(message)
  );
}

function resolveFirebaseApiKey(explicitApiKey) {
  const directEnv = [
    explicitApiKey,
    process.env.FIREBASE_API_KEY,
    process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    process.env.VOICE_LIVE_API_KEY,
  ].find((value) => typeof value === 'string' && value.trim().length > 0);
  if (directEnv) {
    return directEnv.trim();
  }

  const candidateFiles = [
    path.resolve(process.cwd(), 'apps/empire_flutter/app/lib/firebase_options.dart'),
    path.resolve(process.cwd(), 'src/firebase/client-init.ts'),
    path.resolve(process.cwd(), 'src/firebase/client-init-impactory.ts'),
  ];

  for (const candidate of candidateFiles) {
    if (!fs.existsSync(candidate)) continue;
    const source = fs.readFileSync(candidate, 'utf8');
    const singleQuoteMatch = source.match(/apiKey:\s*'([^']+)'/);
    if (singleQuoteMatch && singleQuoteMatch[1]) {
      return singleQuoteMatch[1].trim();
    }
    const envMatch = source.match(/NEXT_PUBLIC_FIREBASE_API_KEY.*\|\|\s*'([^']+)'/);
    if (envMatch && envMatch[1]) {
      return envMatch[1].trim();
    }
  }

  return null;
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
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      (payload && payload.error && payload.error.message) ||
      `${response.status} ${response.statusText}`;
    throw new Error(`Firebase password sign-in failed: ${message}`);
  }
  if (!payload.idToken || typeof payload.idToken !== 'string') {
    throw new Error('Firebase password sign-in returned no idToken.');
  }
  return payload.idToken;
}

function getGcloudAccessToken() {
  try {
    const token = cp.execSync('gcloud auth print-access-token', {
      stdio: ['ignore', 'pipe', 'pipe'],
      encoding: 'utf8',
    });
    const normalized = String(token || '').trim();
    if (!normalized) {
      throw new Error('gcloud auth print-access-token returned an empty token.');
    }
    return normalized;
  } catch (error) {
    const stderr =
      error && typeof error === 'object' && typeof error.stderr === 'string'
        ? error.stderr.trim()
        : '';
    throw new Error(
      stderr ||
        'Unable to obtain a gcloud access token. Run `gcloud auth login` and ensure the signed-in user can read Firestore.',
    );
  }
}

function initializeFirebaseAdmin(admin, options = {}) {
  const credentialPath = resolveCredentialPath(options.credentialPath, options.extraCredentialPaths || []);
  const projectId = resolveProjectId(options.projectId, credentialPath);
  let credentialMode = 'applicationDefault';

  if (!admin.apps.length) {
    if (credentialPath) {
      const payload = readJsonFileSafe(credentialPath);
      if (isServiceAccountPayload(payload)) {
        const serviceAccount = { ...payload };
        if (!serviceAccount.project_id && projectId) {
          serviceAccount.project_id = projectId;
        }
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: projectId || serviceAccount.project_id,
          ...(options.serviceAccountId ? { serviceAccountId: options.serviceAccountId } : {}),
        });
        credentialMode = 'serviceAccount';
      } else {
        process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
          ...(projectId ? { projectId } : {}),
          ...(options.serviceAccountId ? { serviceAccountId: options.serviceAccountId } : {}),
        });
      }
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        ...(projectId ? { projectId } : {}),
        ...(options.serviceAccountId ? { serviceAccountId: options.serviceAccountId } : {}),
      });
    }
  } else {
    const appOptions = admin.app().options || {};
    if (appOptions.credential && credentialPath) {
      const payload = readJsonFileSafe(credentialPath);
      credentialMode = isServiceAccountPayload(payload) ? 'serviceAccount' : 'applicationDefault';
    }
  }

  return {
    projectId: projectId || admin.app().options.projectId || null,
    credentialPath: credentialPath ? path.relative(process.cwd(), credentialPath) : 'applicationDefault',
    credentialMode,
  };
}

function encodeDocumentPath(...segments) {
  return segments.map((segment) => encodeURIComponent(String(segment))).join('/');
}

function encodeFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((entry) => encodeFirestoreValue(entry)),
      },
    };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (value && typeof value === 'object') {
    const fields = {};
    for (const [key, entry] of Object.entries(value)) {
      fields[key] = encodeFirestoreValue(entry);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

function decodeFirestoreValue(value) {
  if (!value || typeof value !== 'object') return undefined;
  if (Object.prototype.hasOwnProperty.call(value, 'nullValue')) return null;
  if (Object.prototype.hasOwnProperty.call(value, 'stringValue')) return value.stringValue;
  if (Object.prototype.hasOwnProperty.call(value, 'booleanValue')) return value.booleanValue;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return value.doubleValue;
  if (Object.prototype.hasOwnProperty.call(value, 'timestampValue')) return new Date(value.timestampValue);
  if (Object.prototype.hasOwnProperty.call(value, 'referenceValue')) return value.referenceValue;
  if (Object.prototype.hasOwnProperty.call(value, 'bytesValue')) return value.bytesValue;
  if (Object.prototype.hasOwnProperty.call(value, 'geoPointValue')) {
    return {
      latitude: value.geoPointValue.latitude,
      longitude: value.geoPointValue.longitude,
    };
  }
  if (Object.prototype.hasOwnProperty.call(value, 'arrayValue')) {
    const entries = Array.isArray(value.arrayValue && value.arrayValue.values)
      ? value.arrayValue.values
      : [];
    return entries.map((entry) => decodeFirestoreValue(entry));
  }
  if (Object.prototype.hasOwnProperty.call(value, 'mapValue')) {
    const fields = (value.mapValue && value.mapValue.fields) || {};
    const record = {};
    for (const [key, entry] of Object.entries(fields)) {
      record[key] = decodeFirestoreValue(entry);
    }
    return record;
  }
  return undefined;
}

function decodeFirestoreDocument(document) {
  const fields = (document && document.fields) || {};
  const data = {};
  for (const [key, value] of Object.entries(fields)) {
    data[key] = decodeFirestoreValue(value);
  }
  return data;
}

function createDocSnapshot(id, exists, data) {
  return {
    id,
    exists,
    data() {
      return exists ? data : undefined;
    },
  };
}

function createQuerySnapshot(docs) {
  return {
    docs,
    size: docs.length,
  };
}

function normalizeRestOperator(operator) {
  if (operator === '==') return 'EQUAL';
  if (operator === 'array-contains') return 'ARRAY_CONTAINS';
  if (operator === '>=') return 'GREATER_THAN_OR_EQUAL';
  throw new Error(`Unsupported Firestore REST operator: ${operator}`);
}

function buildStructuredWhere(filters) {
  if (!Array.isArray(filters) || filters.length === 0) return undefined;

  const mapped = filters.map(({ field, operator, value }) => ({
    fieldFilter: {
      field: { fieldPath: field },
      op: normalizeRestOperator(operator),
      value: encodeFirestoreValue(value),
    },
  }));

  if (mapped.length === 1) {
    return mapped[0];
  }

  return {
    compositeFilter: {
      op: 'AND',
      filters: mapped,
    },
  };
}

function normalizeRestDirection(direction) {
  if (typeof direction !== 'string' || !direction.trim()) return 'ASCENDING';
  return direction.trim().toLowerCase() === 'desc' ? 'DESCENDING' : 'ASCENDING';
}

function buildFirestoreRestClient(projectId, accessToken) {
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

  async function requestJson(url, options = {}) {
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        ...(options.body ? { 'Content-Type': 'application/json' } : {}),
        ...(options.headers || {}),
      },
    });

    const text = await response.text();
    const payload = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const errorMessage =
        (payload && payload.error && payload.error.message) ||
        `${response.status} ${response.statusText}`;
      const error = new Error(`${response.status} ${errorMessage}`);
      error.status = response.status;
      error.payload = payload;
      throw error;
    }
    return payload;
  }

  function createQuery(collectionName, filters = [], limitCount = null, orderings = []) {
    return {
      where(field, operator, value) {
        return createQuery(collectionName, [...filters, { field, operator, value }], limitCount, orderings);
      },
      limit(value) {
        return createQuery(collectionName, filters, value, orderings);
      },
      orderBy(field, direction = 'asc') {
        return createQuery(collectionName, filters, limitCount, [
          ...orderings,
          { field, direction },
        ]);
      },
      async get() {
        const structuredQuery = {
          from: [{ collectionId: collectionName }],
        };
        const where = buildStructuredWhere(filters);
        if (where) structuredQuery.where = where;
        if (orderings.length > 0) {
          structuredQuery.orderBy = orderings.map(({ field, direction }) => ({
            field: { fieldPath: field },
            direction: normalizeRestDirection(direction),
          }));
        }
        if (typeof limitCount === 'number' && Number.isFinite(limitCount)) {
          structuredQuery.limit = Math.max(0, Math.trunc(limitCount));
        }

        const responses = await requestJson(`${baseUrl}:runQuery`, {
          method: 'POST',
          body: JSON.stringify({ structuredQuery }),
        });

        const docs = Array.isArray(responses)
          ? responses
              .filter((entry) => entry && entry.document)
              .map((entry) => {
                const name = String(entry.document.name || '');
                const id = name.split('/').pop() || '';
                return createDocSnapshot(id, true, decodeFirestoreDocument(entry.document));
              })
          : [];

        return createQuerySnapshot(docs);
      },
    };
  }

  return {
    collection(collectionName) {
      return {
        doc(documentId) {
          return {
            async get() {
              const documentPath = `${baseUrl}/${encodeDocumentPath(collectionName, documentId)}`;
              try {
                const document = await requestJson(documentPath);
                return createDocSnapshot(documentId, true, decodeFirestoreDocument(document));
              } catch (error) {
                if (
                  error &&
                  typeof error === 'object' &&
                  (error.status === 404 ||
                    (error.payload &&
                      error.payload.error &&
                      String(error.payload.error.status || '').toUpperCase() === 'NOT_FOUND'))
                ) {
                  return createDocSnapshot(documentId, false, undefined);
                }
                throw error;
              }
            },
          };
        },
        where(field, operator, value) {
          return createQuery(collectionName).where(field, operator, value);
        },
        limit(value) {
          return createQuery(collectionName).limit(value);
        },
        orderBy(field, direction) {
          return createQuery(collectionName).orderBy(field, direction);
        },
        async get() {
          return createQuery(collectionName).get();
        },
      };
    },
  };
}

function initializeFirestoreRestFallback(projectId) {
  if (!projectId) {
    throw new Error('Unable to initialize gcloud Firestore fallback without a resolved project ID.');
  }

  const accessToken = getGcloudAccessToken();
  return {
    db: buildFirestoreRestClient(projectId, accessToken),
    projectId,
    credentialPath: 'gcloud-auth-user',
    transport: 'firestoreRestOAuth',
  };
}

async function initializeFirestoreUserRestFallback(projectId, options = {}) {
  if (!projectId) {
    throw new Error('Unable to initialize Firebase user Firestore fallback without a resolved project ID.');
  }

  const apiKey = resolveFirebaseApiKey(options.apiKey);
  const email =
    (typeof options.email === 'string' && options.email.trim()) ||
    process.env.FIREBASE_REST_FALLBACK_EMAIL ||
    process.env.CROSS_LINK_FALLBACK_EMAIL ||
    'hq@scholesa.test';
  const password =
    (typeof options.password === 'string' && options.password.trim()) ||
    process.env.FIREBASE_REST_FALLBACK_PASSWORD ||
    process.env.TEST_USER_PASSWORD ||
    'Test123!';

  if (!apiKey) {
    throw new Error('Unable to resolve a Firebase Web API key for Firestore REST user fallback.');
  }

  const accessToken = await signInWithPassword(apiKey, email, password);
  return {
    db: buildFirestoreRestClient(projectId, accessToken),
    projectId,
    credentialPath: 'firebase-user-auth',
    transport: 'firestoreRestUserAuth',
    email,
  };
}

module.exports = {
  buildFirestoreRestClient,
  getGcloudAccessToken,
  initializeFirebaseAdmin,
  initializeFirestoreRestFallback,
  initializeFirestoreUserRestFallback,
  isCredentialAuthError,
  isServiceAccountCredentialPath,
  isServiceAccountPayload,
  readJsonFileSafe,
  resolveFirebaseApiKey,
  resolveCredentialPath,
  resolveProjectId,
  signInWithPassword,
};
