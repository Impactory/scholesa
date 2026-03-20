import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

describe('learner profile wording availability', () => {
  it('keeps the learner motivation profile on evidence-and-growth language', () => {
    const profileSource = readRepoFile('src', 'components', 'motivation', 'StudentMotivationProfile.tsx');
    const englishLocale = readRepoFile('packages', 'i18n', 'locales', 'en.json');
    const simplifiedChineseLocale = readRepoFile('packages', 'i18n', 'locales', 'zh-CN.json');
    const traditionalChineseLocale = readRepoFile('packages', 'i18n', 'locales', 'zh-TW.json');

    expect(profileSource).toContain("title={t('motivation.sdt.competence.title')}");
    expect(profileSource).toContain("subtitle={t('motivation.sdt.competence.subtitle')}");
    expect(profileSource).toContain("{t('motivation.skills.title')}");
    expect(profileSource).toContain("{t(`motivation.skillLevel.${skill.level}`)}");
    expect(profileSource).toContain("t('motivation.evidenceCollected', { count: skill.evidenceCount })");

    expect(englishLocale).toContain('"subtitle": "Skills I\'m Building"');
    expect(englishLocale).toContain('"mastery": "Strong Evidence"');
    expect(englishLocale).toContain('"headerSubtitle": "Track your growth, skill building, and achievements"');
    expect(englishLocale).not.toContain('"subtitle": "Skills Mastered"');
    expect(englishLocale).not.toContain('"mastery": "Mastery"');

    expect(simplifiedChineseLocale).toContain('"title": "技能"');
    expect(simplifiedChineseLocale).toContain('"subtitle": "我正在发展的技能"');
    expect(simplifiedChineseLocale).toContain('"mastery": "已有充分证据"');
    expect(simplifiedChineseLocale).toContain('"evidenceCollected": "已收集 {{count}} 条证据"');
    expect(simplifiedChineseLocale).not.toContain('"subtitle": "Skills Mastered"');
    expect(simplifiedChineseLocale).not.toContain('"mastery": "Mastery"');

    expect(traditionalChineseLocale).toContain('"title": "技能"');
    expect(traditionalChineseLocale).toContain('"subtitle": "我正在發展的技能"');
    expect(traditionalChineseLocale).toContain('"mastery": "已有充分證據"');
    expect(traditionalChineseLocale).toContain('"evidenceCollected": "已收集 {{count}} 項證據"');
    expect(traditionalChineseLocale).not.toContain('"subtitle": "Skills Mastered"');
    expect(traditionalChineseLocale).not.toContain('"mastery": "Mastery"');
  });
});