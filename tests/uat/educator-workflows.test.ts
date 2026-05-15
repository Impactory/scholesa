import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function prepareEducatorWorkflow(): { harness: UatTestHarness; sessionId: string } {
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

function criterionScores() {
  return mission.capabilityDomains.map((domain, index) => ({
    criterionId: `criterion-${index + 1}`,
    criterionTitle: `${domain} evidence`,
    capabilityDomain: domain,
    score: 3 as const,
  }));
}

async function submitBuilderEvidence(harness: UatTestHarness, sessionId: string) {
  harness.loginAs('builder');

  return harness.submitEvidenceArtifact({
    learnerRole: 'builder',
    missionId: mission.id,
    sessionId,
    checkpointTitle: 'Build a city feature prototype',
    evidenceType: 'image',
    fileName: 'eco-city-review.png',
    contentType: 'image/png',
    body: 'reviewable-evidence-bytes',
    explanation: 'I changed the sensor placement after feedback and can explain the tradeoff.',
  });
}

describe('Educator workflow UAT', () => {
  it('UAT-G1: Educator quickly sees evidence gaps for a Learner who needs support', async () => {
    const { harness } = prepareEducatorWorkflow();

    harness.loginAs('builder');
    await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Help me improve my eco-smart city before I submit.'
    );

    harness.loginAs('educator');
    const gaps = harness.getEducatorEvidenceGaps(buildersCohortId, mission.id);

    expect(gaps).toEqual([
      expect.objectContaining({
        learnerId: getUatUser('builder').id,
        learnerDisplayName: getUatUser('builder').displayName,
        missionId: mission.id,
        missing: expect.arrayContaining([
          'missing reflection',
          'missing artifact',
          'missing explain-it-back',
          'missing AI-use summary',
          'incomplete checkpoint',
        ]),
      }),
    ]);
  });

  it('UAT-G2: Educator publishes a Capability Review, Learner sees feedback, and Portfolio updates', async () => {
    const { harness, sessionId } = prepareEducatorWorkflow();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(),
      feedback: 'Your Evidence shows stronger prototype iteration because you explained what changed after feedback.',
      nextStep: 'Next, compare two sensor placements and explain which one better supports energy savings.',
    });
    const learnerFeedback = harness.getLearnerFeedback('builder', mission.id);
    const portfolioItems = harness.expectPortfolioUpdated('builder');

    expect(review).toMatchObject({
      learnerId: getUatUser('builder').id,
      educatorId: getUatUser('educator').id,
      evidenceId: evidence.id,
      score: 3,
      publishedAt: expect.any(String),
    });
    expect(learnerFeedback).toEqual([expect.objectContaining({ id: review.id, feedback: review.feedback })]);
    expect(portfolioItems).toEqual(
      expect.arrayContaining([expect.objectContaining({ evidenceId: evidence.id, missionId: mission.id })])
    );
  });

  it('UAT-G3: Capability-linked assessment attaches score to learner, artifact, criterion, Capability, Mission, Educator, timestamp, and tenant', async () => {
    const { harness, sessionId } = prepareEducatorWorkflow();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(),
      feedback: 'The review is tied to Capability growth, not a generic score.',
      nextStep: 'Use the next build sprint to test the design against another city need.',
    });

    expect(review).toMatchObject({
      learnerId: getUatUser('builder').id,
      artifactUrl: evidence.artifact.url,
      missionId: mission.id,
      educatorId: getUatUser('educator').id,
      tenantId: getUatUser('builder').tenantId,
      publishedAt: '2026-05-14T13:05:00.000Z',
    });
    expect(review.criterionScores).toEqual(
      mission.capabilityDomains.map((domain, index) => expect.objectContaining({
        criterionId: `criterion-${index + 1}`,
        capabilityDomain: domain,
        score: 3,
      }))
    );
    expect(harness.expectGrowthReportUpdated('builder')[0]).toMatchObject({ latestReviewId: review.id });
  });

  it('UAT-G4: Educator feedback is learner-visible, actionable, and capability-aligned', async () => {
    const { harness, sessionId } = prepareEducatorWorkflow();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(),
      feedback: `Your ${mission.capabilityDomains[0]} Evidence improved when you explained why the sensor moved.`,
      nextStep: `Next step: strengthen ${mission.capabilityDomains[1]} by comparing two sources before the next prototype.`,
    });

    const [learnerView] = harness.getLearnerFeedback('builder', mission.id);

    expect(learnerView.feedback).toContain(mission.capabilityDomains[0]);
    expect(learnerView.nextStep).toContain('Next step');
    expect(learnerView.nextStep).toContain(mission.capabilityDomains[1]);
    expect(review.capabilityDomains).toEqual(mission.capabilityDomains);
  });

  it('UAT-G5: MiloOS Educator Co-pilot can suggest feedback while Educator accept, edit, or ignore decisions are logged', async () => {
    const { harness, sessionId } = prepareEducatorWorkflow();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    const suggestion = harness.suggestEducatorCopilotFeedback(evidence.id);
    const accepted = harness.recordEducatorCopilotDecision(evidence.id, 'accepted', suggestion, suggestion);
    const edited = harness.recordEducatorCopilotDecision(
      evidence.id,
      'edited',
      suggestion,
      `${suggestion} Educator added a more specific next-step checkpoint.`
    );
    const ignored = harness.recordEducatorCopilotDecision(evidence.id, 'ignored', suggestion);

    expect(suggestion).toContain(mission.capabilityDomains[0]);
    expect([accepted, edited, ignored]).toEqual([
      expect.objectContaining({ decision: 'accepted', educatorId: getUatUser('educator').id }),
      expect.objectContaining({ decision: 'edited', finalFeedback: expect.stringContaining('Educator added') }),
      expect.objectContaining({ decision: 'ignored', finalFeedback: undefined }),
    ]);
    expect(harness.checkAuditLog('educator-copilot.accepted')).toHaveLength(1);
    expect(harness.checkAuditLog('educator-copilot.edited')).toHaveLength(1);
    expect(harness.checkAuditLog('educator-copilot.ignored')).toHaveLength(1);
  });
});
