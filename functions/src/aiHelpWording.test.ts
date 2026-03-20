import fs from 'node:fs';
import path from 'node:path';

const functionsRoot = __dirname;

function readFunctionsFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(functionsRoot, ...relativePath), 'utf8');
}

describe('functions AI help wording', () => {
  it('keeps learner-facing callable errors on AI help wording', () => {
    const indexSource = readFunctionsFile('index.ts');

    expect(indexSource).toContain("'Learner role required for AI help.'");
    expect(indexSource).toContain("'AI help session not found.'");
    expect(indexSource).toContain("'interactionId must reference an AI help session.'");
    expect(indexSource).toContain("'AI help session ownership mismatch.'");
    expect(indexSource).not.toContain('Learner role required for AI coach.');
  });
});