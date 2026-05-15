import { MockMiloOSCoach } from '../helpers/mock-ai-service';
import { MockEvidenceStorage } from '../helpers/mock-file-storage';

describe('UAT deterministic mocks', () => {
  it('records deterministic MiloOS usage logs', async () => {
    const coach = new MockMiloOSCoach();
    const response = await coach.useCoach({
      learnerRole: 'innovator',
      missionId: 'mission-venture-sprint',
      capabilityId: 'Leadership and venture',
      mode: 'analyze',
      prompt: 'Help me evaluate the risk in my pitch.',
    });

    expect(response.allowed).toBe(true);
    expect(response.message).toContain('Stage: Innovators.');
    expect(coach.getUsageLogs()[0]).toMatchObject({
      id: response.auditEventId,
      learnerEmail: 'innovator@scholesa.test',
      policy: 'advanced-assistive-use-full-audit',
      capabilityId: 'Leadership and venture',
    });
  });

  it('stores artifact uploads in mock evidence storage', async () => {
    const storage = new MockEvidenceStorage();
    const file = await storage.uploadEvidenceFile({
      tenantId: 'tenant-summer-pilot-2026',
      learnerId: 'user-learner-builder',
      missionId: 'mission-eco-smart-city-lab',
      checkpointId: 'checkpoint-build-artifact',
      fileName: 'eco-city.txt',
      contentType: 'text/plain',
      sizeBytes: 32,
      body: 'solar sensor design sketch',
    });

    expect(file.url).toBe('mock-storage://tenant-summer-pilot-2026/user-learner-builder/artifact-1/eco-city.txt');
    expect(storage.listFilesForLearner('tenant-summer-pilot-2026', 'user-learner-builder')).toEqual([file]);
  });
});
