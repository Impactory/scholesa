import { getCapabilityForMissionDomain } from '../fixtures/uat-capability-graph';
import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function prepareGoldWorkflow(): { harness: UatTestHarness; sessionId: string } {
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
    criterionId: `gold-workflow-criterion-${index + 1}`,
    criterionTitle: `${domain} gold workflow criterion`,
    capabilityDomain: domain,
    score,
  }));
}

describe('Gold workflow UAT gate', () => {
  it('proves curriculum admin can define Capabilities and map them to Missions and checkpoints', () => {
    const capabilityNodes = mission.capabilityDomains.map((domain) =>
      getCapabilityForMissionDomain(domain as never, mission.stage)
    );

    expect(capabilityNodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          domain: mission.capabilityDomains[0],
          stageBand: mission.stage,
          exampleMissions: expect.arrayContaining([mission.title]),
          acceptedEvidenceTypes: expect.arrayContaining(mission.expectedEvidence),
          proofOfWorkRules: expect.arrayContaining([
            expect.stringContaining('Mission, Session, checkpoint, and Capability Review context'),
          ]),
        }),
      ])
    );
    expect(capabilityNodes.every((node) => node.rubricCriteria.length >= 4)).toBe(true);
    expect(mission.checkpointTitles.length).toBeGreaterThan(0);
  });

  it('proves Educator can run a Session and quickly log Capability observations during build time', () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const checkpoint = harness.completeCheckpoint('builder', mission.id, mission.checkpointTitles[0]);

    harness.loginAs('educator');
    const report = harness.getEducatorCohortGrowthReport({
      cohortId: buildersCohortId,
      missionId: mission.id,
      checkpointCompletion: 'complete',
      includeEvidenceGaps: true,
    });

    expect(harness.state.sessions).toEqual([
      expect.objectContaining({ id: sessionId, status: 'open', missionId: mission.id }),
    ]);
    expect(checkpoint).toMatchObject({ checkpointTitle: mission.checkpointTitles[0] });
    expect(report).toMatchObject({
      checkpointCompletionCount: 1,
      actionItems: [expect.objectContaining({ reason: expect.stringContaining('missing artifact') })],
    });
  });

  it('proves Learner can submit artifacts, reflections, and checkpoint Evidence', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const checkpoint = harness.completeCheckpoint('builder', mission.id, mission.checkpointTitles[1]);
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: checkpoint.checkpointTitle,
      evidenceType: 'prototype-link',
      fileName: 'gold-artifact.json',
      contentType: 'application/json',
      body: JSON.stringify({ artifact: 'gold-workflow' }),
      explanation: 'This artifact explains what I built and why it matters.',
      links: ['https://scholesa.test/gold/artifact'],
    });
    const reflection = harness.submitWrittenReflectionProof(
      'builder',
      mission.id,
      sessionId,
      checkpoint.checkpointTitle,
      'My reflection explains what changed after feedback and what I will improve next.'
    );

    expect(evidence).toMatchObject({
      checkpointTitle: checkpoint.checkpointTitle,
      capabilityDomains: mission.capabilityDomains,
      status: 'submitted',
    });
    expect(reflection).toMatchObject({
      checkpointTitle: checkpoint.checkpointTitle,
      capabilityDomains: mission.capabilityDomains,
    });
  });

  it('proves Educator can apply a four-level rubric tied to Capabilities and process domains', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[2],
      evidenceType: 'image',
      fileName: 'gold-rubric.png',
      contentType: 'image/png',
      body: 'gold-rubric',
      explanation: 'This Evidence is ready for a four-level Capability Review.',
    });

    harness.loginAs('educator');
    const rubricScore = harness.scoreEvidenceRubric(evidence.id, 4);
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(4),
      feedback: 'The four-level Capability Review is grounded in artifact quality and explanation.',
      nextStep: 'Transfer this process to the next prototype decision.',
    });

    expect(rubricScore).toEqual({ evidenceId: evidence.id, score: 4 });
    expect(review.criterionScores).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ capabilityDomain: mission.capabilityDomains[0], score: 4 }),
      ])
    );
    expect(harness.checkAuditLog('rubric.score')).toHaveLength(1);
  });

  it('proves proof-of-learning can be captured and reviewed', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const proofValidation = harness.validateProofOfWork({
      explanation: 'I can explain why this prototype changed and what Evidence proves it.',
    });
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[0],
      evidenceType: 'video-link',
      fileName: 'gold-proof-video.json',
      contentType: 'application/json',
      body: JSON.stringify({ video: 'explain-it-back' }),
      explanation: 'Explain-it-back proof shows how my prototype changed after feedback.',
      links: ['https://scholesa.test/gold/proof-video'],
    });

    harness.loginAs('educator');
    const review = harness.performCapabilityReview(
      'builder',
      mission.id,
      evidence.id,
      3,
      'Proof-of-learning reviewed with Capability context intact.'
    );

    expect(proofValidation).toEqual({ ok: true });
    expect(review).toMatchObject({ evidenceId: evidence.id, capabilityDomains: mission.capabilityDomains });
  });

  it('proves Capability growth updates over time from reviewed Evidence', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const firstEvidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[0],
      evidenceType: 'image',
      fileName: 'gold-growth-first.png',
      contentType: 'image/png',
      body: 'gold-growth-first',
      explanation: 'First Evidence shows an early prototype decision.',
    });
    const secondEvidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[1],
      evidenceType: 'image',
      fileName: 'gold-growth-second.png',
      contentType: 'image/png',
      body: 'gold-growth-second',
      explanation: 'Second Evidence shows a stronger decision after feedback.',
    });

    harness.loginAs('educator');
    const firstReview = harness.performCapabilityReview('builder', mission.id, firstEvidence.id, 2, 'Early growth evidence.');
    const secondReview = harness.performCapabilityReview('builder', mission.id, secondEvidence.id, 4, 'Later growth evidence.');

    expect(harness.expectGrowthReportUpdated('builder')).toEqual([
      expect.objectContaining({ latestReviewId: firstReview.id }),
      expect.objectContaining({ latestReviewId: secondReview.id }),
    ]);
  });

  it('proves Portfolio shows real artifacts, reflections, feedback, and best Evidence views', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[0],
      evidenceType: 'prototype-link',
      fileName: 'gold-portfolio.json',
      contentType: 'application/json',
      body: JSON.stringify({ portfolio: true }),
      explanation: 'Portfolio artifact shows prototype Evidence.',
      links: ['https://scholesa.test/gold/portfolio'],
    });
    const reflection = harness.submitWrittenReflectionProof(
      'builder',
      mission.id,
      sessionId,
      mission.checkpointTitles[0],
      'Portfolio reflection explains what this Evidence proves.'
    );

    harness.loginAs('educator');
    const review = harness.performCapabilityReview('builder', mission.id, evidence.id, 4, 'Portfolio feedback is visible.');
    const views = harness.getPortfolioViews('builder');

    expect(views.timelineView).toEqual(expect.arrayContaining([
      expect.objectContaining({ evidenceId: reflection.id }),
      expect.objectContaining({ evidenceId: evidence.id }),
    ]));
    expect(views.bestEvidenceView).toEqual([
      expect.objectContaining({ evidenceId: evidence.id, score: review.score }),
    ]);
    expect(views.feedback).toEqual([review]);
  });

  it('proves Ideation Passport and Growth Report exports are generated from selected Evidence', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[2],
      evidenceType: 'prototype-link',
      fileName: 'gold-passport.json',
      contentType: 'application/json',
      body: JSON.stringify({ passport: true }),
      explanation: 'Selected Evidence for Ideation Passport and Growth Report export.',
      links: ['https://scholesa.test/gold/passport'],
    });

    harness.loginAs('educator');
    harness.performCapabilityReview('builder', mission.id, evidence.id, 4, 'Export-ready reviewed Evidence.');
    harness.setPortfolioShareMode(evidence.id, 'family');
    const portfolioPackage = harness.exportPortfolioPackage('builder', 'builder', [evidence.id]);
    const growthReport = harness.exportGrowthReport({
      actorRole: 'educator',
      learnerRole: 'builder',
      format: 'pdf',
      selectedEvidenceIds: [evidence.id],
    });

    expect(portfolioPackage).toMatchObject({
      exportedBy: getUatUser('builder').id,
      learnerId: getUatUser('builder').id,
      evidenceIds: [evidence.id],
    });
    expect(growthReport).toMatchObject({ format: 'pdf', tenantId: getUatUser('builder').tenantId });
    expect(growthReport.rows).toEqual([
      expect.objectContaining({ evidenceId: evidence.id, missionId: mission.id, score: 4 }),
    ]);
  });

  it('proves AI-use is disclosed and visible for relevant Evidence', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const coachResponse = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Give me questions that help me improve my prototype.',
      false,
      { sessionId }
    );
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Optional AI-use summary if MiloOS Coach was used',
      evidenceType: 'written-reflection',
      fileName: 'gold-ai-disclosure.txt',
      contentType: 'text/plain',
      body: 'AI-use disclosure',
      explanation: 'I used MiloOS Coach for questions, then changed my prototype explanation myself.',
      aiUseSummary: {
        promptUsed: 'Give me questions that help me improve my prototype.',
        coachSuggestion: coachResponse.message,
        learnerChanged: 'I added my own explanation of the design tradeoff.',
      },
    });
    harness.linkAIUsageToSubmission(coachResponse.auditEventId, evidence.id);

    harness.loginAs('educator');
    const logs = harness.getEducatorAIUsageLogsForEvidence(evidence.id);

    expect(evidence.aiUseSummary).toMatchObject({ learnerChanged: expect.stringContaining('my own explanation') });
    expect(logs).toEqual([expect.objectContaining({ submissionId: evidence.id, allowed: true })]);
    expect(harness.checkAuditLog('miloos-coach.use')).toHaveLength(1);
  });

  it('proves Family, Educator, and Admin views are understandable and trustworthy', async () => {
    const { harness, sessionId } = prepareGoldWorkflow();

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: mission.checkpointTitles[0],
      evidenceType: 'image',
      fileName: 'gold-trust.png',
      contentType: 'image/png',
      body: 'gold-trust',
      explanation: 'Trustworthy view Evidence for Family, Educator, and Admin.',
    });

    harness.loginAs('educator');
    harness.performCapabilityReview('builder', mission.id, evidence.id, 3, 'Published growth summary is Evidence-based.');
    harness.createSharedMilestone('builder', mission.id, 'Evidence-based Capability growth milestone');
    harness.publishGrowthSummaryForFamily('builder', mission.id, 'Growth Summary cites reviewed Evidence and next steps.');
    harness.setPortfolioShareMode(evidence.id, 'family');
    const educatorReport = harness.getEducatorCohortGrowthReport({
      cohortId: buildersCohortId,
      missionId: mission.id,
      includeEvidenceGaps: true,
      includeBadgeReadiness: true,
      includeAIUsage: true,
    });

    harness.loginAs('family');
    const familyView = harness.getFamilyLinkedLearnerProgress('family', 'builder');

    harness.loginAs('admin');
    const adminReport = harness.getAdminPlatformReport();

    expect(familyView).toMatchObject({
      allowed: true,
      publishedGrowthSummary: expect.objectContaining({ summary: expect.stringContaining('reviewed Evidence') }),
      selectedPortfolioHighlights: [expect.objectContaining({ evidenceId: evidence.id })],
    });
    expect(educatorReport).toMatchObject({ evidenceSubmissionCount: 1, learnerIds: [getUatUser('builder').id] });
    expect(adminReport).toMatchObject({
      tenantId: getUatUser('admin').tenantId,
      evidenceSubmissionCount: 1,
      capabilityGrowth: expect.arrayContaining([
        expect.objectContaining({ capabilityDomain: mission.capabilityDomains[0], reviewCount: 1 }),
      ]),
    });
  });
});
