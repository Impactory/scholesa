import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

function readLocaleJson(...relativePath: string[]): any {
  return JSON.parse(readRepoFile(...relativePath));
}

describe('learner profile wording availability', () => {
  it('keeps the learner motivation profile on evidence-and-growth language', () => {
    const profileSource = readRepoFile('src', 'components', 'motivation', 'StudentMotivationProfile.tsx');
    const englishLocale = readLocaleJson('packages', 'i18n', 'locales', 'en.json');
    const simplifiedChineseLocale = readLocaleJson('packages', 'i18n', 'locales', 'zh-CN.json');
    const traditionalChineseLocale = readLocaleJson('packages', 'i18n', 'locales', 'zh-TW.json');

    expect(profileSource).toContain("title={t('motivation.sdt.competence.title')}");
    expect(profileSource).toContain("subtitle={t('motivation.sdt.competence.subtitle')}");
    expect(profileSource).toContain("{t('motivation.skills.title')}");
    expect(profileSource).toContain("{t(`motivation.skillLevel.${skill.level}`)}");
    expect(profileSource).toContain("t('motivation.evidenceCollected', { count: skill.evidenceCount })");

    expect(englishLocale.motivation.headerSubtitle).toBe('Track your growth, skill building, and achievements');
    expect(englishLocale.motivation.sdt.competence.title).toBe('Skills');
    expect(englishLocale.motivation.sdt.competence.subtitle).toBe("Skills I'm Building");
    expect(englishLocale.motivation.sdt.overall.subtitle).toBe('Across My Learning');
    expect(englishLocale.motivation.skillLevel.mastery).toBe('Strong Evidence');

    expect(simplifiedChineseLocale.motivation.headerTitle).toBe('我的学习旅程');
    expect(simplifiedChineseLocale.motivation.sdt.competence.title).toBe('技能');
    expect(simplifiedChineseLocale.motivation.sdt.competence.subtitle).toBe('我正在发展的技能');
    expect(simplifiedChineseLocale.motivation.skillLevel.mastery).toBe('已有充分证据');
    expect(simplifiedChineseLocale.motivation.evidenceCollected).toBe('已收集 {{count}} 条证据');

    expect(traditionalChineseLocale.motivation.headerTitle).toBe('我的學習旅程');
    expect(traditionalChineseLocale.motivation.sdt.competence.title).toBe('技能');
    expect(traditionalChineseLocale.motivation.sdt.competence.subtitle).toBe('我正在發展的技能');
    expect(traditionalChineseLocale.motivation.skillLevel.mastery).toBe('已有充分證據');
    expect(traditionalChineseLocale.motivation.evidenceCollected).toBe('已收集 {{count}} 項證據');
  });
});