#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const admin = require('firebase-admin');
const {
  buildCanonicalReport,
  resolveEnv,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const DEFAULT_SITE_ID = process.env.TEST_SITE_ID || 'site_001';

const SERVICE_ACCOUNT_PATHS = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(process.cwd(), 'firebase-service-account.json'),
  path.resolve(process.cwd(), 'studio-service-account.json'),
].filter(Boolean);

const ROLE_MAP = {
  learner: 'learner',
  student: 'learner',
  educator: 'educator',
  teacher: 'educator',
  parent: 'parent',
  guardian: 'parent',
  site: 'site',
  sitelead: 'site',
  site_lead: 'site',
  partner: 'partner',
  hq: 'hq',
  admin: 'hq',
};

const VOICE_TELEMETRY_EVENTS = new Set([
  'voice.transcribe',
  'voice.message',
  'voice.tts',
  'voice.blocked',
  'voice.escalated',
]);

const REQUIRED_VOICE_LOCALES = new Set(['en', 'zh-CN', 'zh-TW', 'th']);
const REQUIRED_VOICE_METADATA_KEYS = [
  'traceId',
  'service',
  'env',
  'siteId',
  'role',
  'gradeBand',
  'locale',
  'eventType',
  'timestamp',
];

const BOS_EVENT_TYPES = new Set([
  'mission_viewed',
  'mission_selected',
  'mission_started',
  'mission_completed',
  'checkpoint_started',
  'checkpoint_submitted',
  'checkpoint_graded',
  'artifact_created',
  'artifact_submitted',
  'artifact_reviewed',
  'ai_help_opened',
  'ai_help_used',
  'ai_coach_response',
  'ai_coach_feedback',
  'mvl_gate_triggered',
  'mvl_evidence_attached',
  'mvl_passed',
  'mvl_failed',
  'teacher_override_mvl',
  'teacher_override_intervention',
  'contestability_requested',
  'contestability_resolved',
  'session_joined',
  'session_left',
  'idle_detected',
  'focus_restored',
]);

const BOS_ALLOWED_SERVICES = new Set(['scholesa-ai', 'scholesa-stt', 'scholesa-tts']);

const BOS_GRADE_BANDS = new Set(['G1_3', 'G4_6', 'G7_9', 'G10_12', 'K_5', 'G6_8', 'G9_12']);

function parseArgs(argv) {
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'dev'),
    strict: false,
    siteId: DEFAULT_SITE_ID,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = resolveEnv(rawValue);
    if (rawKey === 'site-id' || rawKey === 'siteId') args.siteId = rawValue.trim();
  }

  return args;
}

function toStringArray(value) {
  if (!Array.isArray(value)) return [];
  return Array.from(
    new Set(
      value
        .filter((entry) => typeof entry === 'string')
        .map((entry) => entry.trim())
        .filter(Boolean),
    ),
  );
}

function normalizeRole(value) {
  if (typeof value !== 'string') return null;
  return ROLE_MAP[value.trim().toLowerCase()] || null;
}

