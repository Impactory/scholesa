import fs from 'node:fs';
import path from 'node:path';

const functionsRoot = __dirname;

function readFunctionsFile(...relativePath: string[]): string {
  return fs.readFileSync(path.join(functionsRoot, ...relativePath), 'utf8');
}

describe('functions MiloOS wording', () => {
  it('keeps learner-facing callable errors on MiloOS wording', () => {
    const indexSource = readFunctionsFile('index.ts');

    expect(indexSource).toContain("'Learner role required for MiloOS.'");
    expect(indexSource).toContain("'MiloOS session not found.'");
    expect(indexSource).toContain("'interactionId must reference a MiloOS session.'");
    expect(indexSource).toContain("'MiloOS session ownership mismatch.'");
    expect(indexSource).not.toContain('Learner role required for AI coach.');
  });
});