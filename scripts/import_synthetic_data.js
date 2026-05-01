const fs = require('fs');
const path = require('path');
const {
  buildBosMiaSyntheticTrainingArtifacts,
} = require('./lib/bos_mia_synthetic_training');

const ROOT_DIR = path.resolve(__dirname, '..');
const FULL_PACK_DIR = path.join(
  ROOT_DIR,
  'docs',
  'scholesa_synthetic_fulltesting_pack_v2',
);
const STARTER_PACK_DIR = path.join(
  ROOT_DIR,
  'docs',
  'scholesa_synthetic_starter_pack_v1',
);
const DEFAULT_BATCH_SIZE = 400;

function parseArgs(argv) {
  const options = {
    apply: false,
    mode: 'all',
    batchSize: DEFAULT_BATCH_SIZE,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === '--apply') {
      options.apply = true;
      continue;
    }
    if (token === '--dry-run') {
      options.apply = false;
      continue;
    }
    if (token === '--mode') {
      options.mode = String(argv[index + 1] || 'all').trim().toLowerCase();
      index += 1;
      continue;
    }
    if (token.startsWith('--mode=')) {
      options.mode = token.split('=')[1].trim().toLowerCase();
      continue;
    }
    if (token === '--batch-size') {
      options.batchSize = Math.max(
        1,
        Number.parseInt(String(argv[index + 1] || DEFAULT_BATCH_SIZE), 10) ||
          DEFAULT_BATCH_SIZE,
      );
      index += 1;
      continue;
    }
    if (token.startsWith('--batch-size=')) {
      options.batchSize = Math.max(
        1,
        Number.parseInt(token.split('=')[1], 10) || DEFAULT_BATCH_SIZE,
      );
    }
  }

  if (!['starter', 'full', 'all'].includes(options.mode)) {
    throw new Error(`Unsupported mode "${options.mode}". Use starter, full, or all.`);
  }

  return options;
}

