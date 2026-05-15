import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function criterionScores(score: 1 | 2 | 3 | 4 = 3) {
  return mission.capabilityDomains.map((domain, index) => ({
    criterionId: `criterion-${index + 1}`,
    criterionTitle: `${domain} report criterion`,
    capabilityDomain: domain,
    score,
  }));
}

function prepareReportingWorkflow(): { harness: UatTestHarness; sessionId: string } {
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

async function createReportEvidenceSet(harness: UatTestHarness, sessionId: string) {
  harness.loginAs('builder');
  await harness.useMiloOSCoach(
    'builder',
    mission.id,
    mission.capabilityDomains[0],
    'Help me compare evidence for my eco-smart city report.',
    false,
    { sessionId }
  );
  harness.completeCheckpoint('builder', mission.id, mission.checkpointTitles[0]);

  const evidenceItems = await Promise.all(
    mission.checkpointTitles.map((checkpointTitle, index) =>
      harness.submitEvidenceArtifact({
        learnerRole: 'builder',
        missionId: mission.id,
        sessionId,
        checkpointTitle,
        evidenceType: 'image',
        fileName: `report-evidence-${index + 1}.png`,
        contentType: 'image/png',
        body: `report-evidence-${index + 1}`,
        explanation: `I can explain how ${checkpointTitle} shows my capability growth.`,
      })
    )
  );

  harness.loginAs('educator');
  const reviews = evidenceItems.map((evidence, index) =>
    harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(index === 2 ? 4 : 3),
      feedback: `Report feedback ${index + 1}: use this Evidence to decide the next prototype move.`,
      nextStep: `Report next step ${index + 1}: connect the finding to ${mission.capabilityDomains[index % mission.capabilityDomains.length]}.`,
    })
  );
  const badge = harness.markBadgeReadyIfCriteriaMet({
    learnerRole: 'builder',
    badgeId: 'badge-reporting-eco-growth',
    title: 'Reporting Eco Growth',
    requiredCapabilityDomains: mission.capabilityDomains,
    requiredReviewedEvidenceCount: 3,
  });
  harness.assignMentorToShowcase(evidenceItems[2].id, 'mentor');
  harness.seedCrossTenantReportNoise();

  return { evidenceItems, reviews, badge };
}

describe('reporting and analytics UAT', () => {
  it('UAT-K1: Educator Cohort Growth Report filters by Mission, Capability, checkpoint completion, gaps, badge readiness, and AI usage', async () => {
    const { harness, sessionId } = prepareReportingWorkflow();
    const { evidenceItems, badge } = await createReportEvidenceSet(harness, sessionId);

    harness.loginAs('educator');
    const report = harness.getEducatorCohortGrowthReport({
      cohortId: buildersCohortId,
      missionId: mission.id,
      capabilityDomain: mission.capabilityDomains[0],
      checkpointCompletion: 'complete',
      includeEvidenceGaps: true,
      includeBadgeReadiness: true,
      includeAIUsage: true,
    });

    expect(report).toMatchObject({
      tenantId: getUatUser('educator').tenantId,
      cohortId: buildersCohortId,
      missionId: mission.id,
      capabilityDomain: mission.capabilityDomains[0],
      learnerIds: [getUatUser('builder').id],
      evidenceSubmissionCount: evidenceItems.length,
      checkpointCompletionCount: 1,
      aiUsageCount: 1,
    });
    expect(report.evidenceGaps).toEqual([
      expect.objectContaining({
        learnerId: getUatUser('builder').id,
        missing: expect.arrayContaining(['missing reflection', 'missing AI-use summary', 'incomplete checkpoint']),
      }),
    ]);
    expect(report.badgeReadiness).toEqual([badge]);
    expect(report.actionItems).toEqual([
      expect.objectContaining({ learnerId: getUatUser('builder').id, reason: expect.stringContaining('missing reflection') }),
    ]);
  });

  it('UAT-K2: Admin platform report is tenant-scoped, exportable, and excludes cross-tenant noise', async () => {
    const { harness, sessionId } = prepareReportingWorkflow();
    const { evidenceItems, badge } = await createReportEvidenceSet(harness, sessionId);

    harness.loginAs('admin');
    const report = harness.getAdminPlatformReport();
    const exported = harness.exportAdminPlatformReport('csv');

    expect(report.tenantId).toBe(getUatUser('admin').tenantId);
    expect(report.learnerProgress).toEqual(
      expect.arrayContaining([expect.objectContaining({ learnerId: getUatUser('builder').id })])
    );
    expect(report.cohortProgress).toEqual(
      expect.arrayContaining([expect.objectContaining({ cohortId: buildersCohortId, assignedMissionCount: 1, openSessionCount: 1 })])
    );
    expect(report.capabilityGrowth).toEqual(
      mission.capabilityDomains.map((domain) => expect.objectContaining({ capabilityDomain: domain, reviewCount: 3 }))
    );
    expect(report.evidenceSubmissionCount).toBe(evidenceItems.length);
    expect(report.aiUsageCount).toBe(1);
    expect(report.badgeReadiness).toEqual([badge]);
    expect(report.showcaseReadiness).toEqual([
      expect.objectContaining({ evidenceId: evidenceItems[2].id, status: 'assigned' }),
    ]);
    expect(JSON.stringify(report)).not.toContain('foreign-tenant-evidence-1');
    expect(exported).toMatchObject({
      exportedBy: getUatUser('admin').id,
      format: 'csv',
      tenantId: getUatUser('admin').tenantId,
    });
    expect(exported.rows).toEqual(
      expect.arrayContaining([
        { metric: 'evidenceSubmissionCount', value: evidenceItems.length },
        { metric: 'aiUsageCount', value: 1 },
        { metric: 'badgeReadiness', value: 1 },
      ])
    );
    expect(JSON.stringify(exported)).not.toContain('tenant-not-scholesa-pilot');
  });

  it('UAT-K3: Growth Report export is accurate and excludes private or unauthorized Evidence', async () => {
    const { harness, sessionId } = prepareReportingWorkflow();
    const { evidenceItems } = await createReportEvidenceSet(harness, sessionId);

    harness.setPortfolioShareMode(evidenceItems[0].id, 'family');
    harness.setPortfolioShareMode(evidenceItems[1].id, 'private');
    harness.setPortfolioShareMode(evidenceItems[2].id, 'public-showcase', { publicApproved: false });

    harness.loginAs('educator');
    const exported = harness.exportGrowthReport({
      actorRole: 'educator',
      learnerRole: 'builder',
      format: 'pdf',
      selectedEvidenceIds: evidenceItems.map((evidence) => evidence.id),
    });

    expect(exported).toMatchObject({
      exportedBy: getUatUser('educator').id,
      format: 'pdf',
      tenantId: getUatUser('builder').tenantId,
      excludedEvidenceIds: [evidenceItems[1].id, evidenceItems[2].id],
    });
    expect(exported.rows).toEqual([
      expect.objectContaining({
        learnerId: getUatUser('builder').id,
        evidenceId: evidenceItems[0].id,
        missionId: mission.id,
        score: 3,
        capabilityDomains: mission.capabilityDomains.join('|'),
      }),
    ]);
    expect(JSON.stringify(exported)).not.toContain(evidenceItems[1].artifact.url);
    expect(JSON.stringify(exported)).not.toContain(evidenceItems[2].artifact.url);
    expect(harness.checkAuditLog('growth-report.export')).toHaveLength(1);
  });
});