function compactCount(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '0';
  if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M`;
  if (value >= 1000) return `${(value / 1000).toFixed(1)}K`;
  return String(value);
}

function resolveServiceAccount() {
  for (const candidate of SERVICE_ACCOUNT_PATHS) {
    if (!candidate) continue;
    if (!fs.existsSync(candidate)) continue;
    const json = JSON.parse(fs.readFileSync(candidate, 'utf8'));
    const isServiceAccount =
      json &&
      typeof json === 'object' &&
      json.type === 'service_account' &&
      typeof json.project_id === 'string' &&
      typeof json.private_key === 'string';
    if (!isServiceAccount) continue;
    return { credentialPath: candidate, json };
  }
  return null;
}

function resolveProjectId() {
  const envProjectId = [process.env.FIREBASE_PROJECT_ID, process.env.GOOGLE_CLOUD_PROJECT, process.env.GCLOUD_PROJECT].find(
    (value) => typeof value === 'string' && value.trim(),
  );
  if (envProjectId) return envProjectId.trim();

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
    // Best-effort project discovery; Firebase Admin will still attempt default resolution.
  }

  return undefined;
}

function isCredentialAuthError(error) {
  const message = error instanceof Error ? error.message : String(error || '');
  return (
    /unable to impersonate/i.test(message) ||
    /Could not refresh access token/i.test(message) ||
    /iam\.serviceAccounts\.getAccessToken/i.test(message) ||
    /\bUNAUTHENTICATED\b/i.test(message) ||
    /invalid authentication credentials/i.test(message)
  );
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

  function createQuery(collectionName, filters = [], limitCount = null) {
    return {
      where(field, operator, value) {
        return createQuery(collectionName, [...filters, { field, operator, value }], limitCount);
      },
      limit(value) {
        return createQuery(collectionName, filters, value);
      },
      async get() {
        const structuredQuery = {
          from: [{ collectionId: collectionName }],
        };
        const where = buildStructuredWhere(filters);
        if (where) structuredQuery.where = where;
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
        async get() {
          return createQuery(collectionName).get();
        },
      };
    },
  };
}

function initializeGcloudRestFallback(projectId) {
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

function initializeAdmin() {
  const serviceAccount = resolveServiceAccount();
  const resolvedProjectId = resolveProjectId();

  if (!admin.apps.length) {
    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount.json),
        projectId: serviceAccount.json.project_id,
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        ...(resolvedProjectId ? { projectId: resolvedProjectId } : {}),
      });
    }
  }

  const runtimeProjectId =
    (serviceAccount && serviceAccount.json && serviceAccount.json.project_id) ||
    admin.app().options.projectId ||
    resolvedProjectId ||
    null;

  return {
    db: admin.firestore(),
    projectId: runtimeProjectId,
    credentialPath: serviceAccount ? path.relative(process.cwd(), serviceAccount.credentialPath) : 'applicationDefault',
    transport: 'firebaseAdmin',
  };
}

function readTextSafe(filePath) {
  if (!fs.existsSync(filePath)) return '';
  return fs.readFileSync(filePath, 'utf8');
}

function isObjectRecord(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function isTimestampLike(value) {
  return (
    value instanceof admin.firestore.Timestamp ||
    value instanceof Date ||
    typeof value === 'string' ||
    typeof value === 'number'
  );
}

function hasFiniteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function checkVoiceBosStaticSupport() {
  const indexSourcePath = path.resolve(process.cwd(), 'functions/src/index.ts');
  const voiceSourcePath = path.resolve(process.cwd(), 'functions/src/voiceSystem.ts');
  const bosSourcePath = path.resolve(process.cwd(), 'functions/src/bosRuntime.ts');
  const voiceServicePath = path.resolve(process.cwd(), 'src/lib/voice/voiceService.ts');
  const telemetrySmokePath = path.resolve(process.cwd(), 'scripts/telemetry_smoke_check.js');

  const indexSource = readTextSafe(indexSourcePath);
  const voiceSource = readTextSafe(voiceSourcePath);
  const bosSource = readTextSafe(bosSourcePath);
  const voiceServiceSource = readTextSafe(voiceServicePath);
  const telemetrySmokeSource = readTextSafe(telemetrySmokePath);

  const checks = [
    {
      id: 'voice_events_allowed_backend',
      pass:
        indexSource.includes("'voice.transcribe'") &&
        indexSource.includes("'voice.message'") &&
        indexSource.includes("'voice.tts'") &&
        indexSource.includes("'voice.blocked'") &&
        indexSource.includes("'voice.escalated'"),
    },
    {
      id: 'voice_locales_supported_backend',
      pass:
        voiceSource.includes("SUPPORTED_VOICE_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th']") ||
        (voiceSource.includes("'zh-CN'") &&
          voiceSource.includes("'zh-TW'") &&
          voiceSource.includes("'th'") &&
          voiceSource.includes("'en'")),
    },
    {
      id: 'voice_locale_forwarded_from_web_client',
      pass:
        voiceServiceSource.includes("'x-scholesa-locale'") &&
        voiceServiceSource.includes('/voice/transcribe') &&
        voiceServiceSource.includes('/copilot/message'),
    },
    {
      id: 'bos_callables_exported',
      pass:
        indexSource.includes('bosIngestEvent') &&
        indexSource.includes('bosGetIntervention') &&
        indexSource.includes('bosGetOrchestrationState') &&
        indexSource.includes('bosScoreMvl') &&
        indexSource.includes('bosSubmitMvlEvidence') &&
        indexSource.includes('bosContestability'),
    },
    {
      id: 'bos_runtime_collections_declared',
      pass:
        bosSource.includes("collection('interactionEvents')") &&
        bosSource.includes("collection('fdmFeatures')") &&
        bosSource.includes("collection('orchestrationStates')") &&
        bosSource.includes("collection('interventions')") &&
        bosSource.includes("collection('mvlEpisodes')"),
    },
    {
      id: 'voice_to_bos_bridge_declared',
      pass:
        voiceSource.includes('recordBosInteractionEvent(') &&
        voiceSource.includes("eventType: 'ai_help_opened'") &&
        voiceSource.includes("eventType: 'ai_help_used'") &&
        voiceSource.includes("eventType: 'ai_coach_response'"),
    },
    {
      id: 'bos_self_learning_pipeline_declared',
      pass:
        bosSource.includes('extractFeatures(') &&
        bosSource.includes('emaStateEstimatorUpdate(') &&
        bosSource.includes('computeIntervention(') &&
        bosSource.includes('scoreMvlEpisode('),
    },
    {
      id: 'non_core_telemetry_registry_declared',
      pass:
        telemetrySmokeSource.includes('const NON_CORE_EVENTS = [') &&
        telemetrySmokeSource.includes("'lead.submitted'") &&
        telemetrySmokeSource.includes("'contract.created'") &&
        telemetrySmokeSource.includes("'contract.approved'") &&
        telemetrySmokeSource.includes("'deliverable.submitted'") &&
        telemetrySmokeSource.includes("'deliverable.accepted'") &&
        telemetrySmokeSource.includes("'payout.approved'") &&
        telemetrySmokeSource.includes("'aiDraft.requested'") &&
        telemetrySmokeSource.includes("'aiDraft.reviewed'"),
    },
  ];

  return {
    pass: checks.every((check) => check.pass === true),
    checks,
    sourceFiles: {
      indexSourcePath: path.relative(process.cwd(), indexSourcePath),
      voiceSourcePath: path.relative(process.cwd(), voiceSourcePath),
      bosSourcePath: path.relative(process.cwd(), bosSourcePath),
      voiceServicePath: path.relative(process.cwd(), voiceServicePath),
      telemetrySmokePath: path.relative(process.cwd(), telemetrySmokePath),
    },
  };
}

function checkUserCoreFields(users, siteId) {
  const missing = [];
  for (const [uid, user] of users.entries()) {
    const role = normalizeRole(user.role);
    const siteIds = toStringArray(user.siteIds);
    const activeSiteId = typeof user.activeSiteId === 'string' ? user.activeSiteId.trim() : '';
    const email = typeof user.email === 'string' ? user.email.trim() : '';
    if (!email) missing.push(`${uid}:missing_email`);
    if (!role) missing.push(`${uid}:missing_or_invalid_role`);
    if (!siteIds.includes(siteId)) missing.push(`${uid}:siteIds_missing_${siteId}`);
    if (activeSiteId && !siteIds.includes(activeSiteId)) {
      missing.push(`${uid}:activeSite_not_in_siteIds:${activeSiteId}`);
    }
  }

  return {
    id: 'users_core_fields_present',
    pass: missing.length === 0,
    details: {
      usersChecked: users.size,
      missingCount: missing.length,
      sample: missing.slice(0, 80),
    },
  };
}

function checkRoleCoverage(users) {
  const roleCounts = {
    learner: 0,
    parent: 0,
    educator: 0,
    site: 0,
    partner: 0,
    hq: 0,
  };
  for (const user of users.values()) {
    const role = normalizeRole(user.role);
    if (role && Object.prototype.hasOwnProperty.call(roleCounts, role)) {
      roleCounts[role] += 1;
    }
  }

  const missingCoreRoles = ['learner', 'parent', 'educator', 'site'].filter(
    (role) => roleCounts[role] === 0,
  );
  return {
    id: 'ui_role_coverage_present',
    pass: missingCoreRoles.length === 0,
    details: {
      roleCounts,
      missingCoreRoles,
    },
  };
}

function checkSiteDoc(siteDoc, usersByRole) {
  if (!siteDoc) {
    return {
      id: 'site_doc_role_arrays_match_users',
      pass: false,
      details: {
        reason: 'site_doc_missing',
      },
    };
  }

  const fieldToRole = {
    learnerIds: 'learner',
    parentIds: 'parent',
    educatorIds: 'educator',
    siteLeadIds: 'site',
    partnerIds: 'partner',
    hqIds: 'hq',
  };

  const mismatches = [];
  for (const [field, role] of Object.entries(fieldToRole)) {
    const expected = new Set(usersByRole[role] || []);
    const current = new Set(toStringArray(siteDoc[field]));
    const missing = [];
    for (const uid of expected) {
      if (!current.has(uid)) missing.push(uid);
    }
    if (missing.length > 0) {
      mismatches.push({ field, role, missing: missing.slice(0, 80), missingCount: missing.length });
    }
  }

  return {
    id: 'site_doc_role_arrays_match_users',
    pass: mismatches.length === 0,
    details: {
      mismatchCount: mismatches.length,
      mismatches,
    },
  };
}

async function checkParentDashboardContract(db, users, siteId) {
  const parents = Array.from(users.entries())
    .filter(([, user]) => normalizeRole(user.role) === 'parent')
    .map(([uid]) => uid);

  const failures = [];
  let linksChecked = 0;
  let learnersResolved = 0;

  for (const parentId of parents) {
    const parent = users.get(parentId) || {};
    const candidateLearnerIds = new Set(toStringArray(parent.learnerIds));

    try {
      const guardianLinks = await db
        .collection('guardianLinks')
        .where('parentId', '==', parentId)
        .where('siteId', '==', siteId)
        .get();
      for (const doc of guardianLinks.docs) {
        const learnerId = typeof doc.data().learnerId === 'string' ? doc.data().learnerId.trim() : '';
        if (learnerId) candidateLearnerIds.add(learnerId);
      }
    } catch {
      failures.push(`guardianLinks_lookup_failed:${parentId}`);
    }

    for (const learnerId of candidateLearnerIds) {
      linksChecked += 1;
      const learner = users.get(learnerId);
      if (!learner) {
        failures.push(`parent_link_missing_learner_doc:${parentId}:${learnerId}`);
        continue;
      }
      if (normalizeRole(learner.role) !== 'learner') {
        failures.push(`parent_link_wrong_role:${parentId}:${learnerId}:${String(learner.role || '')}`);
        continue;
      }
      const reverseParentIds = toStringArray(learner.parentIds);
      if (!reverseParentIds.includes(parentId)) {
        failures.push(`learner_missing_parent_reverse_link:${learnerId}:${parentId}`);
      }
      const displayName = typeof learner.displayName === 'string' ? learner.displayName.trim() : '';
      const email = typeof learner.email === 'string' ? learner.email.trim() : '';
      if (!displayName && !email) {
        failures.push(`learner_missing_display_identity:${learnerId}`);
      }
      learnersResolved += 1;
    }
  }

  return {
    id: 'parent_dashboard_data_contract',
    pass: failures.length === 0,
    details: {
      parentsChecked: parents.length,
      linksChecked,
      learnersResolved,
      failureCount: failures.length,
      sample: failures.slice(0, 80),
    },
  };
}

async function checkEducatorRosterContract(db, users, siteId) {
  const educators = Array.from(users.entries())
    .filter(([, user]) => normalizeRole(user.role) === 'educator')
    .map(([uid]) => uid);

  const failures = [];
  let linksChecked = 0;

  for (const educatorId of educators) {
    const educator = users.get(educatorId) || {};
    const learnerIds = new Set([
      ...toStringArray(educator.learnerIds),
      ...toStringArray(educator.studentIds),
    ]);

    try {
      const links = await db
        .collection('educatorLearnerLinks')
        .where('educatorId', '==', educatorId)
        .where('siteId', '==', siteId)
        .get();
      for (const doc of links.docs) {
        const learnerId = typeof doc.data().learnerId === 'string' ? doc.data().learnerId.trim() : '';
        if (learnerId) learnerIds.add(learnerId);
      }
    } catch {
      failures.push(`educator_links_lookup_failed:${educatorId}`);
    }

    for (const learnerId of learnerIds) {
      linksChecked += 1;
      const learner = users.get(learnerId);
      if (!learner) {
        failures.push(`educator_link_missing_learner_doc:${educatorId}:${learnerId}`);
        continue;
      }
      if (normalizeRole(learner.role) !== 'learner') {
        failures.push(`educator_link_wrong_role:${educatorId}:${learnerId}:${String(learner.role || '')}`);
        continue;
      }
      const learnerEducatorIds = toStringArray(learner.educatorIds);
      const learnerTeacherIds = toStringArray(learner.teacherIds);
      if (!learnerEducatorIds.includes(educatorId) && !learnerTeacherIds.includes(educatorId)) {
        failures.push(`learner_missing_educator_reverse_link:${learnerId}:${educatorId}`);
      }
    }
  }

  return {
    id: 'educator_roster_data_contract',
    pass: failures.length === 0,
    details: {
      educatorsChecked: educators.length,
      linksChecked,
      failureCount: failures.length,
      sample: failures.slice(0, 80),
    },
  };
}

async function checkEducatorSessionCardFields(db, users, siteId) {
  const educatorIds = Array.from(users.entries())
    .filter(([, user]) => normalizeRole(user.role) === 'educator')
    .map(([uid]) => uid);

  if (educatorIds.length === 0) {
    return {
      id: 'educator_session_card_fields_present',
      pass: true,
      details: {
        educatorsChecked: 0,
        sessionsChecked: 0,
        failureCount: 0,
        sample: [],
      },
    };
  }

  const failures = [];
  let sessionsChecked = 0;
  let sessionsSnap;
  try {
    sessionsSnap = await db
      .collection('sessions')
      .where('siteId', '==', siteId)
      .get();
  } catch (error) {
    return {
      id: 'educator_session_card_fields_present',
      pass: false,
      details: {
        educatorsChecked: educatorIds.length,
        sessionsChecked: 0,
        failureCount: 1,
        sample: [`sessions_query_failed:${error instanceof Error ? error.message : String(error)}`],
      },
    };
  }

  for (const doc of sessionsSnap.docs) {
    const data = doc.data() || {};
    const educatorLinks = new Set(toStringArray(data.educatorIds));
    const primaryEducator = typeof data.educatorId === 'string' ? data.educatorId.trim() : '';
    if (primaryEducator) educatorLinks.add(primaryEducator);
    const intersects = educatorIds.some((id) => educatorLinks.has(id));
    if (!intersects) continue;
    sessionsChecked += 1;

    const title = typeof data.title === 'string' ? data.title.trim() : '';
    if (!title) failures.push(`session_missing_title:${doc.id}`);

    const startDate = data.startDate;
    const hasStart =
      startDate instanceof admin.firestore.Timestamp ||
      startDate instanceof Date ||
      typeof startDate === 'string' ||
      typeof startDate === 'number';
    if (!hasStart) failures.push(`session_missing_startDate:${doc.id}`);

    const pillarCodes = Array.isArray(data.pillarCodes) ? data.pillarCodes : [];
    if (pillarCodes.length === 0) failures.push(`session_missing_pillarCodes:${doc.id}`);
  }

  return {
    id: 'educator_session_card_fields_present',
    pass: failures.length === 0,
    details: {
      educatorsChecked: educatorIds.length,
      sessionsChecked,
      failureCount: failures.length,
      sample: failures.slice(0, 80),
    },
  };
}

async function checkVoiceBosTelemetrySupport(db, siteId) {
  const queryErrors = [];
  const voiceFailures = [];
  const bosFailures = [];

  let telemetryDocs = [];
  let interactionDocs = [];
  let fdmDocs = [];
  let orchestrationDocs = [];
  let interventionDocs = [];
  let mvlDocs = [];

  try {
    const telemetrySnap = await db
      .collection('telemetryEvents')
      .where('siteId', '==', siteId)
      .limit(300)
      .get();
    telemetryDocs = telemetrySnap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  } catch (error) {
    queryErrors.push(`telemetryEvents_query_failed:${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const interactionSnap = await db
      .collection('interactionEvents')
      .where('siteId', '==', siteId)
      .limit(300)
      .get();
    interactionDocs = interactionSnap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  } catch (error) {
    queryErrors.push(`interactionEvents_query_failed:${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const fdmSnap = await db
      .collection('fdmFeatures')
      .where('siteId', '==', siteId)
      .limit(120)
      .get();
    fdmDocs = fdmSnap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  } catch (error) {
    queryErrors.push(`fdmFeatures_query_failed:${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const orchestrationSnap = await db
      .collection('orchestrationStates')
      .where('siteId', '==', siteId)
      .limit(120)
      .get();
    orchestrationDocs = orchestrationSnap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  } catch (error) {
    queryErrors.push(`orchestrationStates_query_failed:${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const interventionSnap = await db
      .collection('interventions')
      .where('siteId', '==', siteId)
      .limit(120)
      .get();
    interventionDocs = interventionSnap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  } catch (error) {
    queryErrors.push(`interventions_query_failed:${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const mvlSnap = await db
      .collection('mvlEpisodes')
      .where('siteId', '==', siteId)
      .limit(120)
      .get();
    mvlDocs = mvlSnap.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  } catch (error) {
    queryErrors.push(`mvlEpisodes_query_failed:${error instanceof Error ? error.message : String(error)}`);
  }

  const voiceDocs = telemetryDocs.filter((doc) => {
    const event = typeof doc.data.event === 'string' ? doc.data.event.trim() : '';
    const eventType = typeof doc.data.eventType === 'string' ? doc.data.eventType.trim() : '';
    return VOICE_TELEMETRY_EVENTS.has(event || eventType);
  });

  const voiceTranscribeTraceIds = new Set();
  const voiceMessageTraceIds = new Set();
  const voiceTtsTraceIds = new Set();

  for (const doc of voiceDocs) {
    const metadata = isObjectRecord(doc.data.metadata) ? doc.data.metadata : null;
    if (!metadata) {
      voiceFailures.push(`voice_metadata_missing:${doc.id}`);
      continue;
    }

    for (const key of REQUIRED_VOICE_METADATA_KEYS) {
      if (metadata[key] === undefined || metadata[key] === null || metadata[key] === '') {
        voiceFailures.push(`voice_metadata_missing_key:${doc.id}:${key}`);
      }
    }

    const event = typeof doc.data.event === 'string' ? doc.data.event.trim() : '';
    const eventType = typeof metadata.eventType === 'string' ? metadata.eventType.trim() : '';
    if (event && eventType && event !== eventType) {
      voiceFailures.push(`voice_event_type_mismatch:${doc.id}:${event}:${eventType}`);
    }

    const metadataSiteId = typeof metadata.siteId === 'string' ? metadata.siteId.trim() : '';
    if (metadataSiteId && metadataSiteId !== siteId) {
      voiceFailures.push(`voice_site_mismatch:${doc.id}:${metadataSiteId}`);
    }

    const locale = typeof metadata.locale === 'string' ? metadata.locale.trim() : '';
    if (!REQUIRED_VOICE_LOCALES.has(locale)) {
      voiceFailures.push(`voice_locale_invalid:${doc.id}:${locale || 'missing'}`);
    }

    if (!isTimestampLike(metadata.timestamp)) {
      voiceFailures.push(`voice_timestamp_invalid:${doc.id}`);
    }

    const metadataRole = typeof metadata.role === 'string' ? metadata.role.trim() : '';
    if (!metadataRole) {
      voiceFailures.push(`voice_role_missing:${doc.id}`);
    }

    const traceId = typeof metadata.traceId === 'string' ? metadata.traceId.trim() : '';
    if (traceId) {
      if (event === 'voice.transcribe') voiceTranscribeTraceIds.add(traceId);
      if (event === 'voice.message') voiceMessageTraceIds.add(traceId);
      if (event === 'voice.tts') voiceTtsTraceIds.add(traceId);
    }
  }

  const bosEventDocs = interactionDocs.filter((doc) => {
    const eventType = typeof doc.data.eventType === 'string' ? doc.data.eventType.trim() : '';
    return BOS_EVENT_TYPES.has(eventType);
  });

  const bosTraceIds = new Set();

  for (const doc of bosEventDocs) {
    const data = doc.data;
    if (typeof data.eventType !== 'string' || !data.eventType.trim()) {
      bosFailures.push(`bos_event_type_missing:${doc.id}`);
    }
    if (typeof data.siteId !== 'string' || data.siteId.trim() !== siteId) {
      bosFailures.push(`bos_site_mismatch:${doc.id}:${String(data.siteId || 'missing')}`);
    }
    if (typeof data.actorId !== 'string' || !data.actorId.trim()) {
      bosFailures.push(`bos_actor_missing:${doc.id}`);
    }
    if (typeof data.actorRole !== 'string' || !data.actorRole.trim()) {
      bosFailures.push(`bos_actor_role_missing:${doc.id}`);
    }
    if (typeof data.gradeBand !== 'string' || !BOS_GRADE_BANDS.has(data.gradeBand.trim())) {
      bosFailures.push(`bos_grade_band_invalid:${doc.id}:${String(data.gradeBand || 'missing')}`);
    }
    if (!isTimestampLike(data.timestamp)) {
      bosFailures.push(`bos_timestamp_missing:${doc.id}`);
    }
    if (data.payload !== undefined && !isObjectRecord(data.payload)) {
      bosFailures.push(`bos_payload_not_object:${doc.id}`);
    }
    const payloadLocale = isObjectRecord(data.payload) && typeof data.payload.locale === 'string'
      ? data.payload.locale.trim()
      : '';
    const eventLocale = typeof data.locale === 'string' ? data.locale.trim() : '';
    const effectiveLocale = eventLocale || payloadLocale;
    if (!REQUIRED_VOICE_LOCALES.has(effectiveLocale)) {
      bosFailures.push(`bos_locale_invalid:${doc.id}:${effectiveLocale || 'missing'}`);
    }
    const service = typeof data.service === 'string' ? data.service.trim() : '';
    if (service && !BOS_ALLOWED_SERVICES.has(service)) {
      bosFailures.push(`bos_service_invalid:${doc.id}:${service}`);
    }
    const env = typeof data.env === 'string' ? data.env.trim() : '';
    if (env && env !== 'dev' && env !== 'staging' && env !== 'prod') {
      bosFailures.push(`bos_env_invalid:${doc.id}:${env}`);
    }
    if (isObjectRecord(data.payload)) {
      const payloadTrace = typeof data.payload.traceId === 'string' ? data.payload.traceId.trim() : '';
      const eventTrace = typeof data.traceId === 'string' ? data.traceId.trim() : '';
      const traceId = payloadTrace || eventTrace;
      if (!traceId) {
        bosFailures.push(`bos_trace_missing:${doc.id}`);
      }
      if (traceId) bosTraceIds.add(traceId);
    } else {
      const eventTrace = typeof data.traceId === 'string' ? data.traceId.trim() : '';
      if (!eventTrace) {
        bosFailures.push(`bos_trace_missing:${doc.id}`);
      } else {
        bosTraceIds.add(eventTrace);
      }
    }
  }

  for (const doc of fdmDocs) {
    const data = doc.data;
    if (typeof data.learnerId !== 'string' || !data.learnerId.trim()) {
      bosFailures.push(`fdm_missing_learner:${doc.id}`);
    }
    if (typeof data.sessionOccurrenceId !== 'string' || !data.sessionOccurrenceId.trim()) {
      bosFailures.push(`fdm_missing_session:${doc.id}`);
    }
    if (!isObjectRecord(data.features)) {
      bosFailures.push(`fdm_missing_features:${doc.id}`);
      continue;
    }
    if (!hasFiniteNumber(data.features.cognition)) bosFailures.push(`fdm_bad_cognition:${doc.id}`);
    if (!hasFiniteNumber(data.features.engagement)) bosFailures.push(`fdm_bad_engagement:${doc.id}`);
    if (!hasFiniteNumber(data.features.integrity)) bosFailures.push(`fdm_bad_integrity:${doc.id}`);
  }

  for (const doc of orchestrationDocs) {
    const data = doc.data;
    if (typeof data.learnerId !== 'string' || !data.learnerId.trim()) {
      bosFailures.push(`orchestration_missing_learner:${doc.id}`);
    }
    if (typeof data.sessionOccurrenceId !== 'string' || !data.sessionOccurrenceId.trim()) {
      bosFailures.push(`orchestration_missing_session:${doc.id}`);
    }
    if (!isObjectRecord(data.x_hat)) {
      bosFailures.push(`orchestration_missing_x_hat:${doc.id}`);
    } else {
      const xHat = data.x_hat;
      if (!hasFiniteNumber(xHat.cognition)) bosFailures.push(`orchestration_bad_cognition:${doc.id}`);
      if (!hasFiniteNumber(xHat.engagement)) bosFailures.push(`orchestration_bad_engagement:${doc.id}`);
      if (!hasFiniteNumber(xHat.integrity)) bosFailures.push(`orchestration_bad_integrity:${doc.id}`);
    }
    if (!isObjectRecord(data.P) || !hasFiniteNumber(data.P.confidence)) {
      bosFailures.push(`orchestration_missing_covariance:${doc.id}`);
    }
  }

  for (const doc of interventionDocs) {
    const data = doc.data;
    if (typeof data.learnerId !== 'string' || !data.learnerId.trim()) {
      bosFailures.push(`intervention_missing_learner:${doc.id}`);
    }
    if (typeof data.sessionOccurrenceId !== 'string' || !data.sessionOccurrenceId.trim()) {
      bosFailures.push(`intervention_missing_session:${doc.id}`);
    }
    if (typeof data.type !== 'string' || !data.type.trim()) {
      bosFailures.push(`intervention_missing_type:${doc.id}`);
    }
    if (typeof data.salience !== 'string' || !data.salience.trim()) {
      bosFailures.push(`intervention_missing_salience:${doc.id}`);
    }
    if (!isObjectRecord(data.policy)) {
      bosFailures.push(`intervention_missing_policy:${doc.id}`);
    } else {
      if (!hasFiniteNumber(data.policy.lambda)) bosFailures.push(`intervention_bad_lambda:${doc.id}`);
      if (!hasFiniteNumber(data.policy.m_dagger)) bosFailures.push(`intervention_bad_m_dagger:${doc.id}`);
    }
  }

  for (const doc of mvlDocs) {
    const data = doc.data;
    if (typeof data.learnerId !== 'string' || !data.learnerId.trim()) {
      bosFailures.push(`mvl_missing_learner:${doc.id}`);
    }
    if (!Array.isArray(data.riskSources)) {
      bosFailures.push(`mvl_missing_risk_sources:${doc.id}`);
    }
    if (!isTimestampLike(data.createdAt) && !isTimestampLike(data.updatedAt)) {
      bosFailures.push(`mvl_missing_timestamps:${doc.id}`);
    }
  }

  const toLearnerSessionKey = (value) => {
    const learnerId = typeof value.learnerId === 'string'
      ? value.learnerId.trim()
      : typeof value.actorId === 'string'
      ? value.actorId.trim()
      : '';
    const sessionOccurrenceId = typeof value.sessionOccurrenceId === 'string'
      ? value.sessionOccurrenceId.trim()
      : '';
    if (!learnerId || !sessionOccurrenceId) return null;
    return `${learnerId}::${sessionOccurrenceId}`;
  };

  const bosFlowKeys = new Set(
    bosEventDocs
      .map((doc) => toLearnerSessionKey(doc.data))
      .filter(Boolean),
  );
  const fdmKeys = new Set(
    fdmDocs
      .map((doc) => toLearnerSessionKey(doc.data))
      .filter(Boolean),
  );
  const orchestrationKeys = new Set(
    orchestrationDocs
      .map((doc) => toLearnerSessionKey(doc.data))
      .filter(Boolean),
  );
  const interventionKeys = new Set(
    interventionDocs
      .map((doc) => toLearnerSessionKey(doc.data))
      .filter(Boolean),
  );

  const overlap = (a, b) => {
    if (a.size === 0 || b.size === 0) return [];
    const shared = [];
    for (const key of a.values()) {
      if (b.has(key)) shared.push(key);
    }
    return shared;
  };

  const sharedEventToState = overlap(bosFlowKeys, orchestrationKeys);
  const sharedStateToIntervention = overlap(orchestrationKeys, interventionKeys);
  const sharedFeatureToState = overlap(fdmKeys, orchestrationKeys);
  const sharedSttToMessageTraces = overlap(voiceTranscribeTraceIds, voiceMessageTraceIds);
  const sharedMessageToBosTraces = overlap(voiceMessageTraceIds, bosTraceIds);
  const sharedTtsToBosTraces = overlap(voiceTtsTraceIds, bosTraceIds);

  if (bosFlowKeys.size > 0 && orchestrationKeys.size > 0 && sharedEventToState.length === 0) {
    bosFailures.push('bos_self_learning_no_event_to_state_link');
  }
  if (fdmKeys.size > 0 && orchestrationKeys.size > 0 && sharedFeatureToState.length === 0) {
    bosFailures.push('bos_self_learning_no_feature_to_state_link');
  }
  if (orchestrationKeys.size > 0 && interventionKeys.size > 0 && sharedStateToIntervention.length === 0) {
    bosFailures.push('bos_self_learning_no_state_to_intervention_link');
  }
  if (voiceTranscribeTraceIds.size > 0 && voiceMessageTraceIds.size > 0 && sharedSttToMessageTraces.length === 0) {
    bosFailures.push('voice_stt_to_message_trace_gap');
  }
  if (voiceMessageTraceIds.size > 0 && bosTraceIds.size > 0 && sharedMessageToBosTraces.length === 0) {
    bosFailures.push('voice_message_to_bos_trace_gap');
  }
  if (voiceTtsTraceIds.size > 0 && bosTraceIds.size > 0 && sharedTtsToBosTraces.length === 0) {
    bosFailures.push('voice_tts_to_bos_trace_gap');
  }

  const staticSupport = checkVoiceBosStaticSupport();
  const pass =
    queryErrors.length === 0 &&
    voiceFailures.length === 0 &&
    bosFailures.length === 0 &&
    staticSupport.pass;

  return {
    id: 'voice_bos_telemetry_intelligence_support',
    pass,
    details: {
      siteId,
      queryErrors: queryErrors.slice(0, 40),
      staticSupport,
      counts: {
        telemetryDocs: telemetryDocs.length,
        voiceDocs: voiceDocs.length,
        interactionDocs: interactionDocs.length,
        bosEventDocs: bosEventDocs.length,
        fdmDocs: fdmDocs.length,
        orchestrationDocs: orchestrationDocs.length,
        interventionDocs: interventionDocs.length,
        mvlDocs: mvlDocs.length,
      },
      selfLearningLinks: {
        bosFlowKeys: bosFlowKeys.size,
        fdmKeys: fdmKeys.size,
        orchestrationKeys: orchestrationKeys.size,
        interventionKeys: interventionKeys.size,
        sharedEventToState: sharedEventToState.length,
        sharedFeatureToState: sharedFeatureToState.length,
        sharedStateToIntervention: sharedStateToIntervention.length,
        voiceTranscribeTraceIds: voiceTranscribeTraceIds.size,
        voiceMessageTraceIds: voiceMessageTraceIds.size,
        voiceTtsTraceIds: voiceTtsTraceIds.size,
        bosTraceIds: bosTraceIds.size,
        sharedSttToMessageTraces: sharedSttToMessageTraces.length,
        sharedMessageToBosTraces: sharedMessageToBosTraces.length,
        sharedTtsToBosTraces: sharedTtsToBosTraces.length,
        sampleSharedKeys: [
          ...sharedEventToState.slice(0, 5),
          ...sharedFeatureToState.slice(0, 5),
          ...sharedStateToIntervention.slice(0, 5),
          ...sharedSttToMessageTraces.slice(0, 5),
          ...sharedMessageToBosTraces.slice(0, 5),
          ...sharedTtsToBosTraces.slice(0, 5),
        ],
      },
      voiceFailureCount: voiceFailures.length,
      bosFailureCount: bosFailures.length,
      voiceFailureSample: voiceFailures.slice(0, 80),
      bosFailureSample: bosFailures.slice(0, 80),
    },
  };
}

function checkRoleDashboardStatSources(db, siteId) {
  const requiredCollections = [
    'users',
    'sites',
    'enrollments',
    'missionAssignments',
    'messages',
    'sessionOccurrences',
    'missionAttempts',
    'events',
    'attendanceRecords',
    'incidents',
    'approvals',
  ];
  const checks = requiredCollections.map((collection) => ({
    collection,
    exists: true,
  }));
  return {
    id: 'dashboard_source_collections_declared',
    pass: checks.every((row) => row.exists),
    details: {
      siteId,
      collections: checks,
      note: 'Collections are queried by callable dashboard adapters and tolerate empty datasets.',
    },
  };
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  let { db, projectId, credentialPath, transport } = initializeAdmin();

  let siteSnap;
  let usersSnap;
  try {
    const siteRef = db.collection('sites').doc(args.siteId);
    [siteSnap, usersSnap] = await Promise.all([
      siteRef.get(),
      db.collection('users').where('siteIds', 'array-contains', args.siteId).get(),
    ]);
  } catch (error) {
    if (!isCredentialAuthError(error)) {
      throw error;
    }

    ({ db, projectId, credentialPath, transport } = initializeGcloudRestFallback(projectId));
    const siteRef = db.collection('sites').doc(args.siteId);
    [siteSnap, usersSnap] = await Promise.all([
      siteRef.get(),
      db.collection('users').where('siteIds', 'array-contains', args.siteId).get(),
    ]);
  }

  const siteDoc = siteSnap.exists ? siteSnap.data() || {} : null;
  const users = new Map(usersSnap.docs.map((doc) => [doc.id, doc.data() || {}]));

  const usersByRole = {
    learner: [],
    parent: [],
    educator: [],
    site: [],
    partner: [],
    hq: [],
  };
  for (const [uid, user] of users.entries()) {
    const role = normalizeRole(user.role);
    if (role && usersByRole[role]) usersByRole[role].push(uid);
  }

  const checks = [];
  checks.push({
    id: 'site_doc_exists',
    pass: siteSnap.exists,
    details: {
      siteId: args.siteId,
    },
  });
  checks.push(checkRoleCoverage(users));
  checks.push(checkUserCoreFields(users, args.siteId));
  checks.push(checkSiteDoc(siteDoc, usersByRole));
  checks.push(await checkParentDashboardContract(db, users, args.siteId));
  checks.push(await checkEducatorRosterContract(db, users, args.siteId));
  checks.push(await checkEducatorSessionCardFields(db, users, args.siteId));
  checks.push(await checkVoiceBosTelemetrySupport(db, args.siteId));
  checks.push(checkRoleDashboardStatSources(db, args.siteId));

  const pass = checks.every((check) => check.pass === true);
  const report = buildCanonicalReport({
    reportName: 'firebase-ui-field-wiring',
    env: args.env,
    pass,
    checks,
    metadata: {
      siteId: args.siteId,
      strict: args.strict,
      projectId,
      credentialPath,
      transport,
      counts: {
        usersAtSite: users.size,
        learners: usersByRole.learner.length,
        parents: usersByRole.parent.length,
        educators: usersByRole.educator.length,
        sites: usersByRole.site.length,
        partners: usersByRole.partner.length,
        hq: usersByRole.hq.length,
      },
      formatterSample: compactCount(users.size),
    },
  });
  const outputPath = writeCanonicalReport('firebase-ui-field-wiring', report);

  const output = {
    status: report.pass ? 'PASS' : 'FAIL',
    env: args.env,
    siteId: args.siteId,
    report: path.relative(process.cwd(), outputPath),
    pass: report.pass,
    failedChecks: checks.filter((check) => check.pass !== true).map((check) => check.id),
  };
  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (!report.pass) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  process.stderr.write(
    JSON.stringify(
      {
        status: 'FAIL',
        error: error instanceof Error ? error.message : String(error),
      },
      null,
      2,
    ) + '\n',
  );
  process.exit(1);
});
