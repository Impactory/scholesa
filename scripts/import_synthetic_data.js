const fs = require('fs');
const path = require('path');
const {
  buildBosMiaSyntheticTrainingArtifacts,
} = require('./lib/bos_mia_synthetic_training');
const {
  getGcloudAccessToken,
  resolveProjectId,
} = require('./firebase_runtime_auth');

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

  const miloosGoldSourceCounts = {
    miloosGoldLearnerStates: 5,
    miloosGoldInteractionEvents: 13,
  };

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
    sourceCounts: miloosGoldSourceCounts,
    synthetic: true,
    sourcePack: 'miloos-gold-readiness',
    importedAt: startedAt,
  });

  incrementCount(bundle.sourceCounts, 'miloosGoldLearnerStates', miloosGoldSourceCounts.miloosGoldLearnerStates);
  incrementCount(bundle.sourceCounts, 'miloosGoldInteractionEvents', miloosGoldSourceCounts.miloosGoldInteractionEvents);
}

function addPlatformEvidenceChainGoldSyntheticState(bundle, startedAt) {
  const siteId = 'site-alpha';
  const learnerId = 'learner-alpha';
  const educatorId = 'educator-alpha';
  const parentId = 'parent-alpha';
  const capabilityId = 'capability-prototype-iteration';
  const processDomainId = 'process-domain-evidence-reasoning';
  const sessionId = 'session-future-skills';
  const sessionOccurrenceId = 'session-future-skills';
  const evidenceId = 'evidence-chain-alpha';
  const portfolioItemId = 'portfolio-evidence-chain-alpha';
  const proofBundleId = 'proof-bundle-alpha';
  const rubricTemplateId = 'rubric-template-prototype-iteration';
  const rubricApplicationId = 'rubric-application-alpha';
  const growthEventId = 'growth-event-alpha';
  const processGrowthEventId = 'process-growth-event-alpha';
  const reportShareConsentId = 'report-share-consent-alpha';
  const reportShareRequestId = 'report-share-request-alpha';
  const sourcePack = 'platform-evidence-chain-gold-readiness';
  const routeProofReferences = {
    hqCapabilityFrameworks: {
      route: '/hq/capability-frameworks',
      web: ['src/__tests__/evidence-chain-renderer-wiring.test.ts'],
      serverSynthetic: ['scripts/import_synthetic_data.js', 'test/synthetic_miloos_gold_states.test.js'],
      mobile: [
        'apps/empire_flutter/app/test/hq_authoring_persistence_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_routes_test.dart',
        'apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart',
      ],
    },
    hqRubricBuilder: {
      route: '/hq/rubric-builder',
      web: ['src/__tests__/evidence-chain-renderer-wiring.test.ts'],
      serverSynthetic: ['functions/src/evidenceChainEmulator.test.ts'],
      mobile: [
        'apps/empire_flutter/app/test/hq_authoring_persistence_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_routes_test.dart',
        'apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart',
      ],
    },
    educatorToday: {
      route: '/educator/today',
      web: [
        'src/__tests__/evidence-chain-renderer-wiring.test.ts',
        'test/e2e/mobile-evidence-workflows.e2e.spec.ts',
      ],
      serverSynthetic: ['scripts/import_synthetic_data.js'],
      mobile: [
        'apps/empire_flutter/app/test/educator_today_page_test.dart',
        'apps/empire_flutter/app/test/educator_live_session_mode_test.dart',
      ],
    },
    educatorEvidence: {
      route: '/educator/evidence',
      web: [
        'src/__tests__/evidence-chain-renderer-wiring.test.ts',
        'test/e2e/mobile-evidence-workflows.e2e.spec.ts',
      ],
      serverSynthetic: ['functions/src/evidenceChainEmulator.test.ts'],
      mobile: [
        'apps/empire_flutter/app/test/observation_capture_page_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_routes_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_offline_queue_test.dart',
      ],
    },
    learnerProofAssembly: {
      route: '/learner/proof-assembly',
      web: ['src/__tests__/evidence-chain-renderer-wiring.test.ts'],
      serverSynthetic: ['functions/src/evidenceChainEmulator.test.ts', 'scripts/import_synthetic_data.js'],
      mobile: [
        'apps/empire_flutter/app/test/proof_assembly_page_test.dart',
        'apps/empire_flutter/app/test/sync_coordinator_test.dart',
        'apps/empire_flutter/app/test/mission_proof_bundle_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_routes_test.dart',
      ],
    },
    educatorProofReview: {
      route: '/educator/proof-review',
      web: ['src/__tests__/evidence-chain-renderer-wiring.test.ts'],
      serverSynthetic: ['functions/src/evidenceChainEmulator.test.ts'],
      mobile: [
        'apps/empire_flutter/app/test/proof_verification_page_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_routes_test.dart',
      ],
    },
    educatorRubricApply: {
      route: '/educator/rubrics/apply',
      web: ['test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
      serverSynthetic: ['functions/src/evidenceChainEmulator.test.ts', 'test/synthetic_miloos_gold_states.test.js'],
      mobile: [
        'apps/empire_flutter/app/test/growth_engine_service_test.dart',
        'apps/empire_flutter/app/test/evidence_chain_firestore_service_test.dart',
      ],
    },
    learnerPortfolio: {
      route: '/learner/portfolio',
      web: ['src/__tests__/evidence-chain-renderer-wiring.test.ts', 'test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
      serverSynthetic: ['scripts/import_synthetic_data.js'],
      mobile: ['apps/empire_flutter/app/test/learner_portfolio_honesty_test.dart'],
    },
    parentPassport: {
      route: '/parent/passport',
      web: ['test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
      serverSynthetic: ['functions/src/evidenceChainEmulator.test.ts'],
      mobile: [
        'apps/empire_flutter/app/test/parent_surfaces_workflow_test.dart',
        'apps/empire_flutter/app/test/parent_child_page_test.dart',
        'apps/empire_flutter/app/test/parent_growth_timeline_page_test.dart',
      ],
    },
    siteEvidenceHealth: {
      route: '/site/evidence-health',
      web: ['test/e2e/evidence-chain-cross-role.e2e.spec.ts'],
      serverSynthetic: ['scripts/import_synthetic_data.js'],
      mobile: [
        'apps/empire_flutter/app/test/site_dashboard_page_test.dart',
        'apps/empire_flutter/app/test/site_sessions_page_test.dart',
      ],
    },
  };

  upsertDoc(bundle, 'capabilities', capabilityId, {
    id: capabilityId,
    siteId,
    title: 'Prototype iteration and testing',
    pillarCode: 'FUTURE_SKILLS',
    progressionDescriptor: 'Explains test evidence and chooses the next prototype change.',
    status: 'active',
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'processDomains', processDomainId, {
    id: processDomainId,
    siteId,
    title: 'Evidence reasoning',
    status: 'active',
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'sessions', sessionId, {
    id: sessionId,
    siteId,
    title: 'Skills Studio',
    educatorIds: [educatorId],
    status: 'scheduled',
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'sessionOccurrences', sessionOccurrenceId, {
    id: sessionOccurrenceId,
    siteId,
    sessionId,
    title: 'Skills Studio',
    sessionTitle: 'Skills Studio',
    educatorId,
    startTime: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'evidenceRecords', evidenceId, {
    id: evidenceId,
    siteId,
    learnerId,
    educatorId,
    sessionOccurrenceId,
    capabilityIds: [capabilityId],
    portfolioItemId,
    source: 'educator_observation',
    description: 'Educator observed Learner Alpha comparing prototype test results.',
    capabilityMapped: true,
    rubricStatus: 'applied',
    growthStatus: 'recorded',
    rubricApplicationId,
    createdAt: startedAt,
    observedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'proofOfLearningBundles', proofBundleId, {
    id: proofBundleId,
    siteId,
    learnerId,
    portfolioItemId,
    status: 'verified',
    verificationStatus: 'verified',
    verifiedBy: educatorId,
    verifiedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'portfolioItems', portfolioItemId, {
    id: portfolioItemId,
    siteId,
    learnerId,
    title: 'Robotics Prototype Evidence Pack',
    description: 'Verified proof bundle tied to educator observation and rubric application.',
    mediaType: 'document',
    status: 'published',
    source: 'educator_observation',
    capabilityIds: [capabilityId],
    evidenceRecordIds: [evidenceId],
    missionAttemptId: 'mission-attempt-alpha',
    proofOfLearningStatus: 'verified',
    aiDisclosureStatus: 'learner-ai-not-used',
    proofDetails: {
      explainItBack: true,
      oralCheck: true,
      miniRebuild: true,
      explainItBackExcerpt: 'I changed one variable and used the test evidence to justify the next iteration.',
      oralCheckExcerpt: 'Learner explained why the stronger test result supports the design choice.',
      miniRebuildExcerpt: 'Learner rebuilt the sensor mount from memory and named the tradeoff.',
      educatorVerifierName: 'Educator Alpha',
      proofCheckpointCount: 3,
    },
    reviewedAt: startedAt,
    rubricScore: { raw: 4, max: 4, level: 'Level 4' },
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'rubricTemplates', rubricTemplateId, {
    id: rubricTemplateId,
    siteId,
    title: 'Prototype Iteration Evidence Rubric',
    capabilityIds: [capabilityId],
    criteria: [
      {
        id: 'criterion-prototype-iteration',
        label: 'Uses test evidence to choose the next prototype change',
        capabilityId,
        processDomainId,
        pillarCode: 'FUTURE_SKILLS',
        maxScore: 4,
        descriptors: {
          beginning: 'Names a prototype change with limited evidence connection.',
          developing: 'Connects a prototype change to one test observation.',
          proficient: 'Uses test evidence to justify a practical next iteration.',
          advanced: 'Compares test evidence, tradeoffs, and next iteration choices clearly.',
        },
      },
    ],
    status: 'published',
    createdBy: 'hq-alpha',
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'rubricApplications', rubricApplicationId, {
    id: rubricApplicationId,
    siteId,
    learnerId,
    educatorId,
    portfolioItemId,
    rubricId: rubricTemplateId,
    evidenceRecordIds: [evidenceId],
    capabilityScores: [{ capabilityId, score: 4, maxScore: 4 }],
    status: 'applied',
    createdAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'capabilityMastery', `mastery-${learnerId}-${capabilityId}`, {
    id: `mastery-${learnerId}-${capabilityId}`,
    siteId,
    learnerId,
    capabilityId,
    currentLevel: 4,
    highestLevel: 4,
    evidenceCount: 1,
    rubricScore: { raw: 4, max: 4 },
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
    interpretationOwner: 'server',
  });
  upsertDoc(bundle, 'processDomainMastery', `process-mastery-${learnerId}-${processDomainId}`, {
    id: `process-mastery-${learnerId}-${processDomainId}`,
    siteId,
    learnerId,
    processDomainId,
    title: 'Evidence reasoning',
    currentLevel: 'Level 4',
    highestLevel: 'Level 4',
    evidenceCount: 1,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
    interpretationOwner: 'server',
  });
  upsertDoc(bundle, 'capabilityGrowthEvents', growthEventId, {
    id: growthEventId,
    siteId,
    learnerId,
    capabilityId,
    capabilityTitle: 'Prototype iteration and testing',
    levelAchieved: 'Level 4',
    educatorId,
    educatorName: 'Educator Alpha',
    linkedEvidenceCount: 1,
    linkedPortfolioCount: 1,
    linkedEvidenceRecordIds: [evidenceId],
    linkedPortfolioItemIds: [portfolioItemId],
    missionAttemptId: 'mission-attempt-alpha',
    rubricScore: { raw: 4, max: 4 },
    createdAt: startedAt,
    date: startedAt,
    synthetic: true,
    sourcePack,
    interpretationOwner: 'server',
  });
  upsertDoc(bundle, 'processDomainGrowthEvents', processGrowthEventId, {
    id: processGrowthEventId,
    siteId,
    learnerId,
    processDomainId,
    processDomainTitle: 'Evidence reasoning',
    fromLevel: 'Level 3',
    toLevel: 'Level 4',
    educatorName: 'Educator Alpha',
    evidenceCount: 1,
    createdAt: startedAt,
    date: startedAt,
    synthetic: true,
    sourcePack,
    interpretationOwner: 'server',
  });
  upsertDoc(bundle, 'reportShareConsents', reportShareConsentId, {
    id: reportShareConsentId,
    siteId,
    learnerId,
    requesterId: educatorId,
    requesterRole: 'educator',
    approverId: parentId,
    approverRole: 'parent',
    status: 'granted',
    scope: 'external',
    audience: 'external',
    visibility: 'external',
    purpose: 'Share verified evidence-chain passport with an approved external reviewer.',
    evidenceSummary: 'Verified proof bundle, rubric application, portfolio item, and server-owned growth only.',
    linkedReportShareRequestIds: [reportShareRequestId],
    requestedAt: startedAt,
    decidedAt: startedAt,
    expiresAt: startedAt,
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'reportShareRequests', reportShareRequestId, {
    id: reportShareRequestId,
    siteId,
    learnerId,
    createdBy: educatorId,
    createdByRole: 'educator',
    status: 'active',
    reportAction: 'share',
    reportDelivery: 'shared',
    audience: 'external',
    visibility: 'external',
    source: 'passport',
    surface: 'platform_gold_route_matrix',
    cta: 'canonical_external_share_after_granted_consent',
    fileName: 'learner-alpha-evidence-chain-passport.txt',
    explicitConsentId: reportShareConsentId,
    sharePolicy: {
      requiresEvidenceProvenance: true,
      requiresGuardianContext: true,
      allowsExternalSharing: true,
      includesLearnerIdentifiers: true,
    },
    provenance: {
      expectedSignals: ['evidence', 'proof', 'rubric', 'growth', 'portfolio', 'consent'],
      missingSignals: [],
      meetsProvenanceContract: true,
      meetsDeliveryContract: true,
      sharePolicyDeclared: true,
    },
    expiresAt: startedAt,
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });

  const platformEvidenceChainSourceCounts = {
    platformEvidenceChainCapabilities: 1,
    platformEvidenceChainProcessDomains: 1,
    platformEvidenceChainSessions: 1,
    platformEvidenceChainSessionOccurrences: 1,
    platformEvidenceChainEvidenceRecords: 1,
    platformEvidenceChainProofBundles: 1,
    platformEvidenceChainPortfolioItems: 1,
    platformEvidenceChainRubricTemplates: 1,
    platformEvidenceChainRubricApplications: 1,
    platformEvidenceChainMasteryRecords: 2,
    platformEvidenceChainGrowthEvents: 2,
    platformEvidenceChainReportShareConsents: 1,
    platformEvidenceChainReportShareRequests: 1,
  };

  upsertDoc(bundle, 'syntheticPlatformEvidenceChainGoldStates', 'latest', {
    id: 'latest',
    siteId,
    modeSupport: ['starter', 'full', 'all'],
    ids: {
      learnerId,
      educatorId,
      parentId,
      capabilityId,
      processDomainId,
      sessionId,
      sessionOccurrenceId,
      evidenceId,
      portfolioItemId,
      proofBundleId,
      rubricTemplateId,
      rubricApplicationId,
      growthEventId,
      processGrowthEventId,
      reportShareConsentId,
      reportShareRequestId,
    },
    routeProofReferences,
    usage: 'Use this canonical state for the platform HQ-to-passport evidence-chain certification path.',
    evidenceChain: 'HQ setup -> educator evidence -> proof -> rubric -> server-owned growth -> portfolio -> guardian passport -> site evidence health',
    serverOwnedGrowth: true,
    noClientMasteryWrites: true,
    sourceCounts: platformEvidenceChainSourceCounts,
    synthetic: true,
    sourcePack,
    importedAt: startedAt,
  });

  Object.entries(platformEvidenceChainSourceCounts).forEach(([key, value]) => {
    incrementCount(bundle.sourceCounts, key, value);
  });
}

function addCutoverDashboardReadinessSyntheticData(bundle, startedAt) {
  const sourcePack = 'cutover-dashboard-readiness';
  const siteId = 'pilot-site-001';
  const learnerId = 'test-learner-001';
  const educatorId = 'test-educator-001';
  const sessionId = 'pilot-session-001';
  const sessionOccurrenceId = 'synthetic-dashboard-occurrence-001';
  const evidenceId = 'synthetic-dashboard-evidence-prototype-iteration';
  const portfolioItemId = 'synthetic-dashboard-portfolio-prototype-iteration';
  const proofBundleId = 'synthetic-dashboard-proof-prototype-iteration';
  const rubricTemplateId = 'synthetic-dashboard-rubric-prototype-iteration';
  const rubricApplicationId = 'synthetic-dashboard-rubric-application-prototype-iteration';
  const missionAttemptId = 'synthetic-dashboard-mission-attempt-prototype-iteration';
  const capabilityDocs = [
    {
      id: 'pilot-capability-prototype-iteration',
      name: 'Prototype Iteration',
      title: 'Prototype Iteration',
      normalizedTitle: 'prototype iteration',
      domain: 'technical',
      pillarCode: 'tech',
      description: 'Improve a working prototype using feedback and observed evidence.',
      descriptor: 'Learner can improve a build from evidence rather than preference.',
      sortOrder: 10,
    },
    {
      id: 'pilot-capability-evidence-explanation',
      name: 'Evidence Explanation',
      title: 'Evidence Explanation',
      normalizedTitle: 'evidence explanation',
      domain: 'human',
      pillarCode: 'lead',
      description: 'Explain what evidence proves and what still needs verification.',
      descriptor: 'Learner can explain how their artifact proves progress.',
      sortOrder: 20,
    },
    {
      id: 'pilot-capability-impact-check',
      name: 'Impact Check',
      title: 'Impact Check',
      normalizedTitle: 'impact check',
      domain: 'human',
      pillarCode: 'impact',
      description: 'Connect a build decision to the user or community it affects.',
      descriptor: 'Learner can describe who benefits and what evidence supports that claim.',
      sortOrder: 30,
    },
  ];
  const progressionDescriptors = {
    beginning: 'Can identify one change they made when prompted.',
    developing: 'Can explain a change using feedback or observed evidence.',
    proficient: 'Can independently improve a prototype and explain the evidence behind the change.',
    advanced: 'Can coach peers on using evidence to make better build decisions.',
  };

  for (const capability of capabilityDocs) {
    upsertDoc(bundle, 'capabilities', capability.id, {
      ...capability,
      siteId,
      progressionDescriptors,
      status: 'active',
      unitMappings: [sessionId],
      checkpointMappings: [{ checkpointId: 'pilot-checkpoint-prototype-demo', weight: 1 }],
      teacherLookFors: [
        'Names the evidence that motivated the change.',
        'Explains what improved between versions.',
        'Identifies a next test or user signal.',
      ],
      createdAt: startedAt,
      updatedAt: startedAt,
      synthetic: true,
      sourcePack,
    });
  }

  upsertDoc(bundle, 'coppaSchoolConsents', siteId, {
    id: siteId,
    siteId,
    active: true,
    agreementSigned: true,
    educationalUseOnly: true,
    parentNoticeProvided: true,
    noStudentMarketing: true,
    consentSource: 'synthetic-cutover-dashboard-readiness',
    signedBy: educatorId,
    signedAt: startedAt,
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });

  upsertDoc(bundle, 'sessionOccurrences', sessionOccurrenceId, {
    id: sessionOccurrenceId,
    sessionId,
    siteId,
    educatorId,
    educatorIds: [educatorId],
    learnerIds: [learnerId],
    title: 'Synthetic Dashboard Evidence Studio',
    startsAt: startedAt,
    endsAt: startedAt,
    status: 'completed',
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'evidenceRecords', evidenceId, {
    id: evidenceId,
    learnerId,
    educatorId,
    siteId,
    sessionOccurrenceId,
    capabilityId: 'pilot-capability-prototype-iteration',
    capabilityMapped: true,
    phaseKey: 'build.iterate',
    description: 'Learner revised a Scratch game after peer testing and explained the evidence behind the change.',
    rubricStatus: 'applied',
    growthStatus: 'recorded',
    portfolioCandidate: true,
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'rubricTemplates', rubricTemplateId, {
    id: rubricTemplateId,
    siteId,
    title: 'Prototype Iteration Evidence Rubric',
    name: 'Prototype Iteration Evidence Rubric',
    capabilityIds: capabilityDocs.map((capability) => capability.id),
    criteria: capabilityDocs.map((capability, index) => ({
      id: `${capability.id}-criterion`,
      criterionId: `${capability.id}-criterion`,
      capabilityId: capability.id,
      label: capability.title,
      description: capability.description,
      maxScore: 4,
      sortOrder: index + 1,
    })),
    status: 'published',
    createdBy: educatorId,
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'rubricApplications', rubricApplicationId, {
    id: rubricApplicationId,
    learnerId,
    educatorId,
    siteId,
    rubricTemplateId,
    evidenceRecordIds: [evidenceId],
    missionAttemptId,
    capabilityId: 'pilot-capability-prototype-iteration',
    scores: [
      { criterionId: 'pilot-capability-prototype-iteration-criterion', capabilityId: 'pilot-capability-prototype-iteration', score: 3 },
      { criterionId: 'pilot-capability-evidence-explanation-criterion', capabilityId: 'pilot-capability-evidence-explanation', score: 2 },
      { criterionId: 'pilot-capability-impact-check-criterion', capabilityId: 'pilot-capability-impact-check', score: 2 },
    ],
    status: 'growth-recorded',
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'proofOfLearningBundles', proofBundleId, {
    id: proofBundleId,
    learnerId,
    siteId,
    portfolioItemId,
    capabilityId: 'pilot-capability-prototype-iteration',
    hasExplainItBack: true,
    hasOralCheck: true,
    hasMiniRebuild: true,
    explainItBackExcerpt: 'I changed the enemy speed because two testers got stuck in the first ten seconds.',
    oralCheckExcerpt: 'Learner explained the bug, the evidence, and why the next test should isolate one variable.',
    miniRebuildExcerpt: 'Learner rebuilt the loop condition live and narrated the fix without prompts.',
    verificationStatus: 'verified',
    educatorVerifierId: educatorId,
    version: 1,
    createdAt: startedAt,
    updatedAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'portfolioItems', portfolioItemId, {
    id: portfolioItemId,
    learnerId,
    siteId,
    title: 'Scratch Game Iteration Evidence',
    description: 'Before/after prototype evidence with learner explanation and educator verification.',
    pillarCodes: ['tech', 'lead', 'impact'],
    artifacts: ['https://example.scholesa.dev/synthetic/scratch-game-iteration.png'],
    evidenceRecordIds: [evidenceId],
    capabilityIds: capabilityDocs.map((capability) => capability.id),
    capabilityTitles: capabilityDocs.map((capability) => capability.title),
    growthEventIds: [
      'synthetic-dashboard-growth-prototype-iteration',
      'synthetic-dashboard-growth-evidence-explanation',
      'synthetic-dashboard-growth-impact-check',
    ],
    missionAttemptId,
    rubricApplicationId,
    proofBundleId,
    proofOfLearningStatus: 'verified',
    proofHasExplainItBack: true,
    proofHasOralCheck: true,
    proofHasMiniRebuild: true,
    proofCheckpointCount: 3,
    proofExplainItBackExcerpt: 'I changed the enemy speed because two testers got stuck in the first ten seconds.',
    proofOralCheckExcerpt: 'Explained the bug and evidence behind the change.',
    proofMiniRebuildExcerpt: 'Rebuilt the loop condition live.',
    aiAssistanceUsed: true,
    aiAssistanceDetails: 'AI suggested debug questions; learner selected and implemented the fix independently.',
    aiDisclosureStatus: 'learner-ai-verified',
    educatorId,
    verificationPrompt: 'Explain why this iteration improved the game for a tester.',
    verificationNotes: 'Verified through explain-it-back, oral check, and mini rebuild.',
    verificationStatus: 'verified',
    source: 'synthetic-cutover-dashboard-readiness',
    createdAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'missionAttempts', missionAttemptId, {
    id: missionAttemptId,
    learnerId,
    missionId: 'pilot-mission-001',
    missionTitle: 'Build a Scratch Game',
    sessionOccurrenceId,
    siteId,
    status: 'in_progress',
    content: 'Iteration in progress with verified proof already attached to the portfolio item.',
    notes: 'Synthetic cutover dashboard mission slice; not a mastery shortcut.',
    attachmentUrls: ['https://example.scholesa.dev/synthetic/scratch-game-iteration.png'],
    startedAt: startedAt,
    submittedAt: startedAt,
    updatedAt: startedAt,
    proofBundleId,
    aiAssistanceUsed: true,
    aiAssistanceDetails: 'AI debug prompts disclosed and verified through proof-of-learning.',
    aiDisclosureStatus: 'learner-ai-verified',
    synthetic: true,
    sourcePack,
  });

  const masteryRows = [
    ['pilot-capability-prototype-iteration', 'tech', 'proficient', 'developing', ['synthetic-dashboard-growth-prototype-iteration'], 3, 4],
    ['pilot-capability-evidence-explanation', 'lead', 'developing', 'emerging', ['synthetic-dashboard-growth-evidence-explanation'], 2, 4],
    ['pilot-capability-impact-check', 'impact', 'developing', 'emerging', ['synthetic-dashboard-growth-impact-check'], 2, 4],
  ];
  for (const [capabilityId, pillarCode, level, previousLevel, growthIds, rawScore, maxScore] of masteryRows) {
    const growthEventId = growthIds[0];
    upsertDoc(bundle, 'capabilityMastery', `${learnerId}_${capabilityId}`, {
      id: `${learnerId}_${capabilityId}`,
      learnerId,
      capabilityId,
      pillarCode,
      currentLevel: level,
      latestLevel: level,
      previousLevel,
      evidenceCount: 1,
      evidenceIds: [evidenceId],
      lastAssessedBy: educatorId,
      lastAssessedAt: startedAt,
      updatedAt: startedAt,
      synthetic: true,
      sourcePack,
    });
    upsertDoc(bundle, 'capabilityGrowthEvents', growthEventId, {
      id: growthEventId,
      learnerId,
      capabilityId,
      level,
      fromLevel: previousLevel,
      toLevel: level,
      educatorId,
      siteId,
      rubricApplicationId,
      evidenceIds: [evidenceId],
      linkedEvidenceRecordIds: [evidenceId],
      linkedPortfolioItemIds: [portfolioItemId],
      rawScore,
      maxScore,
      createdAt: startedAt,
      synthetic: true,
      sourcePack,
      interpretationOwner: 'server',
    });
  }

  upsertDoc(bundle, 'orchestrationStates', 'synthetic-dashboard-state-current', {
    id: 'synthetic-dashboard-state-current',
    siteId,
    learnerId,
    x_hat: { cognition: 0.78, engagement: 0.74, integrity: 0.88 },
    lastUpdatedAt: startedAt,
    createdAt: startedAt,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'orchestrationStates', 'synthetic-dashboard-state-baseline', {
    id: 'synthetic-dashboard-state-baseline',
    siteId,
    learnerId,
    x_hat: { cognition: 0.62, engagement: 0.58, integrity: 0.81 },
    lastUpdatedAt: new Date(startedAt.getTime() - 7 * 24 * 60 * 60 * 1000),
    createdAt: new Date(startedAt.getTime() - 7 * 24 * 60 * 60 * 1000),
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'interactionEvents', 'synthetic-dashboard-ai-help-opened', {
    id: 'synthetic-dashboard-ai-help-opened',
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'ai_help_opened',
    mode: 'debug_prompt',
    studentInput: 'Why does my enemy sprite freeze after the first collision?',
    createdAt: startedAt,
    timestamp: startedAt,
    payload: { mode: 'debug_prompt', capabilityId: 'pilot-capability-prototype-iteration' },
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'interactionEvents', 'synthetic-dashboard-ai-help-used', {
    id: 'synthetic-dashboard-ai-help-used',
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'ai_help_used',
    interactionId: 'synthetic-dashboard-ai-help-opened',
    createdAt: startedAt,
    timestamp: startedAt,
    payload: { learnerChange: 'Learner changed the loop condition and retested with peers.' },
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'interactionEvents', 'synthetic-dashboard-explain-back', {
    id: 'synthetic-dashboard-explain-back',
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'explain_it_back_submitted',
    interactionId: 'synthetic-dashboard-ai-help-opened',
    aiHelpOpenedEventId: 'synthetic-dashboard-ai-help-opened',
    createdAt: startedAt,
    timestamp: startedAt,
    payload: { aiHelpOpenedEventId: 'synthetic-dashboard-ai-help-opened' },
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'interactionEvents', 'synthetic-dashboard-goal-updated', {
    id: 'synthetic-dashboard-goal-updated',
    siteId,
    actorId: learnerId,
    learnerId,
    eventType: 'ai_learning_goal_updated',
    createdAt: startedAt,
    timestamp: startedAt,
    payload: { latest_goal: 'Use tester evidence before changing game difficulty.' },
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'mvlEpisodes', 'synthetic-dashboard-mvl-active', {
    id: 'synthetic-dashboard-mvl-active',
    siteId,
    learnerId,
    createdAt: startedAt,
    triggerReason: 'ai_dependency_verification',
    evidenceRecordId: evidenceId,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'mvlEpisodes', 'synthetic-dashboard-mvl-passed', {
    id: 'synthetic-dashboard-mvl-passed',
    siteId,
    learnerId,
    createdAt: startedAt,
    resolution: 'passed',
    evidenceRecordId: evidenceId,
    synthetic: true,
    sourcePack,
  });
  upsertDoc(bundle, 'mvlEpisodes', 'synthetic-dashboard-mvl-needs-review', {
    id: 'synthetic-dashboard-mvl-needs-review',
    siteId,
    learnerId,
    createdAt: startedAt,
    resolution: 'failed',
    evidenceRecordId: evidenceId,
    synthetic: true,
    sourcePack,
  });

  const sourceCounts = {
    cutoverDashboardCoppaSchoolConsents: 1,
    cutoverDashboardCapabilities: capabilityDocs.length,
    cutoverDashboardSessionOccurrences: 1,
    cutoverDashboardEvidenceRecords: 1,
    cutoverDashboardProofBundles: 1,
    cutoverDashboardPortfolioItems: 1,
    cutoverDashboardRubricTemplates: 1,
    cutoverDashboardRubricApplications: 1,
    cutoverDashboardMissionAttempts: 1,
    cutoverDashboardMasteryRecords: masteryRows.length,
    cutoverDashboardGrowthEvents: masteryRows.length,
    cutoverDashboardOrchestrationStates: 2,
    cutoverDashboardInteractionEvents: 4,
    cutoverDashboardMvlEpisodes: 3,
  };
  upsertDoc(bundle, 'syntheticDashboardReadinessStates', 'latest', {
    id: 'latest',
    siteId,
    learnerId,
    educatorId,
    modeSupport: ['starter', 'full', 'all'],
    purpose: 'Live learner dashboard readiness slice with evidence-backed growth, portfolio proof, mission activity, and MiloOS learner-loop signals.',
    ids: {
      sessionOccurrenceId,
      evidenceId,
      portfolioItemId,
      proofBundleId,
      rubricTemplateId,
      rubricApplicationId,
      missionAttemptId,
      capabilityIds: capabilityDocs.map((capability) => capability.id),
    },
    evidenceChain: 'educator evidence -> proof bundle -> rubric application -> server-owned growth events -> portfolio item -> learner dashboard -> MiloOS support snapshot',
    sourceCounts,
    serverOwnedGrowth: true,
    noClientMasteryWrites: true,
    synthetic: true,
    sourcePack,
    importedAt: startedAt,
  });
  Object.entries(sourceCounts).forEach(([key, value]) => {
    incrementCount(bundle.sourceCounts, key, value);
  });
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
  addPlatformEvidenceChainGoldSyntheticState(bundle, startedAt);
  addCutoverDashboardReadinessSyntheticData(bundle, startedAt);

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
    platformEvidenceChainGoldState: {
      collection: 'syntheticPlatformEvidenceChainGoldStates',
      documentId: 'latest',
      seedModes: ['starter', 'full', 'all'],
      purpose: 'Platform HQ-to-passport evidence-chain certification without local browser-only fixtures.',
    },
    dashboardReadinessState: {
      collection: 'syntheticDashboardReadinessStates',
      documentId: 'latest',
      seedModes: ['starter', 'full', 'all'],
      purpose: 'Live learner dashboard cutover proof for test-learner-001 at pilot-site-001.',
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
    await writeBundleToFirestoreRest(bundle, batchSize);
    return admin;
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

function encodeDocumentPath(...segments) {
  return segments.map((segment) => encodeURIComponent(String(segment))).join('/');
}

function encodeFirestoreValue(value) {
  if (typeof value === 'undefined' || value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map((entry) => encodeFirestoreValue(entry)) } };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (value && typeof value === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value)
            .filter(([, entry]) => typeof entry !== 'undefined')
            .map(([key, entry]) => [key, encodeFirestoreValue(entry)]),
        ),
      },
    };
  }
  return { stringValue: String(value) };
}

function buildRestWrite(projectId, collectionName, id, data) {
  const fieldEntries = Object.entries(data || {}).filter(([, value]) => typeof value !== 'undefined');
  return {
    update: {
      name: `projects/${projectId}/databases/(default)/documents/${encodeDocumentPath(collectionName, id)}`,
      fields: Object.fromEntries(fieldEntries.map(([key, value]) => [key, encodeFirestoreValue(value)])),
    },
    updateMask: {
      fieldPaths: fieldEntries.map(([key]) => key),
    },
  };
}

async function writeBundleToFirestoreRest(bundle, batchSize) {
  const projectId = resolveProjectId(process.env.FIREBASE_PROJECT_ID, null);
  if (!projectId) {
    throw new Error('Unable to resolve project ID for gcloud-auth synthetic import.');
  }
  const accessToken = getGcloudAccessToken();
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:batchWrite`;
  const maxBatchSize = Math.min(batchSize, 500);
  for (const [collectionName, docs] of bundle.collections.entries()) {
    const entries = Array.from(docs.entries());
    for (let index = 0; index < entries.length; index += maxBatchSize) {
      const slice = entries.slice(index, index + maxBatchSize);
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'x-goog-user-project': projectId,
        },
        body: JSON.stringify({
          writes: slice.map(([id, data]) => buildRestWrite(projectId, collectionName, id, data)),
        }),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        const message = payload?.error?.message || `${response.status} ${response.statusText}`;
        throw new Error(`Synthetic Firestore REST import failed for ${collectionName}: ${message}`);
      }
      console.log(`Committed ${collectionName} REST batch ${Math.floor(index / maxBatchSize) + 1} (${slice.length} docs)`);
    }
  }
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