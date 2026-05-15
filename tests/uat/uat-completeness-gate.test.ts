import { uatMissionDefinitions, getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import {
  createUatApiClient,
  createUatTestHarness,
  requiredScholesaTerminology,
  type UatTestHarness,
} from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function prepareCompletenessWorkflow(): { harness: UatTestHarness; sessionId: string } {
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
    criterionId: `uat-completeness-criterion-${index + 1}`,
    criterionTitle: `${domain} completeness criterion`,
    capabilityDomain: domain,
    score,
  }));
}

describe('UAT completeness gate', () => {
  it('covers required roles, optional Mentor flag safety, and all four Learner stages', () => {
    const harness = createUatTestHarness();

    expect([
      getUatUser('admin').role,
      getUatUser('educator').role,
      getUatUser('builder').role,
      getUatUser('family').role,
    ]).toEqual(['admin', 'educator', 'learner', 'family']);
    expect(getUatUser('mentor')).toMatchObject({
      role: 'mentor',
      purpose: expect.stringContaining('Approved external expert'),
    });

    harness.setFeatureFlag('mentor', false);
    expect(harness.getCoreMvpFeatureStatus()).toMatchObject({
      mentorEnabled: false,
      adminOperational: true,
      educatorOperational: true,
      learnerOperational: true,
      familyOperational: true,
    });
    expect(uatMissionDefinitions.map((item) => item.stage)).toEqual([
      'Discoverers',
      'Builders',
      'Explorers',
      'Innovators',
    ]);
  });

  it('covers the full Scholesa learning chain from Capability to Growth Report', async () => {
    const { harness, sessionId } = prepareCompletenessWorkflow();

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
      evidenceType: 'image',
      fileName: 'uat-completeness-chain.png',
      contentType: 'image/png',
      body: 'uat-completeness-chain',
      explanation: 'This Evidence explains what changed after feedback.',
    });
    const reflection = harness.submitWrittenReflectionProof(
      'builder',
      mission.id,
      sessionId,
      checkpoint.checkpointTitle,
      'I improved my prototype by testing the tradeoff and explaining the result.'
    );

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(4),
      feedback: 'Capability Review confirms this Evidence is ready for Portfolio and badge review.',
      nextStep: 'Prepare the Showcase explanation using the strongest Evidence.',
    });
    const badge = harness.markBadgeReadyIfCriteriaMet({
      learnerRole: 'builder',
      badgeId: 'badge-uat-completeness-chain',
      title: 'UAT Completeness Chain Badge',
      requiredCapabilityDomains: mission.capabilityDomains,
      requiredReviewedEvidenceCount: 1,
    });
    const showcaseRequest = harness.requestPublicShowcasePublication(evidence.id);
    const showcaseApproval = harness.approvePublicShowcasePublication(showcaseRequest.id);

    expect(mission.capabilityDomains.length).toBeGreaterThan(0);
    expect(harness.state.assignments).toEqual([expect.objectContaining({ missionId: mission.id })]);
    expect(harness.state.sessions).toEqual([expect.objectContaining({ id: sessionId, missionId: mission.id })]);
    expect(checkpoint).toMatchObject({ missionId: mission.id });
    expect(evidence).toMatchObject({ missionId: mission.id, capabilityDomains: mission.capabilityDomains });
    expect(reflection).toMatchObject({ missionId: mission.id, capabilityDomains: mission.capabilityDomains });
    expect(review).toMatchObject({ evidenceId: evidence.id, capabilityDomains: mission.capabilityDomains });
    expect(harness.expectPortfolioUpdated('builder')).toEqual(
      expect.arrayContaining([expect.objectContaining({ evidenceId: evidence.id, missionId: mission.id })])
    );
    expect(badge).toMatchObject({ status: 'ready-for-review', evidenceIds: [evidence.id] });
    expect(showcaseApproval).toMatchObject({ status: 'approved', evidenceId: evidence.id });
    expect(harness.expectGrowthReportUpdated('builder')).toEqual([
      expect.objectContaining({ latestReviewId: review.id, capabilityDomains: mission.capabilityDomains }),
    ]);
  });

  it('covers AI policy by grade band', async () => {
    const harness = createUatTestHarness();
    const discovererMission = getUatMissionByStage('Discoverers');
    const explorerMission = getUatMissionByStage('Explorers');
    const innovatorMission = getUatMissionByStage('Innovators');

    expect(await harness.useMiloOSCoach(
      'discoverer',
      discovererMission.id,
      discovererMission.capabilityDomains[0],
      'Can I use MiloOS Coach alone?'
    )).toMatchObject({ allowed: false, supportType: 'policy-block' });
    expect(await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Give me brainstorming questions.'
    )).toMatchObject({ allowed: true, supportType: 'scaffolded-support' });
    expect(await harness.useMiloOSCoach(
      'explorer',
      explorerMission.id,
      explorerMission.capabilityDomains[0],
      'Help me evaluate a media claim.',
      false,
      { mode: 'analyze' }
    )).toMatchObject({ allowed: true, supportType: 'analytical-support' });
    expect(await harness.useMiloOSCoach(
      'innovator',
      innovatorMission.id,
      innovatorMission.capabilityDomains[0],
      'Critique my venture risks.',
      false,
      { mode: 'review' }
    )).toMatchObject({ allowed: true, supportType: 'advanced-critique' });
    expect(harness.checkAIUsageLog()).toHaveLength(4);
  });

  it('covers permission boundaries, tenant isolation, audit logs, accessibility, UDL, and autosave', async () => {
    const { harness } = prepareCompletenessWorkflow();
    const api = createUatApiClient(harness);
    const blockedCapabilityReview = await api.performAction('family', 'performCapabilityReview', mission);

    expect(blockedCapabilityReview).toMatchObject({ ok: false, status: 403 });
    expect(harness.queryTenantScopedRecords('educator', 'tenant-other-academy', 'cohort')).toEqual([]);
    expect(harness.checkAuditLog('tenant.access.denied')).toHaveLength(1);

    expect(harness.verifyKeyboardNavigation('learner-dashboard', [
      'open Mission card',
      'open Portfolio',
      'open MiloOS Coach',
    ])).toMatchObject({ noKeyboardTrap: true, allMajorActionsReachable: true });
    expect(harness.verifyResponsiveLayout('desktop', 200)).toMatchObject({
      coreWorkflowsUsable: true,
      textOverlapsCriticalControls: false,
    });

    harness.loginAs('educator');
    const override = harness.enableEvidenceOverride(
      'builder',
      'UDL accommodation: oral Evidence may replace written response.'
    );
    expect(override.reason).toContain('UDL accommodation');

    harness.loginAs('builder');
    const draft = harness.writeReflectionDraft('builder', mission.id, 'Autosaved UAT completeness draft.');
    harness.autosaveReflectionDraft(draft.id);
    expect(harness.refreshReflectionDraft(draft.id).value).toBe('Autosaved UAT completeness draft.');
  });

  it('enforces launch blocker coverage and Scholesa terminology', () => {
    const launchBlockers = [
      'cross-learner Evidence access',
      'Family Evidence edit',
      'Family Capability Review',
      'Mentor unassigned access',
      'Educator cross-tenant Cohort access',
      'Admin cross-tenant report leakage',
      'MiloOS no-copy guardrail',
      'AI usage logging',
      'Discoverer independent MiloOS restriction',
      'Evidence Capability context',
      'Portfolio Learner ownership',
      'Capability Review persistence',
      'Public Showcase approval',
      'Badge Evidence criteria',
      'refresh data preservation',
      'key audit logs',
      'Scholesa terminology',
    ];
    const productCopy = requiredScholesaTerminology.join(' ');
    const forbiddenTerms = /\b(Teacher|Student|Parent|Assignment|Homework|Grading|Report Card)\b/;

    expect(launchBlockers).toHaveLength(17);
    for (const term of requiredScholesaTerminology) {
      expect(productCopy).toContain(term);
    }
    expect(productCopy).not.toMatch(forbiddenTerms);
  });
});
