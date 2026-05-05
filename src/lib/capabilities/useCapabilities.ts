'use client';

import { useCallback, useEffect, useState } from 'react';
import { getDocs, query, where } from 'firebase/firestore';
import { capabilitiesCollection } from '@/src/firebase/firestore/collections';
import type { Capability } from '@/src/types/schema';

/**
 * Client-side cache of capability entities for a site.
 * Replaces the pattern of storing denormalized capabilityTitles[] on every document.
 * Load once per session and resolve titles by ID.
 */

const siteCapabilityCache = new Map<string, Map<string, Capability>>();

export async function loadCapabilitiesForSite(siteId: string): Promise<Map<string, Capability>> {
  const cached = siteCapabilityCache.get(siteId);
  if (cached) return cached;

  if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
    const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
    const map = new Map<string, Capability>();
    getE2ECollection('capabilities')
      .filter((record) => record.siteId === siteId)
      .forEach((record) => {
        map.set(String(record.id), { ...record, id: String(record.id) } as unknown as Capability);
      });
    siteCapabilityCache.set(siteId, map);
    return map;
  }

  const snap = await getDocs(query(capabilitiesCollection, where('siteId', '==', siteId)));
  const map = new Map<string, Capability>();
  for (const doc of snap.docs) {
    map.set(doc.id, { ...doc.data(), id: doc.id });
  }
  siteCapabilityCache.set(siteId, map);
  return map;
}

export function resolveCapabilityTitle(
  capabilityId: string,
  capabilities: Map<string, Capability>
): string {
  return capabilities.get(capabilityId)?.title ?? capabilityId;
}

export function resolveCapabilityTitles(
  capabilityIds: string[],
  capabilities: Map<string, Capability>
): string[] {
  return capabilityIds.map((id) => resolveCapabilityTitle(id, capabilities));
}

export function invalidateCapabilityCache(siteId: string): void {
  siteCapabilityCache.delete(siteId);
}

/**
 * React hook to load and cache capabilities for a site.
 * Returns the capability map and a title resolver function.
 */
export function useCapabilities(siteId: string | null) {
  const [capabilities, setCapabilities] = useState<Map<string, Capability>>(new Map());
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!siteId) return;
    setLoading(true);
    loadCapabilitiesForSite(siteId)
      .then(setCapabilities)
      .catch((err) => console.error('Failed to load capabilities', err))
      .finally(() => setLoading(false));
  }, [siteId]);

  const resolveTitle = useCallback(
    (capabilityId: string) => resolveCapabilityTitle(capabilityId, capabilities),
    [capabilities]
  );

  const resolveTitles = useCallback(
    (capabilityIds: string[]) => resolveCapabilityTitles(capabilityIds, capabilities),
    [capabilities]
  );

  return {
    capabilities,
    loading,
    resolveTitle,
    resolveTitles,
    capabilityList: Array.from(capabilities.values()),
  };
}
