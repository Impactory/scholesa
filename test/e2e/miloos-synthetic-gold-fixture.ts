import type { Page } from '@playwright/test';
import { buildImportBundle } from '../../scripts/import_synthetic_data';

export const WEB_MILOOS_SYNTHETIC_IDS = {
  siteId: 'site-alpha',
  otherSiteId: 'site-beta',
  pendingExplainBackLearnerId: 'learner-alpha',
  supportCurrentLearnerId: 'learner-beta',
  crossSiteDenialLearnerId: 'learner-alpha',
  missingSiteDenialLearnerId: 'learner-beta',
} as const;

type CanonicalBundle = {
  collections: Map<string, Map<string, Record<string, unknown>>>;
  summary?: {
    sourceCounts?: Record<string, number>;
  };
};

type CanonicalSyntheticManifest = {
  siteId: string;
  sourcePack?: string;
  states: Record<string, string>;
  noMasteryWrites: boolean;
  modeSupport?: string[];
  usage?: string;
};

type MiloOSGoldWebSeed = {
  interactionEvents: Array<Record<string, unknown>>;
  syntheticStates: Array<Record<string, unknown>>;
};

function collectionMap(bundle: CanonicalBundle, name: string): Map<string, Record<string, unknown>> {
  return bundle.collections.get(name) || new Map<string, Record<string, unknown>>();
}

function canonicalManifest(bundle: CanonicalBundle): CanonicalSyntheticManifest {
  const manifest = collectionMap(bundle, 'syntheticMiloOSGoldStates').get('latest');
  if (!manifest) {
    throw new Error('Missing syntheticMiloOSGoldStates/latest in canonical MiloOS bundle.');
  }
  return manifest as unknown as CanonicalSyntheticManifest;
}

function timestampIso(value: unknown): string | undefined {
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    return value;
  }
  return undefined;
}

function mappedSiteId(siteId: unknown): string | null {
  if (siteId === 'synthetic-site-miloos-gold') {
    return WEB_MILOOS_SYNTHETIC_IDS.siteId;
  }
  if (siteId === 'synthetic-site-miloos-other') {
    return WEB_MILOOS_SYNTHETIC_IDS.otherSiteId;
  }
  return null;
}

function mappedLearnerId(learnerId: unknown, manifest: CanonicalSyntheticManifest): string {
  switch (learnerId) {
    case manifest.states.pendingExplainBackLearnerId:
      return WEB_MILOOS_SYNTHETIC_IDS.pendingExplainBackLearnerId;
    case manifest.states.supportCurrentLearnerId:
      return WEB_MILOOS_SYNTHETIC_IDS.supportCurrentLearnerId;
    case manifest.states.crossSiteDenialLearnerId:
      return WEB_MILOOS_SYNTHETIC_IDS.crossSiteDenialLearnerId;
    case manifest.states.missingSiteDenialLearnerId:
      return WEB_MILOOS_SYNTHETIC_IDS.missingSiteDenialLearnerId;
    default:
      return String(learnerId || 'unknown-learner');
  }
}

function interactionIdFor(event: Record<string, unknown>): string | undefined {
  const payload = event.payload as Record<string, unknown> | undefined;
  const payloadOpenedId = payload?.aiHelpOpenedEventId;
  if (typeof payloadOpenedId === 'string' && payloadOpenedId.trim().length > 0) {
    return payloadOpenedId;
  }
  const traceId = event.traceId;
  if (typeof traceId === 'string' && traceId.trim().length > 0) {
    return traceId;
  }
  return undefined;
}

export function canonicalMiloOSGoldWebEvents(): Array<Record<string, unknown>> {
  return canonicalMiloOSGoldWebSeed().interactionEvents;
}

export function canonicalMiloOSGoldWebSeed(): MiloOSGoldWebSeed {
  const bundle = buildImportBundle({ mode: 'starter' }) as CanonicalBundle;
  const manifest = canonicalManifest(bundle);
  const interactionEvents = collectionMap(bundle, 'interactionEvents');

  if (manifest.siteId !== 'synthetic-site-miloos-gold' || manifest.noMasteryWrites !== true) {
    throw new Error('Canonical MiloOS synthetic manifest no longer matches web E2E expectations.');
  }

  const mappedStates = {
    ...manifest.states,
    pendingExplainBackLearnerId: WEB_MILOOS_SYNTHETIC_IDS.pendingExplainBackLearnerId,
    supportCurrentLearnerId: WEB_MILOOS_SYNTHETIC_IDS.supportCurrentLearnerId,
    crossSiteDenialLearnerId: WEB_MILOOS_SYNTHETIC_IDS.crossSiteDenialLearnerId,
    missingSiteDenialLearnerId: WEB_MILOOS_SYNTHETIC_IDS.missingSiteDenialLearnerId,
  };

  const syntheticStates = [{
    id: 'latest',
    siteId: WEB_MILOOS_SYNTHETIC_IDS.siteId,
    sourcePack: manifest.sourcePack || 'miloos-gold-readiness',
    noMasteryWrites: manifest.noMasteryWrites,
    states: mappedStates,
    sourceCounts: bundle.summary?.sourceCounts,
    modeSupport: manifest.modeSupport,
    usage: manifest.usage,
  }];

  const mappedEvents = Array.from(interactionEvents.entries()).map(([id, event]) => {
    const learnerId = mappedLearnerId(event.learnerId ?? event.actorId, manifest);
    const timestamp = timestampIso(event.timestamp) || timestampIso(event.createdAt);
    const payload = event.payload as Record<string, unknown> | undefined;
    return {
      id,
      siteId: mappedSiteId(event.siteId),
      actorId: learnerId,
      learnerId,
      eventType: event.eventType,
      interactionId: interactionIdFor(event),
      timestamp,
      createdAt: timestamp,
      mode: typeof payload?.mode === 'string' ? payload.mode : undefined,
    };
  });

  return {
    interactionEvents: mappedEvents,
    syntheticStates,
  };
}

export async function seedCanonicalMiloOSGoldWebState(page: Page): Promise<void> {
  await page.evaluate((seed) => {
    const harness = (window as Window & {
      __scholesaE2E?: {
        seedInteractionEvents: (events: Array<Record<string, unknown>>) => void;
        seedSyntheticMiloOSGoldStates?: (records: Array<Record<string, unknown>>) => void;
      };
    }).__scholesaE2E;

    harness?.seedSyntheticMiloOSGoldStates?.(seed.syntheticStates);
    harness?.seedInteractionEvents(seed.interactionEvents);
  }, canonicalMiloOSGoldWebSeed());
}
