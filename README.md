# pgpm Extensions

PostgreSQL extensions using the pgpm/Sqitch-style workflow for safe, testable, reversible SQL changes.

## Overview

pgpm extends the Sqitch model to a multi-package npm workspace. Each package contains SQL changes organized as deploy/verify/revert triplets, enabling safe database migrations with proper rollback capabilities.

## Installation

```bash
# Install dependencies
pnpm install

# Install pgpm CLI globally
npm install -g @launchql/cli
```

## Package Structure

### Data Types
- `@pgpm/types` - Core PostgreSQL data types
- `@pgpm/uuid` - UUID utilities and extensions
- `@pgpm/stamps` - Timestamp utilities and audit trails
- `@pgpm/geotypes` - Geographic data types and spatial functions

### Jobs & Background Processing
- `@pgpm/jobs` - Core job system for background tasks
- `@pgpm/database-jobs` - Database-specific job handling

### Meta & Database Introspection
- `@pgpm/db_meta` - Database metadata utilities
- `@pgpm/db_meta_modules` - Module metadata handling
- `@pgpm/db_meta_test` - Testing utilities for metadata

### Security & Authentication
- `@pgpm/default-roles` - Default PostgreSQL role definitions
- `@pgpm/defaults` - Security defaults and configurations
- `@pgpm/jwt-claims` - JWT claim handling and validation
- `@pgpm/totp` - Time-based One-Time Password authentication
- `@pgpm/encrypted-secrets` - Encrypted secrets management
- `@pgpm/encrypted-secrets-table` - Table-based encrypted secrets

### Utilities
- `@pgpm/utils` - General utility functions
- `@pgpm/verify` - Verification utilities (used by other modules)
- `@pgpm/inflection` - String inflection utilities
- `@pgpm/base32` - Base32 encoding/decoding
- `@pgpm/faker` - Fake data generation for testing

### Metrics & Analytics
- `@pgpm/measurements` - Performance tracking and analytics
- `@pgpm/achievements` - Achievement system for user progress

## pgpm Workflow

Each package follows the deploy/verify/revert pattern:

- **Deploy**: `deploy/**/*.sql` - Applies database changes
- **Verify**: `verify/**/*.sql` - Proves changes work correctly
- **Revert**: `revert/**/*.sql` - Safely removes changes

### Basic Commands

```bash
# Deploy changes
pgpm deploy

# Verify deployment
pgpm verify

# Revert changes
pgpm revert

# Package a module
pgpm package
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
    "@pgpm/verify": "workspace:*"
  }
}
```

For more details on the pgpm workflow, see [AGENTS.md](./AGENTS.md).
