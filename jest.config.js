module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/test'],
  testMatch: ['**/?(*.)+(test).[tj]s?(x)'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }],
  },
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  testPathIgnorePatterns: [
    '<rootDir>/test/firestore-rules.test.js',
    '<rootDir>/src/lib/analytics/analyticsEngine.test.ts',
  ],
  modulePathIgnorePatterns: ['<rootDir>/functions/', '<rootDir>/apps/empire_flutter/app/'],
  setupFiles: ['<rootDir>/jest.setup.js'],
};