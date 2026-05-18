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

Git-like version control for database objects, built on immutable Merkle trees.

## Overview

If `@pgpm/object-store` is the storage engine, `@pgpm/object-tree` is the version control system built on top of it. Like Git, it layers commits, refs, and stores over a content-addressable object graph — but instead of tracking files on a filesystem, it tracks structured data inside PostgreSQL.

This package was born alongside `@pgpm/object-store`, written in Egypt during the same stretch of deep work on immutable database architectures. The inspiration, again, was Rich Hickey and the ideas behind Datomic: that a database should remember everything, that time is a first-class concept, and that you should be able to ask "what did this look like yesterday?" as naturally as you ask "what does this look like now?" Where the object store provides the immutable foundation — content-addressable nodes, structural sharing, Merkle integrity — the object tree adds the narrative layer: commits that record *when* things changed, refs that name the current state, and stores that isolate independent histories from each other.

The result is a version-controlled data layer that lives entirely inside your database. Every mutation is a commit. Every commit points to an immutable tree root. You can branch, diff, and time-travel through your data's history using the same mental model you use with Git — except the objects are rows, and the repository is a schema.

## Features

- **Commits**: Track changes with parent references, messages, and timestamps — a full history chain
- **Refs / Branches**: Named pointers to commits (like Git branches), with `main` as the default
- **Stores**: Isolated repositories within a single database — multiple independent histories per scope
- **Rev-Parse**: Resolve a ref name to the current tree root in a single call
- **Set-and-Commit**: Atomic insert-and-commit in a single operation — no partial states
- **Set-Props-and-Commit**: Update node properties (preserving children) and commit atomically
- **Time Travel**: Access any historical state via commit IDs — every past tree root is still available
- **Built on @pgpm/object-store**: Inherits content-addressable hashing, structural sharing, and immutability

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

A store is an isolated object repository within a scope, analogous to a Git repository. Multiple stores can exist within the same scope for different purposes (e.g., one for metaschema definitions, another for migration state). Each store has its own independent commit history and refs.

### Commits

A commit records a snapshot of the tree at a point in time. Each commit references:

| Field | Type | Description |
|-------|------|-------------|
| `id` | uuid | Unique commit identifier |
| `scope_id` | uuid | Tenant/namespace isolation |
| `store_id` | uuid | Which store this commit belongs to |
| `tree_id` | uuid | Root object ID of the tree at this commit |
| `parent_ids` | uuid[] | Parent commit(s) for history traversal |
| `message` | text | Descriptive commit message |
| `created_at` | timestamptz | When the commit was created |

Because the `tree_id` points into the object store (which is immutable and content-addressable), the full state of the tree at any commit is always available — it's never overwritten or garbage-collected.

### Refs

A ref is a named pointer to a commit, exactly like a Git branch. The default ref is `main`. When you make a new commit, the ref is updated to point to the new commit — but the old commit (and its tree) remain accessible by ID.

| Field | Type | Description |
|-------|------|-------------|
| `id` | uuid | Unique ref identifier |
| `scope_id` | uuid | Tenant/namespace isolation |
| `store_id` | uuid | Which store this ref belongs to |
| `name` | text | The ref name (e.g., `main`) |
| `commit_id` | uuid | The commit this ref currently points to |

### Scope and Store: Two Levels of Isolation

- **`scope_id`** isolates tenants — it's on every table and prevents cross-tenant access entirely
- **`store_id`** isolates repositories *within* a tenant — different stores have independent commit histories, refs, and trees, but objects in the underlying store can be shared across stores via structural sharing

## Core Functions

### object_tree_public.init_empty_repo(s_id, store_id)

Initialize a new repository with an empty root object, a `main` ref, and a first commit. Raises `REPO_EXISTS` if the store already has commits.

**Signature:**
```sql
object_tree_public.init_empty_repo(
  s_id uuid,          -- scope identifier
  store_id uuid       -- store identifier for the new repo
) RETURNS void
```

