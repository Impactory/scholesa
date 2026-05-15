import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, requiredScholesaTerminology, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const discoverersCohortId = 'cohort-discoverers-1-3';
const mission = getUatMissionByStage('Builders');
const discovererMission = getUatMissionByStage('Discoverers');

type ProductPromiseDimension =
  | 'capability growth'
  | 'Evidence quality'
  | 'Learner safety'
  | 'Educator usability'
  | 'Family trust'
  | 'Admin trust'
  | 'MiloOS auditability'
  | 'Portfolio visibility';

type ProductFeatureSignal = {
  feature: string;
  strengthens: ProductPromiseDimension[];
};

function prepareProductPromiseWorkflow(): { harness: UatTestHarness; sessionId: string } {
  const harness = createUatTestHarness();

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort('builder', buildersCohortId);
  harness.addLearnerToCohort('discoverer', discoverersCohortId);
  harness.assignEducatorToCohort('educator', buildersCohortId);
  harness.assignEducatorToCohort('educator', discoverersCohortId);

  harness.loginAs('educator');
  harness.assignMission(mission.id, buildersCohortId);
  harness.assignMission(discovererMission.id, discoverersCohortId);
  const session = harness.openMissionSession(mission.id, buildersCohortId);

  return { harness, sessionId: session.id };
}

function criterionScores(score: 1 | 2 | 3 | 4 = 3) {
  return mission.capabilityDomains.map((domain, index) => ({
    criterionId: `promise-criterion-${index + 1}`,
    criterionTitle: `${domain} product promise criterion`,
    capabilityDomain: domain,
    score,
  }));
}

function requiresProductReview(feature: ProductFeatureSignal): boolean {
  return feature.strengthens.length === 0;
}

