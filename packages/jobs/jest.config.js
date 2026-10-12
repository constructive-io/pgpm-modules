/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  forceExit: true,
  // queue-claim-order and queue-batch each open 64 concurrent claimers; run
  // files serially so two of them never exceed Postgres' default
  // max_connections (100).
  maxWorkers: 1,
  preset: 'ts-jest',
  testEnvironment: 'node',

  // Match both __tests__ and colocated test files
  testMatch: ['**/?(*.)+(test|spec).{ts,tsx,js,jsx}'],

  // Ignore build artifacts and type declarations
  testPathIgnorePatterns: ['/dist/', '\\.d\\.ts$'],
  modulePathIgnorePatterns: ['<rootDir>/dist/'],
  watchPathIgnorePatterns: ['/dist/'],

  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node'],
};