**Usage:**
```sql
SELECT object_tree_public.init_empty_repo(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
);
-- Creates: empty root object, 'main' ref, and first commit
```

### object_tree_public.set_and_commit(s_id, store_id, refname, path, data, kids, ktree)

Insert or replace a node at the given path and create a new commit in one atomic operation. Resolves the current ref, inserts the node into the current tree (via `object_store_public.insert_node_at_path`), creates a commit with the new tree root, and advances the ref.

**Signature:**
```sql
object_tree_public.set_and_commit(
  s_id uuid,          -- scope identifier
  store_id uuid,      -- store identifier
  refname text,       -- ref to commit on (e.g., 'main')
  path text[],        -- path to the target node
  data jsonb,         -- JSON payload for the new node
  kids uuid[],        -- child object IDs
  ktree text[]        -- child names
) RETURNS uuid        -- new tree root ID
```

**Usage:**
```sql
-- Add a file and commit in one step
SELECT object_tree_public.set_and_commit(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'main',
  ARRAY['src', 'main.ts'],
  '{"content": "hello world"}'::jsonb,
  ARRAY[]::uuid[],
  ARRAY[]::text[]
);
```

### object_tree_public.set_props_and_commit(s_id, store_id, refname, path, data)

Update the data on an existing node (preserving its children) and commit atomically. Uses `object_store_public.set_data_at_path` under the hood.

**Signature:**
```sql
object_tree_public.set_props_and_commit(
  s_id uuid,          -- scope identifier
  store_id uuid,      -- store identifier
  refname text,       -- ref to commit on (e.g., 'main')
  path text[],        -- path to the target node
  data jsonb          -- new JSON payload (children preserved)
) RETURNS uuid        -- new tree root ID
```

**Usage:**
```sql
-- Update properties on an existing node and commit
SELECT object_tree_public.set_props_and_commit(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'main',
  ARRAY['src', 'main.ts'],
  '{"content": "updated content"}'::jsonb
);
```

### object_tree_public.rev_parse(s_id, store_id, refname)

Resolve a ref name to its current tree root ID. Follows the ref to its commit, then returns the commit's `tree_id`. The `refname` parameter defaults to `'main'`.

**Signature:**
```sql
object_tree_public.rev_parse(
  s_id uuid,          -- scope identifier
  store_id uuid,      -- store identifier
  refname text        -- ref name to resolve (default: 'main')
) RETURNS uuid        -- tree root ID
```

**Usage:**
```sql
-- Get the current tree root for 'main'
SELECT object_tree_public.rev_parse(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'main'
);
```

### object_tree_public.get_object_at_path(s_id, store_id, path, refname)

Get the object at a path for a given ref. Combines `rev_parse` and `object_store_public.get_node_at_path` into a single call. The `refname` parameter defaults to `'main'`.

**Signature:**
```sql
object_tree_public.get_object_at_path(
  s_id uuid,          -- scope identifier
  store_id uuid,      -- store identifier
  path text[],        -- path to the target node
  refname text        -- ref name (default: 'main')
) RETURNS object_store_public.object
```

**Usage:**
```sql
-- Get the object at a path on the main branch
SELECT * FROM object_tree_public.get_object_at_path(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  ARRAY['src', 'main.ts'],
  'main'
);
```

## Usage Examples

### Setting Up a Repository and Making Changes

```sql
DO $$
DECLARE
  scope uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  store uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  tree_root uuid;
BEGIN
  -- Initialize a new repo
  PERFORM object_tree_public.init_empty_repo(scope, store);

  -- Add a file and commit
  SELECT object_tree_public.set_and_commit(
    scope, store, 'main',
    ARRAY['README.md'],
    '{"content": "# My Project"}'::jsonb,
    ARRAY[]::uuid[], ARRAY[]::text[]
  ) INTO tree_root;

  -- Add another file and commit
  SELECT object_tree_public.set_and_commit(
    scope, store, 'main',
    ARRAY['src', 'index.ts'],
    '{"content": "export default {}"}'::jsonb,
    ARRAY[]::uuid[], ARRAY[]::text[]
  ) INTO tree_root;

  -- Update a file's content (preserving children) and commit
  SELECT object_tree_public.set_props_and_commit(
    scope, store, 'main',
    ARRAY['README.md'],
    '{"content": "# My Project\n\nUpdated readme."}'::jsonb
  ) INTO tree_root;
END $$;
```

