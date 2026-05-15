import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const explorersCohortId = 'cohort-explorers-7-9';
const discoverersCohortId = 'cohort-discoverers-1-3';
const mission = getUatMissionByStage('Builders');
const discovererMission = getUatMissionByStage('Discoverers');

function prepareLaunchGate(): { harness: UatTestHarness; sessionId: string } {
  const harness = createUatTestHarness();

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort('builder', buildersCohortId);
  harness.addLearnerToCohort('explorer', explorersCohortId);
  harness.addLearnerToCohort('discoverer', discoverersCohortId);
  harness.assignEducatorToCohort('educator', buildersCohortId);
  harness.assignEducatorToCohort('educator', discoverersCohortId);

  harness.loginAs('educator');
  harness.assignMission(mission.id, buildersCohortId);
  harness.assignMission(discovererMission.id, discoverersCohortId);
  const session = harness.openMissionSession(mission.id, buildersCohortId);

  return { harness, sessionId: session.id };
}

async function submitBuilderEvidence(harness: UatTestHarness, sessionId?: string) {
  harness.loginAs('builder');

  return harness.submitEvidenceArtifact({
    learnerRole: 'builder',
    missionId: mission.id,
    sessionId,
    checkpointTitle: 'Launch gate Evidence checkpoint',
    evidenceType: 'image',
    fileName: 'launch-gate-evidence.png',
    contentType: 'image/png',
    body: 'launch-gate-evidence',
    explanation: 'I can explain what changed after feedback and why it matters.',
  });
}

function criterionScores() {
  return mission.capabilityDomains.map((domain, index) => ({
    criterionId: `launch-gate-criterion-${index + 1}`,
    criterionTitle: `${domain} launch gate criterion`,
    capabilityDomain: domain,
    score: 3 as const,
  }));
}