function slugify(input) {
  return String(input || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'unknown';
}

function titleCaseFromSlug(input) {
  return String(input || '')
    .split(/[_-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function toBoolean(value) {
  if (typeof value === 'boolean') return value;
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'yes';
}

function toNumber(value, fallback = 0) {
  const parsed = Number.parseFloat(String(value ?? ''));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toInteger(value, fallback = 0) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toDate(value) {
  if (!value) return null;
  const date = new Date(String(value));
  return Number.isNaN(date.getTime()) ? null : date;
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
function gradeBandCode(raw) {
  switch (String(raw || '').trim()) {
    case '1-3':
      return 'G1_3';
    case '4-6':
      return 'G4_6';
    case '7-9':
      return 'G7_9';
    case '10-12':
      return 'G10_12';
    default:
      return 'G4_6';
  }
}

function missionDifficulty(gradeBand) {
  switch (String(gradeBand || '').trim()) {
    case '1-3':
    case '4-6':
      return 'beginner';
    case '7-9':
      return 'intermediate';
    case '10-12':
      return 'advanced';
    default:
      return 'beginner';
  }
}

function pillarCodesForUnitFamily(unitFamily) {
  const normalized = String(unitFamily || '').toLowerCase();
  if (
    normalized.includes('venture') ||
    normalized.includes('innovation') ||
    normalized.includes('impact')
  ) {
    return ['impact', 'lead'];
  }
  if (
    normalized.includes('lead') ||
    normalized.includes('agency') ||
    normalized.includes('debate')
  ) {
    return ['lead', 'impact'];
  }
  if (
    normalized.includes('robot') ||
    normalized.includes('coding') ||
    normalized.includes('ai') ||
    normalized.includes('design') ||
    normalized.includes('invention')
  ) {
    return ['tech', 'impact'];
  }
  return ['tech'];
}

function mediaTypeForArtifact(artifactType) {
  const normalized = String(artifactType || '').toLowerCase();
  if (normalized.includes('video')) return 'video';
  if (normalized.includes('photo') || normalized.includes('image')) return 'image';
  if (normalized.includes('journal') || normalized.includes('doc')) return 'document';
  return 'document';
}

function summarizeIntegrityRisk(raw) {
  const normalized = String(raw || '').trim().toLowerCase();
  if (normalized === 'high') return 0.82;
  if (normalized === 'medium') return 0.58;
  return 0.24;
}

function summarizeConfidence(confidenceGap) {
  const normalized = Math.abs(toNumber(confidenceGap, 0));
  return Math.max(0.2, Math.min(0.95, 1 - normalized / 100));
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let inQuotes = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const nextChar = text[index + 1];

    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        cell += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char === ',' && !inQuotes) {
      row.push(cell);
      cell = '';
      continue;
    }

    if ((char === '\n' || char === '\r') && !inQuotes) {
      if (char === '\r' && nextChar === '\n') {
        index += 1;
      }
      row.push(cell);
      cell = '';
      if (row.some((value) => value !== '')) {
        rows.push(row);
      }
      row = [];
      continue;
    }

    cell += char;
  }

  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    if (row.some((value) => value !== '')) {
      rows.push(row);
    }
  }

  if (rows.length === 0) return [];
  const header = rows[0].map((value) => value.trim());
  return rows.slice(1).map((values) => {
    const record = {};
    header.forEach((key, index) => {
      record[key] = (values[index] || '').trim();
    });
    return record;
  });
}

function readCsvFile(filePath) {
  return parseCsv(fs.readFileSync(filePath, 'utf8'));
}

function readJsonlFile(filePath) {
  return fs
    .readFileSync(filePath, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function ensureCollection(bundle, collectionName) {
  if (!bundle.collections.has(collectionName)) {
    bundle.collections.set(collectionName, new Map());
  }
  return bundle.collections.get(collectionName);
}

function upsertDoc(bundle, collectionName, id, data) {
  const collection = ensureCollection(bundle, collectionName);
  collection.set(id, data);
}

function incrementCount(counter, key, amount = 1) {
  counter[key] = (counter[key] || 0) + amount;
}

function buildTeacherIds(team) {
  return String(team || '')
    .split('+')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => {
      const cleaned = part.replace(/^ms\/mr\s+/i, '').replace(/^ms\/?mr\s+/i, '');
      const slug = slugify(cleaned);
      return {
        id: `synthetic-educator-${slug}`,
        displayName: cleaned,
        email: `${slug}@synthetic.scholesa.test`,
      };
    });
}

function checkpointStatus(result) {
  const normalized = String(result || '').trim().toLowerCase();
  if (normalized === 'not_yet') return 'submitted';
  return 'completed';
}

function mvlTriggerReason(row) {
  if (toBoolean(row.mia_review_needed_expected)) {
    return 'mia_review_needed_expected';
  }
  if (String(row.expected_action || '').trim() === 'escalate_teacher_review') {
    return 'expected_action_requires_teacher_review';
  }
  return 'integrity_follow_up';
}

function parseRawEvent(event, cohortById, sessionById, rowByRecordId) {
  const cohort = cohortById.get(event.cohort_id) || null;
  sessionById.get(event.session_id);
  const record = rowByRecordId.get(event.record_id) || null;
  const siteId = cohort ? cohort._siteId : (record ? record._siteId : 'synthetic-site-starter');
  return {
    id: event.event_id,
    eventType: event.event_type || 'synthetic.event',
    timestamp: toDate(event.event_ts) || new Date(),
    siteId,
    learnerId: event.learner_id || record?._learnerId || null,
    sessionOccurrenceId: event.session_id || record?._sessionOccurrenceId || null,
    metadata: {
      synthetic: true,
      sourcePack: 'full',
      cohortId: event.cohort_id || null,
      recordId: event.record_id || null,
      details: event.details || '',
    },
  };
}

function addMiloOSGoldSyntheticStates(bundle, startedAt) {
  const siteId = 'synthetic-site-miloos-gold';
  const otherSiteId = 'synthetic-site-miloos-other';
  const sessionOccurrenceId = 'synthetic-miloos-gold-occurrence-01';
  const missionId = 'synthetic-miloos-gold-mission';
  const learners = {
    noSupport: 'synthetic-miloos-no-support-learner',
    pendingExplainBack: 'synthetic-miloos-pending-explain-back-learner',
    supportCurrent: 'synthetic-miloos-support-current-learner',
    crossSite: 'synthetic-miloos-cross-site-denial-learner',
    missingSite: 'synthetic-miloos-missing-site-denial-learner',
  };

  upsertDoc(bundle, 'sites', siteId, {
    id: siteId,
    name: 'Synthetic MiloOS Gold Readiness Site',
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
    purpose: 'MiloOS demo, UAT, and regression support-state coverage',
  });
  upsertDoc(bundle, 'sites', otherSiteId, {
    id: otherSiteId,
    name: 'Synthetic MiloOS Cross-Site Denial Site',
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
    purpose: 'Cross-site raw interactionEvents denial coverage',
  });
  upsertDoc(bundle, 'missions', missionId, {
    id: missionId,
    siteId,
    title: 'MiloOS Gold Readiness Support Mission',
    description: 'Canonical synthetic mission for MiloOS support provenance and verification debt.',
    pillarCodes: ['tech', 'lead'],
    difficulty: 'intermediate',
    estimatedDurationMinutes: 45,
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
  });
  upsertDoc(bundle, 'sessions', 'synthetic-miloos-gold-session', {
    id: 'synthetic-miloos-gold-session',
    siteId,
    title: 'MiloOS Gold Readiness Studio',
    educatorIds: ['synthetic-miloos-gold-educator'],
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
  });
  upsertDoc(bundle, 'sessionOccurrences', sessionOccurrenceId, {
    id: sessionOccurrenceId,
    sessionId: 'synthetic-miloos-gold-session',
    siteId,
    educatorId: 'synthetic-miloos-gold-educator',
    startTime: startedAt,
    endTime: new Date(startedAt.getTime() + 45 * 60 * 1000),
    status: 'completed',
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
  });
  upsertDoc(bundle, 'users', 'synthetic-miloos-gold-educator', {
    uid: 'synthetic-miloos-gold-educator',
    displayName: 'Synthetic MiloOS Educator',
    email: 'miloos.educator@synthetic.scholesa.test',
    role: 'educator',
    siteIds: [siteId],
    activeSiteId: siteId,
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
  });
  upsertDoc(bundle, 'users', 'synthetic-miloos-gold-site-lead', {
    uid: 'synthetic-miloos-gold-site-lead',
    displayName: 'Synthetic MiloOS Site Lead',
    email: 'miloos.site@synthetic.scholesa.test',
    role: 'siteLead',
    siteIds: [siteId],
    activeSiteId: siteId,
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
  });

  Object.entries(learners).forEach(([stateKey, learnerId]) => {
    const learnerSiteIds = stateKey === 'crossSite' ? [otherSiteId] : [siteId];
    upsertDoc(bundle, 'users', learnerId, {
      uid: learnerId,
      displayName: titleCaseFromSlug(learnerId),
      email: `${learnerId}@synthetic.scholesa.test`,
      role: 'learner',
      siteIds: learnerSiteIds,
      activeSiteId: learnerSiteIds[0],
      synthetic: true,
      sourcePack: 'miloos-gold-readiness',
      miloosGoldState: stateKey,
    });
    upsertDoc(bundle, 'enrollments', `synthetic-miloos-enrollment-${stateKey}`, {
      learnerId,
      sessionId: 'synthetic-miloos-gold-session',
      siteId: learnerSiteIds[0],
      status: 'active',
      synthetic: true,
      sourcePack: 'miloos-gold-readiness',
    });
  });

  const writeSupportTurn = ({ learnerId, openedId, site, submitted, minutesOffset }) => {
    const timestamp = new Date(startedAt.getTime() + minutesOffset * 60 * 1000);
    upsertDoc(bundle, 'interactionEvents', openedId, {
      eventType: 'ai_help_opened',
      siteId: site,
      actorId: learnerId,
      actorRole: 'learner',
      learnerId,
      gradeBand: 'G7_9',
      missionId,
      sessionOccurrenceId,
      traceId: openedId,
      payload: {
        mode: 'hint',
        aiHelpOpenedEventId: openedId,
        conceptTags: ['prototype testing'],
        aiResponseText: 'Compare one prototype variable at a time and explain what the evidence shows.',
      },
      timestamp,
      createdAt: timestamp,
      synthetic: true,
      sourcePack: 'miloos-gold-readiness',
    });
    upsertDoc(bundle, 'interactionEvents', `${openedId}-used`, {
      eventType: 'ai_help_used',
      siteId: site,
      actorId: learnerId,
      actorRole: 'learner',
      learnerId,
      gradeBand: 'G7_9',
      missionId,
      sessionOccurrenceId,
      payload: {
        mode: 'hint',
        aiHelpOpenedEventId: openedId,
        traceId: openedId,
        requiresExplainBack: true,
        safetyOutcome: 'allowed',
        safetyReasonCode: 'none',
      },
      timestamp: new Date(timestamp.getTime() + 30 * 1000),
      createdAt: new Date(timestamp.getTime() + 30 * 1000),
      synthetic: true,
      sourcePack: 'miloos-gold-readiness',
    });
    upsertDoc(bundle, 'interactionEvents', `${openedId}-response`, {
      eventType: 'ai_coach_response',
      siteId: site,
      actorId: learnerId,
      actorRole: 'learner',
      learnerId,
      gradeBand: 'G7_9',
      missionId,
      sessionOccurrenceId,
      payload: {
        mode: 'hint',
        aiHelpOpenedEventId: openedId,
        traceId: openedId,
        safetyOutcome: 'allowed',
        safetyReasonCode: 'none',
        aiResponseText: 'Compare one prototype variable at a time and explain what the evidence shows.',
      },
      timestamp: new Date(timestamp.getTime() + 45 * 1000),
      createdAt: new Date(timestamp.getTime() + 45 * 1000),
      synthetic: true,
      sourcePack: 'miloos-gold-readiness',
    });
    if (submitted) {
      upsertDoc(bundle, 'interactionEvents', `${openedId}-explain-back`, {
        eventType: 'explain_it_back_submitted',
        siteId: site,
        actorId: learnerId,
        actorRole: 'learner',
        learnerId,
        gradeBand: 'G7_9',
        missionId,
        sessionOccurrenceId,
        payload: {
          mode: 'hint',
          aiHelpOpenedEventId: openedId,
          approved: true,
          explainBackLength: 116,
          feedback: 'Explain-back attached to the MiloOS support turn.',
        },
        timestamp: new Date(timestamp.getTime() + 3 * 60 * 1000),
        createdAt: new Date(timestamp.getTime() + 3 * 60 * 1000),
        synthetic: true,
        sourcePack: 'miloos-gold-readiness',
      });
    }
  };

  writeSupportTurn({
    learnerId: learners.pendingExplainBack,
    openedId: 'synthetic-miloos-pending-opened-01',
    site: siteId,
    submitted: false,
    minutesOffset: 5,
  });
  writeSupportTurn({
    learnerId: learners.supportCurrent,
    openedId: 'synthetic-miloos-current-opened-01',
    site: siteId,
    submitted: true,
    minutesOffset: 15,
  });
  writeSupportTurn({
    learnerId: learners.crossSite,
    openedId: 'synthetic-miloos-cross-site-opened-01',
    site: otherSiteId,
    submitted: false,
    minutesOffset: 25,
  });
  writeSupportTurn({
    learnerId: learners.missingSite,
    openedId: 'synthetic-miloos-missing-site-opened-01',
    site: null,
    submitted: false,
    minutesOffset: 35,
  });

  upsertDoc(bundle, 'syntheticMiloOSGoldStates', 'latest', {
    id: 'latest',
    siteId,
    modeSupport: ['starter', 'full', 'all'],
    states: {
      noSupportLearnerId: learners.noSupport,
      pendingExplainBackLearnerId: learners.pendingExplainBack,
      supportCurrentLearnerId: learners.supportCurrent,
      crossSiteDenialLearnerId: learners.crossSite,
      missingSiteDenialLearnerId: learners.missingSite,
    },
    usage: 'Use these synthetic states for MiloOS demos, UAT, rules tests, and regression checks only.',
    noMasteryWrites: true,
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
    importedAt: startedAt,
  });

  incrementCount(bundle.sourceCounts, 'miloosGoldLearnerStates', 5);
  incrementCount(bundle.sourceCounts, 'miloosGoldInteractionEvents', 13);
}

function starterContextForRow(row) {
  const unitSlug = slugify(row.unit_family || 'starter-unit');
  const gradeSlug = slugify(row.grade_band || 'starter');
  const sessionIndex = toInteger(row.session_index, 1);
  const cohortId = `starter-${gradeSlug}-${unitSlug}`;
  const learnerId = `starter-${slugify(row.record_id)}`;
  const sessionOccurrenceId = `starter-occ-${gradeSlug}-${unitSlug}-${String(sessionIndex).padStart(2, '0')}`;
  const sessionId = `starter-session-${gradeSlug}-${unitSlug}`;
  return {
    learnerId,
    cohortId,
    sessionId,
    sessionOccurrenceId,
    siteId: 'synthetic-site-starter',
  };
}

function buildImportBundle(options) {
  const startedAt = new Date();
  const bundle = {
    collections: new Map(),
    sourceCounts: {},
    nativeCounts: {},
    sourcePacks: [],
  };

  const cohortById = new Map();
  const sessionById = new Map();
  const rowByRecordId = new Map();
  const expectedByRecordId = new Map();
  let starterTrainingRows = [];
  let fullExpectedRows = [];
  let longitudinalRows = [];
  let goldEvalRows = [];

  if (options.mode === 'starter' || options.mode === 'all') {
    const starterBootstrapRows = readJsonlFile(
      path.join(STARTER_PACK_DIR, 'scholesa_synthetic_bootstrap_v1.jsonl'),
    );
    const starterChallengeRows = readJsonlFile(
      path.join(STARTER_PACK_DIR, 'scholesa_synthetic_challenge_v1.jsonl'),
    );
    starterTrainingRows = starterBootstrapRows;
    bundle.sourcePacks.push('starter');
    incrementCount(bundle.sourceCounts, 'starterBootstrapRows', starterBootstrapRows.length);
    incrementCount(bundle.sourceCounts, 'starterChallengeRows', starterChallengeRows.length);

    upsertDoc(bundle, 'sites', 'synthetic-site-starter', {
      id: 'synthetic-site-starter',
      name: 'Synthetic Starter Studio',
      location: 'Starter Pack',
      siteLeadIds: [],
      createdAt: startedAt,
      synthetic: true,
      sourcePack: 'starter',
    });

    const starterMissionIds = new Set();
    const starterSessionDocs = new Map();

    for (const row of [...starterBootstrapRows, ...starterChallengeRows]) {
      const context = starterContextForRow(row);
      row._learnerId = context.learnerId;
      row._cohortId = context.cohortId;
      row._sessionId = context.sessionId;
      row._sessionOccurrenceId = context.sessionOccurrenceId;
      row._siteId = context.siteId;
      rowByRecordId.set(row.record_id, row);

      const missionId = `synthetic-mission-${slugify(row.unit_family)}`;
      if (!starterMissionIds.has(missionId)) {
        starterMissionIds.add(missionId);
        upsertDoc(bundle, 'missions', missionId, {
          id: missionId,
          title: row.unit_label || titleCaseFromSlug(row.unit_family),
          description: `Synthetic starter mission for ${row.unit_label || row.unit_family}`,
          pillarCodes: pillarCodesForUnitFamily(row.unit_family),
          difficulty: missionDifficulty(row.grade_band),
          estimatedDurationMinutes: 60,
          siteId: context.siteId,
          synthetic: true,
          sourcePack: 'starter',
        });
      }

      if (!starterSessionDocs.has(context.sessionId)) {
        starterSessionDocs.set(context.sessionId, true);
        upsertDoc(bundle, 'sessions', context.sessionId, {
          id: context.sessionId,
          title: row.unit_label || titleCaseFromSlug(row.unit_family),
          description: `Synthetic starter session sequence for ${row.unit_family}`,
          siteId: context.siteId,
          educatorIds: [],
          pillarCodes: pillarCodesForUnitFamily(row.unit_family),
          startDate: toDate('2026-01-01T08:00:00Z'),
          endDate: toDate('2026-12-31T17:00:00Z'),
          recurrence: 'synthetic',
          synthetic: true,
          sourcePack: 'starter',
        });
      }

      upsertDoc(bundle, 'sessionOccurrences', context.sessionOccurrenceId, {
        id: context.sessionOccurrenceId,
        sessionId: context.sessionId,
        siteId: context.siteId,
        startTime: toDate(`2026-01-${String(Math.max(1, toInteger(row.session_index, 1))).padStart(2, '0')}T09:00:00Z`) || startedAt,
        endTime: toDate(`2026-01-${String(Math.max(1, toInteger(row.session_index, 1))).padStart(2, '0')}T10:00:00Z`) || startedAt,
        educatorId: null,
        status: 'completed',
        synthetic: true,
        sourcePack: 'starter',
      });

      upsertDoc(bundle, 'users', context.learnerId, {
        uid: context.learnerId,
        email: `${context.learnerId}@synthetic.scholesa.test`,
        displayName: `Starter Learner ${row.record_id}`,
        role: 'learner',
        siteIds: [context.siteId],
        activeSiteId: context.siteId,
        createdAt: startedAt,
        updatedAt: startedAt,
        synthetic: true,
        sourcePack: 'starter',
      });

      upsertDoc(bundle, 'enrollments', `synthetic-enrollment-${context.learnerId}`, {
        id: `synthetic-enrollment-${context.learnerId}`,
        sessionId: context.sessionId,
        learnerId: context.learnerId,
        siteId: context.siteId,
        enrolledAt: startedAt,
        status: 'active',
        synthetic: true,
        sourcePack: 'starter',
      });

      upsertDoc(bundle, 'missionAttempts', row.record_id, {
        missionId,
        learnerId: context.learnerId,
        sessionOccurrenceId: context.sessionOccurrenceId,
        siteId: context.siteId,
        status: checkpointStatus(row.checkpoint_result),
        content: row.learner_response || '',
        feedback: row.teacher_observation || '',
        startedAt: startedAt,
        completedAt: startedAt,
        sourcePack: 'starter',
        synthetic: true,
        datasetPartition: row.dataset_partition,
        recommendedSplit: row.recommended_split,
      });

      if (toBoolean(row.proof_of_work_present)) {
        upsertDoc(bundle, 'portfolioItems', `starter-artifact-${slugify(row.record_id)}`, {
          id: `starter-artifact-${slugify(row.record_id)}`,
          learnerId: context.learnerId,
          portfolioId: `portfolio-${context.learnerId}`,
          siteId: context.siteId,
          title: row.session_title || 'Synthetic Starter Artifact',
          description: row.artifact_summary || row.prompt_text || '',
          mediaType: mediaTypeForArtifact(row.proof_of_work_type),
          mediaUrl: `synthetic://starter/${row.record_id}`,
          createdAt: startedAt,
          synthetic: true,
          sourcePack: 'starter',
        });
      }

      if (String(row.peer_feedback || '').trim()) {
        upsertDoc(bundle, 'peerFeedback', `starter-feedback-${slugify(row.record_id)}`, {
          id: `starter-feedback-${slugify(row.record_id)}`,
          siteId: context.siteId,
          learnerId: context.learnerId,
          recipientId: context.learnerId,
          sessionOccurrenceId: context.sessionOccurrenceId,
          authorId: `starter-peer-${slugify(row.record_id)}`,
          content: row.peer_feedback,
          feedbackFocus: row.task_family || 'general',
          revisionRequested: toBoolean(row.needs_followup),
          createdAt: startedAt,
          synthetic: true,
          sourcePack: 'starter',
        });
      }

      if (String(row.teacher_observation || '').trim()) {
        upsertDoc(bundle, 'educatorFeedback', `starter-observation-${slugify(row.record_id)}`, {
          id: `starter-observation-${slugify(row.record_id)}`,
          siteId: context.siteId,
          learnerId: context.learnerId,
          sessionOccurrenceId: context.sessionOccurrenceId,
          educatorId: 'synthetic-starter-educator',
          feedback: row.teacher_observation,
          priority: toBoolean(row.needs_followup) ? 'high' : 'low',
          createdAt: startedAt,
          synthetic: true,
          sourcePack: 'starter',
        });
      }

      const masteryScore = Math.round(
        Math.max(35, Math.min(92, toNumber(row.confidence_self_rating, 3) * 18)),
      );
      const readinessScore = Math.round(
        Math.max(30, Math.min(90, masteryScore - (toBoolean(row.needs_followup) ? 10 : 0))),
      );
      const integrityScore = Math.round(
        Math.max(35, Math.min(95, (1 - summarizeIntegrityRisk(row.integrity_risk)) * 100)),
      );
      upsertDoc(bundle, 'orchestrationStates', `${context.learnerId}_${context.sessionOccurrenceId}`, {
        siteId: context.siteId,
        learnerId: context.learnerId,
        sessionOccurrenceId: context.sessionOccurrenceId,
        x_hat: {
          cognition: masteryScore / 100,
          engagement: readinessScore / 100,
          integrity: integrityScore / 100,
        },
        P: {
          diag: [0.24, 0.22, 0.18],
          trace: 0.64,
          confidence: summarizeConfidence(100 - integrityScore),
        },
        model: {
          estimator: 'synthetic-import',
          version: 'starter-v1',
          Q_version: 'synthetic',
          R_version: 'synthetic',
        },
        fusion: {
          familiesPresent: ['teacher_observation', 'artifact_summary', 'peer_feedback'],
          sensorFusionMet: true,
        },
        lastUpdatedAt: startedAt,
        synthetic: true,
        sourcePack: 'starter',
      });

      if (toBoolean(row.needs_followup) || String(row.integrity_risk || '').trim() === 'high') {
        upsertDoc(bundle, 'mvlEpisodes', `starter-mvl-${slugify(row.record_id)}`, {
          siteId: context.siteId,
          learnerId: context.learnerId,
          sessionOccurrenceId: context.sessionOccurrenceId,
          triggerReason: 'starter_follow_up',
          reliability: {
            method: 'synthetic-import',
            K: 1,
            M: 1,
            H_sem: summarizeIntegrityRisk(row.integrity_risk),
            riskScore: summarizeIntegrityRisk(row.integrity_risk),
            threshold: 0.5,
          },
          evidenceEventIds: [row.record_id],
          createdAt: startedAt,
          synthetic: true,
          sourcePack: 'starter',
        });
      }

      upsertDoc(bundle, 'syntheticEvidenceRecords', row.record_id, {
        ...row,
        learner_id: context.learnerId,
        cohort_id: context.cohortId,
        session_id: context.sessionOccurrenceId,
        site_id: context.siteId,
        sourcePack: 'starter',
        importedAt: startedAt,
      });
    }
  }

  if (options.mode === 'full' || options.mode === 'all') {
    const cohortRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'cohorts_v2.csv'));
    const learnerRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'learners_v2.csv'));
    const sessionRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'sessions_v2.csv'));
    const coreRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'core_evidence_records_v2.csv'));
    const artifactRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'artifact_metadata_v2.csv'));
    const teacherObservationRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'teacher_observations_v2.csv'));
    const peerFeedbackRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'peer_feedback_v2.csv'));
    const expectedRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'expected_model_outputs_v2.csv'));
    const aiTraceRows = readCsvFile(path.join(FULL_PACK_DIR, 'normalized', 'ai_trace_records_v2.csv'));
    const rawEventRows = readJsonlFile(path.join(FULL_PACK_DIR, 'normalized', 'raw_event_log_v2.jsonl'));
    const dashboardAggregateRows = readCsvFile(path.join(FULL_PACK_DIR, 'suites', 'dashboard_aggregates_v2.csv'));
    const fairnessSuiteRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'fairness_counterfactual_suite_v2.jsonl'));
    goldEvalRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'gold_eval_suite_v2.jsonl'));
    const integrityRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'integrity_adversarial_suite_v2.jsonl'));
    const privacyRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'privacy_safety_suite_v2.jsonl'));
    const schemaEdgeRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'schema_edgecase_suite_v2.jsonl'));
    longitudinalRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'longitudinal_trajectory_suite_v2.jsonl'));
    const loadTestRows = readJsonlFile(path.join(FULL_PACK_DIR, 'suites', 'load_test_requests_v2.jsonl'));
    fullExpectedRows = expectedRows;
    bundle.sourcePacks.push('full');

    incrementCount(bundle.sourceCounts, 'fullCohorts', cohortRows.length);
    incrementCount(bundle.sourceCounts, 'fullLearners', learnerRows.length);
    incrementCount(bundle.sourceCounts, 'fullSessions', sessionRows.length);
    incrementCount(bundle.sourceCounts, 'fullCoreEvidenceRows', coreRows.length);
    incrementCount(bundle.sourceCounts, 'fullArtifacts', artifactRows.length);
    incrementCount(bundle.sourceCounts, 'fullTeacherObservations', teacherObservationRows.length);
    incrementCount(bundle.sourceCounts, 'fullPeerFeedback', peerFeedbackRows.length);
    incrementCount(bundle.sourceCounts, 'fullExpectedOutputs', expectedRows.length);
    incrementCount(bundle.sourceCounts, 'fullAiTraceRows', aiTraceRows.length);
    incrementCount(bundle.sourceCounts, 'fullRawEventRows', rawEventRows.length);
    incrementCount(bundle.sourceCounts, 'fullDashboardAggregateRows', dashboardAggregateRows.length);
    incrementCount(bundle.sourceCounts, 'fullSuiteRows', fairnessSuiteRows.length + goldEvalRows.length + integrityRows.length + privacyRows.length + schemaEdgeRows.length + longitudinalRows.length + loadTestRows.length);

    for (const row of cohortRows) {
      const siteId = `synthetic-site-${slugify(row.region)}`;
      row._siteId = siteId;
      cohortById.set(row.cohort_id, row);

      const teacherIds = buildTeacherIds(row.teacher_team);
      upsertDoc(bundle, 'sites', siteId, {
        id: siteId,
        name: `${row.region} Synthetic Studio`,
        location: row.region,
        siteLeadIds: teacherIds.map((teacher) => teacher.id),
        createdAt: toDate(row.start_date) || startedAt,
        synthetic: true,
        sourcePack: 'full',
      });

      teacherIds.forEach((teacher) => {
        upsertDoc(bundle, 'users', teacher.id, {
          uid: teacher.id,
          email: teacher.email,
          displayName: teacher.displayName,
          role: 'educator',
          siteIds: [siteId],
          activeSiteId: siteId,
          createdAt: toDate(row.start_date) || startedAt,
          updatedAt: startedAt,
          synthetic: true,
          sourcePack: 'full',
        });
      });

      const sessionId = `synthetic-session-${row.cohort_id}`;
      row._sessionDocId = sessionId;
      upsertDoc(bundle, 'sessions', sessionId, {
        id: sessionId,
        title: row.unit_label,
        description: `${row.grade_band} synthetic cohort ${row.cohort_id}`,
        siteId,
        educatorIds: teacherIds.map((teacher) => teacher.id),
        pillarCodes: pillarCodesForUnitFamily(row.unit_family),
        startDate: toDate(row.start_date) || startedAt,
        endDate: toDate(row.start_date) || startedAt,
        recurrence: 'weekly',
        synthetic: true,
        sourcePack: 'full',
        cohortSplit: row.cohort_split,
        aiAccessPolicy: row.ai_access_policy,
      });
    }

    for (const row of learnerRows) {
      const cohort = cohortById.get(row.cohort_id);
      const siteId = cohort?._siteId || 'synthetic-site-unknown';
      row._siteId = siteId;
      upsertDoc(bundle, 'users', row.learner_id, {
        uid: row.learner_id,
        email: `${String(row.learner_id).toLowerCase()}@synthetic.scholesa.test`,
        displayName: `Synthetic Learner ${row.learner_id}`,
        role: 'learner',
        siteIds: [siteId],
        activeSiteId: siteId,
        createdAt: startedAt,
        updatedAt: startedAt,
        synthetic: true,
        sourcePack: 'full',
        cohortId: row.cohort_id,
        gradeBand: row.grade_band,
        supportProfile: row.support_profile,
        languageSupport: row.language_support,
      });

      const cohortSessionId = cohort?._sessionDocId || `synthetic-session-${row.cohort_id}`;
      upsertDoc(bundle, 'enrollments', `synthetic-enrollment-${row.learner_id}`, {
        id: `synthetic-enrollment-${row.learner_id}`,
        sessionId: cohortSessionId,
        learnerId: row.learner_id,
        siteId,
        enrolledAt: startedAt,
        status: 'active',
        synthetic: true,
        sourcePack: 'full',
      });
    }

    const missionIds = new Set();
    for (const row of sessionRows) {
      const cohort = cohortById.get(row.cohort_id);
      const siteId = cohort?._siteId || 'synthetic-site-unknown';
      const sessionDocId = cohort?._sessionDocId || `synthetic-session-${row.cohort_id}`;
      row._siteId = siteId;
      row._sessionDocId = sessionDocId;
      sessionById.set(row.session_id, row);

      const missionId = `synthetic-mission-${slugify(row.unit_family)}`;
      if (!missionIds.has(missionId)) {
        missionIds.add(missionId);
        upsertDoc(bundle, 'missions', missionId, {
          id: missionId,
          title: row.unit_label,
          description: `Synthetic mission imported from ${row.unit_family}`,
          pillarCodes: pillarCodesForUnitFamily(row.unit_family),
          difficulty: missionDifficulty(row.grade_band),
          estimatedDurationMinutes: toInteger(row.duration_min, 60),
          siteId,
          synthetic: true,
          sourcePack: 'full',
        });
      }

      const startDate = toDate(`${row.scheduled_date}T09:00:00Z`) || startedAt;
      const endDate = new Date(startDate.getTime() + toInteger(row.duration_min, 60) * 60 * 1000);
      upsertDoc(bundle, 'sessionOccurrences', row.session_id, {
        id: row.session_id,
        sessionId: sessionDocId,
        siteId,
        startTime: startDate,
        endTime: endDate,
        educatorId: (cohort && buildTeacherIds(cohort.teacher_team)[0]?.id) || null,
        status: 'completed',
        synthetic: true,
        sourcePack: 'full',
        title: row.session_title,
      });
    }

    for (const row of expectedRows) {
      expectedByRecordId.set(row.record_id, row);
      upsertDoc(bundle, 'syntheticExpectedModelOutputs', row.record_id, {
        ...row,
        synthetic: true,
        sourcePack: 'full',
        importedAt: startedAt,
      });
    }

    for (const row of coreRows) {
      const cohort = cohortById.get(row.cohort_id);
      const session = sessionById.get(row.session_id);
      const expected = expectedByRecordId.get(row.record_id) || null;
      const siteId = cohort?._siteId || 'synthetic-site-unknown';
      const sessionOccurrenceId = row.session_id;
      const missionId = `synthetic-mission-${slugify(row.unit_family)}`;

      row._siteId = siteId;
      row._learnerId = row.learner_id;
      row._sessionOccurrenceId = sessionOccurrenceId;
      rowByRecordId.set(row.record_id, row);

      upsertDoc(bundle, 'missionAttempts', row.record_id, {
        missionId,
        learnerId: row.learner_id,
        sessionOccurrenceId,
        siteId,
        status: checkpointStatus(row.checkpoint_result),
        content: row.learner_response,
        feedback: row.teacher_observation,
        startedAt: toDate(row.timestamp_created) || startedAt,
        completedAt: toDate(row.timestamp_created) || startedAt,
        synthetic: true,
        sourcePack: 'full',
        checkpointResult: row.checkpoint_result,
        datasetPartition: row.dataset_partition,
        eligibleForTraining: toBoolean(row.eligible_for_training),
        eligibleForEval: toBoolean(row.eligible_for_eval),
      });

      const masteryScore = toNumber(
        expected?.bos_mastery_score_expected || row.bos_mastery_expected,
        50,
      );
      const readinessScore = toNumber(
        expected?.bos_readiness_score_expected || row.bos_readiness_expected,
        50,
      );
      const integrityScore = toNumber(
        expected?.mia_integrity_score_expected || row.mia_integrity_expected,
        75,
      );
      const confidence = summarizeConfidence(
        expected?.confidence_calibration_gap || row.confidence_calibration_gap,
      );
      upsertDoc(bundle, 'orchestrationStates', `${row.learner_id}_${sessionOccurrenceId}`, {
        siteId,
        learnerId: row.learner_id,
        sessionOccurrenceId,
        x_hat: {
          cognition: masteryScore / 100,
          engagement: readinessScore / 100,
          integrity: integrityScore / 100,
        },
        P: {
          diag: [0.22, 0.2, 0.18],
          trace: 0.6,
          confidence,
        },
        model: {
          estimator: 'synthetic-import',
          version: 'full-v2',
          Q_version: 'synthetic',
          R_version: 'synthetic',
        },
        fusion: {
          familiesPresent: ['teacher_observation', 'peer_feedback', 'artifact_metadata', 'expected_model_output'],
          sensorFusionMet: true,
        },
        lastUpdatedAt: toDate(row.timestamp_created) || startedAt,
        synthetic: true,
        sourcePack: 'full',
      });

      if (
        toBoolean(expected?.mia_review_needed_expected || row.mia_review_needed_expected) ||
        String(row.expected_action || '').trim() === 'escalate_teacher_review' ||
        String(row.integrity_risk || '').trim().toLowerCase() === 'high'
      ) {
        upsertDoc(bundle, 'mvlEpisodes', `mvl-${row.record_id}`, {
          siteId,
          learnerId: row.learner_id,
          sessionOccurrenceId,
          triggerReason: mvlTriggerReason(row),
          reliability: {
            method: 'synthetic-import',
            K: 1,
            M: 1,
            H_sem: summarizeIntegrityRisk(row.integrity_risk),
            riskScore: summarizeIntegrityRisk(row.integrity_risk),
            threshold: 0.5,
          },
          autonomy: {
            signals: toBoolean(row.ai_used)
              ? ['ai_used', 'disclosure_check']
              : ['teacher_follow_up'],
            riskScore: toBoolean(row.ai_used) ? 0.42 : 0.2,
            threshold: 0.5,
          },
          evidenceEventIds: [row.record_id],
          createdAt: toDate(row.timestamp_created) || startedAt,
          synthetic: true,
          sourcePack: 'full',
        });
      }

      upsertDoc(bundle, 'syntheticEvidenceRecords', row.record_id, {
        ...row,
        site_id: siteId,
        importedAt: startedAt,
        sourcePack: 'full',
      });

      if (session) {
        upsertDoc(bundle, 'classInsights', `insight-${sessionOccurrenceId}`, {
          siteId,
          sessionOccurrenceId,
          cohortId: row.cohort_id,
          gradeBand: row.grade_band,
          unitFamily: row.unit_family,
          synthetic: true,
          sourcePack: 'full',
        });
      }
    }

    for (const row of artifactRows) {
      const core = rowByRecordId.get(row.record_id);
      const siteId = core?._siteId || 'synthetic-site-unknown';
      upsertDoc(bundle, 'portfolioItems', row.artifact_id, {
        id: row.artifact_id,
        learnerId: row.learner_id,
        portfolioId: `portfolio-${row.learner_id}`,
        siteId,
        title: core?.session_title || row.artifact_type,
        description: row.artifact_summary,
        mediaType: mediaTypeForArtifact(row.artifact_type),
        mediaUrl: `synthetic://artifact/${row.artifact_id}`,
        createdAt: toDate(row.created_ts) || startedAt,
        synthetic: true,
        sourcePack: 'full',
        versionCount: toInteger(row.version_count, 1),
      });
    }

    for (const row of teacherObservationRows) {
      const core = rowByRecordId.get(row.record_id);
      const siteId = core?._siteId || 'synthetic-site-unknown';
      upsertDoc(bundle, 'educatorFeedback', row.observation_id, {
        id: row.observation_id,
        siteId,
        learnerId: row.learner_id,
        sessionOccurrenceId: row.session_id,
        educatorId: `synthetic-observer-${slugify(row.cohort_id)}`,
        feedback: row.teacher_observation,
        priority: row.followup_priority || 'low',
        explainItBack: toBoolean(row.check_explain_it_back),
        proofOfWork: toBoolean(row.check_proof_of_work),
        userClaimLink: toBoolean(row.check_user_or_claim_link),
        revisionNamed: toBoolean(row.check_revision_named),
        createdAt: toDate(row.observation_ts) || startedAt,
        synthetic: true,
        sourcePack: 'full',
      });
    }

    for (const row of peerFeedbackRows) {
      const core = rowByRecordId.get(row.record_id);
      const siteId = core?._siteId || 'synthetic-site-unknown';
      upsertDoc(bundle, 'peerFeedback', row.feedback_id, {
        id: row.feedback_id,
        siteId,
        learnerId: row.learner_id,
        recipientId: row.learner_id,
        sessionOccurrenceId: row.session_id,
        authorId: `synthetic-peer-${slugify(row.feedback_id)}`,
        content: row.peer_feedback,
        feedbackFocus: row.feedback_focus,
        revisionRequested: toBoolean(row.revision_requested),
        createdAt: toDate(row.feedback_ts) || startedAt,
        synthetic: true,
        sourcePack: 'full',
      });
    }

    for (const row of aiTraceRows) {
      const core = rowByRecordId.get(row.record_id);
      const siteId = core?._siteId || 'synthetic-site-unknown';
      upsertDoc(bundle, 'interactionEvents', row.ai_trace_id, {
        eventType: 'ai_coach_feedback',
        timestamp: toDate(row.trace_ts) || startedAt,
        siteId,
        learnerId: row.learner_id,
        sessionOccurrenceId: row.session_id,
        metadata: {
          synthetic: true,
          sourcePack: 'full',
          traceId: row.ai_trace_id,
          aiMode: row.ai_mode,
          aiPrompt: row.ai_prompt,
          suggestionCategory: row.ai_suggestion_category,
          disclosureQuality: row.disclosure_quality,
          humanVerified: toBoolean(row.human_verified),
        },
      });
    }

    for (const event of rawEventRows) {
      const parsed = parseRawEvent(event, cohortById, sessionById, rowByRecordId);
      upsertDoc(bundle, 'interactionEvents', parsed.id, parsed);
    }

    for (const row of dashboardAggregateRows) {
      const cohort = cohortById.get(row.cohort_id);
      const siteId = cohort?._siteId || 'synthetic-site-unknown';
      upsertDoc(bundle, 'telemetryAggregates', `synthetic-aggregate-${row.aggregate_level}-${row.cohort_id}-${row.session_index}`, {
        siteId,
        cohortId: row.cohort_id,
        gradeBand: row.grade_band,
        unitFamily: row.unit_family,
        sessionIndex: toInteger(row.session_index, 0),
        sessionTitle: row.session_title,
        aggregateLevel: row.aggregate_level,
        submissionRate: toNumber(row.submission_rate, 0),
        avgBosMastery: toNumber(row.avg_bos_mastery, 0),
        avgBosReadiness: toNumber(row.avg_bos_readiness, 0),
        avgMiaIntegrity: toNumber(row.avg_mia_integrity, 0),
        proofOfWorkRate: toNumber(row.proof_of_work_rate, 0),
        aiUseRate: toNumber(row.ai_use_rate, 0),
        followupRate: toNumber(row.followup_rate, 0),
        reviewNeededRate: toNumber(row.review_needed_rate, 0),
        recordedAt: startedAt,
        synthetic: true,
        sourcePack: 'full',
      });

      upsertDoc(bundle, 'classInsights', `insight-${row.cohort_id}-${row.session_index}`, {
        siteId,
        sessionOccurrenceId: `synthetic-session-occurrence-${row.cohort_id}-${String(row.session_index).padStart(2, '0')}`,
        cohortId: row.cohort_id,
        averages: {
          cognition: toNumber(row.avg_bos_mastery, 0) / 100,
          engagement: toNumber(row.avg_bos_readiness, 0) / 100,
          integrity: toNumber(row.avg_mia_integrity, 0) / 100,
        },
        learnerCount: toInteger(row.distinct_learners, 0),
        activeMvlCount: Math.round(toInteger(row.distinct_learners, 0) * toNumber(row.review_needed_rate, 0)),
        synthetic: true,
        sourcePack: 'full',
      });
    }

    const fairnessSuiteSummary = {
      totalCases: fairnessSuiteRows.length,
      integrityCases: integrityRows.length,
      privacyCases: privacyRows.length,
      schemaEdgeCases: schemaEdgeRows.length,
      longitudinalCases: longitudinalRows.length,
      goldEvalCases: goldEvalRows.length,
      loadTestCases: loadTestRows.length,
    };
    upsertDoc(bundle, 'fairnessAudits', 'synthetic-fairness-audit-v2', {
      siteId: 'synthetic-site-cross-pack',
      createdAt: startedAt,
      synthetic: true,
      sourcePack: 'full',
      summary: fairnessSuiteSummary,
    });

    const suiteGroups = [
      ['gold_eval_suite_v2', goldEvalRows],
      ['fairness_counterfactual_suite_v2', fairnessSuiteRows],
      ['integrity_adversarial_suite_v2', integrityRows],
      ['privacy_safety_suite_v2', privacyRows],
      ['schema_edgecase_suite_v2', schemaEdgeRows],
      ['longitudinal_trajectory_suite_v2', longitudinalRows],
      ['load_test_requests_v2', loadTestRows],
    ];

    suiteGroups.forEach(([suiteType, rows]) => {
      rows.forEach((row, index) => {
        const id = row.id || row.case_id || row.request_id || `${suiteType}-${index + 1}`;
        upsertDoc(bundle, 'syntheticEvaluationSuites', `${suiteType}-${id}`, {
          suiteType,
          synthetic: true,
          sourcePack: 'full',
          importedAt: startedAt,
          ...row,
        });
      });
    });
  }

  addMiloOSGoldSyntheticStates(bundle, startedAt);

  const trainingArtifacts = buildBosMiaSyntheticTrainingArtifacts({
    importedAt: startedAt,
    sourcePacks: bundle.sourcePacks,
    starterTrainingRows,
    fullExpectedRows,
    coreRows: Array.from(rowByRecordId.values()),
    longitudinalRows,
    goldEvalRows,
  });

  upsertDoc(bundle, 'bosMiaTrainingRuns', trainingArtifacts.trainingRunId, trainingArtifacts.trainingRunDoc);
  upsertDoc(bundle, 'bosMiaTrainingRuns', 'latest', trainingArtifacts.trainingRunDoc);
  upsertDoc(bundle, 'bosMiaCalibrationProfiles', trainingArtifacts.trainingRunId, trainingArtifacts.profileDoc);
  upsertDoc(bundle, 'bosMiaCalibrationProfiles', 'latest', trainingArtifacts.profileDoc);

  bundle.collections.forEach((docs, collectionName) => {
    bundle.nativeCounts[collectionName] = docs.size;
  });

  const summary = {
    id: `synthetic-import-${startedAt.toISOString().replace(/[:.]/g, '-')}`,
    mode: options.mode,
    sourcePacks: bundle.sourcePacks,
    importedAt: startedAt,
    summaryLabel:
      options.mode === 'all'
        ? 'Starter + full synthetic packs'
        : options.mode === 'starter'
          ? 'Starter synthetic pack'
          : 'Full synthetic testing pack',
    sourceCounts: bundle.sourceCounts,
    nativeCounts: bundle.nativeCounts,
    folders: bundle.sourcePacks.map((pack) =>
      pack === 'starter'
        ? 'docs/scholesa_synthetic_starter_pack_v1'
        : 'docs/scholesa_synthetic_fulltesting_pack_v2',
    ),
    bosMiaTraining: trainingArtifacts.summary,
    miloosGoldReadinessStates: {
      collection: 'syntheticMiloOSGoldStates',
      documentId: 'latest',
      seedModes: ['starter', 'full', 'all'],
      purpose: 'MiloOS demos, UAT, rules tests, and regression checks without support-only mastery writes.',
    },
    synthetic: true,
  };
  upsertDoc(bundle, 'syntheticDatasetImports', summary.id, summary);
  upsertDoc(bundle, 'syntheticDatasetImports', 'latest', summary);
  bundle.nativeCounts.syntheticDatasetImports = 2;
  bundle.nativeCounts.bosMiaTrainingRuns = 2;
  bundle.nativeCounts.bosMiaCalibrationProfiles = 2;

  return {
    collections: bundle.collections,
    summary,
  };
}

