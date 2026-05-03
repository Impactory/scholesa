const { buildImportBundle } = require('../scripts/import_synthetic_data');

function collectionMap(bundle, name) {
  return bundle.collections.get(name) || new Map();
}

function interactionEventsFor(bundle, learnerId) {
  return Array.from(collectionMap(bundle, 'interactionEvents').entries())
    .map(([id, data]) => ({ id, data }))
    .filter((event) => event.data.actorId === learnerId || event.data.learnerId === learnerId);
}

describe('synthetic MiloOS gold-readiness states', () => {
  it('adds canonical learner states for demos, UAT, rules, and regression checks', () => {
    const bundle = buildImportBundle({ mode: 'starter' });
    const users = collectionMap(bundle, 'users');
    const manifest = collectionMap(bundle, 'syntheticMiloOSGoldStates').get('latest');

    expect(manifest).toMatchObject({
      siteId: 'synthetic-site-miloos-gold',
      modeSupport: ['starter', 'full', 'all'],
      noMasteryWrites: true,
      sourceCounts: {
        miloosGoldLearnerStates: 5,
        miloosGoldInteractionEvents: 13,
      },
      sourcePack: 'miloos-gold-readiness',
    });
    expect(bundle.summary.miloosGoldReadinessStates).toMatchObject({
      collection: 'syntheticMiloOSGoldStates',
      documentId: 'latest',
      seedModes: ['starter', 'full', 'all'],
    });
    expect(users.get('synthetic-miloos-gold-educator')).toMatchObject({
      role: 'educator',
      siteIds: ['synthetic-site-miloos-gold'],
      activeSiteId: 'synthetic-site-miloos-gold',
    });
    expect(users.get('synthetic-miloos-gold-site-lead')).toMatchObject({
      role: 'siteLead',
      siteIds: ['synthetic-site-miloos-gold'],
      activeSiteId: 'synthetic-site-miloos-gold',
    });
    expect(users.get(manifest.states.noSupportLearnerId)).toMatchObject({
      role: 'learner',
      miloosGoldState: 'noSupport',
    });
    expect(users.get(manifest.states.pendingExplainBackLearnerId)).toMatchObject({
      role: 'learner',
      miloosGoldState: 'pendingExplainBack',
    });
    expect(users.get(manifest.states.supportCurrentLearnerId)).toMatchObject({
      role: 'learner',
      miloosGoldState: 'supportCurrent',
    });
    expect(users.get(manifest.states.crossSiteDenialLearnerId)).toMatchObject({
      role: 'learner',
      siteIds: ['synthetic-site-miloos-other'],
      miloosGoldState: 'crossSite',
    });
    expect(users.get(manifest.states.missingSiteDenialLearnerId)).toMatchObject({
      role: 'learner',
      miloosGoldState: 'missingSite',
    });
  });

  it('models no-support, pending, current, cross-site, and missing-site support turns', () => {
    const bundle = buildImportBundle({ mode: 'starter' });
    const manifest = collectionMap(bundle, 'syntheticMiloOSGoldStates').get('latest');
    const interactionEvents = collectionMap(bundle, 'interactionEvents');

    expect(interactionEventsFor(bundle, manifest.states.noSupportLearnerId)).toHaveLength(0);

    const pendingEvents = interactionEventsFor(bundle, manifest.states.pendingExplainBackLearnerId);
    expect(pendingEvents.map((event) => event.data.eventType)).toEqual(expect.arrayContaining([
      'ai_help_opened',
      'ai_help_used',
      'ai_coach_response',
    ]));
    expect(pendingEvents.some((event) => event.data.eventType === 'explain_it_back_submitted')).toBe(false);
    expect(interactionEvents.get('synthetic-miloos-pending-opened-01')).toMatchObject({
      traceId: 'synthetic-miloos-pending-opened-01',
      payload: { aiHelpOpenedEventId: 'synthetic-miloos-pending-opened-01' },
    });

    const currentEvents = interactionEventsFor(bundle, manifest.states.supportCurrentLearnerId);
    expect(currentEvents.map((event) => event.data.eventType)).toEqual(expect.arrayContaining([
      'ai_help_opened',
      'ai_help_used',
      'ai_coach_response',
      'explain_it_back_submitted',
    ]));
    expect(interactionEvents.get('synthetic-miloos-current-opened-01-explain-back')).toMatchObject({
      payload: {
        aiHelpOpenedEventId: 'synthetic-miloos-current-opened-01',
        approved: true,
      },
    });

    expect(interactionEvents.get('synthetic-miloos-cross-site-opened-01')).toMatchObject({
      siteId: 'synthetic-site-miloos-other',
      actorId: manifest.states.crossSiteDenialLearnerId,
    });
    expect(interactionEvents.get('synthetic-miloos-missing-site-opened-01')).toMatchObject({
      siteId: null,
      actorId: manifest.states.missingSiteDenialLearnerId,
    });
  });

  it('does not seed support-only capability mastery or growth writes', () => {
    const bundle = buildImportBundle({ mode: 'starter' });
    const masteryDocs = Array.from(collectionMap(bundle, 'capabilityMastery').values());
    const growthDocs = Array.from(collectionMap(bundle, 'capabilityGrowthEvents').values());

    expect(masteryDocs.some((doc) => doc.sourcePack === 'miloos-gold-readiness')).toBe(false);
    expect(growthDocs.some((doc) => doc.sourcePack === 'miloos-gold-readiness')).toBe(false);
    expect(bundle.summary.sourceCounts).toMatchObject({
      miloosGoldLearnerStates: 5,
      miloosGoldInteractionEvents: 13,
    });
  });
});
