import { getCapabilityForMissionDomain } from '../fixtures/uat-capability-graph';
import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function prepareUdlWorkflow(): { harness: UatTestHarness; sessionId: string } {
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

describe('accessibility and Universal Design for Learning UAT', () => {
  it('UAT-L1: Keyboard-only navigation reaches Learner dashboard, Session, Evidence submit, and Educator review actions without traps', () => {
    const { harness } = prepareUdlWorkflow();

    const checks = [
      harness.verifyKeyboardNavigation('learner-dashboard', [
        'open Mission card',
        'open Portfolio',
        'open MiloOS Coach',
      ]),
      harness.verifyKeyboardNavigation('mission-session', [
        'move between Session blocks',
        'complete checkpoint',
        'open Evidence submit',
      ]),
      harness.verifyKeyboardNavigation('evidence-submit', [
        'choose Evidence mode',
        'upload Evidence',
        'submit Evidence',
      ]),
      harness.verifyKeyboardNavigation('educator-evidence-review', [
        'open Evidence',
        'score rubric criterion',
        'publish Capability Review',
      ]),
    ];

    expect(checks).toEqual(
      checks.map(() => expect.objectContaining({ noKeyboardTrap: true, allMajorActionsReachable: true }))
    );
    expect(harness.checkAuditLog('accessibility.keyboard.verify')).toHaveLength(4);
  });

  it('UAT-L2: Screen reader labels provide accessible names without visual-only context', () => {
    const { harness } = prepareUdlWorkflow();
    const labels = harness.getScreenReaderLabelInventory();

    expect(labels).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ control: 'Mission cards', accessibleName: expect.stringContaining('Open Mission') }),
        expect.objectContaining({ control: 'Session blocks', accessibleName: expect.stringContaining('Session block') }),
        expect.objectContaining({ control: 'Checkpoint controls', accessibleName: expect.stringContaining('Complete checkpoint') }),
        expect.objectContaining({ control: 'Evidence upload buttons', accessibleName: expect.stringContaining('Upload Evidence') }),
        expect.objectContaining({ control: 'Reflection fields', accessibleName: expect.stringContaining('Learner reflection') }),
        expect.objectContaining({ control: 'Capability review controls', accessibleName: expect.stringContaining('Score Capability') }),
        expect.objectContaining({ control: 'Portfolio share controls', accessibleName: expect.stringContaining('Portfolio sharing') }),
        expect.objectContaining({ control: 'MiloOS Coach input', accessibleName: expect.stringContaining('MiloOS Coach') }),
        expect.objectContaining({ control: 'Growth report filters', accessibleName: expect.stringContaining('Growth Report') }),
      ])
    );
    expect(labels.every((label) => label.accessibleName.length > 0)).toBe(true);
    expect(labels.every((label) => label.hasVisualOnlyContext === false)).toBe(true);
  });

  it('UAT-L3: 200% zoom, mobile viewport, and tablet viewport keep core workflows usable without critical text overlap', () => {
    const { harness } = prepareUdlWorkflow();
    const checks = [
      harness.verifyResponsiveLayout('desktop', 200),
      harness.verifyResponsiveLayout('mobile', 100),
      harness.verifyResponsiveLayout('tablet', 100),
    ];

    expect(checks).toEqual([
      expect.objectContaining({ viewport: 'desktop', zoomPercent: 200, coreWorkflowsUsable: true, textOverlapsCriticalControls: false }),
      expect.objectContaining({ viewport: 'mobile', zoomPercent: 100, coreWorkflowsUsable: true, textOverlapsCriticalControls: false }),
      expect.objectContaining({ viewport: 'tablet', zoomPercent: 100, coreWorkflowsUsable: true, textOverlapsCriticalControls: false }),
    ]);
    expect(harness.checkAuditLog('accessibility.responsive.verify')).toHaveLength(3);
  });

  it('UAT-L4: Oral alternative Evidence with accommodation remains Capability-aligned and accepted into Portfolio', async () => {
    const { harness, sessionId } = prepareUdlWorkflow();

    harness.loginAs('educator');
    const override = harness.enableEvidenceOverride(
      'builder',
      'UDL accommodation: Learner may submit oral explain-it-back instead of written reflection.'
    );

    harness.loginAs('builder');
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Alternative oral explain-it-back Evidence',
      evidenceType: 'alternative',
      fileName: 'udl-oral-explain-back.m4a',
      contentType: 'audio/mp4',
      body: 'udl-oral-evidence',
      explanation: 'I explained my design out loud and named what changed after feedback.',
      metadata: { playable: true, mode: 'oral evidence' },
      override,
    });

    harness.loginAs('educator');
    const review = harness.performCapabilityReview(
      'builder',
      mission.id,
      evidence.id,
      3,
      'Oral alternative Evidence accepted with UDL accommodation and clear Capability alignment.'
    );
    const portfolioItem = harness.expectAlternativeEvidenceAcceptedInPortfolio('builder', evidence.id);

    expect(evidence).toMatchObject({
      learnerId: getUatUser('builder').id,
      evidenceType: 'alternative',
      artifact: expect.objectContaining({ contentType: 'audio/mp4' }),
      override: expect.objectContaining({ reason: expect.stringContaining('UDL accommodation') }),
      metadata: { playable: true, mode: 'oral evidence' },
      capabilityDomains: mission.capabilityDomains,
    });
    for (const domain of evidence.capabilityDomains) {
      expect(getCapabilityForMissionDomain(domain as Parameters<typeof getCapabilityForMissionDomain>[0], 'Builders'))
        .toMatchObject({ domain, stageBand: 'Builders' });
    }
    expect(portfolioItem).toMatchObject({ evidenceId: evidence.id, capabilityDomains: mission.capabilityDomains });
    expect(harness.expectCapabilityContextPreserved(review.id, mission.capabilityDomains)).toHaveLength(1);
  });
});
