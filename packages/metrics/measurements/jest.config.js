module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  roots: ['<rootDir>/__tests__'],
  testMatch: ['<rootDir>/__tests__/**/*.test.ts', '<rootDir>/__tests__/**/*.spec.ts'],
  testPathIgnorePatterns: ['/dist/', '\\.d\\.ts$'],
  modulePathIgnorePatterns: ['/dist/'],
  watchPathIgnorePatterns: ['/dist/'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'json'],
  setupFilesAfterEnv: ['<rootDir>/__tests__/jest.setup.ts'],
  maxWorkers: 1
};
