import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

describe('voice reliability wording availability', () => {
  it('keeps analytics voice reliability guidance in plain language', () => {
    const guidanceSource = readRepoFile('src', 'components', 'analytics', 'VoiceReliabilityGuidance.tsx');
    const dashboardSource = readRepoFile('src', 'components', 'analytics', 'AnalyticsDashboard.tsx');
    const hqDashboardSource = readRepoFile('src', 'components', 'analytics', 'HQAnalyticsDashboard.tsx');

    expect(guidanceSource).toContain('This shows how often MiloOS captured voice input clearly enough to use.');
    expect(guidanceSource).toContain('voice-based support numbers here may miss part of the picture.');
    expect(guidanceSource).toContain('voice-based support numbers across sites may miss part of the picture and should be read carefully.');
    expect(guidanceSource).toContain('Low capture lowers confidence because there are fewer clear voice examples across sites.');
    expect(guidanceSource).toContain('Green bars mean capture stayed strong, amber means read voice support trends carefully, and red means there was not enough clear voice evidence to rely on for that period.');

    expect(dashboardSource).toContain('Voice capture needs attention');
    expect(dashboardSource).toContain('MiloOS clearly captured only');
    expect(dashboardSource).toContain('Read voice support trends carefully until capture improves.');

    expect(hqDashboardSource).toContain('Low values mean MiloOS had fewer clear voice inputs to work from.');

    for (const source of [guidanceSource, dashboardSource, hqDashboardSource]) {
      expect(source).not.toContain('trustworthiness of voice-derived support analytics');
      expect(source).not.toContain('less trustworthy operational evidence');
      expect(source).not.toContain('voice-derived support analytics');
      expect(source).not.toContain('fewer trustworthy voice inputs');
      expect(source).not.toContain('materially unreliable');
    }
  });
});