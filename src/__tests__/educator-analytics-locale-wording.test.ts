import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

function readLocaleJson(...relativePath: string[]): any {
  return JSON.parse(readRepoFile(...relativePath));
}

describe('educator analytics locale wording', () => {
  it('keeps educator analytics labels localized and evidence-first in shared catalogs', () => {
    const analyticsDashboardSource = readRepoFile('src', 'components', 'analytics', 'AnalyticsDashboard.tsx');
    const simplifiedChineseLocale = readLocaleJson('packages', 'i18n', 'locales', 'zh-CN.json');
    const traditionalChineseLocale = readLocaleJson('packages', 'i18n', 'locales', 'zh-TW.json');
    const thaiLocale = readLocaleJson('packages', 'i18n', 'locales', 'th.json');

    expect(analyticsDashboardSource).toContain("t('analytics.educator.loadError')");
    expect(analyticsDashboardSource).toContain("t('analytics.educator.thisWeek')");
    expect(analyticsDashboardSource).toContain("t('analytics.educator.thisMonth')");
    expect(analyticsDashboardSource).toContain("t('analytics.educator.table.title')");
    expect(analyticsDashboardSource).toContain("t('analytics.educator.atRiskTitle', { count: atRiskCount })");
    expect(analyticsDashboardSource).toContain("t('analytics.educator.csvHeaders.learnerName')");
    expect(analyticsDashboardSource).toContain("t('analytics.educator.summary.totalLearners')");

    expect(simplifiedChineseLocale.meta.educatorAnalytics.title).toBe('学习数据看板 | Scholesa');
    expect(simplifiedChineseLocale.meta.educatorAnalytics.description).toBe('帮助老师查看学生参与度与学习动力的数据分析');
    expect(simplifiedChineseLocale.analytics.educator.title).toBe('学习数据看板');
    expect(simplifiedChineseLocale.analytics.educator.subtitle).toBe('查看学生参与度、学习动力指标与成长进展');
    expect(simplifiedChineseLocale.analytics.educator.table.title).toBe('学生学习动力概览');
    expect(simplifiedChineseLocale.analytics.educator.atRiskTitle).toBe('有 {{count}} 名学习者可能需要更多支持');

    expect(traditionalChineseLocale.meta.educatorAnalytics.title).toBe('學習數據看板 | Scholesa');
    expect(traditionalChineseLocale.meta.educatorAnalytics.description).toBe('幫助老師查看學生參與度與學習動力的數據分析');
    expect(traditionalChineseLocale.analytics.educator.title).toBe('學習數據看板');
    expect(traditionalChineseLocale.analytics.educator.subtitle).toBe('查看學生參與度、學習動力指標與成長進展');
    expect(traditionalChineseLocale.analytics.educator.table.title).toBe('學生學習動力概覽');
    expect(traditionalChineseLocale.analytics.educator.atRiskTitle).toBe('有 {{count}} 名學習者可能需要更多支持');

    expect(thaiLocale.meta.educatorAnalytics.title).toBe('แดชบอร์ดข้อมูลการเรียนรู้ | Scholesa');
    expect(thaiLocale.meta.educatorAnalytics.description).toBe('ข้อมูลการมีส่วนร่วมและแรงจูงใจของผู้เรียนสำหรับครู');
    expect(thaiLocale.analytics.educator.title).toBe('แดชบอร์ดข้อมูลการเรียนรู้');
    expect(thaiLocale.analytics.educator.subtitle).toBe('ติดตามการมีส่วนร่วมของผู้เรียน ตัวชี้วัดแรงจูงใจ และความก้าวหน้าในการเรียนรู้');
    expect(thaiLocale.analytics.educator.table.title).toBe('ภาพรวมแรงจูงใจของผู้เรียน');
    expect(thaiLocale.analytics.educator.atRiskTitle).toBe('ผู้เรียน {{count}} คนอาจต้องการการช่วยเหลือเพิ่มเติม');
  });
});