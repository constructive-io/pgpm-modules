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

Immutable versioned object storage with content-addressable IDs for PostgreSQL

## Overview

`@pgpm/object-store` implements a content-addressable Merkle tree storage system in PostgreSQL. Objects are immutable once frozen, and their IDs are deterministically derived from their content (data + children), similar to how Git stores objects. This enables efficient structural sharing, deduplication, and tamper-evident storage.

## Features

- **Content-Addressable IDs**: Object IDs are deterministically computed from content using UUID v5 hashing
- **Merkle Tree Structure**: Objects form a tree via `kids`/`ktree` arrays, enabling structural sharing
- **Immutability**: Frozen objects cannot be modified or deleted
- **Path-Based Operations**: Insert, update, remove, and query nodes using hierarchical paths
- **Structural Sharing**: Unchanged subtrees are reused across versions (copy-on-write)
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

### Object Table

Every object has:
- `id` (uuid) — content-addressable hash computed from data + children
- `scope_id` (uuid) — scoping identifier for multi-tenant usage
- `data` (jsonb) — the object's payload
- `kids` (uuid[]) — child object IDs
- `ktree` (text[]) — child names (parallel to `kids`)
- `frzn` (bool) — whether the object is frozen (immutable)

### Content-Addressable Hashing

Object IDs are automatically generated via a trigger that hashes the object's `data` and `kids`/`ktree` arrays. Two objects with identical content will always have the same ID, enabling natural deduplication and structural sharing.

## Core Functions

### object_store_public.insert_node_at_path(scope_id, root, path, data, kids, ktree)

Insert or replace a node at the given path, creating intermediate nodes as needed. Returns the new root ID (since all ancestors are recreated with updated children).

```sql
SELECT object_store_public.insert_node_at_path(
  s_id := 'aaaaaaaa-...'::uuid,
  root := '<root-id>'::uuid,
  path := ARRAY['src', 'main.ts']::text[],
  data := '{"content": "console.log(hello)"}'::jsonb,
  kids := ARRAY[]::uuid[],
  ktree := ARRAY[]::text[]
);
```

### object_store_public.get_node_at_path(scope_id, id, path)

Retrieve the object at a given path from a root node.

```sql
SELECT * FROM object_store_public.get_node_at_path(
  s_id := 'aaaaaaaa-...'::uuid,
  id := '<root-id>'::uuid,
  path := ARRAY['src', 'main.ts']::text[]
);
```

### object_store_public.remove_node_at_path(scope_id, root, path)

Remove a node at the given path, returning a new root with the node removed.

```sql
SELECT object_store_public.remove_node_at_path(
  s_id := 'aaaaaaaa-...'::uuid,
  root := '<root-id>'::uuid,
  path := ARRAY['src', 'old-file.ts']::text[]
);
```

### object_store_public.set_data_at_path(scope_id, root, path, data)

Update the data on an existing node while preserving its children.

```sql
SELECT object_store_public.set_data_at_path(
  s_id := 'aaaaaaaa-...'::uuid,
  root := '<root-id>'::uuid,
  path := ARRAY['src', 'main.ts']::text[],
  data := '{"content": "updated content"}'::jsonb
);
```

### object_store_public.get_all_objects_from_root(scope_id, id)

Recursively retrieve all objects in the tree starting from a root node.

```sql
SELECT * FROM object_store_public.get_all_objects_from_root(
  s_id := 'aaaaaaaa-...'::uuid,
  id := '<root-id>'::uuid
);
```

### object_store_public.freeze_objects(scope_id, id)

Freeze an object and all its descendants, making them immutable.

```sql
SELECT object_store_public.freeze_objects(
  s_id := 'aaaaaaaa-...'::uuid,
  id := '<root-id>'::uuid
);
```

## Testing

```bash
pnpm test
```

## Dependencies

- `@pgpm/verify`: Verification utilities

## Related Tooling

* [pgpm](https://github.com/constructive-io/constructive/tree/main/packages/pgpm): PostgreSQL Package Manager for modular Postgres development.
* [pgsql-test](https://github.com/constructive-io/constructive/tree/main/packages/pgsql-test): Isolated testing environments with per-test transaction rollbacks.

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.
