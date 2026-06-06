# @pgpm/object-tree

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/object-tree"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Fobject-tree%2Fpackage.json"/></a>
</p>

Git-like version control for database objects with commits and refs

## Overview

`@pgpm/object-tree` builds on top of `@pgpm/object-store` to provide a Git-like version control layer for database objects. It adds commits, refs (branches), and stores to organize content-addressable object trees into a full version history with time-travel capabilities.

## Features

- **Commits**: Track changes with parent references, messages, and timestamps
- **Refs / Branches**: Named pointers to commits (like Git branches)
- **Stores**: Isolated repositories within a single database
- **Rev-Parse**: Resolve a ref name to the current tree root
- **Set-and-Commit**: Atomic insert-and-commit in a single operation
- **Set-Props-and-Commit**: Update node properties and commit atomically
- **Time Travel**: Access any historical state via commit IDs
- **Built on @pgpm/object-store**: Inherits content-addressable hashing and structural sharing

## Installation

If you have `pgpm` installed:

```bash
pgpm install @pgpm/object-tree
pgpm deploy
```

This is a quick way to get started. The sections below provide more detailed installation options.

### Prerequisites

```bash
# Install pgpm CLI 
npm install -g pgpm

# Start local Postgres (via Docker) and export env vars
pgpm docker start
eval "$(pgpm env)"
```

> **Tip:** Already running Postgres? Skip the Docker step and just export your `PG*` environment variables.

### **Add to an Existing Package**

```bash
# 1. Install the package
pgpm install @pgpm/object-tree

# 2. Deploy locally
pgpm deploy 
```

### **Add to a New Project**

```bash
# 1. Create a workspace
pgpm init workspace

# 2. Create your first module
cd my-workspace
pgpm init

# 3. Install a package
cd packages/my-module
pgpm install @pgpm/object-tree

# 4. Deploy everything
pgpm deploy --createdb --database mydb1
```

## Core Concepts

### Stores

A store is an isolated object repository within a database, analogous to a Git repository. Multiple stores can exist within the same database for different purposes (e.g., metaschema, migrations).

### Commits

A commit records a snapshot of the tree at a point in time. Each commit references:
- `tree_id` — the root object of the tree at this commit
- `parent_ids` — parent commit(s) for history traversal
- `store_id` — which store this commit belongs to
- `message` — descriptive commit message

### Refs

A ref is a named pointer to a commit (like a Git branch). The default ref is `main`.

## Core Functions

### object_tree_public.init_empty_repo(scope_id, store_id)

Initialize an empty repository with a root object, initial commit, and `main` ref.

```sql
SELECT object_tree_public.init_empty_repo(
  s_id := 'aaaaaaaa-...'::uuid,
  store_id := 'bbbbbbbb-...'::uuid
);
```

### object_tree_public.set_and_commit(scope_id, store_id, refname, path, data, kids, ktree)

Insert a node at the given path and create a new commit atomically.

```sql
SELECT object_tree_public.set_and_commit(
  s_id := 'aaaaaaaa-...'::uuid,
  store_id := 'bbbbbbbb-...'::uuid,
  refname := 'main',
  path := ARRAY['src', 'main.ts']::text[],
  data := '{"content": "hello world"}'::jsonb,
  kids := ARRAY[]::uuid[],
  ktree := ARRAY[]::text[]
);
```

### object_tree_public.set_props_and_commit(scope_id, store_id, refname, path, data)

Update the properties of an existing node (preserving children) and commit.

```sql
SELECT object_tree_public.set_props_and_commit(
  s_id := 'aaaaaaaa-...'::uuid,
  store_id := 'bbbbbbbb-...'::uuid,
  refname := 'main',
  path := ARRAY['src', 'main.ts']::text[],
  data := '{"content": "updated"}'::jsonb
);
```

### object_tree_public.rev_parse(scope_id, store_id, refname)

Resolve a ref name to its current tree root ID.

```sql
SELECT object_tree_public.rev_parse(
  s_id := 'aaaaaaaa-...'::uuid,
  store_id := 'bbbbbbbb-...'::uuid,
  refname := 'main'
);
```

### object_tree_public.get_object_at_path(scope_id, store_id, path, refname)

Get the object at a path for a given ref.

```sql
SELECT * FROM object_tree_public.get_object_at_path(
  s_id := 'aaaaaaaa-...'::uuid,
  store_id := 'bbbbbbbb-...'::uuid,
  path := ARRAY['src', 'main.ts']::text[],
  refname := 'main'
);
```

## Testing

```bash
pnpm test
```

## Dependencies

- `@pgpm/object-store`: Content-addressable Merkle tree storage
- `@pgpm/verify`: Verification utilities

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
