# PGPM Modules Verification Checklist

## What This Checklist Means

✅ **When a module is checked, it means:**

1. **Complete File Structure**: Every file in `deploy/**/*.sql` has a corresponding file in both `revert/**/*.sql` and `verify/**/*.sql`
2. **Functional Verification**: All deploy, revert, and verify operations work properly
3. **Proper Verification Utilities**: The verify scripts use the `pgpm-verify` package's utilities from `packages/utils/verify`
4. **Dependency Requirements**: If verification utilities are used, `pgpm-verify` is properly declared as a dependency in the project's control file

## Verification Requirements

- **Deploy**: Contains the actual SQL changes/additions
- **Revert**: Contains SQL to undo the deploy changes
- **Verify**: Contains SQL to verify the changes were applied correctly (should use `pgpm-verify` utilities)
- **Control File**: Must include `pgpm-verify` as a dependency if verification utilities are used

---

## Data Types

### Core Types
- [ ] `packages/data-types/types` - Core data types
- [ ] `packages/data-types/uuid` - UUID utilities
- [ ] `packages/data-types/stamps` - Timestamp utilities
- [ ] `packages/data-types/geotypes` - Geographic data types

## Jobs & Background Processing

### Job Management
- [ ] `packages/jobs/jobs` - Core job system
- [ ] `packages/jobs/database-jobs` - Database-specific job handling

## Meta & Database Introspection

### Database Metadata
- [ ] `packages/meta/db-meta-schema` - Database metadata schema and utilities
- [ ] `packages/meta/db-meta-modules` - Module metadata handling

## Security & Authentication

### Core Security
- [ ] `packages/security/defaults` - Security defaults
- [ ] `packages/security/jwt-claims` - JWT claim handling
- [ ] `packages/security/totp` - Time-based One-Time Password (TOTP)

### Encryption & Secrets
- [ ] `packages/security/encrypted-secrets` - Encrypted secrets management
- [ ] `packages/security/encrypted-secrets-table` - Table-based encrypted secrets

## Utilities

### Core Utilities
- [ ] `packages/utils/utils` - General utility functions
- [ ] `packages/utils/verify` - Verification utilities (used by other modules)
- [ ] `packages/utils/inflection` - String inflection utilities
- [ ] `packages/utils/base32` - Base32 encoding/decoding
- [ ] `packages/utils/faker` - Fake data generation

## Metrics & Analytics

### Performance & Tracking
- [ ] `packages/metrics/measurements` - Measurement utilities
- [ ] `packages/metrics/achievements` - Achievement system
