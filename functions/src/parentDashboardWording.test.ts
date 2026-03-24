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
});