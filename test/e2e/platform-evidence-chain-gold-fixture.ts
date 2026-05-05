import { buildImportBundle } from '../../scripts/import_synthetic_data';

type CollectionRecord = Record<string, unknown>;

type CanonicalBundle = {
  collections: Map<string, Map<string, CollectionRecord>>;
};

type PlatformEvidenceChainManifest = {
  siteId: string;
  ids: Record<string, string>;
  routeProofReferences: Record<
    string,
    {
      route: string;
      web: string[];
      serverSynthetic: string[];
      mobile: string[];
    }
  >;
  serverOwnedGrowth: boolean;
  noClientMasteryWrites: boolean;
};

export const PLATFORM_EVIDENCE_CHAIN_GOLD_IDS = {
  learnerId: 'learner-alpha',
  educatorId: 'educator-alpha',
  parentId: 'parent-alpha',
  siteAdminId: 'site-alpha-admin',
  siteId: 'site-alpha',
  capabilityId: 'capability-prototype-iteration',
  evidenceId: 'evidence-chain-alpha',
  portfolioItemId: 'portfolio-evidence-chain-alpha',
  proofBundleId: 'proof-bundle-alpha',
  rubricApplicationId: 'rubric-application-alpha',
  growthEventId: 'growth-event-alpha',
} as const;

function collectionMap(bundle: CanonicalBundle, name: string): Map<string, CollectionRecord> {
  return bundle.collections.get(name) || new Map<string, CollectionRecord>();
}

function manifestFor(bundle: CanonicalBundle): PlatformEvidenceChainManifest {
  const manifest = collectionMap(bundle, 'syntheticPlatformEvidenceChainGoldStates').get('latest');
  if (!manifest) {
    throw new Error('Missing syntheticPlatformEvidenceChainGoldStates/latest in canonical platform bundle.');
  }
  return manifest as PlatformEvidenceChainManifest;
}

function cloneForBrowser<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function requiredDoc(
  bundle: CanonicalBundle,
  collectionName: string,
  documentId: string
): CollectionRecord {
  const doc = collectionMap(bundle, collectionName).get(documentId);
  if (!doc) {
    throw new Error(`Missing ${collectionName}/${documentId} in canonical platform evidence-chain bundle.`);
  }
  return cloneForBrowser(doc);
}

export function canonicalPlatformEvidenceChainGoldRecords(): Record<string, CollectionRecord[]> {
  const bundle = buildImportBundle({ mode: 'starter' }) as CanonicalBundle;
  const manifest = manifestFor(bundle);
  const { ids } = manifest;

  if (
    manifest.siteId !== PLATFORM_EVIDENCE_CHAIN_GOLD_IDS.siteId ||
    manifest.serverOwnedGrowth !== true ||
    manifest.noClientMasteryWrites !== true
  ) {
    throw new Error('Canonical platform evidence-chain manifest no longer matches web E2E expectations.');
  }

  return {
    capabilities: [requiredDoc(bundle, 'capabilities', ids.capabilityId)],
    processDomains: [requiredDoc(bundle, 'processDomains', ids.processDomainId)],
    evidenceRecords: [requiredDoc(bundle, 'evidenceRecords', ids.evidenceId)],
    proofOfLearningBundles: [requiredDoc(bundle, 'proofOfLearningBundles', ids.proofBundleId)],
    portfolioItems: [requiredDoc(bundle, 'portfolioItems', ids.portfolioItemId)],
    rubricApplications: [requiredDoc(bundle, 'rubricApplications', ids.rubricApplicationId)],
    capabilityMastery: [
      requiredDoc(bundle, 'capabilityMastery', `mastery-${ids.learnerId}-${ids.capabilityId}`),
    ],
    processDomainMastery: [
      requiredDoc(bundle, 'processDomainMastery', `process-mastery-${ids.learnerId}-${ids.processDomainId}`),
    ],
    capabilityGrowthEvents: [requiredDoc(bundle, 'capabilityGrowthEvents', ids.growthEventId)],
    processDomainGrowthEvents: [
      requiredDoc(bundle, 'processDomainGrowthEvents', ids.processGrowthEventId),
    ],
    reportShareConsents: [
      requiredDoc(bundle, 'reportShareConsents', ids.reportShareConsentId),
    ],
    reportShareRequests: [
      requiredDoc(bundle, 'reportShareRequests', ids.reportShareRequestId),
    ],
  };
}

export function canonicalPlatformEvidenceChainRouteProofReferences() {
  const bundle = buildImportBundle({ mode: 'starter' }) as CanonicalBundle;
  const manifest = manifestFor(bundle);

  return cloneForBrowser(manifest.routeProofReferences);
}