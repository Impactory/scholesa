const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');

describe('Firebase config source contracts', () => {
  test('Flutter app Firebase config reuses root security rules', () => {
    const configPath = path.join(repoRoot, 'apps/empire_flutter/app/firebase.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

    expect(config.firestore.rules).toBe('../../../firestore.rules');
    expect(config.firestore.indexes).toBe('../../../firestore.indexes.json');
    expect(config.storage.rules).toBe('../../../storage.rules');

    expect(fs.existsSync(path.resolve(path.dirname(configPath), config.firestore.rules))).toBe(true);
    expect(fs.existsSync(path.resolve(path.dirname(configPath), config.firestore.indexes))).toBe(true);
    expect(fs.existsSync(path.resolve(path.dirname(configPath), config.storage.rules))).toBe(true);
  });
});
