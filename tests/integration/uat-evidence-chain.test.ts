import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness } from '../helpers';

describe('Scholesa UAT evidence chain harness', () => {
  it('runs mission -> checkpoint -> evidence -> reflection -> capability review -> portfolio -> growth report', async () => {
    const harness = createUatTestHarness();
    const mission = getUatMissionByStage('Builders');

    harness.loginAs('admin');
    expect(harness.createTenant().name).toBe('Scholesa Summer Pilot 2026');
    expect(harness.createOrganization().name).toBe('Scholesa Pilot Academy');
    const cohort = harness.createCohort('cohort-builders-4-6');

    harness.loginAs('educator');
    harness.assignMission(mission.id, cohort.id);
    harness.openMissionSession(mission.id, cohort.id);
    harness.completeCheckpoint('builder', mission.id, mission.checkpointTitles[0]);
    const evidence = await harness.submitEvidence('builder', mission.id);
    harness.submitReflection(
      'builder',
      mission.id,
      'I improved the eco-smart city feature after checking what people needed.'
    );
    const aiResponse = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Help me explain why my city feature saves energy.'
    );
    const rubricScore = harness.scoreEvidenceRubric(evidence.id, 3);
    const review = harness.performCapabilityReview(
      'builder',
      mission.id,
      evidence.id,
      rubricScore.score,
      'Evidence shows a tested design idea with a clear explain-it-back.'
    );

    expect(aiResponse).toMatchObject({ allowed: true, requiresEducator: false });
    expect(harness.checkAIUsageLog(aiResponse.auditEventId)).toHaveLength(1);
    expect(harness.expectPortfolioUpdated('builder')[0]).toMatchObject({ evidenceId: evidence.id });
    expect(harness.expectGrowthReportUpdated('builder')[0]).toMatchObject({ latestReviewId: review.id });
    expect(harness.expectCapabilityContextPreserved(review.id, mission.capabilityDomains)).toHaveLength(1);
    expect(harness.checkAuditLog('capability-review.perform')[0]).toMatchObject({ targetId: review.id });
  });

  it('enforces educator-led AI for Discoverers and tenant isolation expectations', async () => {
    const harness = createUatTestHarness();
    const mission = getUatMissionByStage('Discoverers');

    harness.loginAs('educator');
    const deniedResponse = await harness.useMiloOSCoach(
      'discoverer',
      mission.id,
      mission.capabilityDomains[0],
      'Can I chat with MiloOS by myself?'
    );
    const educatorLedResponse = await harness.useMiloOSCoach(
      'discoverer',
      mission.id,
      mission.capabilityDomains[0],
      'Help me ask an age-appropriate reflection prompt.',
      true
    );

    expect(deniedResponse).toMatchObject({ allowed: false, requiresEducator: true });
    expect(educatorLedResponse).toMatchObject({ allowed: true, requiresEducator: true });
    expect(harness.checkAIUsageLog()).toHaveLength(2);

    harness.expectAccessDenied(
      'family',
      'capability-review-official-record',
      getUatUser('family').restriction ?? 'Family edit denied.'
    );
    expect(harness.state.accessDenied[0]).toMatchObject({ targetId: 'capability-review-official-record' });
    expect(harness.expectTenantIsolation('mentor', 'tenant-other-academy')).toMatchObject({ allowed: false });
  });
});
