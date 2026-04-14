import fs from 'node:fs';
import path from 'node:path';

function readRepoFile(relativePath: string): string {
  return fs.readFileSync(path.join(process.cwd(), relativePath), 'utf8');
}

describe('skills-first honesty entrypoints', () => {
  it('keeps root metadata aligned to K-12 skills-first wording', () => {
    const rootLayout = readRepoFile('app/layout.tsx');
    const localeMetadata = readRepoFile('app/[locale]/metadata.ts');
    const localeLayout = readRepoFile('app/[locale]/layout.tsx');

    expect(rootLayout).toContain('Skills-First Learning OS');
    expect(rootLayout).toContain('K–12 skills-first operating system');
    expect(rootLayout).not.toContain('Future Skills Academy');
    expect(rootLayout).not.toContain('K–9');

    expect(localeMetadata).toContain('K-12 skills-first learning OS');
    expect(localeLayout).toContain('K-12 skills-first learning OS');
  });

  it('keeps landing locale files free of the old K-9 and three-pillar claims', () => {
    const localePaths = [
      'locales/en.json',
      'locales/es.json',
      'locales/th.json',
      'locales/zh-CN.json',
      'locales/zh-TW.json',
    ];

    for (const localePath of localePaths) {
      const contents = readRepoFile(localePath);
      expect(contents).not.toContain('K–9');
      expect(contents).not.toContain('3 Pillars');
      expect(contents).not.toContain('三大支柱');
      expect(contents).not.toContain('Future Skills Academy');
    }
  });

  it('keeps shared entrypoint branding out of the old academy and three-pillar framing', () => {
    const manifest = readRepoFile('public/manifest.webmanifest');
    const sharedEn = readRepoFile('packages/i18n/locales/en.json');
    const hqDashboard = readRepoFile('src/features/dashboards/hq/components/HqDashboard.tsx');

    expect(manifest).toContain('Skills-First Learning OS');
    expect(manifest).not.toContain('Future Skills Academy');

    expect(sharedEn).toContain('Skills-first learning OS');
    expect(sharedEn).not.toContain('Future Skills Academy');

    expect(hqDashboard).toContain('Legacy Curriculum Families');
    expect(hqDashboard).not.toContain('The 3 Pillars');
  });

  it('keeps major learner, educator, and HQ surfaces honest about legacy family compatibility', () => {
    const learnerDashboard = readRepoFile('src/features/dashboards/learner/components/LearnerDashboard.tsx');
    const educatorDashboard = readRepoFile('src/components/dashboards/EducatorDashboardToday.tsx');
    const portfolioBrowser = readRepoFile('src/components/evidence/LearnerPortfolioBrowser.tsx');
    const capabilityGuidance = readRepoFile('src/components/analytics/CapabilityGuidancePanel.tsx');
    const capabilityEditor = readRepoFile('src/components/capabilities/CapabilityFrameworkEditor.tsx');
    const hqAnalytics = readRepoFile('src/features/workflows/renderers/HqCapabilityAnalyticsRenderer.tsx');
    const learnerPortfolio = readRepoFile('src/features/workflows/renderers/LearnerPortfolioCurationRenderer.tsx');
    const passportExport = readRepoFile('src/components/passport/LearnerPassportExport.tsx');
    const workflowData = readRepoFile('src/features/workflows/workflowData.ts');
    const functionsIndex = readRepoFile('functions/src/index.ts');

    expect(learnerDashboard).toContain('Legacy Curriculum Families');
    expect(learnerDashboard).toContain('These compatibility roll-ups group evidence from the live six-strand curriculum.');
    expect(learnerDashboard).toContain('getLegacyPillarFamilyLabel');

    expect(educatorDashboard).toContain('Class Legacy Family Snapshot');

    expect(portfolioBrowser).toContain('All legacy families');

    expect(capabilityGuidance).toContain('Legacy family breakdown for the live six-strand curriculum');

    expect(capabilityEditor).toContain('All Legacy Families');
    expect(capabilityEditor).toContain('Legacy family *');

    expect(hqAnalytics).toContain('Legacy Families Active');
    expect(hqAnalytics).toContain('Mastery by Legacy Family');

    expect(learnerPortfolio).toContain('Legacy family roll-up of the live six-strand curriculum');
    expect(learnerPortfolio).toContain('Legacy family *');

    expect(passportExport).toContain('Legacy Family Progress');
    expect(passportExport).toContain('Legacy family');

    expect(workflowData).toContain('Think, Make & Navigate AI ${futureSkills}');
    expect(workflowData).toContain("label: 'Legacy family code'");

    expect(functionsIndex).toContain("return 'Communicate & Lead';");
  });
});