### Time Travel: Reading Historical State

```sql
-- Every commit stores its tree_id, so you can read any past state:

-- Get all commits for a store (newest first)
SELECT id, tree_id, message, created_at
FROM object_tree_public.commit
WHERE scope_id = 'aaaaaaaa-...' AND store_id = 'bbbbbbbb-...'
ORDER BY created_at DESC;

-- Read the tree at any historical commit
SELECT * FROM object_store_public.get_all(
  'aaaaaaaa-...',
  'historical-tree-id-from-commit'::uuid
);
```

### Multiple Stores in One Scope

```sql
-- Store 1: metaschema definitions
SELECT object_tree_public.init_empty_repo(scope, store_metaschema);
SELECT object_tree_public.set_and_commit(
  scope, store_metaschema, 'main',
  ARRAY['tables', 'users'],
  '{"columns": ["id", "email", "name"]}'::jsonb,
  ARRAY[]::uuid[], ARRAY[]::text[]
);

-- Store 2: migration state (completely independent history)
SELECT object_tree_public.init_empty_repo(scope, store_migrations);
SELECT object_tree_public.set_and_commit(
  scope, store_migrations, 'main',
  ARRAY['001_init'],
  '{"applied": true, "at": "2026-01-15"}'::jsonb,
  ARRAY[]::uuid[], ARRAY[]::text[]
);
```

## Database Schema

### Tables

| Table | Schema | Purpose |
|-------|--------|---------|
| `commit` | `object_tree_public` | Commit history with tree snapshots and parent links |
| `ref` | `object_tree_public` | Named pointers (branches) to commits |
| `store` | `object_tree_public` | Store registry (optional metadata for stores) |

### Schemas

| Schema | Purpose |
|--------|---------|
| `object_tree_public` | Public API — commits, refs, stores, and all user-facing functions |

## Testing

```bash
pnpm test
```

## Dependencies

- [`@pgpm/object-store`](https://www.npmjs.com/package/@pgpm/object-store): Content-addressable Merkle tree storage — the immutable foundation this package builds on
- [`@pgpm/verify`](https://www.npmjs.com/package/@pgpm/verify): Verification utilities

## Related Tooling

* [pgpm](https://github.com/constructive-io/constructive/tree/main/packages/pgpm): **PostgreSQL Package Manager** for modular Postgres development. Works with database workspaces, scaffolding, migrations, seeding, and installing database packages.
* [pgsql-test](https://github.com/constructive-io/constructive/tree/main/packages/pgsql-test): **Isolated testing environments** with per-test transaction rollbacks — ideal for integration tests, complex migrations, and RLS simulation.
* [supabase-test](https://github.com/constructive-io/constructive/tree/main/packages/supabase-test): **Supabase-native test harness** preconfigured for the local Supabase stack — per-test rollbacks, JWT/role context helpers, and CI/GitHub Actions ready.
* [graphile-test](https://github.com/constructive-io/constructive/tree/main/packages/graphile-test): **Authentication mocking** for Graphile-focused test helpers and emulating row-level security contexts.
* [pgsql-parser](https://github.com/constructive-io/pgsql-parser): **SQL conversion engine** that interprets and converts PostgreSQL syntax.
* [libpg-query-node](https://github.com/constructive-io/libpg-query-node): **Node.js bindings** for `libpg_query`, converting SQL into parse trees.
* [pg-proto-parser](https://github.com/constructive-io/pg-proto-parser): **Protobuf parser** for parsing PostgreSQL Protocol Buffers definitions to generate TypeScript interfaces, utility functions, and JSON mappings for enums.

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.