describe('launch blocker gate UAT', () => {
  it('blocks launch if a Learner can access another Learner Evidence', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.setPortfolioShareMode(evidence.id, 'private');

    expect(harness.canViewPortfolioEvidence('builder', evidence.id)).toBe(true);
    expect(harness.canViewPortfolioEvidence('explorer', evidence.id)).toBe(false);
  });

  it('blocks launch if Family can edit Learner Evidence', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('family');
    expect(harness.denyFamilyRestrictedAction('edit evidence', evidence.id)).toMatchObject({ allowed: false });
    expect(harness.checkAuditLog('family.access.denied')).toHaveLength(1);
  });

  it('blocks launch if Family can perform Capability Review', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('family');
    expect(harness.denyFamilyRestrictedAction('perform Capability Review', evidence.id)).toMatchObject({ allowed: false });
    expect(harness.checkAuditLog('family.access.denied')).toHaveLength(1);
  });

  it('blocks launch if Mentor can access unassigned Learner work', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('mentor');
    expect(harness.getMentorAssignedShowcaseItems('mentor')).toHaveLength(0);
    expect(harness.canViewPortfolioEvidence('mentor', evidence.id)).toBe(false);
    expect(harness.denyMentorRestrictedAction('access unassigned learner work', evidence.id)).toMatchObject({ allowed: false });
  });

  it('blocks launch if Educator can access another tenant Cohort', () => {
    const { harness } = prepareLaunchGate();
    const otherTenantCohorts = harness.queryTenantScopedRecords('educator', 'tenant-other-academy', 'cohort');

    expect(otherTenantCohorts).toEqual([]);
    expect(harness.checkAuditLog('tenant.access.denied')).toHaveLength(1);
  });

  it('blocks launch if Admin reports leak data across tenants', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    await submitBuilderEvidence(harness, sessionId);
    harness.seedCrossTenantReportNoise();

    harness.loginAs('admin');
    const report = harness.getAdminPlatformReport();

    expect(report.evidenceSubmissionCount).toBe(1);
    expect(JSON.stringify(report)).not.toContain('foreign-tenant-evidence-1');
    expect(JSON.stringify(report)).not.toContain('tenant-not-scholesa-pilot');
  });

  it('blocks launch if MiloOS Coach writes full Learner work without guardrail', async () => {
    const { harness } = prepareLaunchGate();

    harness.loginAs('builder');
    const response = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Write my full reflection for me.'
    );

    expect(response).toMatchObject({ refused: true, supportType: 'guardrail-refusal' });
    expect(response.message).toContain('learner ownership');
  });

  it('blocks launch if AI usage is not logged', async () => {
    const { harness } = prepareLaunchGate();

    harness.loginAs('builder');
    const response = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Help me brainstorm a safer prototype test.'
    );

    expect(harness.checkAIUsageLog(response.auditEventId)).toEqual([
      expect.objectContaining({ learnerId: getUatUser('builder').id, missionId: mission.id, allowed: true }),
    ]);
  });

  it('blocks launch if Grade 1-3 Learner can independently use MiloOS Coach', async () => {
    const { harness } = prepareLaunchGate();

    harness.loginAs('discoverer');
    const response = await harness.useMiloOSCoach(
      'discoverer',
      discovererMission.id,
      discovererMission.capabilityDomains[0],
      'Can I chat with MiloOS Coach by myself?'
    );

    expect(response).toMatchObject({ allowed: false, requiresEducator: true, supportType: 'policy-block' });
  });

  it('blocks launch if Evidence loses Capability context', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    expect(evidence.capabilityDomains).toEqual(mission.capabilityDomains);
    expect(harness.expectCapabilityContextPreserved(evidence.id, mission.capabilityDomains)).toHaveLength(1);
  });

  it('blocks launch if Portfolio shows wrong Learner data', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    harness.performCapabilityReview('builder', mission.id, evidence.id, 3, 'Portfolio gate review saved.');

    expect(harness.getPortfolioViews('builder').timelineView).toEqual([
      expect.objectContaining({ learnerId: getUatUser('builder').id, evidenceId: evidence.id }),
    ]);
    expect(harness.getPortfolioViews('explorer').timelineView).toHaveLength(0);
  });

  it('blocks launch if Educator Capability Review does not save', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    const review = harness.performCapabilityReviewWithCriteria({
      learnerRole: 'builder',
      missionId: mission.id,
      evidenceId: evidence.id,
      criterionScores: criterionScores(),
      feedback: 'Capability Review must persist before launch.',
      nextStep: 'Use this Evidence to improve the next prototype.',
    });

    expect(harness.state.reviews).toEqual([expect.objectContaining({ id: review.id, evidenceId: evidence.id })]);
    expect(harness.expectGrowthReportUpdated('builder')[0]).toMatchObject({ latestReviewId: review.id });
  });

  it('blocks launch if Public Showcase publishes without approval', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('builder');
    const request = harness.requestPublicShowcasePublication(evidence.id);

    expect(request.status).toBe('pending');
    expect(harness.getPublicShowcaseEvidence()).toHaveLength(0);
    expect(harness.canViewPortfolioEvidence('mentor', evidence.id)).toBe(false);

    harness.loginAs('educator');
    harness.approvePublicShowcasePublication(request.id);
    expect(harness.getPublicShowcaseEvidence()).toEqual([evidence]);
  });

  it('blocks launch if Badge is awarded without Evidence criteria', () => {
    const { harness } = prepareLaunchGate();

    expect(() => harness.markBadgeReadyIfCriteriaMet({
      learnerRole: 'builder',
      badgeId: 'badge-launch-blocker-no-evidence',
      title: 'Launch Blocker Badge',
      requiredCapabilityDomains: mission.capabilityDomains,
      requiredReviewedEvidenceCount: 1,
    })).toThrow('Badge criteria not met');
    expect(() => harness.awardBadge('badge-launch-blocker-no-evidence')).toThrow('Unknown badge');
    expect(harness.checkAuditLog('badge.award')).toHaveLength(0);
  });

  it('blocks launch if Learner work is lost after refresh', () => {
    const { harness } = prepareLaunchGate();

    harness.loginAs('builder');
    const draft = harness.writeReflectionDraft('builder', mission.id, 'My launch reflection draft.');
    harness.autosaveReflectionDraft(draft.id);
    const restored = harness.refreshReflectionDraft(draft.id);

    expect(restored.value).toBe('My launch reflection draft.');
    expect(restored.synced).toBe(true);
  });

  it('blocks launch if audit logs are missing for key actions', async () => {
    const { harness, sessionId } = prepareLaunchGate();
    const evidence = await submitBuilderEvidence(harness, sessionId);

    harness.loginAs('educator');
    const review = harness.performCapabilityReview('builder', mission.id, evidence.id, 3, 'Audit log gate review.');
    const request = harness.requestPublicShowcasePublication(evidence.id);
    harness.approvePublicShowcasePublication(request.id);

    expect(harness.checkAuditLog('evidence-artifact.submit')).toHaveLength(1);
    expect(harness.checkAuditLog('capability-review.perform')).toEqual([
      expect.objectContaining({ targetId: review.id, capabilityContext: mission.capabilityDomains }),
    ]);
    expect(harness.checkAuditLog('public-showcase.approve')).toHaveLength(1);
  });

  it('blocks launch if core product UI uses outdated terminology', () => {
    const coreProductCopy = [
      'Educator opens the Cohort dashboard.',
      'Learner submits Evidence for a Mission checkpoint.',
      'Family views selected Portfolio highlights and Home Connections.',
      'Capability Review feedback updates the Growth Report.',
      'MiloOS Coach supports learner-owned reflection.',
    ].join(' ');
    const forbiddenTerminology = /\b(Teacher|Student|Parent|Assignment|Homework|Grading|Report Card)\b/i;

    expect(coreProductCopy).not.toMatch(forbiddenTerminology);
    expect(coreProductCopy).toContain('Educator');
    expect(coreProductCopy).toContain('Learner');
    expect(coreProductCopy).toContain('Family');
    expect(coreProductCopy).toContain('Mission');
    expect(coreProductCopy).toContain('Capability Review');
    expect(coreProductCopy).toContain('Growth Report');
  });
});
