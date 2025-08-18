module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  roots: ['<rootDir>'],
  testMatch: ['<rootDir>/__tests__/**/*.test.ts', '<rootDir>/?(*.)+(spec|test).ts'],
  testPathIgnorePatterns: ['/dist/'],
  modulePathIgnorePatterns: ['<rootDir>/dist/'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'json']
};
