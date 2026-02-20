module.exports = {
  testEnvironment: 'node',
  testTimeout: 60000,
  roots: ['<rootDir>/src'],
  testMatch: ['<rootDir>/src/lib/analytics/analyticsEngine.test.ts'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }],
  },
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  setupFiles: ['<rootDir>/jest.setup.js'],
};
