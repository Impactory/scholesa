const runEmulatorTests = process.env.RUN_EMULATOR_TESTS === '1';

module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/*.test.ts',
    '!src/**/*.spec.ts',
  ],
  testPathIgnorePatterns: [
    '<rootDir>/src/coppaGuards.spec.ts',
    '<rootDir>/src/voiceSystem.voiceSmoke.spec.ts',
    ...(runEmulatorTests ? [] : ['<rootDir>/src/evidenceChainEmulator.test.ts']),
  ],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node'],
  transform: {
    '^.+\\.(ts|tsx)$': ['ts-jest', { tsconfig: 'tsconfig.json' }],
  },
};
