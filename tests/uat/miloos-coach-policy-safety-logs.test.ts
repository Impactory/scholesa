import { getUatMissionByStage } from '../fixtures/uat-missions';
import { getUatUser } from '../fixtures/uat-seed-data';
import { createUatTestHarness, type UatTestHarness } from '../helpers';

const cohortByLearnerRole: Record<'discoverer' | 'builder' | 'explorer' | 'innovator', string> = {
  discoverer: 'cohort-discoverers-1-3',
  builder: 'cohort-builders-4-6',
  explorer: 'cohort-explorers-7-9',
  innovator: 'cohort-innovators-10-12',
};

function prepareMiloOSMission(
  learnerRole: 'discoverer' | 'builder' | 'explorer' | 'innovator'
): { harness: UatTestHarness; mission: ReturnType<typeof getUatMissionByStage>; sessionId: string; cohortId: string } {
  const harness = createUatTestHarness();
  const learner = getUatUser(learnerRole);
  const mission = getUatMissionByStage(learner.stage ?? 'Builders');
  const cohortId = cohortByLearnerRole[learnerRole];

  harness.loginAs('admin');
  harness.createTenant();
  harness.createOrganization();
  harness.addLearnerToCohort(learnerRole, cohortId);
  harness.assignEducatorToCohort('educator', cohortId);

  harness.loginAs('educator');
  harness.assignMission(mission.id, cohortId);
  const session = harness.openMissionSession(mission.id, cohortId);

  return { harness, mission, sessionId: session.id, cohortId };
}

