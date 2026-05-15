import { getCapabilityForMissionDomain } from '../fixtures/uat-capability-graph';
import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function prepareEvidenceMission(): { harness: UatTestHarness; sessionId: string } {
  const harness = createUatTestHarness();

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort('builder', buildersCohortId);
  harness.assignEducatorToCohort('educator', buildersCohortId);

  harness.loginAs('educator');
  harness.assignMission(mission.id, buildersCohortId);
  const session = harness.openMissionSession(mission.id, buildersCohortId);

  return { harness, sessionId: session.id };
}

describe('evidence capture and proof-of-work UAT', () => {
  it('UAT-E1: Written reflection stores learner, tenant, Cohort, Mission, Session, checkpoint, and Capability context', () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('builder');
    const reflection = harness.submitWrittenReflectionProof(
      'builder',
      mission.id,
      sessionId,
      'Build sprint reflection',
      'I changed my eco-smart city design after I saw that shade and sensors could save more energy.'
    );
    const educatorReflections = harness.getEducatorReviewableReflections(buildersCohortId, mission.id);
    const portfolioItems = harness.expectPortfolioUpdated('builder');

    expect(reflection).toMatchObject({
      learnerId: getUatUser('builder').id,
      tenantId: getUatUser('builder').tenantId,
      cohortId: buildersCohortId,
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Build sprint reflection',
      capabilityDomains: mission.capabilityDomains,
    });
    expect(educatorReflections).toEqual([reflection]);
    expect(portfolioItems).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ evidenceId: reflection.id, capabilityDomains: mission.capabilityDomains }),
      ])
    );
    expect(harness.expectCapabilityContextPreserved(reflection.id, mission.capabilityDomains)).toHaveLength(1);
  });

  it('UAT-E2: Image or screenshot Evidence stores artifact metadata and is Educator-reviewable', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Design sketch or screenshot',
      evidenceType: 'image',
      fileName: 'eco-city-screenshot.png',
      contentType: 'image/png',
      body: 'png-bytes-uat',
      explanation: 'This screenshot shows where I placed solar panels and shade trees.',
      metadata: { width: 1440, height: 900, source: 'screenshot' },
    });

    expect(evidence.artifact).toMatchObject({
      fileName: 'eco-city-screenshot.png',
      contentType: 'image/png',
      tenantId: getUatUser('builder').tenantId,
      learnerId: getUatUser('builder').id,
    });
    expect(evidence.metadata).toMatchObject({ width: 1440, height: 900, source: 'screenshot' });
    expect(harness.getEducatorReviewableEvidence(buildersCohortId, mission.id)).toEqual([evidence]);
    expect(evidence.capabilityDomains).toEqual(mission.capabilityDomains);
  });

  it('UAT-E3: Audio explain-it-back is retrievable and accepted as learning proof', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Explain-it-back response',
      evidenceType: 'audio',
      fileName: 'eco-city-explain-back.m4a',
      contentType: 'audio/mp4',
      body: 'audio-bytes-uat',
      explanation: 'I explained why my sensor idea helps the city save power.',
      metadata: { playable: true, durationSeconds: 42 },
    });

    expect(evidence.metadata).toMatchObject({ playable: true, durationSeconds: 42 });
    expect(evidence.artifact.url).toContain('mock-storage://');
    expect(harness.getEducatorReviewableEvidence(buildersCohortId, mission.id)[0]).toMatchObject({
      evidenceType: 'audio',
      explanation: expect.stringContaining('sensor idea'),
    });
  });

  it('UAT-E4: Video, prototype, and code links attach to reviewable Capability-tagged Evidence', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Build artifact links',
      evidenceType: 'prototype-link',
      fileName: 'eco-city-links.json',
      contentType: 'application/json',
      body: JSON.stringify({ links: true }),
      explanation: 'These links show my demo, prototype, and code notes.',
      links: [
        'https://scholesa.test/demo/eco-city-video',
        'https://scholesa.test/prototype/eco-city-design',
        'https://scholesa.test/code/eco-city-sensors',
      ],
    });

    expect(evidence.links).toHaveLength(3);
    expect(harness.getEducatorReviewableEvidence(buildersCohortId, mission.id)).toEqual([evidence]);
    expect(evidence.capabilityDomains).toEqual(mission.capabilityDomains);
    expect(harness.expectCapabilityContextPreserved(evidence.id, mission.capabilityDomains)).toHaveLength(1);
  });

  it('UAT-E5: Explain-it-back is required before artifact proof can be submitted', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    expect(harness.validateProofOfWork({ explanation: '' })).toMatchObject({
      ok: false,
      error: 'Explanation is required for proof-of-work.',
    });

    const validProof = harness.validateProofOfWork({
      explanation: 'I tested shade placement and learned where the city stayed cooler.',
    });
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Explain-it-back response',
      evidenceType: 'image',
      fileName: 'eco-city-after-explanation.png',
      contentType: 'image/png',
      body: 'png-after-explanation',
      explanation: 'I tested shade placement and learned where the city stayed cooler.',
    });

    expect(validProof).toEqual({ ok: true });
    expect(evidence.explanation).toContain('shade placement');
    expect(evidence.status).toBe('submitted');
  });

  it('UAT-E6: Revision history distinguishes previous and current versions and contributes to growth Evidence', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Build artifact revision',
      evidenceType: 'image',
      fileName: 'eco-city-v1.png',
      contentType: 'image/png',
      body: 'version-one',
      explanation: 'This is my first city design.',
    });
    const revised = harness.reviseEvidence(
      evidence.id,
      'I moved the sensors closer to the shaded paths after feedback.',
      'mock-storage://tenant-summer-pilot-2026/user-learner-builder/artifact-2/eco-city-v2.png'
    );

    harness.loginAs('educator');
    const review = harness.performCapabilityReview(
      'builder',
      mission.id,
      evidence.id,
      3,
      'Revision shows growth from feedback and stronger Evidence.'
    );

    expect(harness.getRevisionHistory(evidence.id)).toEqual([
      expect.objectContaining({
        version: 1,
        note: expect.stringContaining('sensors closer'),
        previousArtifactUrl: evidence.artifact.url,
        currentArtifactUrl: expect.stringContaining('eco-city-v2.png'),
      }),
    ]);
    expect(revised.revisions?.[0].previousArtifactUrl).not.toBe(revised.revisions?.[0].currentArtifactUrl);
    expect(harness.expectGrowthReportUpdated('builder')[0]).toMatchObject({ latestReviewId: review.id });
  });

  it('UAT-E7: AI-supported work requires prompt, MiloOS Coach suggestion, and learner change summary', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('builder');
    const aiResponse = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Help me improve the energy-saving part of my city.'
    );

    expect(harness.validateProofOfWork({
      explanation: 'I used MiloOS Coach to improve my design.',
      aiSupported: true,
    })).toMatchObject({ ok: false });

    const summary = {
      promptUsed: 'Help me improve the energy-saving part of my city.',
      coachSuggestion: aiResponse.message,
      learnerChanged: 'I added shade sensors and explained why they reduce energy use.',
    };
    expect(harness.validateProofOfWork({
      explanation: 'I used MiloOS Coach and changed my design in my own words.',
      aiSupported: true,
      aiUseSummary: summary,
    })).toEqual({ ok: true });

    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Optional AI-use summary if MiloOS Coach was used',
      evidenceType: 'written-reflection',
      fileName: 'eco-city-ai-summary.txt',
      contentType: 'text/plain',
      body: 'AI-use accountability summary',
      explanation: 'I used MiloOS Coach and changed my design in my own words.',
      aiUseSummary: summary,
    });

    expect(evidence.aiUseSummary).toEqual(summary);
    expect(harness.checkAIUsageLog(aiResponse.auditEventId)).toHaveLength(1);
  });

  it('UAT-E8: Educator override accepts alternative Evidence and keeps Capability Review auditable', async () => {
    const { harness, sessionId } = prepareEvidenceMission();

    harness.loginAs('educator');
    const override = harness.enableEvidenceOverride(
      'builder',
      'Accessibility accommodation: Learner may submit narrated alternative Evidence instead of typed reflection.'
    );

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Alternative explain-it-back Evidence',
      evidenceType: 'alternative',
      fileName: 'eco-city-accessibility-response.m4a',
      contentType: 'audio/mp4',
      body: 'alternative-audio-proof',
      explanation: 'I explained the city design out loud as my accommodation.',
      override,
    });

    harness.loginAs('educator');
    const review = harness.performCapabilityReview(
      'builder',
      mission.id,
      evidence.id,
      3,
      'Alternative Evidence accepted with documented override reason.'
    );

    for (const domain of evidence.capabilityDomains) {
      expect(getCapabilityForMissionDomain(domain as Parameters<typeof getCapabilityForMissionDomain>[0], 'Builders'))
        .toMatchObject({ domain, stageBand: 'Builders' });
    }
    expect(evidence.override).toMatchObject({
      enabledBy: getUatUser('educator').id,
      reason: expect.stringContaining('Accessibility accommodation'),
    });
    expect(harness.checkAuditLog('evidence-override.enable')).toHaveLength(1);
    expect(harness.expectCapabilityContextPreserved(review.id, mission.capabilityDomains)).toHaveLength(1);
  });
});
