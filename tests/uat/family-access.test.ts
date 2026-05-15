import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const explorersCohortId = 'cohort-explorers-7-9';
const mission = getUatMissionByStage('Builders');

function criterionScores() {
  return mission.capabilityDomains.map((domain, index) => ({
    criterionId: `criterion-${index + 1}`,
    criterionTitle: `${domain} observable Evidence`,
    capabilityDomain: domain,
    score: 3 as const,
  }));
}

async function prepareFamilyWorkflow(): Promise<{ harness: UatTestHarness; evidenceId: string }> {
  const harness = createUatTestHarness();

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort('builder', buildersCohortId);
  harness.addLearnerToCohort('explorer', explorersCohortId);
  harness.assignEducatorToCohort('educator', buildersCohortId);

  harness.loginAs('educator');
  harness.assignMission(mission.id, buildersCohortId);
  const session = harness.openMissionSession(mission.id, buildersCohortId);
  harness.publishHomeConnection(
    mission.id,
    buildersCohortId,
    'Ask your Learner to explain one city design tradeoff.',
    true
  );

  harness.loginAs('builder');
  const evidence = await harness.submitEvidenceArtifact({
    learnerRole: 'builder',
    missionId: mission.id,
    sessionId: session.id,
    checkpointTitle: 'Build a city feature prototype',
    evidenceType: 'image',
    fileName: 'family-highlight.png',
    contentType: 'image/png',
    body: 'family-highlight-bytes',
    explanation: 'I changed the prototype after feedback and can explain the tradeoff.',
  });
  harness.submitWrittenReflectionProof(
    'builder',
    mission.id,
    session.id,
    'Family-visible reflection checkpoint',
    'I learned that showing the tradeoff helped my design make more sense.'
  );

  harness.loginAs('educator');
  harness.performCapabilityReviewWithCriteria({
    learnerRole: 'builder',
    missionId: mission.id,
    evidenceId: evidence.id,
    criterionScores: criterionScores(),
    feedback: 'Shared summary: the Learner connected prototype changes to capability growth.',
    nextStep: 'Next, explain one new tradeoff at home using the Home Connection prompt.',
  });
  harness.createSharedMilestone('builder', mission.id, 'Prototype iteration milestone shared with Family');
  harness.publishGrowthSummaryForFamily(
    'builder',
    mission.id,
    'Published growth summary: Bailey is improving prototype iteration with clearer explanations.'
  );
  harness.setPortfolioShareMode(evidence.id, 'family');

  return { harness, evidenceId: evidence.id };
}

describe('Family access UAT', () => {
  it('UAT-I1: Family sees only selected linked Learner progress and cannot access other Learners', async () => {
    const { harness, evidenceId } = await prepareFamilyWorkflow();

    harness.loginAs('family');
    const linkedProgress = harness.getFamilyLinkedLearnerProgress('family', 'builder');
    const otherLearnerProgress = harness.getFamilyLinkedLearnerProgress('family', 'explorer');

    expect(linkedProgress).toMatchObject({
      learnerId: getUatUser('builder').id,
      allowed: true,
      sharedMilestones: [expect.objectContaining({ title: expect.stringContaining('Prototype iteration') })],
      homeConnections: [expect.objectContaining({ title: expect.stringContaining('tradeoff') })],
      selectedPortfolioHighlights: [expect.objectContaining({ evidenceId })],
      publishedGrowthSummary: expect.objectContaining({ summary: expect.stringContaining('Published growth summary') }),
    });
    expect(linkedProgress.selectedPortfolioHighlights).toHaveLength(1);
    expect(otherLearnerProgress).toMatchObject({
      learnerId: getUatUser('explorer').id,
      allowed: false,
      sharedMilestones: [],
      homeConnections: [],
      selectedPortfolioHighlights: [],
    });
    expect(harness.checkAuditLog('family.access.denied')).toEqual([
      expect.objectContaining({ actorId: getUatUser('family').id, targetId: getUatUser('explorer').id }),
    ]);
  });

  it('UAT-I2: Family read-only restrictions block edits, reviews, private AI logs, and share changes with denied-access audit logs', async () => {
    const { harness, evidenceId } = await prepareFamilyWorkflow();

    harness.loginAs('builder');
    const aiResponse = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Help me improve my explanation before my Family sees the summary.'
    );
    harness.linkAIUsageToSubmission(aiResponse.auditEventId, evidenceId);

    harness.loginAs('family');
    const blockedActions = [
      harness.denyFamilyRestrictedAction('edit evidence', evidenceId),
      harness.denyFamilyRestrictedAction('change reflection', 'reflection-1'),
      harness.denyFamilyRestrictedAction('perform Capability Review', evidenceId),
      harness.denyFamilyRestrictedAction('view private AI logs', aiResponse.auditEventId),
      harness.denyFamilyRestrictedAction('change portfolio sharing', evidenceId),
    ];

    expect(blockedActions).toEqual([
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('edit evidence') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('change reflection') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('perform Capability Review') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('view private AI logs') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('change portfolio sharing') }),
    ]);
    expect(harness.getEducatorAIUsageLogsForEvidence.bind(harness, evidenceId)).toThrow(
      'Expected current user role educator, got family.'
    );
    expect(harness.checkAuditLog('family.access.denied')).toHaveLength(5);
  });
});
