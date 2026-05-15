import { getCapabilityForMissionDomain } from '../fixtures/uat-capability-graph';
import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';
import type { MissionSessionBlock } from '../helpers/uat-state';

const buildersCohortId = 'cohort-builders-4-6';
const builderMission = getUatMissionByStage('Builders');
const defaultSessionBlocks: MissionSessionBlock[] = [
  'Hook',
  'Micro-skill',
  'Build sprint',
  'Retrieval and transfer',
  'Showcase and reflection',
  'Home connection',
];

function prepareBuildersMission(): UatTestHarness {
  const harness = createUatTestHarness();

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort('builder', buildersCohortId);
  harness.assignEducatorToCohort('educator', buildersCohortId);

  harness.loginAs('educator');
  harness.assignMission(builderMission.id, buildersCohortId);

  return harness;
}

describe('mission and Session delivery UAT', () => {
  it('UAT-D1: Learner completes Eco-Smart City Lab Session blocks and progress persists', () => {
    const harness = prepareBuildersMission();

    harness.loginAs('educator');
    const session = harness.openMissionSession(builderMission.id, buildersCohortId);

    harness.loginAs('builder');

    for (const block of defaultSessionBlocks) {
      harness.saveSessionBlockProgress('builder', builderMission.id, session.id, block);
    }

    const progressBeforeRefresh = harness.getLearnerSessionProgress('builder', builderMission.id);
    const progressAfterRefresh = harness.getLearnerSessionProgress('builder', builderMission.id);
    const educatorProgress = harness.getEducatorCheckpointProgress(buildersCohortId, builderMission.id);

    expect(progressBeforeRefresh.map((progress) => progress.block)).toEqual(defaultSessionBlocks);
    expect(progressAfterRefresh).toEqual(progressBeforeRefresh);
    expect(educatorProgress).toHaveLength(defaultSessionBlocks.length);

    for (const progress of progressAfterRefresh) {
      expect(progress).toMatchObject({ status: 'saved', capabilityDomains: builderMission.capabilityDomains });
      expect(harness.expectCapabilityContextPreserved(progress.id, builderMission.capabilityDomains)).toHaveLength(1);
    }
  });

  it('UAT-D2: Educator assigns Eco-Smart City Lab only to Builders Cohort and Learner sees stage language', () => {
    const harness = createUatTestHarness();

    harness.loginAs('admin');
    harness.createTenant();
    harness.createOrganization();
    harness.addLearnerToCohort('builder', buildersCohortId);
    harness.addLearnerToCohort('discoverer', 'cohort-discoverers-1-3');
    harness.assignEducatorToCohort('educator', buildersCohortId);

    harness.loginAs('educator');
    const assignment = harness.assignMission(builderMission.id, buildersCohortId);

    const builderDashboard = harness.getLearnerDashboard('builder');
    const discovererDashboard = harness.getLearnerDashboard('discoverer');

    expect(assignment).toMatchObject({ cohortId: buildersCohortId, missionId: builderMission.id });
    expect(builderDashboard.missionTitles).toContain('Eco-Smart City Lab');
    expect(builderDashboard.stage).toBe('Builders');
    expect(builderMission.grades).toBe('4-6');
    expect(discovererDashboard.missionTitles).not.toContain('Eco-Smart City Lab');
  });

  it('UAT-D3: Educator reorders Sessions without breaking existing Evidence continuity', async () => {
    const harness = prepareBuildersMission();
    const originalEvidence = await harness.submitEvidence('builder', builderMission.id);
    const originalCapabilityDomains = [...originalEvidence.capabilityDomains];
    const reorderedBlocks: MissionSessionBlock[] = [
      'Hook',
      'Build sprint',
      'Micro-skill',
      'Retrieval and transfer',
      'Showcase and reflection',
      'Home connection',
    ];

    harness.loginAs('educator');
    harness.reorderMissionSessions(builderMission.id, reorderedBlocks);

    harness.loginAs('builder');
    expect(harness.getMissionSessionOrder(builderMission.id)).toEqual(reorderedBlocks);

    const evidenceAfterReorder = harness.state.evidence.find((item) => item.id === originalEvidence.id);

    expect(evidenceAfterReorder).toMatchObject({
      id: originalEvidence.id,
      missionId: builderMission.id,
      capabilityDomains: originalCapabilityDomains,
    });
    expect(harness.expectCapabilityContextPreserved(builderMission.id, builderMission.capabilityDomains)).toHaveLength(1);
  });

  it('UAT-D4: Optional stretch challenge unlock maps Evidence to Capability Graph and Portfolio', async () => {
    const harness = prepareBuildersMission();

    harness.loginAs('educator');
    const challenge = harness.unlockStretchChallenge(
      builderMission.id,
      buildersCohortId,
      'Eco-Smart Sensor Stretch Challenge'
    );

    harness.loginAs('builder');
    const learnerChallenges = harness.getStretchChallengesForLearner('builder', builderMission.id);
    const stretchEvidence = await harness.submitStretchEvidence('builder', builderMission.id, challenge.id);
    const portfolioItems = harness.expectPortfolioUpdated('builder');

    for (const domain of stretchEvidence.capabilityDomains) {
      expect(getCapabilityForMissionDomain(domain as Parameters<typeof getCapabilityForMissionDomain>[0], 'Builders'))
        .toMatchObject({ domain, stageBand: 'Builders' });
    }

    expect(learnerChallenges).toEqual([challenge]);
    expect(stretchEvidence.capabilityDomains).toEqual(builderMission.capabilityDomains);
    expect(portfolioItems).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ evidenceId: stretchEvidence.id, capabilityDomains: builderMission.capabilityDomains }),
      ])
    );
    expect(harness.expectCapabilityContextPreserved(challenge.id, builderMission.capabilityDomains).length)
      .toBeGreaterThanOrEqual(1);
  });

  it('UAT-D5: Home Connection is visible to Learner and shared Family, while Family cannot edit official Evidence', () => {
    const harness = prepareBuildersMission();

    harness.loginAs('educator');
    const homeConnection = harness.publishHomeConnection(
      builderMission.id,
      buildersCohortId,
      'Eco-Smart City Home Connection',
      true
    );

    const learnerHomeConnections = harness.getHomeConnectionsForLearner('builder', builderMission.id);
    const familyHomeConnections = harness.getHomeConnectionsForFamily('family', 'builder', builderMission.id);

    harness.expectAccessDenied(
      'family',
      'official-learning-evidence-edit',
      getUatUser('family').restriction ?? 'Family cannot edit official learning evidence.'
    );

    expect(learnerHomeConnections).toEqual([homeConnection]);
    expect(familyHomeConnections).toEqual([homeConnection]);
    expect(harness.state.accessDenied).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ targetId: 'official-learning-evidence-edit' }),
      ])
    );
    expect(harness.expectCapabilityContextPreserved(homeConnection.id, builderMission.capabilityDomains)).toHaveLength(1);
  });
});
