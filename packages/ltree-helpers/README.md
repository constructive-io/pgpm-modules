# @pgpm/ltree-helpers

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/ltree-helpers"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Fltree-helpers%2Fpackage.json"/></a>
</p>

Slash-path to ltree/lquery conversion helpers for PostgreSQL.

## Overview

`@pgpm/ltree-helpers` provides simple SQL functions for converting between user-facing slash-delimited paths (like `/projects/alpha/docs`) and PostgreSQL's `ltree`/`lquery` types. This keeps ltree as an implementation detail while exposing a familiar filesystem-style path API.

## Features

- **Slash to ltree**: Convert `/projects/alpha/docs` to `projects.alpha.docs`
- **ltree to slash**: Convert `projects.alpha.docs` to `/projects/alpha/docs`
- **Glob to lquery**: Convert `/projects/*/docs` to `projects.*.docs` and `/**` to `.*{1,}`
- **Pure SQL**: All functions are `IMMUTABLE STRICT` for maximum performance and plan caching
- **Own schema**: Functions live in the `ltree_helpers` schema, not in `public`

## Installation

```bash
cd packages/my-module
pgpm install @pgpm/ltree-helpers
```

## Usage

```sql
-- Slash path to ltree
SELECT ltree_helpers.to_path('/projects/alpha/docs');
-- => 'projects.alpha.docs'::ltree

-- ltree to slash path
SELECT ltree_helpers.to_slash('projects.alpha.docs'::ltree);
-- => '/projects/alpha/docs'

-- Glob to lquery (single-level wildcard)
SELECT ltree_helpers.to_query('/projects/*/docs');
-- => 'projects.*.docs'::lquery

-- Glob to lquery (recursive wildcard)
SELECT ltree_helpers.to_query('/projects/**');
-- => 'projects.*{1,}'::lquery

-- Use with ltree operators
SELECT * FROM files
WHERE path <@ ltree_helpers.to_path('/projects/alpha');

-- Glob matching
SELECT * FROM files
WHERE path ~ ltree_helpers.to_query('/projects/*/docs');
```

## API

| Function | Signature | Description |
|----------|-----------|-------------|
| `ltree_helpers.to_path` | `(text) -> ltree` | Slash path to ltree |
| `ltree_helpers.to_slash` | `(ltree) -> text` | ltree to slash path |
| `ltree_helpers.to_query` | `(text) -> lquery` | Glob pattern to lquery |

## Dependencies

- `ltree` (PostgreSQL contrib extension)
- `pgpm-verify`

## Related Tooling

* [pgpm](https://github.com/constructive-io/constructive/tree/main/pgpm/pgpm): **🖥️ PostgreSQL Package Manager** for modular Postgres development. Works with database workspaces, scaffolding, migrations, seeding, and installing database packages.
* [pgsql-test](https://github.com/constructive-io/constructive/tree/main/postgres/pgsql-test): **📊 Isolated testing environments** with per-test transaction rollbacks—ideal for integration tests, complex migrations, and RLS simulation.
* [supabase-test](https://github.com/constructive-io/constructive/tree/main/postgres/supabase-test): **🧪 Supabase-native test harness** preconfigured for the local Supabase stack—per-test rollbacks, JWT/role context helpers, and CI/GitHub Actions ready.
* [graphile-test](https://github.com/constructive-io/constructive/tree/main/graphile/graphile-test): **🔐 Authentication mocking** for Graphile-focused test helpers and emulating row-level security contexts.
* [pgsql-parser](https://github.com/constructive-io/pgsql-parser): **🔄 SQL conversion engine** that interprets and converts PostgreSQL syntax.
* [libpg-query-node](https://github.com/constructive-io/libpg-query-node): **🌉 Node.js bindings** for `libpg_query`, converting SQL into parse trees.
* [pg-proto-parser](https://github.com/constructive-io/pg-proto-parser): **📦 Protobuf parser** for parsing PostgreSQL Protocol Buffers definitions to generate TypeScript interfaces, utility functions, and JSON mappings for enums.

### 📚 Documentation & Skills

* [constructive-skills](https://github.com/constructive-io/constructive-skills): **📖 Platform documentation and AI agent skills** — feature catalog, blueprint reference, SDK guides, and deployment guides.

Install skills for AI coding agents:

```bash
# All platform skills (security, blueprints, codegen, billing, etc.)
npx skills add constructive-io/constructive-skills

# Individual repo skills (pgpm, testing, CLI, search, etc.)
npx skills add https://github.com/constructive-io/constructive --skill pgpm
npx skills add https://github.com/constructive-io/constructive --skill constructive-testing
```

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.
