import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');

function listJsonFiles(relativeDir: string): string[] {
  const absoluteDir = path.join(repoRoot, relativeDir);

  return fs.readdirSync(absoluteDir)
      .filter((entry) => entry.endsWith('.json'))
      .sort()
      .map((entry) => path.join(absoluteDir, entry));
}

describe('locale json parse smoke', () => {
  it('parses shared locale catalogs without syntax errors', () => {
    const localeFiles = [
      ...listJsonFiles(path.join('packages', 'i18n', 'locales')),
      ...listJsonFiles('locales'),
    ];

    expect(localeFiles.length).toBeGreaterThan(0);

    for (const localeFile of localeFiles) {
      const localeSource = fs.readFileSync(localeFile, 'utf8');

      expect(() => JSON.parse(localeSource)).not.toThrow();
    }
  });
});