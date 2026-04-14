import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function readRepoFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(repoRoot, ...relativePath), 'utf8');
}

describe('parent workflow wording availability', () => {
  it('keeps parent workflow summaries on evidence-first family language', () => {
    const workflowDataSource = readRepoFile('src', 'features', 'workflows', 'workflowData.ts');
    const englishLocale = JSON.parse(readRepoFile('packages', 'i18n', 'locales', 'en.json'));
    const simplifiedChineseLocale = JSON.parse(readRepoFile('packages', 'i18n', 'locales', 'zh-CN.json'));
    const traditionalChineseLocale = JSON.parse(readRepoFile('packages', 'i18n', 'locales', 'zh-TW.json'));
    const thaiLocale = JSON.parse(readRepoFile('packages', 'i18n', 'locales', 'th.json'));

    expect(workflowDataSource).toContain('title: `${learnerName} growth snapshot`');
    expect(workflowDataSource).toContain('Think, Make & Navigate AI ${futureSkills}');
    expect(workflowDataSource).toContain('Build for the World ${impact}');
    expect(workflowDataSource).toContain("'No verified growth evidence yet'");
    expect(workflowDataSource).toContain("status: capabilityBand || 'Evidence building'");

    expect(workflowDataSource).toContain('title: `${learnerName} portfolio highlights`');
    expect(workflowDataSource).toContain('publishedArtifactCount ? `Shared ${publishedArtifactCount}` : null');

    expect(workflowDataSource).toContain('title: `${learnerName} learning story`');
    expect(workflowDataSource).toContain('completedMissions ? `Completed missions ${completedMissions}` : null');
    expect(workflowDataSource).toContain('voiceInteractions ? `Voice check-ins ${voiceInteractions}` : null');

    expect(workflowDataSource).toContain('artifactCount != null ? `Artifacts ${artifactCount}` : null');
    expect(workflowDataSource).toContain('reflectionsSubmitted != null ? `Reflections ${reflectionsSubmitted}` : null');
    expect(workflowDataSource).toContain('missionsCompleted != null ? `Completed missions ${missionsCompleted}` : null');
    expect(workflowDataSource).toContain("'No verified portfolio or reflection evidence yet'");

    expect(workflowDataSource).not.toContain('title: `${learnerName} capability graph`');
    expect(workflowDataSource).not.toContain('title: `${learnerName} portfolio snapshot`');
    expect(workflowDataSource).not.toContain('title: `${learnerName} ideation passport`');
    expect(workflowDataSource).not.toContain('currentLevel != null ? `Level ${currentLevel}` : null');
    expect(workflowDataSource).not.toContain('totalXp != null ? `XP ${totalXp}` : null');
    expect(workflowDataSource).not.toContain("'No verified summary evidence yet'");
    expect(workflowDataSource).not.toContain("'No capability band yet'");

    expect(englishLocale.role.parent.levelXp).toBe('Reviewed evidence {{level}} • Shared artifacts {{xp}}');
    expect(englishLocale.role.parent.missionsCount).toBe('Completed missions: {{count}}');
    expect(englishLocale.role.parent.streakCount).toBe('Recent active days: {{count}}');

    expect(simplifiedChineseLocale.role.parent.levelXp).toBe('已评审证据 {{level}} • 已分享作品 {{xp}}');
    expect(simplifiedChineseLocale.role.parent.missionsCount).toBe('已完成任务：{{count}}');
    expect(simplifiedChineseLocale.role.parent.streakCount).toBe('近期活跃天数：{{count}}');

    expect(traditionalChineseLocale.role.parent.levelXp).toBe('已審查證據 {{level}} • 已分享作品 {{xp}}');
    expect(traditionalChineseLocale.role.parent.missionsCount).toBe('已完成任務：{{count}}');
    expect(traditionalChineseLocale.role.parent.streakCount).toBe('近期活躍天數：{{count}}');

    expect(thaiLocale.role.parent.levelXp).toBe('หลักฐานที่ตรวจแล้ว {{level}} • ผลงานที่แชร์ {{xp}}');
    expect(thaiLocale.role.parent.missionsCount).toBe('ภารกิจที่เสร็จแล้ว: {{count}}');
    expect(thaiLocale.role.parent.streakCount).toBe('วันที่มีการเรียนรู้ล่าสุด: {{count}}');
  });
});
