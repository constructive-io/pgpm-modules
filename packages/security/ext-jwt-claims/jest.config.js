module.exports = {
  testEnvironment: 'node',
  rootDir: '.',
  roots: ['<rootDir>/__tests__'],
  testMatch: ['<rootDir>/__tests__/**/*.test.ts', '<rootDir>/?(*.)+(spec|test).ts'],
  testPathIgnorePatterns: ['/dist/'],
  modulePathIgnorePatterns: ['<rootDir>/dist/'],
  watchPathIgnorePatterns: ['/dist/'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'json'],
  transform: {
    '^.+\\.(ts|tsx)$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.jest.json' }]
  }
};
