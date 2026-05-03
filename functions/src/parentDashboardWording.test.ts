import fs from 'node:fs';
import path from 'node:path';

const functionsRoot = __dirname;

function readFunctionsFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(functionsRoot, ...relativePath), 'utf8');
}

describe('parent dashboard wording honesty', () => {
  it('keeps the passport empty summary tied to reviewed evidence instead of verified claims', () => {
    const indexSource = readFunctionsFile('index.ts');

    expect(indexSource).toContain('No capability claims backed by reviewed evidence are available yet.');
    expect(indexSource).not.toContain('No verified capability claims are available yet.');
  });

  it('keeps HQ-authored verification criteria in callable parent portfolio previews and passport claims', () => {
    const indexSource = readFunctionsFile('index.ts');
    const portfolioBlock = indexSource.slice(
      indexSource.indexOf('const portfolioItemsPreview = portfolioRows'),
      indexSource.indexOf('const reflectionDates = reflectionRows'),
    );
    const passportBlock = indexSource.slice(
      indexSource.indexOf('const passportClaims = masteryRows'),
      indexSource.indexOf('const ideationPassport: Record<string, unknown> = {'),
    );

    expect(portfolioBlock).toContain('progressionDescriptors,');
    expect(portfolioBlock).toContain('checkpointMappings,');
    expect(passportBlock).toContain('progressionDescriptors,');
    expect(passportBlock).toContain('checkpointMappings,');
  });

  it('keeps portfolio, passport, and growth provenance fields in the callable summary payload', () => {
    const indexSource = readFunctionsFile('index.ts');
    const portfolioBlock = indexSource.slice(
      indexSource.indexOf('const portfolioItemsPreview = portfolioRows'),
      indexSource.indexOf('const reflectionDates = reflectionRows'),
    );
    const passportBlock = indexSource.slice(
      indexSource.indexOf('const passportClaims = masteryRows'),
      indexSource.indexOf('const ideationPassport: Record<string, unknown> = {'),
    );
    const growthBlock = indexSource.slice(
      indexSource.indexOf('const growthTimeline = growthRows'),
      indexSource.indexOf('const currentLevel = resolveParentCurrentLevel'),
    );

    expect(portfolioBlock).toContain('evidenceRecordIds:');
    expect(portfolioBlock).toContain('missionAttemptId: missionAttemptId || null');
    expect(portfolioBlock).toContain('verificationPrompt:');
    expect(portfolioBlock).toContain('proofCheckpointCount,');
    expect(portfolioBlock).toContain('aiAssistanceDetails,');
    expect(portfolioBlock).toContain('reviewingEducatorName: reviewerName');
    expect(portfolioBlock).toContain('rubricRawScore,');

    expect(passportBlock).toContain('evidenceRecordIds:');
    expect(passportBlock).toContain('portfolioItemIds:');
    expect(passportBlock).toContain('missionAttemptIds:');
    expect(passportBlock).toContain('proofCheckpointCount,');
    expect(passportBlock).toContain('aiAssistanceDetails,');
    expect(passportBlock).toContain('reviewingEducatorName: reviewerName');
    expect(passportBlock).toContain('rubricRawScore,');

    expect(growthBlock).toContain('linkedEvidenceRecordIds:');
    expect(growthBlock).toContain('linkedPortfolioItemIds:');
    expect(growthBlock).toContain('reviewingEducatorName: reviewerId ? reviewerNames[reviewerId] ?? null : null');
    expect(growthBlock).toContain('rubricRawScore:');
    expect(growthBlock).toContain('missionAttemptId:');

    const summaryTailBlock = indexSource.slice(
      indexSource.indexOf('processDomainSnapshot: pdMasterySnap.docs'),
      indexSource.indexOf('};\n}\n\nasync function loadParentUpcomingEvents')
    );

    expect(summaryTailBlock).toContain('processDomainSnapshot: pdMasterySnap.docs');
    expect(summaryTailBlock).toContain('processDomainGrowthTimeline: pdGrowthSnap.docs');
    expect(summaryTailBlock).toContain('title: processDomainTitlesById.get(processDomainId) ?? processDomainId');
    expect(summaryTailBlock).toContain('reviewingEducatorName: educatorId ? reviewerNames[educatorId] ?? null : null');
    expect(summaryTailBlock).toContain('linkedEvidenceRecordIds: evidenceIds');
    expect(summaryTailBlock).toContain('missionAttemptId: typeof data.missionAttemptId');
    expect(summaryTailBlock).toContain('rubricApplicationId: typeof data.rubricApplicationId');
    expect(summaryTailBlock).toContain('rubricRawScore: typeof data.rawScore');
  });
});