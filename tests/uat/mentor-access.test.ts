import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

async function prepareMentorWorkflow(): Promise<{ harness: UatTestHarness; evidenceId: string }> {
  const harness = createUatTestHarness();

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort('builder', buildersCohortId);
  harness.assignEducatorToCohort('educator', buildersCohortId);

  harness.loginAs('educator');
  harness.assignMission(mission.id, buildersCohortId);
  const session = harness.openMissionSession(mission.id, buildersCohortId);

  harness.loginAs('builder');
  const evidence = await harness.submitEvidenceArtifact({
    learnerRole: 'builder',
    missionId: mission.id,
    sessionId: session.id,
    checkpointTitle: 'Showcase-ready prototype',
    evidenceType: 'prototype-link',
    fileName: 'mentor-showcase.json',
    contentType: 'application/json',
    body: JSON.stringify({ showcase: true }),
    explanation: 'I revised my prototype and want Mentor feedback before the Showcase.',
    links: ['https://scholesa.test/showcase/eco-smart-city'],
  });

  harness.loginAs('educator');
  harness.assignMentorToShowcase(evidence.id, 'mentor');

  return { harness, evidenceId: evidence.id };
}

describe('Mentor access UAT', () => {
  it('UAT-J1: Mentor views assigned Showcase item and adds structured feedback visible to Learner and Educator', async () => {
    const { harness, evidenceId } = await prepareMentorWorkflow();

    harness.loginAs('mentor');
    const assignedItems = harness.getMentorAssignedShowcaseItems('mentor');
    const feedback = harness.addMentorStructuredFeedback({
      evidenceId,
      strengths: ['The prototype story is clear and tied to a real city need.'],
      questions: ['What tradeoff did you make between energy savings and cost?'],
      showcaseReadinessNextStep: 'Add one sentence explaining what changed after feedback before the Showcase.',
    });

    harness.loginAs('builder');
    const learnerFeedback = harness.getMentorFeedbackForLearner('builder');

    harness.loginAs('educator');
    const educatorFeedback = harness.getMentorFeedbackForEducator(evidenceId);

    expect(assignedItems).toEqual([expect.objectContaining({ id: evidenceId, missionId: mission.id })]);
    expect(feedback).toMatchObject({
      mentorId: getUatUser('mentor').id,
      learnerId: getUatUser('builder').id,
      evidenceId,
      strengths: [expect.stringContaining('prototype story')],
      questions: [expect.stringContaining('tradeoff')],
      showcaseReadinessNextStep: expect.stringContaining('Showcase'),
      visibleToLearner: true,
      visibleToEducator: true,
    });
    expect(learnerFeedback).toEqual([feedback]);
    expect(educatorFeedback).toEqual([feedback]);
    expect(harness.checkAuditLog('mentor-feedback.add')).toHaveLength(1);
  });

  it('UAT-J2: Mentor sees only assigned Showcase items and restricted actions are denied', async () => {
    const { harness, evidenceId } = await prepareMentorWorkflow();

    harness.loginAs('builder');
    const unassignedEvidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      checkpointTitle: 'Unassigned portfolio item',
      evidenceType: 'image',
      fileName: 'unassigned-mentor-item.png',
      contentType: 'image/png',
      body: 'unassigned-bytes',
      explanation: 'This item was not assigned to a Mentor.',
    });

    harness.loginAs('mentor');
    const assignedItems = harness.getMentorAssignedShowcaseItems('mentor');
    const blockedActions = [
      harness.denyMentorRestrictedAction('access unassigned learner portfolio', unassignedEvidence.id),
      harness.denyMentorRestrictedAction('access full Cohort', buildersCohortId),
      harness.denyMentorRestrictedAction('edit Evidence', evidenceId),
      harness.denyMentorRestrictedAction('perform official Capability Review', evidenceId),
    ];

    expect(assignedItems.map((item) => item.id)).toEqual([evidenceId]);
    expect(assignedItems.map((item) => item.id)).not.toContain(unassignedEvidence.id);
    expect(blockedActions).toEqual([
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('unassigned learner portfolio') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('full Cohort') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('edit Evidence') }),
      expect.objectContaining({ allowed: false, reason: expect.stringContaining('official Capability Review') }),
    ]);
    expect(harness.checkAuditLog('mentor.access.denied')).toHaveLength(4);
  });

  it('UAT-J3: Mentor MVP feature flag can be disabled without breaking Admin, Educator, Learner, or Family flows', async () => {
    const harness = createUatTestHarness();

    harness.loginAs('admin');
    harness.createTenant();
    harness.createOrganization();
    harness.addLearnerToCohort('builder', buildersCohortId);
    harness.assignEducatorToCohort('educator', buildersCohortId);
    harness.setFeatureFlag('mentor', false);

    harness.loginAs('educator');
    harness.assignMission(mission.id, buildersCohortId);
    harness.publishHomeConnection(mission.id, buildersCohortId, 'Family discussion prompt', true);

    harness.loginAs('builder');
    const learnerDashboard = harness.getLearnerDashboard('builder');

    harness.loginAs('family');
    const familyProgress = harness.getFamilyLinkedLearnerProgress('family', 'builder');

    expect(harness.getCoreMvpFeatureStatus()).toEqual({
      mentorEnabled: false,
      adminOperational: true,
      educatorOperational: true,
      learnerOperational: true,
      familyOperational: true,
    });
    expect(learnerDashboard.missionTitles).toEqual([mission.title]);
    expect(familyProgress).toMatchObject({ allowed: true, learnerId: getUatUser('builder').id });
    expect(harness.checkAuditLog('feature-flag.set')).toHaveLength(1);
  });
});
