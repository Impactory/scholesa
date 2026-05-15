import { getUatMissionByStage } from '../fixtures/uat-missions';
import { createUatTestHarness } from '../helpers';

const buildersCohortId = 'cohort-builders-4-6';
const mission = getUatMissionByStage('Builders');

function prepareReliabilityWorkflow() {
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

describe('performance and learning-state reliability UAT', () => {
  it('UAT-M1: Main views load under the 2 second staging broadband target', () => {
    const { harness } = prepareReliabilityWorkflow();
    const checks = [
      harness.measureMainViewPerformance('learner-dashboard', 820),
      harness.measureMainViewPerformance('mission-session-page', 1040),
      harness.measureMainViewPerformance('evidence-submission-page', 1180),
      harness.measureMainViewPerformance('educator-cohort-dashboard', 1360),
      harness.measureMainViewPerformance('portfolio-page', 1250),
      harness.measureMainViewPerformance('admin-report-page', 1480),
    ];

    expect(checks).toEqual(
      checks.map(() => expect.objectContaining({ targetMs: 2000, passed: true }))
    );
    expect(Math.max(...checks.map((check) => check.loadTimeMs))).toBeLessThan(2000);
    expect(harness.checkAuditLog('performance.main-view.measure')).toHaveLength(6);
  });

  it('UAT-M2: Reflection draft autosaves, survives refresh, preserves offline typing, and syncs after reconnect', () => {
    const { harness } = prepareReliabilityWorkflow();

    harness.loginAs('builder');
    const draft = harness.writeReflectionDraft(
      'builder',
      mission.id,
      'I noticed my prototype changed after feedback.'
    );
    const autosaved = harness.autosaveReflectionDraft(draft.id);
    const restoredAfterRefresh = harness.refreshReflectionDraft(draft.id);
    const offlineDraft = harness.simulateDraftNetworkInterruption(draft.id);
    const continuedOffline = harness.continueReflectionDraftOffline(
      draft.id,
      ' While offline, I added why the new design works better.'
    );
    const synced = harness.restoreDraftNetworkAndSync(draft.id);

    expect(autosaved).toMatchObject({ synced: true, localPending: false });
    expect(restoredAfterRefresh.value).toBe('I noticed my prototype changed after feedback.');
    expect(offlineDraft).toMatchObject({ networkOnline: false, localPending: true, synced: false });
    expect(continuedOffline.value).toContain('While offline');
    expect(synced).toMatchObject({
      networkOnline: true,
      localPending: false,
      synced: true,
      value: continuedOffline.value,
    });
    expect(harness.checkAuditLog('reflection-draft.sync')).toHaveLength(1);
  });

  it('UAT-M3: Graceful error states preserve data, show friendly messages, offer retry, and log failures', () => {
    const { harness } = prepareReliabilityWorkflow();
    const scenarios = [
      'file upload failure',
      'MiloOS Coach unavailable',
      'report loading failure',
      'evidence save failure',
      'portfolio export failure',
    ] as const;

    const errors = scenarios.map((scenario) => harness.simulateGracefulError(scenario));

    expect(errors).toEqual(
      scenarios.map((scenario) => expect.objectContaining({
        scenario,
        friendlyMessage: expect.any(String),
        noDataLoss: true,
        retryAvailable: true,
        logged: true,
      }))
    );
    expect(errors.every((error) => error.friendlyMessage.length > 20)).toBe(true);
    expect(harness.checkAuditLog('reliability.error')).toHaveLength(5);
  });

  it('UAT-M4: Empty states guide users to the next meaningful action', () => {
    const harness = createUatTestHarness();
    const emptyStates = harness.getHelpfulEmptyStates();

    expect(emptyStates).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ surface: 'no missions assigned', nextAction: expect.stringContaining('assign a Mission') }),
        expect.objectContaining({ surface: 'no evidence submitted', nextAction: expect.stringContaining('submit Evidence') }),
        expect.objectContaining({ surface: 'no portfolio items yet', nextAction: expect.stringContaining('Educator review') }),
        expect.objectContaining({ surface: 'no growth report data', nextAction: expect.stringContaining('capability growth data') }),
        expect.objectContaining({ surface: 'no showcase items', nextAction: expect.stringContaining('Showcase approval') }),
        expect.objectContaining({ surface: 'no AI usage logs', nextAction: expect.stringContaining('MiloOS Coach') }),
      ])
    );
    expect(emptyStates.every((state) => state.message.length > 0 && state.nextAction.length > 0)).toBe(true);
  });
});