function serializeSummary(summary) {
  return JSON.stringify(
    {
      ...summary,
      importedAt: summary.importedAt.toISOString(),
    },
    null,
    2,
  );
}

async function writeBundleToFirestore(bundle, batchSize) {
  const admin = require('firebase-admin');
  const { initializeApp, cert, getApps } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path before using --apply.');
  }

  if (getApps().length === 0) {
    initializeApp({
      credential: cert(require(path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS))),
    });
  }

  const db = getFirestore();
  for (const [collectionName, docs] of bundle.collections.entries()) {
    const entries = Array.from(docs.entries());
    for (let index = 0; index < entries.length; index += batchSize) {
      const batch = db.batch();
      const slice = entries.slice(index, index + batchSize);
      slice.forEach(([id, data]) => {
        const ref = db.collection(collectionName).doc(id);
        batch.set(ref, data, { merge: true });
      });
      await batch.commit();
      console.log(`Committed ${collectionName} batch ${Math.floor(index / batchSize) + 1} (${slice.length} docs)`);
    }
  }
  return admin;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const result = buildImportBundle(options);
  console.log(serializeSummary(result.summary));

  if (!options.apply) {
    console.log('Dry run only. Re-run with --apply to write these documents to Firestore.');
    return;
  }

  await writeBundleToFirestore(result, options.batchSize);
  console.log('Synthetic data import complete.');
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = {
  buildImportBundle,
  parseCsv,
  readJsonlFile,
  starterContextForRow,
};