# @pgpm/object-store

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/object-store"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Fobject-store%2Fpackage.json"/></a>
</p>

A content-addressable, immutable object store for PostgreSQL — Merkle trees, all the way down. Pair with [`@pgpm/object-tree`](https://www.npmjs.com/package/@pgpm/object-tree) for Git-like version control.

## Overview

Born from the conviction that the best ideas in computer science keep getting reinvented because they keep being right, `@pgpm/object-store` brings content-addressable storage and structural sharing into PostgreSQL. Inspired by Rich Hickey's philosophy that immutability is not a constraint but a liberation — that the past should never be silently rewritten — this package implements a Merkle tree directly in SQL, where every object's identity is derived from what it contains rather than where it sits.

The original code was written in Egypt, during a period of deep focus on what it would mean to treat a relational database the way Hickey's Datomic treats time: as an accretion of immutable facts rather than a place that forgets. The result is a storage engine where objects are permanent, identity is derived from content, and every version of every tree is always available — not because you remembered to snapshot it, but because the data structure itself makes forgetting impossible.

The design follows a simple principle borrowed from Git's object model: if you know the content, you know the identity. Objects are stored as nodes in a tree. Each node holds a JSON payload and an ordered list of named children. A trigger hashes the content on every insert, producing a deterministic UUID. Two objects with identical data and children always produce the same ID — deduplication and integrity verification happen automatically, by construction, not by convention.

Once an object is frozen, it becomes truly immutable — no updates, no deletes, enforced by triggers at the database level. New versions don't destroy old ones; they share structure with them. Change one leaf and only the nodes along the path from that leaf to the root are recreated. Everything else is reused. This is structural sharing — the same trick that makes persistent data structures in Clojure and Haskell efficient — running inside your database.

## Features

- **Content-Addressable IDs**: Object IDs are deterministically computed from content using UUID v5 hashing — same content always produces the same ID
- **Merkle Tree Structure**: Objects form a tree via parallel `kids`/`ktree` arrays, enabling structural sharing across versions
- **Immutability Enforcement**: Frozen objects cannot be modified or deleted, enforced at the trigger level
- **Path-Based Operations**: Insert, update, remove, and query nodes using hierarchical paths like a filesystem
- **Structural Sharing**: Unchanged subtrees are reused across versions (copy-on-write), keeping storage efficient
- **Recursive Traversal**: Walk entire trees or paths from root to leaf in a single query
- **Scope Isolation**: Multi-tenant by design — `scope_id` partitions all data without foreign keys
- **Array Utilities**: Built-in helper functions for array manipulation (`array_shift`, `array_pop`, `array_index_of`, etc.)
- **Pure plpgsql**: No external dependencies beyond pgcrypto and uuid-ossp

## Installation

If you have `pgpm` installed:

```bash
pgpm install @pgpm/object-store
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
pgpm install @pgpm/object-store

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
pgpm install @pgpm/object-store

# 4. Deploy everything
pgpm deploy --createdb --database mydb1
```

## Core Concepts

### The Object Table

Every object in the store is a row in `object_store_public.object`:

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Content-addressable hash, computed automatically from `data` + `kids`/`ktree` |
| `scope_id` | uuid | Tenant/namespace isolation key |
| `data` | jsonb | The object's payload — any JSON value |
| `kids` | uuid[] | Ordered array of child object IDs |
| `ktree` | text[] | Ordered array of child names (parallel to `kids`) |
| `frzn` | bool | Whether the object is frozen (immutable) |
| `created_at` | timestamptz | When the object was first stored |

The primary key is `(id, scope_id)`. The `kids` and `ktree` arrays must always have the same length (enforced by a CHECK constraint), or both be NULL for leaf nodes.

### Content-Addressable Hashing

Every time you insert an object, a `BEFORE INSERT` trigger computes its ID by hashing the `data` and `kids`/`ktree` arrays using UUID v5. This means:

- Two objects with identical content always have the same ID
- Deduplication is automatic — inserting the same content twice is a no-op
- Any change to content produces a completely different ID
- You can verify integrity by recomputing the hash

This is the same principle behind Git's object store and Merkle trees in general.

### Structural Sharing

When you update a single node deep in a tree, only the nodes along the path from that node to the root are recreated. All other subtrees are shared by reference:

```
Before:                         After updating C:

     R                              R'
    / \                            / \
   A   B          -->             A   B'
  / \   \                       / \   \
 C   D   E                    C'   D   E
```

Only R, B, and C are new objects. A, D, and E are reused. This keeps the storage cost proportional to the depth of the change, not the size of the tree.

### Immutability and Freezing

Objects start mutable (`frzn = false`). Once frozen via `freeze_objects()`, they become permanently immutable:

- **Updates are blocked**: Any attempt to change a frozen object's `id`, `data`, `kids`, or `ktree` raises an exception
- **Deletes are blocked**: Frozen objects cannot be deleted
- **Freezing is recursive**: `freeze_objects()` freezes the target and all its descendants
- **The only allowed transition** is `frzn: false -> true` (you can freeze an unfrozen object, but never unfreeze)

This gives you an append-only history where past states are preserved by construction.

## Core Functions

### object_store_public.insert_node_at_path(s_id, root, path, data, kids, ktree)

Insert or replace a node at the given path, creating intermediate nodes as needed. Returns the new root ID (since all ancestors are recreated with updated children via structural sharing).

**Signature:**
```sql
object_store_public.insert_node_at_path(
  s_id uuid,        -- scope identifier
  root uuid,        -- current root object ID
  path text[],      -- path to the target node
  data jsonb,       -- JSON payload for the new node
  kids uuid[],      -- child object IDs (empty array for leaf nodes)
  ktree text[]      -- child names (empty array for leaf nodes)
) RETURNS uuid      -- new root ID
```

**Usage:**
```sql
-- Create a root node
INSERT INTO object_store_public.object (scope_id)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
  RETURNING id;
-- Returns: <root-id>

-- Insert a leaf node at path ['src', 'main.ts']
SELECT object_store_public.insert_node_at_path(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid,
  ARRAY['src', 'main.ts'],
  '{"content": "console.log(hello)"}'::jsonb,
  ARRAY[]::uuid[],
  ARRAY[]::text[]
);
-- Returns: <new-root-id>
```

### object_store_public.set_data_at_path(s_id, root, path, data)

Update the data on an existing node while preserving its children. Looks up the existing node's `kids`/`ktree` first, then delegates to `insert_node_at_path`.

**Signature:**
```sql
object_store_public.set_data_at_path(
  s_id uuid,        -- scope identifier
  root uuid,        -- current root object ID
  path text[],      -- path to the target node
  data jsonb        -- new JSON payload
) RETURNS uuid      -- new root ID
```

**Usage:**
```sql
-- Update only the data at a path, keeping children intact
SELECT object_store_public.set_data_at_path(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid,
  ARRAY['src', 'main.ts'],
  '{"content": "console.log(updated)"}'::jsonb
);
```

### object_store_public.get_node_at_path(s_id, id, path)

Retrieve the object at a given path from a root node. Returns the full object row.

**Signature:**
```sql
object_store_public.get_node_at_path(
  s_id uuid,        -- scope identifier
  id uuid,          -- root object ID
  path text[]       -- path to traverse (empty array returns the root itself)
) RETURNS object_store_public.object
```

**Usage:**
```sql
-- Get the object at ['src', 'main.ts']
SELECT * FROM object_store_public.get_node_at_path(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid,
  ARRAY['src', 'main.ts']
);

-- Get the root object itself
SELECT * FROM object_store_public.get_node_at_path(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid,
  ARRAY[]::text[]
);
```

### object_store_public.remove_node_at_path(s_id, root, path)

Remove a node at the given path. Returns a new root with the node removed from its parent's children. If the node doesn't exist, returns the original root unchanged. Cannot remove the root node itself.

**Signature:**
```sql
object_store_public.remove_node_at_path(
  s_id uuid,        -- scope identifier
  root uuid,        -- current root object ID
  path text[]       -- path to the node to remove
) RETURNS uuid      -- new root ID
```

**Usage:**
```sql
-- Remove the node at ['src', 'old-file.ts']
SELECT object_store_public.remove_node_at_path(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid,
  ARRAY['src', 'old-file.ts']
);
```

### object_store_public.get_all_objects_from_root(s_id, id)

Recursively retrieve all objects in the tree starting from a root node. Uses a recursive CTE to walk the entire `kids` graph.

**Signature:**
```sql
object_store_public.get_all_objects_from_root(
  s_id uuid,        -- scope identifier
  id uuid           -- root object ID
) RETURNS SETOF object_store_public.object
```

**Usage:**
```sql
-- Get every object in the tree
SELECT * FROM object_store_public.get_all_objects_from_root(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid
);
```

### object_store_public.get_path_objects_from_root(s_id, id, path)

Retrieve all objects along a path from root to the target node. Returns one row per node along the path, starting with the root.

**Signature:**
```sql
object_store_public.get_path_objects_from_root(
  s_id uuid,        -- scope identifier
  id uuid,          -- root object ID
  path text[]       -- path to walk
) RETURNS SETOF object_store_public.object
```

**Usage:**
```sql
-- Get every object along the path ['src', 'components', 'Button.tsx']
SELECT * FROM object_store_public.get_path_objects_from_root(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid,
  ARRAY['src', 'components', 'Button.tsx']
);
-- Returns: root, src node, components node, Button.tsx node
```

### object_store_public.get_all(s_id, id)

Recursively retrieve all paths and their data from a root node. Returns `(path, data)` tuples for every node in the tree, walking children depth-first.

**Signature:**
```sql
object_store_public.get_all(
  s_id uuid,        -- scope identifier
  id uuid           -- root object ID
) RETURNS TABLE (path text[], data jsonb)
```

**Usage:**
```sql
-- Flatten the tree into path/data pairs
SELECT * FROM object_store_public.get_all(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid
);
-- Returns rows like:
--   path: ['src', 'main.ts'],    data: '{"content": "..."}'
--   path: ['src', 'utils.ts'],   data: '{"content": "..."}'
--   path: ['README.md'],         data: '{"content": "..."}'
--   path: [],                    data: null  (root node)
```

### object_store_public.freeze_objects(s_id, id)

Recursively freeze an object and all its descendants. Once frozen, objects are permanently immutable — enforced by database triggers.

**Signature:**
```sql
object_store_public.freeze_objects(
  s_id uuid,        -- scope identifier
  id uuid           -- root object ID to freeze
) RETURNS void
```

**Usage:**
```sql
-- Freeze the entire tree
SELECT object_store_public.freeze_objects(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '<root-id>'::uuid
);

-- Now any modification attempt will fail:
-- UPDATE object_store_public.object SET data = '{}' WHERE id = '<root-id>';
-- ERROR: you cannot mutate an immutable record.
```

### object_store_public.update_node_at_path(s_id, root, path, data, kids, ktree)

Replace an existing node at the given path entirely (data + children). Delegates to `insert_node_at_path`.

**Signature:**
```sql
object_store_public.update_node_at_path(
  s_id uuid,        -- scope identifier
  root uuid,        -- current root object ID
  path text[],      -- path to the target node
  data jsonb,       -- new JSON payload
  kids uuid[],      -- new child object IDs
  ktree text[]      -- new child names
) RETURNS uuid      -- new root ID
```

## Usage Examples

### Building a Virtual Filesystem

```sql
DO $$
DECLARE
  scope uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  root_id uuid;
  new_root uuid;
BEGIN
  -- Create an empty root
  INSERT INTO object_store_public.object (scope_id)
    VALUES (scope) RETURNING id INTO root_id;

  -- Add files
  SELECT object_store_public.insert_node_at_path(
    scope, root_id, ARRAY['README.md'],
    '{"content": "# My Project"}'::jsonb,
    ARRAY[]::uuid[], ARRAY[]::text[]
  ) INTO new_root;

  SELECT object_store_public.insert_node_at_path(
    scope, new_root, ARRAY['src', 'index.ts'],
    '{"content": "export default {}"}'::jsonb,
    ARRAY[]::uuid[], ARRAY[]::text[]
  ) INTO new_root;

  -- List all files
  PERFORM * FROM object_store_public.get_all(scope, new_root);
END $$;
```

### Comparing Versions

```sql
-- After making changes, you have two root IDs (old and new).
-- Get all objects from each to diff them:

SELECT 'added' as status, path, data
FROM object_store_public.get_all(scope, new_root)
WHERE path NOT IN (SELECT path FROM object_store_public.get_all(scope, old_root))

UNION ALL

SELECT 'removed' as status, path, data
FROM object_store_public.get_all(scope, old_root)
WHERE path NOT IN (SELECT path FROM object_store_public.get_all(scope, new_root));
```

### Multi-Tenant Isolation

```sql
-- Each tenant gets their own scope_id.
-- Objects are completely isolated between scopes.

-- Tenant A
SELECT object_store_public.insert_node_at_path(
  'aaaaaaaa-0000-0000-0000-000000000001', root_a, ...
);

-- Tenant B (completely separate namespace)
SELECT object_store_public.insert_node_at_path(
  'aaaaaaaa-0000-0000-0000-000000000002', root_b, ...
);
```

## Database Schema

### Schemas

| Schema | Purpose |
|--------|---------|
| `object_store_public` | Public API — the object table and all user-facing functions |
| `object_store_private` | Internal — hash computation and trigger functions |
| `object_store_utils` | Array utility functions used by the store internals |

### Indexes

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| `scope_id_idx` | object | `scope_id` | Fast scope-based queries |
| `frzn_idx` | object | `frzn` | Efficient frozen/unfrozen filtering |
| `object_kids_idx` | object | `kids` (GIN) | Fast child lookups for recursive traversals |

### Triggers

| Trigger | Event | Purpose |
|---------|-------|---------|
| `generate_id_hash` | BEFORE INSERT | Computes content-addressable ID from data + children |
| `immutable_objects` | BEFORE UPDATE | Prevents modification of frozen objects |
| `delete_immutable_objects` | BEFORE DELETE | Prevents deletion of frozen objects |

## Testing

```bash
pnpm test
```

## Dependencies

- [`@pgpm/verify`](https://www.npmjs.com/package/@pgpm/verify): Verification utilities

## See Also

- [`@pgpm/object-tree`](https://www.npmjs.com/package/@pgpm/object-tree): Git-like version control layer built on top of this package — adds commits, refs, and stores for full history tracking

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
