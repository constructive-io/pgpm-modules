# LaunchQL Extension Modules Verification Checklist

## What This Checklist Means

✅ **When a module is checked, it means:**

1. **Complete File Structure**: Every file in `deploy/**/*.sql` has a corresponding file in both `revert/**/*.sql` and `verify/**/*.sql`
2. **Functional Verification**: All deploy, revert, and verify operations work properly
3. **Proper Verification Utilities**: The verify scripts use the `launchql-verify` package's utilities from `packages/utils/verify`
4. **Dependency Requirements**: If verification utilities are used, `launchql-verify` is properly declared as a dependency in the project's control file

## Verification Requirements

- **Deploy**: Contains the actual SQL changes/additions
- **Revert**: Contains SQL to undo the deploy changes
- **Verify**: Contains SQL to verify the changes were applied correctly (should use `launchql-verify` utilities)
- **Control File**: Must include `launchql-verify` as a dependency if verification utilities are used

---

## Data Types

### Core Types
- [ ] `packages/data-types/types` - Core data types (ISSUE: domain verification failures - attachment, email, hostname, image, multiple_select, single_select, upload, url domains fail verification)
- [ ] `packages/data-types/uuid` - UUID utilities
- [ ] `packages/data-types/stamps` - Timestamp utilities
- [ ] `packages/data-types/geotypes` - Geographic data types (ISSUE: deployment fails due to embedded types package creating domain conflicts - "type 'attachment' already exists")

## Jobs & Background Processing

### Job Management
- [ ] `packages/jobs/jobs` - Core job system
- [ ] `packages/jobs/database-jobs` - Database-specific job handling

## Meta & Database Introspection

### Database Metadata
- [ ] `packages/meta/db_meta` - Core database metadata utilities
- [ ] `packages/meta/db_meta_modules` - Module metadata handling
- [ ] `packages/meta/db_meta_test` - Testing utilities for metadata

## Security & Authentication

### Core Security
- [ ] `packages/security/default-roles` - Default role definitions (ISSUE: Revert fails due to cross-database role dependencies)
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

---


## Test Results Summary

**Last Updated:** September 11, 2025
**Test Environment:** Docker PostgreSQL 13
**LaunchQL CLI Version:** 4.9.0

**Passing Modules (16/22):** verify, base32, uuid, db_meta, jobs, database-jobs, defaults, db_meta_modules, db_meta_test, jwt-claims, totp, encrypted-secrets-table, encrypted-secrets, measurements, achievements, inflection, stamps
**Failing Modules (6/22):** utils, faker, types, default-roles, geotypes
**Untested Modules (0/22):** All packages have been tested

### Common Issues Found

1. **Revert Script Issues:**
   - Function name conflicts requiring explicit signatures in DROP statements (inflection)
   - Schema dependency issues requiring CASCADE or proper ordering (utils)

2. **Verification Failures:**
   - Domain verification failures in types package affecting dependent packages
   - Table and procedure verification failures (faker, stamps)

3. **Dependency Chain Problems:**
   - Many packages depend on the types package which has verification failures
   - The verify package works correctly and is properly used as a dependency

## Notes

- The `packages/utils/verify` module provides essential verification utilities that should be used in other modules' verify scripts
- All modules should follow the same deploy/revert/verify pattern
- Control files must declare dependencies properly
- Each SQL file should be properly tested and reversible
- Individual package testing reveals issues not caught by batch testing due to dependency order problems
