import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser, uatSeedData, type UatLoginRole } from '../fixtures/uat-seed-data';
import { createUatTestHarness } from '../helpers';

const cohortLearnerMap: Array<{ cohortId: string; learnerRole: UatLoginRole; missionStage: Parameters<typeof getUatMissionByStage>[0] }> = [
  { cohortId: 'cohort-discoverers-1-3', learnerRole: 'discoverer', missionStage: 'Discoverers' },
  { cohortId: 'cohort-builders-4-6', learnerRole: 'builder', missionStage: 'Builders' },
  { cohortId: 'cohort-explorers-7-9', learnerRole: 'explorer', missionStage: 'Explorers' },
  { cohortId: 'cohort-innovators-10-12', learnerRole: 'innovator', missionStage: 'Innovators' },
];

describe('tenant and cohort readiness UAT', () => {
  it('UAT-B1: Admin creates tenant, organization, cohorts, learner memberships, and educator assignments', () => {
    const harness = createUatTestHarness();

    harness.loginAs('admin');
    const tenant = harness.createTenant();
    const organization = harness.createOrganization();

    for (const item of cohortLearnerMap) {
      harness.createCohort(item.cohortId);
      harness.addLearnerToCohort(item.learnerRole, item.cohortId);
      harness.assignEducatorToCohort('educator', item.cohortId);
    }

    harness.loginAs('educator');
    for (const item of cohortLearnerMap) {
      const mission = getUatMissionByStage(item.missionStage);
      harness.assignMission(mission.id, item.cohortId);
    }

    expect(tenant).toMatchObject({ id: 'tenant-summer-pilot-2026', name: 'Scholesa Summer Pilot 2026' });
    expect(organization).toMatchObject({
      id: 'org-scholesa-pilot-academy',
      name: 'Scholesa Pilot Academy',
      tenantId: tenant.id,
    });
    expect(harness.state.cohorts.map((cohort) => cohort.name)).toEqual([
      'Discoverers Grades 1-3',
      'Builders Grades 4-6',
      'Explorers Grades 7-9',
      'Innovators Grades 10-12',
    ]);

    for (const item of cohortLearnerMap) {
      const learner = getUatUser(item.learnerRole);
      const membership = harness.getActiveCohortForLearner(item.learnerRole);
      const dashboard = harness.getLearnerDashboard(item.learnerRole);
      const mission = getUatMissionByStage(item.missionStage);

      expect(membership).toMatchObject({ learnerId: learner.id, cohortId: item.cohortId, activeTo: null });
      expect(dashboard).toMatchObject({ stage: learner.stage });
      expect(dashboard.missionTitles).toContain(mission.title);
    }

    expect(harness.getEducatorCohorts('educator').map((cohort) => cohort.id).sort()).toEqual(
      uatSeedData.cohorts.map((cohort) => cohort.id).sort()
    );
    expect(harness.checkAuditLog('tenant.create')).toHaveLength(1);
    expect(harness.checkAuditLog('organization.create')).toHaveLength(1);
    expect(harness.checkAuditLog('cohort.learner.add')).toHaveLength(4);
    expect(harness.checkAuditLog('cohort.educator.assign')).toHaveLength(4);
  });

  it('UAT-B2: Cohort movement updates dashboard and new missions without destroying historical evidence', async () => {
    const harness = createUatTestHarness();
    const builderMission = getUatMissionByStage('Builders');
    const explorerMission = getUatMissionByStage('Explorers');

    harness.loginAs('admin');
    harness.createTenant();
    harness.createOrganization();
    harness.addLearnerToCohort('builder', 'cohort-builders-4-6');
    harness.assignEducatorToCohort('educator', 'cohort-builders-4-6');
    harness.assignEducatorToCohort('educator', 'cohort-explorers-7-9');

    harness.loginAs('educator');
    harness.assignMission(builderMission.id, 'cohort-builders-4-6');
    const historicalEvidence = await harness.submitEvidence('builder', builderMission.id);
    const historicalReview = harness.performCapabilityReview(
      'builder',
      builderMission.id,
      historicalEvidence.id,
      3,
      'Historical Builder evidence remains attached to the original Mission and Capability context.'
    );

    harness.loginAs('admin');
    const newMembership = harness.moveLearnerToCohort('builder', 'cohort-explorers-7-9');

    harness.loginAs('educator');
    harness.assignMission(explorerMission.id, 'cohort-explorers-7-9');
    const dashboard = harness.getLearnerDashboard('builder');

    expect(newMembership).toMatchObject({
      learnerId: getUatUser('builder').id,
      cohortId: 'cohort-explorers-7-9',
      activeTo: null,
    });
    expect(dashboard.activeCohort).toMatchObject({ cohortId: 'cohort-explorers-7-9' });
    expect(dashboard.missionTitles).toContain(explorerMission.title);
    expect(dashboard.missionTitles).not.toContain(builderMission.title);

    expect(harness.state.evidence).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: historicalEvidence.id,
          missionId: builderMission.id,
          learnerId: getUatUser('builder').id,
          capabilityDomains: builderMission.capabilityDomains,
        }),
      ])
    );
    expect(harness.state.reviews).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: historicalReview.id,
          missionId: builderMission.id,
          capabilityDomains: builderMission.capabilityDomains,
        }),
      ])
    );
    expect(harness.state.learnerCohortMemberships).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ cohortId: 'cohort-builders-4-6', activeTo: expect.any(String) }),
        expect.objectContaining({ cohortId: 'cohort-explorers-7-9', activeTo: null }),
      ])
    );
    expect(harness.expectCapabilityContextPreserved(historicalReview.id, builderMission.capabilityDomains)).toHaveLength(1);
  });

  it('UAT-B3: Tenant isolation blocks Educator A from Tenant B cohort, learner, evidence, reports, and portfolio data', async () => {
    const harness = createUatTestHarness();
    const tenantA = uatSeedData.tenant.id;
    const tenantB = 'tenant-summer-pilot-2026-b';
    const builderMission = getUatMissionByStage('Builders');

    harness.loginAs('admin');
    harness.createTenant();
    harness.createOrganization();
    harness.createCohort('cohort-builders-4-6');
    harness.addLearnerToCohort('builder', 'cohort-builders-4-6');
    harness.assignEducatorToCohort('educator', 'cohort-builders-4-6');

    harness.loginAs('educator');
    harness.assignMission(builderMission.id, 'cohort-builders-4-6');
    const evidence = await harness.submitEvidence('builder', builderMission.id);
    harness.performCapabilityReview(
      'builder',
      builderMission.id,
      evidence.id,
      3,
      'Tenant A report and Portfolio data must stay scoped to Tenant A.'
    );

    expect(harness.queryTenantScopedRecords('educator', tenantA, 'cohort')).toHaveLength(1);

    for (const recordType of ['cohort', 'learner', 'evidence', 'report', 'portfolio'] as const) {
      expect(harness.queryTenantScopedRecords('educator', tenantB, recordType)).toEqual([]);
    }

    expect(harness.state.accessDenied).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ targetId: `${tenantB}:cohort` }),
        expect.objectContaining({ targetId: `${tenantB}:learner` }),
        expect.objectContaining({ targetId: `${tenantB}:evidence` }),
        expect.objectContaining({ targetId: `${tenantB}:report` }),
        expect.objectContaining({ targetId: `${tenantB}:portfolio` }),
      ])
    );
    expect(harness.checkAuditLog('tenant.access.denied')).toHaveLength(5);
    expect(harness.state.growthReports.every((report) => report.tenantId === tenantA)).toBe(true);
    expect(harness.state.portfolio.every((item) => item.tenantId === tenantA)).toBe(true);
  });
});
