import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function preparePortfolioWorkflow(): { harness: UatTestHarness; sessionId: string } {
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

function criterionScores(score: 1 | 2 | 3 | 4 = 3) {
  return mission.capabilityDomains.map((domain, index) => ({
    criterionId: `criterion-${index + 1}`,
    criterionTitle: `${domain} observable Evidence`,
    capabilityDomain: domain,
    score,
  }));
}

async function submitEvidence(
  harness: UatTestHarness,
  sessionId: string,
  fileName: string,
  checkpointTitle: string
) {
  harness.loginAs('builder');

  return harness.submitEvidenceArtifact({
    learnerRole: 'builder',
    missionId: mission.id,
    sessionId,
    checkpointTitle,
    evidenceType: 'image',
    fileName,
    contentType: 'image/png',
    body: `${fileName}-bytes`,
    explanation: `I can explain how ${checkpointTitle} shows my prototype changed after feedback.`,
  });
}

async function createReviewedEvidenceSet(harness: UatTestHarness, sessionId: string) {
  const evidenceItems = [
    await submitEvidence(harness, sessionId, 'portfolio-evidence-1.png', 'Research an eco-smart need'),
    await submitEvidence(harness, sessionId, 'portfolio-evidence-2.png', 'Build a city feature prototype'),
    await submitEvidence(harness, sessionId, 'portfolio-evidence-3.png', 'Explain what changed after feedback'),
  ];

  harness.loginAs('builder');
  harness.submitWrittenReflectionProof(
    'builder',
    mission.id,
    sessionId,
    'Portfolio reflection',
    'My strongest Evidence is the version where I explained how feedback changed the prototype.'
  );

  harness.loginAs('educator');
  const reviews = evidenceItems.map((evidence, index) =>
    harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(index === 2 ? 4 : 3),
      feedback: `Portfolio-ready feedback ${index + 1}: connect this Evidence to the next prototype decision.`,
      nextStep: `Next step ${index + 1}: explain one tradeoff using ${mission.capabilityDomains[index % mission.capabilityDomains.length]}.`,
    })
  );

  return { evidenceItems, reviews };
}

