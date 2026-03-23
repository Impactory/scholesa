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
});