import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

const scannedRoots = [
  path.join(repoRoot, 'src'),
  path.join(repoRoot, 'functions', 'src'),
  path.join(repoRoot, 'apps', 'empire_flutter', 'app', 'lib'),
];

const allowedLegacyFiles = new Set([
  path.join(repoRoot, 'functions', 'src', 'aiCoachTone.ts'),
  path.join(repoRoot, 'functions', 'src', 'workflowOps.ts'),
  path.join(repoRoot, 'src', 'features', 'workflows', 'workflowData.ts'),
]);

const relevantExtensions = new Set(['.ts', '.tsx', '.dart']);
const forbiddenPatterns = [
  /\bMiloOS\b/g,
  /\bAI Coach\b/g,
  /\bAI coach\b/g,
  /\bmiloos_loop\b/g,
  /\bmiloosLoop\b/g,
  /\bmiloos_voice_[a-z_]+\b/g,
];

function collectFiles(dirPath: string): string[] {
  const results: string[] = [];
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const resolved = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === '__tests__' || entry.name === 'test') {
        continue;
      }
      results.push(...collectFiles(resolved));
      continue;
    }

    if (
      relevantExtensions.has(path.extname(entry.name)) &&
      !entry.name.endsWith('.test.ts') &&
      !entry.name.endsWith('.spec.ts') &&
      !entry.name.endsWith('.test.tsx') &&
      !entry.name.endsWith('.spec.tsx') &&
      !entry.name.endsWith('_test.dart')
    ) {
      results.push(resolved);
    }
  }
  return results;
}

describe('assistant legacy branding guard', () => {
  it('keeps legacy assistant branding out of active code paths', () => {
    const violations: string[] = [];

    for (const root of scannedRoots) {
      for (const filePath of collectFiles(root)) {
        if (allowedLegacyFiles.has(filePath)) {
          continue;
        }

        const source = fs.readFileSync(filePath, 'utf8');
        const matchedPatterns = forbiddenPatterns
          .filter((pattern) => pattern.test(source))
          .map((pattern) => pattern.source);

        if (matchedPatterns.length > 0) {
          violations.push(`${path.relative(repoRoot, filePath)} -> ${matchedPatterns.join(', ')}`);
        }
      }
    }

    expect(violations).toEqual([]);
  });
});