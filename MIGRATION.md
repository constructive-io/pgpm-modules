# Migration Notes Update

## Local development prerequisites
- Use Node 20 or 18. We recommend Node 20 for parity with CI.
  - If using nvm: `nvm install 20 && nvm use 20` (also see .nvmrc at repo root)

## DB-backed tests (local)
The CI uses a Postgres/PostGIS service and prepares extensions/schemas. Locally, mirror this setup:
- Ensure Postgres is running and accessible
- Create extensions and schemas as needed by packages:
  - Extensions: postgis, pgcrypto, citext, uuid-ossp
  - Schemas: myschema, myschema_public, meta_public, meta_private, collections_public, collections_private, app_jobs
- Export env (adjust host/port as needed):
```
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=testdb
- Dist now includes SQL assets for SQL-backed packages: launchql.plan, deploy/, verify/, revert/, schemas/, *.control, optional sql/, and sqitch.conf. Copy scripts standardized with cpy --parents --cwd . so nested directories are preserved during build.
- TypeScript emit excludes __tests__/ to keep test sources out of dist via per-package tsconfig.json exclude.
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/testdb
```

## Per-package Jest scoping
Each package contains a local `jest.config.js`. Running tests within a package only runs that package’s tests:
- Example: `pnpm --filter @launchql/ext-uuid test`
- All packages: `pnpm -r test`

## Historical tests
All historical tests from legacy workspaces were restored and converted to TypeScript under `packages/*/**/__tests__`. No `.test.js` or `.spec.js` files remain, and no placeholder tests were left in place.
- Legacy JS test files that co-existed with the restored TS tests have been removed to avoid duplication.
- Per-package utils from history were restored where required so the original test logic runs unchanged (modulo TS types).
## SQL assets
For each SQL-backed extension/package:
- `sqitch.plan` files were renamed to `launchql.plan` while preserving any existing `launchql.plan`
- `deploy/`, `verify/`, `revert/` directories were restored
- Package copy scripts include these assets in `dist/`

## CI note
GitHub Actions is configured to run on Node 20 with a PostGIS service and prepared schemas/extensions. If CI is temporarily blocked (e.g., billing), you can validate locally using the steps above and re-run CI once unblocked.
Tests migration
- Restored historical tests from legacy workspaces (source/internal-utils, source/pg-utils, source/utils) into packages/* by category.
- Converted all JavaScript tests to TypeScript (*.test.ts) and placed under __tests__.
- Updated Jest to use ts-jest at the root and aligned per-package test scripts to reference the root config.
- Skipped DB integration tests by default where applicable to avoid env dependencies; structure and assertions preserved.
- Confirmed no *.test.js or *.spec.js remain under packages/*.




SQL assets restored and publishing
- Renamed sqitch.plan to launchql.plan across packages while preserving any existing launchql.plan files.
- Ensured SQL assets (deploy/, verify/, revert/, sql/, *.control, sqitch.conf, launchql.plan) are included in published dist by updating package copy scripts.
- Added repository script "migrate:sql" to move SQL assets into packages and rename sqitch.plan to launchql.plan.




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
## Helper scripts

Start a local PostGIS and prepare CI-like DB (extensions/schemas):
```
pnpm db:start
```

Stop and remove the local DB container:
```
pnpm db:stop
```

Run all package tests against the local DB:
```
pnpm test:db
```

## Quick commands

Setup Node and install deps:
```
nvm use 20
pnpm install
```

Build all packages:
```
pnpm -r build
```

Run tests for a single package (scoped to that package only):
```
pnpm --filter @launchql/ext-uuid test
pnpm --filter @launchql/ext-types test
pnpm --filter @launchql/measurements test
```

Run tests for all packages (requires Postgres env vars set as above):
```
pnpm -r test
```

Optional: start a local Postgres with PostGIS using Docker
```
docker run --name launchql-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=testdb -p 5432:5432 -d postgis/postgis:15-3.4
```
## Local DB-backed testing and per-package Jest

 - Each package has its own jest.config.js with roots: ['<rootDir>/__tests__'] so running pnpm test inside a package only runs that package's tests.
- Tests use @launchql/db-testing to provision a fresh database per test run using createdb -T testing-template-db.
- Ensure each SQL-backed package contains:
  - launchql.plan (and a mirrored sqitch.plan where applicable), deploy/, verify/, revert/, and any required *.control files.
  - These assets are included in dist by each package’s build/copy steps.
- TypeScript test configs:
  - Packages that need local test typings include tsconfig.jest.json and use ts-jest transform in their jest.config.js.
  - Intentional ambient test types should live in __tests__/types.d.ts. Generated declaration artifacts like *.test.d.ts are ignored by .gitignore.
