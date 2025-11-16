# pgpm modules

PostgreSQL modules using the `pgpm` workflow for safe, testable, reversible SQL changes.

## Overview

**pgpm** is a modern CLI for modular PostgreSQL development—a focused command-line tool for PostgreSQL database migrations and package management. It provides the core functionality for managing database schemas, migrations, and module dependencies.

This repository contains a curated collection of PostgreSQL modules built using the `pgpm` workflow. Each module follows the Sqitch-inspired deploy/verify/revert pattern, extending it to a multi-package npm workspace where SQL changes are organized as triplets, enabling safe database migrations with proper rollback capabilities.

### Key Features

- 📦 **Postgres Module System** — Reusable, composable database packages with dependency management, per-module plans, and versioned releases
- 🔄 **Deterministic Migration Engine** — Version-controlled, plan-driven deployments with rollback support and idempotent execution enforced by dependency and validation safeguards
- 📊 **Recursive Module Resolution** — Recursively resolves database package dependencies (just like npm) from plan files or SQL headers, producing a reproducible cross-module migration graph
- 🏷️ **Tag-Aware Versioning** — Deploy to @tags, resolve tags to changes, and reference tags across modules for coordinated releases
- 🐘 **Portable Postgres Development** — Rely on standard SQL migrations for a workflow that runs anywhere Postgres does

## Installation

```bash
# Install pgpm CLI 
npm install -g pgpm
```

## Using These Modules

All modules in this repository are published to npm under the `@pgpm` scope. Install and use them in your own pgpm projects.

### 🚀 Quick Start

#### Setup Your Environment

```bash
# Start local Postgres (via Docker) and export env vars
pgpm docker start
eval "$(pgpm env)"
```

> **Tip:** Already running Postgres? Skip the Docker step and just export your `PG*` environment variables.

#### Create a Workspace and Install a Package

```bash
# 1. Create a workspace
pgpm init --workspace
cd my-app

# 2. Create your first module
pgpm init
cd packages/your-module

# 3. Install a package 
pgpm install @pgpm/faker

# 4. Deploy everything
pgpm deploy --createdb --database mydb1
psql -d mydb1 -c "SELECT faker.city('MI');"
>  Ann Arbor
```

#### Add to an Existing Module

```bash
# 1. Navigate to your module
cd packages/your-module

# 2. Install a package 
pgpm install @pgpm/faker

# 3. Deploy all installed modules
pgpm deploy --createdb --database mydb1
psql -d mydb1 -c "SELECT faker.city('MI');"
>  Sterling Heights
```

#### Add a Database Change

```bash
# 1. Navigate to your module
cd packages/your-module

# 2. Add a database change
pgpm add some_change
```

#### Testing your Database

```bash
# 1. Navigate to your module
cd packages/your-module

# 2. Add a database change
pnpm test:watch
```

Each module includes its own README with detailed documentation. See individual package directories for usage examples and API documentation.

---

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

Each package follows the Sqitch-inspired **deploy/verify/revert** pattern:

- **Deploy**: `deploy/**/*.sql` - Applies database changes
- **Verify**: `verify/**/*.sql` - Proves changes work correctly
- **Revert**: `revert/**/*.sql` - Safely removes changes

## Developing

This section is for **contributing to** or **developing** the modules in this repository. If you just want to use the published modules, see [Using These Modules](#using-these-modules) above.

### Getting Started

```bash
# Clone the repository
git clone https://github.com/launchql/pgpm-modules.git
cd pgpm-modules

# Install dependencies
pnpm install
```

### Testing a Package

```bash
# 1. Install workspace deps
pnpm install

# 2. Enter the module directory
cd packages/utils/base32

# 3. Run tests in watch mode
pnpm test:watch
```

### Publishing

```bash
# Publish to npm
pnpm lerna publish
```

## Related Tooling

* [pgpm](https://github.com/launchql/launchql/tree/main/packages/pgpm): **🖥️ PostgreSQL Package Manager** for modular Postgres development. Works with database workspaces, scaffolding, migrations, seeding, and installing database packages.
* [pgsql-test](https://github.com/launchql/launchql/tree/main/packages/pgsql-test): **📊 Isolated testing environments** with per-test transaction rollbacks—ideal for integration tests, complex migrations, and RLS simulation.
* [supabase-test](https://github.com/launchql/launchql/tree/main/packages/supabase-test): **🧪 Supabase-native test harness** preconfigured for the local Supabase stack—per-test rollbacks, JWT/role context helpers, and CI/GitHub Actions ready.
* [graphile-test](https://github.com/launchql/launchql/tree/main/packages/graphile-test): **🔐 Authentication mocking** for Graphile-focused test helpers and emulating row-level security contexts.
* [pgsql-parser](https://github.com/launchql/pgsql-parser): **🔄 SQL conversion engine** that interprets and converts PostgreSQL syntax.
* [libpg-query-node](https://github.com/launchql/libpg-query-node): **🌉 Node.js bindings** for `libpg_query`, converting SQL into parse trees.
* [pg-proto-parser](https://github.com/launchql/pg-proto-parser): **📦 Protobuf parser** for parsing PostgreSQL Protocol Buffers definitions to generate TypeScript interfaces, utility functions, and JSON mappings for enums.

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.
