import {
  getCapabilitiesByDomain,
  getCapabilityForMissionDomain,
  uatCapabilityDomains,
  uatCapabilityGraph,
  type UatCapabilityDomain,
} from '../fixtures/uat-capability-graph';
import { uatMissionDefinitions, type UatMissionDefinition } from '../fixtures/uat-missions';
import { createUatTestHarness } from '../helpers';

const stageOrder = ['Discoverers', 'Builders', 'Explorers', 'Innovators'] as const;

function expectCompleteCapabilityMetadata(domain: UatCapabilityDomain): void {
  const capabilities = getCapabilitiesByDomain(domain);

  expect(capabilities).toHaveLength(4);

  for (const capability of capabilities) {
    expect(capability.capabilityId).toMatch(/^cap-/);
    expect(capability.name).toContain(domain);
    expect(capability.domain).toBe(domain);
    expect(capability.description).toContain(capability.stageBand);
    expect(capability.stageBand).toEqual(expect.stringMatching(/Discoverers|Builders|Explorers|Innovators/));
    expect(capability.prerequisites).toBeDefined();
    expect(capability.progressionLevel).toBeGreaterThanOrEqual(1);
    expect(capability.observableLearnerBehaviors.length).toBeGreaterThan(0);
    expect(capability.educatorLookFors.length).toBeGreaterThan(0);
    expect(capability.acceptedEvidenceTypes.length).toBeGreaterThan(0);
    expect(capability.proofOfWorkRules.length).toBeGreaterThan(0);
    expect(capability.rubricCriteria.length).toBeGreaterThan(0);
    expect(capability.badgeMapping).toContain(domain);
    expect(capability.exampleMissions.length).toBeGreaterThan(0);
    expect(capability.learnerFacingICanStatement).toMatch(/^I can /);
  }
}

describe('Capability Graph integrity UAT', () => {
  it('UAT-C1: Capability domains load with complete Admin and Educator-visible metadata', () => {
    expect(uatCapabilityDomains).toEqual([
      'Technical fluency',
      'Research and analysis',
      'Creation and communication',
      'Leadership and venture',
    ]);

    for (const domain of uatCapabilityDomains) {
      expectCompleteCapabilityMetadata(domain);
    }

    const adminVisibleGraph = uatCapabilityGraph;
    const educatorVisibleGraph = uatCapabilityGraph;

    expect(adminVisibleGraph).toHaveLength(16);
    expect(educatorVisibleGraph).toHaveLength(16);
    expect(uatCapabilityGraph.every((capability) => capability.learnerFacingICanStatement.length <= 120))
      .toBe(true);
  });

  it('UAT-C2: Missions and checkpoints are tagged to capabilities or evidence requirements', () => {
    for (const mission of uatMissionDefinitions) {
      expect(mission.capabilityDomains.length).toBeGreaterThan(0);

      for (const domain of mission.capabilityDomains as UatCapabilityDomain[]) {
        const capability = getCapabilityForMissionDomain(domain, mission.stage);

        expect(capability.exampleMissions).toContain(mission.title);
        expect(capability.acceptedEvidenceTypes).toEqual(
          expect.arrayContaining(mission.expectedEvidence)
        );
      }

      for (const checkpointTitle of mission.checkpointTitles) {
        const mapsToCapability = mission.capabilityDomains.some((domain) =>
          getCapabilityForMissionDomain(domain as UatCapabilityDomain, mission.stage)
        );
        const mapsToEvidence = mission.expectedEvidence.length > 0;

        expect(checkpointTitle).toBeTruthy();
        expect(mapsToCapability || mapsToEvidence).toBe(true);
      }
    }
  });

  it('UAT-C3: Stage progression increases complexity, autonomy, evidence maturity, and AI policy', () => {
    const aiPolicyRank = {
      'educator-led-only': 1,
      'guided-assistive-use': 2,
      'logged-analytical-use': 3,
      'advanced-assistive-use-full-audit': 4,
    } as const;

    for (const domain of uatCapabilityDomains) {
      const capabilities = getCapabilitiesByDomain(domain).sort(
        (left, right) => stageOrder.indexOf(left.stageBand) - stageOrder.indexOf(right.stageBand)
      );
      const progressionLevels = capabilities.map((capability) => capability.progressionLevel);
      const autonomyScores = capabilities.map((capability) => capability.learnerAutonomyScore);
      const evidenceScores = capabilities.map((capability) => capability.evidenceMaturityScore);
      const aiRanks = capabilities.map((capability) =>
        aiPolicyRank[missionForStage(capability.stageBand).aiPolicy]
      );

      expect(progressionLevels).toEqual([1, 2, 3, 4]);
      expect(autonomyScores).toEqual([1, 2, 3, 4]);
      expect(evidenceScores).toEqual([1, 2, 3, 4]);
      expect(aiRanks).toEqual([1, 2, 3, 4]);
    }
  });

  it('UAT-C4: Capability context persists through the full evidence-to-report chain', async () => {
    const harness = createUatTestHarness();
    const mission = missionForStage('Explorers');

    harness.loginAs('admin');
    harness.createTenant();
    harness.createOrganization();
    harness.addLearnerToCohort('explorer', 'cohort-explorers-7-9');
    harness.assignEducatorToCohort('educator', 'cohort-explorers-7-9');

    harness.loginAs('educator');
    const assignment = harness.assignMission(mission.id, 'cohort-explorers-7-9');
    const session = harness.openMissionSession(mission.id, 'cohort-explorers-7-9');
    const checkpoint = harness.completeCheckpoint('explorer', mission.id, mission.checkpointTitles[0]);
    const evidence = await harness.submitEvidence('explorer', mission.id);
    const reflection = harness.submitReflection(
      'explorer',
      mission.id,
      'I compared claims, checked sources, and changed my conclusion after finding stronger Evidence.'
    );
    const review = harness.performCapabilityReview(
      'explorer',
      mission.id,
      evidence.id,
      3,
      'Capability Review preserved source analysis, bias notes, and learner reflection context.'
    );
    const portfolioItem = harness.expectPortfolioUpdated('explorer')[0];
    const growthReport = harness.expectGrowthReportUpdated('explorer')[0];

    const contextTargets = [
      assignment.id,
      session.id,
      checkpoint.id,
      evidence.id,
      reflection.id,
      review.id,
    ];

    for (const targetId of contextTargets) {
      expect(harness.expectCapabilityContextPreserved(targetId, mission.capabilityDomains).length)
        .toBeGreaterThan(0);
    }

    expect(portfolioItem).toMatchObject({
      missionId: mission.id,
      evidenceId: evidence.id,
      capabilityDomains: mission.capabilityDomains,
    });
    expect(growthReport).toMatchObject({
      learnerId: expect.any(String),
      latestReviewId: review.id,
      capabilityDomains: mission.capabilityDomains,
    });
  });
});

function missionForStage(stage: UatMissionDefinition['stage']): UatMissionDefinition {
  const mission = uatMissionDefinitions.find((item) => item.stage === stage);

  if (!mission) {
    throw new Error(`Missing mission for ${stage}`);
  }

  return mission;
}
