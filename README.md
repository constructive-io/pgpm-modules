# LaunchQL Extensions

PostgreSQL extensions using the LaunchQL/Sqitch-style workflow for safe, testable, reversible SQL changes.

## Overview

LaunchQL extends the Sqitch model to a multi-package npm workspace. Each package contains SQL changes organized as deploy/verify/revert triplets, enabling safe database migrations with proper rollback capabilities.

## Installation

```bash
# Install dependencies
pnpm install

# Install LaunchQL CLI globally
npm install -g @launchql/cli
```

## Package Structure

### Data Types
- `@lql-pg/types` - Core PostgreSQL data types
- `@lql-pg/uuid` - UUID utilities and extensions
- `@lql-pg/stamps` - Timestamp utilities and audit trails
- `@lql-pg/geotypes` - Geographic data types and spatial functions

### Jobs & Background Processing
- `@lql-pg/jobs` - Core job system for background tasks
- `@lql-pg/database-jobs` - Database-specific job handling

### Meta & Database Introspection
- `@lql-pg/db_meta` - Database metadata utilities
- `@lql-pg/db_meta_modules` - Module metadata handling
- `@lql-pg/db_meta_test` - Testing utilities for metadata

### Security & Authentication
- `@lql-pg/default-roles` - Default PostgreSQL role definitions
- `@lql-pg/defaults` - Security defaults and configurations
- `@lql-pg/jwt-claims` - JWT claim handling and validation
- `@lql-pg/totp` - Time-based One-Time Password authentication
- `@lql-pg/encrypted-secrets` - Encrypted secrets management
- `@lql-pg/encrypted-secrets-table` - Table-based encrypted secrets

### Utilities
- `@lql-pg/utils` - General utility functions
- `@lql-pg/verify` - Verification utilities (used by other modules)
- `@lql-pg/inflection` - String inflection utilities
- `@lql-pg/base32` - Base32 encoding/decoding
- `@lql-pg/faker` - Fake data generation for testing

### Metrics & Analytics
- `@lql-pg/measurements` - Performance tracking and analytics
- `@lql-pg/achievements` - Achievement system for user progress

## LaunchQL Workflow

Each package follows the deploy/verify/revert pattern:

- **Deploy**: `deploy/**/*.sql` - Applies database changes
- **Verify**: `verify/**/*.sql` - Proves changes work correctly
- **Revert**: `revert/**/*.sql` - Safely removes changes

### Basic Commands

```bash
# Deploy changes
lql deploy

# Verify deployment
lql verify

# Revert changes
lql revert

# Package a module
lql package
```

## Development

```bash
# Install dependencies
pnpm install

# Build all packages
pnpm -r build

# Test all packages
pnpm -r test

# Clean build artifacts
pnpm -r clean

# Lint code
pnpm eslint .
```

## Publishing

```bash
# Version packages
lerna version

# Publish to npm
lerna publish from-package
```

## Dependencies

Packages use workspace protocol for internal dependencies:
```json
{
  "dependencies": {
    "@lql-pg/verify": "workspace:*"
  }
}
```

For more details on the LaunchQL workflow, see [AGENTS.md](./AGENTS.md).