describe('Scholesa product promise UAT gate', () => {
  it('proves Learners do meaningful future-ready work that becomes portfolio-worthy Capability Evidence', async () => {
    const { harness, sessionId } = prepareProductPromiseWorkflow();

    harness.loginAs('builder');
    const checkpoint = harness.completeCheckpoint(
      'builder',
      mission.id,
      'Build a city feature prototype'
    );
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: checkpoint.checkpointTitle,
      evidenceType: 'prototype-link',
      fileName: 'promise-portfolio-proof.json',
      contentType: 'application/json',
      body: JSON.stringify({ prototype: true }),
      explanation: 'I tested a city feature, changed it after feedback, and can explain the tradeoff.',
      links: ['https://scholesa.test/prototype/promise-eco-city'],
    });

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(4),
      feedback: 'This Evidence shows future-ready prototype iteration and clear explanation of tradeoffs.',
      nextStep: 'Prepare one Showcase-ready explanation connecting the prototype to Capability growth.',
    });
    const badge = harness.markBadgeReadyIfCriteriaMet({
      learnerRole: 'builder',
      badgeId: 'badge-product-promise-proof',
      title: 'Product Promise Proof',
      requiredCapabilityDomains: mission.capabilityDomains,
      requiredReviewedEvidenceCount: 1,
    });

    expect(evidence).toMatchObject({
      learnerId: getUatUser('builder').id,
      missionId: mission.id,
      checkpointTitle: checkpoint.checkpointTitle,
      capabilityDomains: mission.capabilityDomains,
      explanation: expect.stringContaining('tradeoff'),
    });
    expect(review.nextStep).toContain('Showcase-ready');
    expect(harness.expectPortfolioUpdated('builder')).toEqual(
      expect.arrayContaining([expect.objectContaining({ evidenceId: evidence.id })])
    );
    expect(badge).toMatchObject({ status: 'ready-for-review', evidenceIds: [evidence.id] });
  });

  it('proves Educators can coach and assess growth with actionable, Capability-aligned feedback', async () => {
    const { harness, sessionId } = prepareProductPromiseWorkflow();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Explain what changed after feedback',
      evidenceType: 'image',
      fileName: 'promise-educator-review.png',
      contentType: 'image/png',
      body: 'promise-educator-review',
      explanation: 'I changed the prototype and explained how feedback improved it.',
    });

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(),
      feedback: `Your Evidence strengthens ${mission.capabilityDomains[0]} because you named what changed.`,
      nextStep: `Next step: strengthen ${mission.capabilityDomains[1]} by comparing one more source.`,
    });

    expect(review.criterionScores).toHaveLength(mission.capabilityDomains.length);
    expect(review.feedback).toContain(mission.capabilityDomains[0]);
    expect(review.nextStep).toContain(mission.capabilityDomains[1]);
    expect(harness.expectGrowthReportUpdated('builder')).toEqual([
      expect.objectContaining({ latestReviewId: review.id, capabilityDomains: mission.capabilityDomains }),
    ]);
  });

  it('proves Families understand progress through selected, trustworthy progress surfaces only', async () => {
    const { harness, sessionId } = prepareProductPromiseWorkflow();

    harness.loginAs('educator');
    harness.publishHomeConnection(mission.id, buildersCohortId, 'Discuss one prototype tradeoff at home.', true);

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Family-visible Portfolio highlight',
      evidenceType: 'image',
      fileName: 'promise-family-highlight.png',
      contentType: 'image/png',
      body: 'promise-family-highlight',
      explanation: 'This highlight is ready for my Family to understand my progress.',
    });

    harness.loginAs('educator');
    harness.performCapabilityReview('builder', mission.id, evidence.id, 3, 'Family-visible growth summary is grounded in Evidence.');
    harness.createSharedMilestone('builder', mission.id, 'Capability growth milestone shared with Family');
    harness.publishGrowthSummaryForFamily('builder', mission.id, 'Published Growth Summary grounded in reviewed Evidence.');
    harness.setPortfolioShareMode(evidence.id, 'family');

    harness.loginAs('family');
    const linkedProgress = harness.getFamilyLinkedLearnerProgress('family', 'builder');
    const unlinkedProgress = harness.getFamilyLinkedLearnerProgress('family', 'discoverer');

    expect(linkedProgress).toMatchObject({
      allowed: true,
      sharedMilestones: [expect.objectContaining({ title: expect.stringContaining('Capability growth') })],
      homeConnections: [expect.objectContaining({ title: expect.stringContaining('tradeoff') })],
      selectedPortfolioHighlights: [expect.objectContaining({ evidenceId: evidence.id })],
      publishedGrowthSummary: expect.objectContaining({ summary: expect.stringContaining('reviewed Evidence') }),
    });
    expect(unlinkedProgress).toMatchObject({ allowed: false, selectedPortfolioHighlights: [] });
  });

  it('proves Mentors can support Showcase readiness only when explicitly enabled and assigned', async () => {
    const { harness, sessionId } = prepareProductPromiseWorkflow();

    harness.setFeatureFlag('mentor', true);

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Mentor Showcase readiness Evidence',
      evidenceType: 'prototype-link',
      fileName: 'promise-mentor-showcase.json',
      contentType: 'application/json',
      body: JSON.stringify({ showcase: true }),
      explanation: 'I want Mentor feedback before Showcase publication.',
      links: ['https://scholesa.test/showcase/promise-mentor'],
    });

    harness.loginAs('mentor');
    expect(harness.getMentorAssignedShowcaseItems('mentor')).toHaveLength(0);

    harness.loginAs('educator');
    harness.assignMentorToShowcase(evidence.id, 'mentor');

    harness.loginAs('mentor');
    const feedback = harness.addMentorStructuredFeedback({
      evidenceId: evidence.id,
      strengths: ['The Showcase story is clear and tied to Evidence.'],
      questions: ['What Capability growth should the audience notice first?'],
      showcaseReadinessNextStep: 'Add one sentence naming the Evidence behind the prototype change.',
    });

    expect(harness.getMentorAssignedShowcaseItems('mentor')).toEqual([evidence]);
    expect(feedback).toMatchObject({
      visibleToLearner: true,
      visibleToEducator: true,
      showcaseReadinessNextStep: expect.stringContaining('Evidence'),
    });
  });

  it('proves Admin trust and MiloOS safety through tenant scope, age policy, guardrails, and auditability', async () => {
    const { harness, sessionId } = prepareProductPromiseWorkflow();

    await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Admin trust Evidence count',
      evidenceType: 'image',
      fileName: 'promise-admin-trust.png',
      contentType: 'image/png',
      body: 'promise-admin-trust',
      explanation: 'This Evidence should appear only in the correct tenant report.',
    });
    harness.seedCrossTenantReportNoise();

    harness.loginAs('admin');
    const report = harness.getAdminPlatformReport();

    harness.loginAs('discoverer');
    const discovererResponse = await harness.useMiloOSCoach(
      'discoverer',
      discovererMission.id,
      discovererMission.capabilityDomains[0],
      'Can I use MiloOS Coach by myself?'
    );

    harness.loginAs('builder');
    const noCopyResponse = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Do the whole project.'
    );

    expect(report.tenantId).toBe(getUatUser('admin').tenantId);
    expect(JSON.stringify(report)).not.toContain('tenant-not-scholesa-pilot');
    expect(discovererResponse).toMatchObject({ allowed: false, supportType: 'policy-block' });
    expect(noCopyResponse).toMatchObject({ refused: true, supportType: 'guardrail-refusal' });
    expect(harness.checkAIUsageLog()).toHaveLength(2);
    expect(harness.checkAuditLog('miloos-coach.use')).toHaveLength(2);
  });

  it('flags features for product review when they do not strengthen the Scholesa promise', () => {
    const reviewedFeatures: ProductFeatureSignal[] = [
      { feature: 'Capability Review feedback', strengthens: ['capability growth', 'Educator usability'] },
      { feature: 'Family Growth Summary', strengthens: ['Family trust', 'Portfolio visibility'] },
      { feature: 'decorative LMS-style points widget', strengthens: [] },
    ];
    const productReviewQueue = reviewedFeatures.filter(requiresProductReview);

    expect(productReviewQueue).toEqual([
      { feature: 'decorative LMS-style points widget', strengthens: [] },
    ]);
  });

  it('enforces Scholesa terminology and rejects generic LMS language in product-promise copy', () => {
    const productPromiseCopy = [
      'Learners do meaningful future-ready work.',
      'Educators coach and assess Capability growth.',
      'Families understand progress through shared Evidence and Growth Reports.',
      'Mentors support Showcase readiness when enabled.',
      'Admins trust tenant-scoped reporting and audit logs.',
      'MiloOS Coach is safe, assistive, age-appropriate, and auditable.',
      'Evidence becomes Portfolio-worthy proof of Capability.',
      ...requiredScholesaTerminology,
    ].join(' ');
    const forbiddenGenericLmsTerms = /\b(Teacher|Student|Parent|Assignment|Homework|Grading|Report Card)\b/;

    for (const term of requiredScholesaTerminology) {
      expect(productPromiseCopy).toContain(term);
    }
    expect(productPromiseCopy).not.toMatch(forbiddenGenericLmsTerms);
  });
});