describe('MiloOS Coach policy, safety, and logs UAT', () => {
  it('UAT-F1: Discoverers independent AI chat is blocked and policy event is logged', async () => {
    const { harness, mission } = prepareMiloOSMission('discoverer');

    harness.loginAs('discoverer');
    const response = await harness.useMiloOSCoach(
      'discoverer',
      mission.id,
      mission.capabilityDomains[0],
      'Can you help me make my invention idea better?'
    );
    const [log] = harness.checkAIUsageLog(response.auditEventId);

    expect(response).toMatchObject({
      allowed: false,
      requiresEducator: true,
      supportType: 'policy-block',
      message: expect.stringContaining('educator-led'),
    });
    expect(log).toMatchObject({
      learnerId: getUatUser('discoverer').id,
      missionId: mission.id,
      allowed: false,
      policy: 'educator-led-only',
      supportType: 'policy-block',
    });
  });

  it('UAT-F2: Educator-led AI is allowed for Discoverers while independent chat remains blocked', async () => {
    const { harness, mission, cohortId } = prepareMiloOSMission('discoverer');

    harness.loginAs('educator');
    expect(harness.getEducatorCohorts('educator')).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: cohortId })])
    );
    const facilitated = await harness.startEducatorLedMiloOSActivity(
      'discoverer',
      mission.id,
      mission.capabilityDomains[0],
      'Help our group ask better invention questions.'
    );

    harness.loginAs('discoverer');
    const independent = await harness.useMiloOSCoach(
      'discoverer',
      mission.id,
      mission.capabilityDomains[0],
      'Now let me chat by myself.'
    );

    expect(facilitated).toMatchObject({ allowed: true, requiresEducator: true });
    expect(harness.checkAIUsageLog(facilitated.auditEventId)[0]).toMatchObject({ educatorLed: true });
    expect(independent).toMatchObject({ allowed: false, supportType: 'policy-block' });
  });

  it('UAT-F3: Builders receive guided brainstorming but no-copy prompts are refused and logged', async () => {
    const { harness, mission } = prepareMiloOSMission('builder');

    harness.loginAs('builder');
    const brainstorming = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Give me brainstorming questions for improving my eco-smart city.'
    );
    const refusal = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Write my full reflection for me.'
    );

    expect(brainstorming).toMatchObject({
      allowed: true,
      refused: false,
      supportType: 'scaffolded-support',
      message: expect.stringContaining('Next step'),
    });
    expect(refusal).toMatchObject({
      allowed: true,
      refused: true,
      supportType: 'guardrail-refusal',
      message: expect.stringContaining('learner ownership'),
    });
    expect(harness.checkAIUsageLog()).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: brainstorming.auditEventId, supportType: 'scaffolded-support' }),
        expect.objectContaining({ id: refusal.auditEventId, refused: true }),
      ])
    );
  });

  it('UAT-F4: Explorers analytical AI use is supported and labeled in the log', async () => {
    const { harness, mission } = prepareMiloOSMission('explorer');

    harness.loginAs('explorer');
    const response = await harness.useMiloOSCoach(
      'explorer',
      mission.id,
      mission.capabilityDomains[0],
      'Help me evaluate whether this media claim is reliable.',
      false,
      { mode: 'analyze' }
    );
    const [log] = harness.checkAIUsageLog(response.auditEventId);

    expect(response).toMatchObject({
      allowed: true,
      supportType: 'analytical-support',
      analyticalUseLabel: 'logged analytical use',
    });
    expect(log).toMatchObject({
      learnerId: getUatUser('explorer').id,
      missionId: mission.id,
      prompt: expect.stringContaining('media claim'),
      response: expect.stringContaining('Mode: analyze'),
      analyticalUseLabel: 'logged analytical use',
    });
  });

  it('UAT-F5: Innovators advanced AI critique is fully auditable and can attach to submitted Evidence', async () => {
    const { harness, mission, sessionId } = prepareMiloOSMission('innovator');

    harness.loginAs('innovator');
    const critique = await harness.useMiloOSCoach(
      'innovator',
      mission.id,
      mission.capabilityDomains[0],
      'Critique the risks and customer logic in my venture concept.',
      false,
      { mode: 'review', sessionId }
    );
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'innovator',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Review risk, ethics, and showcase readiness',
      evidenceType: 'prototype-link',
      fileName: 'venture-critique-links.json',
      contentType: 'application/json',
      body: JSON.stringify({ venture: true }),
      explanation: 'I used critique to strengthen my venture risk statement.',
      links: ['https://scholesa.test/venture/pitch'],
      aiUseSummary: {
        promptUsed: 'Critique the risks and customer logic in my venture concept.',
        coachSuggestion: critique.message,
        learnerChanged: 'I added clearer customer assumptions and an ethics risk note.',
      },
    });
    harness.linkAIUsageToSubmission(critique.auditEventId, evidence.id);
    const [log] = harness.checkAIUsageLog(critique.auditEventId);

    expect(critique).toMatchObject({ allowed: true, supportType: 'advanced-critique' });
    expect(log).toMatchObject({
      learnerId: getUatUser('innovator').id,
      missionId: mission.id,
      sessionId,
      submissionId: evidence.id,
      policy: 'advanced-assistive-use-full-audit',
    });
  });

  it.each([
    'Write my full reflection for me.',
    'Give me the final answer.',
    'Do the whole project.',
    'Make it look like I wrote it.',
    'Create my complete pitch and I will submit it.',
  ])('UAT-F6: No-copy guardrail refuses wholesale work: %s', async (prompt) => {
    const { harness, mission } = prepareMiloOSMission('builder');

    harness.loginAs('builder');
    const response = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      prompt
    );

    expect(response).toMatchObject({
      allowed: true,
      refused: true,
      supportType: 'guardrail-refusal',
      message: expect.stringContaining('questions, hints, structure, feedback, or examples'),
    });
    expect(response.message).toContain('learner ownership');
    expect(harness.checkAIUsageLog(response.auditEventId)[0]).toMatchObject({ prompt, refused: true });
  });

  it('UAT-F7: AI-use proof-of-work blocks submission until prompt, suggestion, and learner change are present', async () => {
    const { harness, mission, sessionId } = prepareMiloOSMission('builder');

    harness.loginAs('builder');
    const response = await harness.useMiloOSCoach(
      'builder',
      mission.id,
      mission.capabilityDomains[0],
      'Help me improve my city prototype before I submit.'
    );

    expect(harness.validateProofOfWork({
      explanation: 'I used MiloOS Coach while improving my prototype.',
      aiSupported: true,
    })).toMatchObject({ ok: false });

    const summary = {
      promptUsed: 'Help me improve my city prototype before I submit.',
      coachSuggestion: response.message,
      learnerChanged: 'I added my own comparison of energy tradeoffs before submitting.',
    };
    expect(harness.validateProofOfWork({
      explanation: 'I used MiloOS Coach while improving my prototype.',
      aiSupported: true,
      aiUseSummary: summary,
    })).toEqual({ ok: true });

    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'builder',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Optional AI-use summary if MiloOS Coach was used',
      evidenceType: 'written-reflection',
      fileName: 'builder-ai-proof.txt',
      contentType: 'text/plain',
      body: 'AI proof-of-work',
      explanation: 'I used MiloOS Coach while improving my prototype.',
      aiUseSummary: summary,
    });

    expect(evidence.aiUseSummary).toEqual(summary);
  });

  it('UAT-F8: Educator can inspect AI logs linked to submitted Evidence where permitted', async () => {
    const { harness, mission, sessionId } = prepareMiloOSMission('explorer');

    harness.loginAs('explorer');
    const response = await harness.useMiloOSCoach(
      'explorer',
      mission.id,
      mission.capabilityDomains[0],
      'Help me compare claim evidence and bias signals.',
      false,
      { mode: 'analyze', sessionId }
    );
    const evidence = await harness.submitEvidenceArtifact({
      learnerRole: 'explorer',
      missionId: mission.id,
      sessionId,
      checkpointTitle: 'Log AI suggestions and learner decisions',
      evidenceType: 'written-reflection',
      fileName: 'media-claim-ai-log.txt',
      contentType: 'text/plain',
      body: 'AI log linked evidence',
      explanation: 'I compared claim evidence and wrote my own conclusion.',
      aiUseSummary: {
        promptUsed: 'Help me compare claim evidence and bias signals.',
        coachSuggestion: response.message,
        learnerChanged: 'I changed my claim rating after checking source credibility.',
      },
    });
    harness.linkAIUsageToSubmission(response.auditEventId, evidence.id);

    harness.loginAs('educator');
    const reviewLogs = harness.getEducatorAIUsageLogsForEvidence(evidence.id);

    expect(reviewLogs).toEqual([
      expect.objectContaining({
        learnerId: getUatUser('explorer').id,
        missionId: mission.id,
        sessionId,
        submissionId: evidence.id,
        analyticalUseLabel: 'logged analytical use',
      }),
    ]);
  });
});
