module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/src/__tests__/**/*.test.ts'],
  moduleNameMapper: {
    '^@/src/(.*)$': '<rootDir>/src/$1',
  },
  modulePathIgnorePatterns: ['<rootDir>/functions/', '<rootDir>/flutter/'],
  setupFilesAfterEnv: ['<rootDir>/src/__tests__/setupTests.ts'],
};