describe('portfolio and credentialing UAT', () => {
  it('UAT-H1: Portfolio auto-aggregates timeline, Capability, best Evidence, reflection, feedback, and badge progress views', async () => {
    const { harness, sessionId } = preparePortfolioWorkflow();
    const { evidenceItems, reviews } = await createReviewedEvidenceSet(harness, sessionId);

    const readyBadge = harness.markBadgeReadyIfCriteriaMet({
      learnerRole: 'builder',
      badgeId: 'badge-eco-smart-prototype-builder',
      title: 'Eco-Smart Prototype Builder',
      requiredCapabilityDomains: mission.capabilityDomains,
      requiredReviewedEvidenceCount: 3,
    });

    harness.loginAs('builder');
    const portfolio = harness.getPortfolioViews('builder');

    expect(portfolio.timelineView.map((item) => item.evidenceId)).toEqual(
      expect.arrayContaining(evidenceItems.map((evidence) => evidence.id))
    );
    expect(portfolio.capabilityView).toEqual(
      mission.capabilityDomains.map((domain) => expect.objectContaining({
        capabilityDomain: domain,
        evidenceIds: expect.arrayContaining(evidenceItems.map((evidence) => evidence.id)),
      }))
    );
    expect(portfolio.bestEvidenceView[0]).toMatchObject({ evidenceId: evidenceItems[2].id, score: 4 });
    expect(portfolio.reflectionView[0]).toMatchObject({ response: expect.stringContaining('strongest Evidence') });
    expect(portfolio.feedback.map((review) => review.id)).toEqual(reviews.map((review) => review.id));
    expect(portfolio.badgeProgress).toEqual([readyBadge]);
  });

  it('UAT-H2: Badge readiness and award are tied to observable Evidence criteria and audit logs', async () => {
    const { harness, sessionId } = preparePortfolioWorkflow();
    const { evidenceItems } = await createReviewedEvidenceSet(harness, sessionId);

    const readyBadge = harness.markBadgeReadyIfCriteriaMet({
      learnerRole: 'builder',
      badgeId: 'badge-observable-eco-evidence',
      title: 'Observable Eco Evidence',
      requiredCapabilityDomains: mission.capabilityDomains,
      requiredReviewedEvidenceCount: 3,
    });

    harness.loginAs('educator');
    const awardedBadge = harness.awardBadge(readyBadge.id);
    const portfolio = harness.getPortfolioViews('builder');

    expect(readyBadge).toMatchObject({
      status: 'ready-for-review',
      evidenceIds: expect.arrayContaining(evidenceItems.map((evidence) => evidence.id)),
      requiredCapabilityDomains: mission.capabilityDomains,
    });
    expect(awardedBadge).toMatchObject({
      status: 'awarded',
      awardedBy: getUatUser('educator').id,
      awardedAt: '2026-05-14T13:20:00.000Z',
    });
    expect(portfolio.badgeProgress).toEqual([awardedBadge]);
    expect(harness.checkAuditLog('badge.award')).toEqual([
      expect.objectContaining({ targetId: readyBadge.id, capabilityContext: mission.capabilityDomains }),
    ]);
  });

  it('UAT-H3: Portfolio share controls enforce private, Cohort, Family, Mentor, and public showcase visibility', async () => {
    const { harness, sessionId } = preparePortfolioWorkflow();
    const privateEvidence = await submitEvidence(harness, sessionId, 'share-private.png', 'Private checkpoint');
    const cohortEvidence = await submitEvidence(harness, sessionId, 'share-cohort.png', 'Cohort checkpoint');
    const familyEvidence = await submitEvidence(harness, sessionId, 'share-family.png', 'Family checkpoint');
    const mentorEvidence = await submitEvidence(harness, sessionId, 'share-mentor.png', 'Mentor checkpoint');
    const publicEvidence = await submitEvidence(harness, sessionId, 'share-public.png', 'Public checkpoint');

    harness.setPortfolioShareMode(privateEvidence.id, 'private');
    harness.setPortfolioShareMode(cohortEvidence.id, 'cohort');
    harness.setPortfolioShareMode(familyEvidence.id, 'family');
    harness.setPortfolioShareMode(mentorEvidence.id, 'mentor', { assignedMentorRole: 'mentor' });
    harness.setPortfolioShareMode(publicEvidence.id, 'public-showcase', { publicApproved: false });

    expect(harness.canViewPortfolioEvidence('builder', privateEvidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('educator', privateEvidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('admin', privateEvidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('family', privateEvidence.id)).toBe(false);
    expect(harness.canViewPortfolioEvidence('builder', cohortEvidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('explorer', cohortEvidence.id)).toBe(false);
    expect(harness.canViewPortfolioEvidence('family', familyEvidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('mentor', familyEvidence.id)).toBe(false);
    expect(harness.canViewPortfolioEvidence('mentor', mentorEvidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('family', mentorEvidence.id)).toBe(false);
    expect(harness.canViewPortfolioEvidence('mentor', publicEvidence.id)).toBe(false);
  });

  it('UAT-H4: Public showcase moderation protects minor Learner work until Educator or Admin approval', async () => {
    const { harness, sessionId } = preparePortfolioWorkflow();
    const evidence = await submitEvidence(harness, sessionId, 'showcase-request.png', 'Showcase checkpoint');

    harness.loginAs('builder');
    const request = harness.requestPublicShowcasePublication(evidence.id);

    expect(request).toMatchObject({ status: 'pending', learnerId: getUatUser('builder').id });
    expect(harness.getPublicShowcaseEvidence()).toHaveLength(0);
    expect(harness.canViewPortfolioEvidence('mentor', evidence.id)).toBe(false);

    harness.loginAs('educator');
    const approval = harness.approvePublicShowcasePublication(request.id);

    expect(approval).toMatchObject({ status: 'approved', approvedBy: getUatUser('educator').id });
    expect(harness.getPublicShowcaseEvidence()).toEqual([evidence]);
    expect(harness.canViewPortfolioEvidence('mentor', evidence.id)).toBe(true);
    expect(harness.checkAuditLog('public-showcase.approve')).toEqual([
      expect.objectContaining({ targetId: request.id, capabilityContext: mission.capabilityDomains }),
    ]);
  });

  it('UAT-H5: Portfolio export includes selected Evidence only and excludes private or unapproved Evidence', async () => {
    const { harness, sessionId } = preparePortfolioWorkflow();
    const familyEvidence = await submitEvidence(harness, sessionId, 'export-family.png', 'Family export checkpoint');
    const mentorEvidence = await submitEvidence(harness, sessionId, 'export-mentor.png', 'Mentor export checkpoint');
    const privateEvidence = await submitEvidence(harness, sessionId, 'export-private.png', 'Private export checkpoint');
    const pendingPublicEvidence = await submitEvidence(harness, sessionId, 'export-pending-public.png', 'Pending export checkpoint');
    const unselectedEvidence = await submitEvidence(harness, sessionId, 'export-unselected.png', 'Unselected export checkpoint');

    harness.setPortfolioShareMode(familyEvidence.id, 'family');
    harness.setPortfolioShareMode(mentorEvidence.id, 'mentor', { assignedMentorRole: 'mentor' });
    harness.setPortfolioShareMode(privateEvidence.id, 'private');
    harness.setPortfolioShareMode(pendingPublicEvidence.id, 'public-showcase', { publicApproved: false });
    harness.setPortfolioShareMode(unselectedEvidence.id, 'family');

    harness.loginAs('educator');
    const exported = harness.exportPortfolioPackage('educator', 'builder', [
      familyEvidence.id,
      mentorEvidence.id,
      privateEvidence.id,
      pendingPublicEvidence.id,
    ]);

    expect(exported).toEqual({
      exportedBy: getUatUser('educator').id,
      learnerId: getUatUser('builder').id,
      evidenceIds: [familyEvidence.id, mentorEvidence.id],
    });
    expect(exported.evidenceIds).not.toContain(privateEvidence.id);
    expect(exported.evidenceIds).not.toContain(pendingPublicEvidence.id);
    expect(exported.evidenceIds).not.toContain(unselectedEvidence.id);
    expect(harness.checkAuditLog('portfolio.export')).toHaveLength(1);
  });
});
