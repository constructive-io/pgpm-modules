



# Migration Map (Legacy -> New Single Workspace)

This file will be updated as we move each package. Destination categories follow PLAN.md.

Progress
- [x] @launchql/ext-verify -> packages/security/ext-verify
- [x] @launchql/ext-types -> packages/data-types/ext-types
- [x] @launchql/ext-default-roles -> packages/security/ext-default-roles
- [x] @launchql/ext-jwt-claims -> packages/security/ext-jwt-claims
- [x] @launchql/ext-jobs -> packages/jobs/ext-jobs

- [x] @launchql/ext-uuid -> packages/data-types/ext-uuid

- [x] @launchql/ext-defaults -> packages/utils/defaults
- [x] @launchql/utils -> packages/utils/utils
- [x] @launchql/inflection -> packages/data-types/inflection
- [x] @launchql/measurements -> packages/metrics/measurements
- [x] @launchql/ext-stamps -> packages/data-types/stamps
- [x] @launchql/base32 -> packages/data-types/base32
- [x] @launchql/geotypes -> packages/geo/geotypes
- [x] @launchql/achievements -> packages/metrics/achievements
- [x] @launchql/faker -> packages/utils/faker
- [x] @launchql/totp -> packages/utils/totp


Details
- ext-verify source: source/utils/packages/verify
- ext-types source: source/utils/packages/types
- ext-uuid source: source/utils/packages/uuid

Legend:
- [ ] pending
- [x] migrated

Security (packages/security/*)
- [x] @launchql/ext-jwt-claims    source/utils/packages/jwt-claims or source/internal-utils/extensions/@launchql/ext-jwt-claims -> packages/security/ext-jwt-claims
- [x] @launchql/ext-verify        source/utils/packages/verify or source/pg-utils/packages/verify -> packages/security/ext-verify
- [x] @launchql/ext-default-roles source/utils/packages/default-roles or source/pg-utils/packages/default-roles or source/internal-utils/extensions/@launchql/ext-default-roles -> packages/security/ext-default-roles
- [x] encrypted-secrets           source/internal-utils/packages/encrypted-secrets -> packages/security/encrypted-secrets
- [x] encrypted-secrets-table     source/internal-utils/packages/encrypted-secrets-table -> packages/security/encrypted-secrets-table

Jobs (packages/jobs/*)
- [x] @launchql/ext-jobs          source/utils/packages/jobs or source/pg-utils/packages/jobs or source/internal-utils/extensions/@launchql/ext-jobs -> packages/jobs/ext-jobs
- [x] jobs-simple                 source/utils/packages/jobs-simple -> packages/jobs/jobs-simple

Data Types (packages/data-types/*)
- [x] @launchql/ext-types         source/utils/packages/types or source/pg-utils/packages/types or source/internal-utils/extensions/@launchql/ext-types -> packages/data-types/ext-types
- [x] @launchql/ext-uuid          source/utils/packages/uuid -> packages/data-types/ext-uuid
- [x] base32                      source/utils/packages/base32 -> packages/data-types/base32
- [x] inflection                  source/utils/packages/inflection or source/internal-utils/extensions/@launchql/inflection -> packages/data-types/inflection
- [x] stamps                      source/utils/packages/stamps or source/internal-utils/extensions/@launchql/ext-stamps -> packages/data-types/ext-stamps

Metrics (packages/metrics/*)
- [x] measurements                source/utils/packages/measurements or source/pg-utils/packages/measurements -> packages/metrics/measurements
- [x] achievements                source/utils/packages/achievements -> packages/metrics/achievements

Geo (packages/geo/*)
- [x] geotypes                    source/utils/packages/geotypes -> packages/geo/geotypes

Utils (packages/utils/*)
- [x] @launchql/utils             source/utils/packages/utils or source/pg-utils/packages/utils -> packages/utils/utils
- [x] @launchql/ext-defaults      source/utils/packages/defaults or source/pg-utils/packages/defaults -> packages/utils/ext-defaults
- [x] faker                       source/utils/packages/faker -> packages/utils/faker
- [x] totp                        source/utils/packages/totp -> packages/utils/totp

Meta (packages/meta/*)
- [x] db_meta                     source/internal-utils/packages/db_meta -> packages/meta/db_meta
- [x] db_meta_modules             source/internal-utils/packages/db_meta_modules -> packages/meta/db_meta_modules
- [x] db_meta_test                source/internal-utils/packages/db_meta_test -> packages/meta/db_meta_test

Notes
- Prefer @launchql/ext-* scoped names for extensions.
- Normalize package.json scripts, metadata, and internal deps (workspace:^).
- Use dual TS outputs (CJS + ESM) mirroring example packages.
