# @pgpm/inflection-db

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/inflection-db"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Finflection-db%2Fpackage.json"/></a>
</p>

Database-level string inflection and naming convention utilities for PostgreSQL

## Overview

`@pgpm/inflection-db` provides a set of deterministic naming convention functions for PostgreSQL that build on top of `@pgpm/inflection`. These functions generate consistent, 63-character-safe identifiers for tables, columns, indexes, constraints, and schemas — ensuring that all generated names respect PostgreSQL's maximum identifier length. This package is essential for code generation systems, schema introspection, and any tooling that programmatically creates database objects.

## Features

- **Identifier Safety**: All names are automatically truncated to 63 characters (PostgreSQL's max identifier length)
- **Table Naming**: Pluralized, underscored table names from any input format
- **Field Naming**: Underscored column/field names
- **Index Naming**: Consistent `{table}_{fields}_idx` patterns
- **Constraint Naming**: Foreign key (`_fkey`), primary key (`_pkey`), unique (`_key`), and check (`_chk`) constraint names
- **Schema Naming**: Dashed schema names from component parts
- **Namespace Naming**: Underscored namespace identifiers from arrays
- **Overloaded Signatures**: Key functions accept both `text` and `text[]` inputs
- **Built on @pgpm/inflection**: Leverages proven pluralization, singularization, and case conversion

## Installation

If you have `pgpm` installed:

```bash
pgpm install @pgpm/inflection-db
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
pgpm install @pgpm/inflection-db

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
pgpm install @pgpm/inflection-db

# 4. Deploy everything
pgpm deploy --createdb --database mydb1
```

## Core Functions

### inflection_db.get_identifier(text)

Base wrapper that truncates any string to PostgreSQL's 63-character identifier limit.

```sql
SELECT inflection_db.get_identifier('some_very_long_identifier_name');
-- some_very_long_identifier_name (truncated at 63 chars if needed)
```

### inflection_db.get_table_name(text) / get_table_name(text[])

Generate a pluralized, underscored table name.

```sql
SELECT inflection_db.get_table_name('UserProfile');
-- user_profiles

SELECT inflection_db.get_table_name('BlogPost');
-- blog_posts

SELECT inflection_db.get_table_name(ARRAY['user', 'profile']);
-- user_profiles
```

### inflection_db.get_table_singular_name(text)

Generate a singularized, underscored table name.

```sql
SELECT inflection_db.get_table_singular_name('UserProfiles');
-- user_profile

SELECT inflection_db.get_table_singular_name('BlogPosts');
-- blog_post
```

### inflection_db.get_table_plural_name(text)

Generate a pluralized, underscored table name (alias-style for explicit pluralization).

```sql
SELECT inflection_db.get_table_plural_name('UserProfile');
-- user_profiles
```

### inflection_db.get_field_name(text) / get_field_name(text[])

Generate an underscored field/column name.

```sql
SELECT inflection_db.get_field_name('firstName');
-- first_name

SELECT inflection_db.get_field_name('EmailAddress');
-- email_address

SELECT inflection_db.get_field_name(ARRAY['user', 'email']);
-- user_email
```

### inflection_db.get_identifier_name(text) / get_identifier_name(text[])

Generate a generic underscored identifier.

```sql
SELECT inflection_db.get_identifier_name('MyCustomType');
-- my_custom_type

SELECT inflection_db.get_identifier_name(ARRAY['app', 'settings']);
-- app_settings
```

### inflection_db.get_schema_name(text[])

Generate a dashed schema name from component parts.

```sql
SELECT inflection_db.get_schema_name(ARRAY['my', 'app', 'schema']);
-- my-app-schema
```

### inflection_db.get_namespace_name(text[])

Generate an underscored namespace name from component parts.

```sql
SELECT inflection_db.get_namespace_name(ARRAY['my', 'app']);
-- my_app
```

### inflection_db.get_foreign_key_field_name(text)

Generate a foreign key column name from a referenced table.

```sql
SELECT inflection_db.get_foreign_key_field_name('UserProfile');
-- user_profile_id
```

### inflection_db.get_index_name(text, text[])

Generate an index name following the `{table}_{fields}_idx` pattern.

```sql
SELECT inflection_db.get_index_name('UserProfile', ARRAY['email']);
-- user_profiles_email_idx

SELECT inflection_db.get_index_name('BlogPost', ARRAY['author_id', 'created_at']);
-- blog_posts_author_id_created_at_idx
```

### inflection_db.get_primary_key_index_name(text)

Generate a primary key constraint name following the `{table}_pkey` pattern.

```sql
SELECT inflection_db.get_primary_key_index_name('UserProfile');
-- user_profiles_pkey
```

### inflection_db.get_foreign_key_index_name(text, text)

Generate a foreign key constraint name following the `{table}_{field}_fkey` pattern.

```sql
SELECT inflection_db.get_foreign_key_index_name('BlogPost', 'author_id');
-- blog_posts_author_id_fkey
```

### inflection_db.get_unique_index_name(text, text[])

Generate a unique constraint name following the `{table}_{fields}_key` pattern.

```sql
SELECT inflection_db.get_unique_index_name('UserProfile', ARRAY['email']);
-- user_profiles_email_key
```

### inflection_db.get_check_constraint_name(text, text[])

Generate a check constraint name following the `{table}_{fields}_chk` pattern.

```sql
SELECT inflection_db.get_check_constraint_name('UserProfile', ARRAY['age']);
-- user_profiles_age_chk
```

## Usage Examples

### Schema Generation

```sql
-- Generate consistent names for a complete table setup
SELECT inflection_db.get_table_name('BlogPost') AS table_name,
       inflection_db.get_primary_key_index_name('BlogPost') AS pk_name,
       inflection_db.get_foreign_key_field_name('User') AS fk_field,
       inflection_db.get_foreign_key_index_name('BlogPost', 'user_id') AS fk_name,
       inflection_db.get_index_name('BlogPost', ARRAY['created_at']) AS idx_name,
       inflection_db.get_unique_index_name('BlogPost', ARRAY['slug']) AS uq_name;

-- table_name: blog_posts
-- pk_name:    blog_posts_pkey
-- fk_field:   user_id
-- fk_name:    blog_posts_user_id_fkey
-- idx_name:   blog_posts_created_at_idx
-- uq_name:    blog_posts_slug_key
```

### Dynamic DDL Generation

```sql
-- Build a CREATE TABLE with consistent naming
DO $$
DECLARE
  tbl text := inflection_db.get_table_name('UserProfile');
  pk  text := inflection_db.get_primary_key_index_name('UserProfile');
BEGIN
  EXECUTE format(
    'CREATE TABLE %I (id uuid CONSTRAINT %I PRIMARY KEY DEFAULT gen_random_uuid())',
    tbl, pk
  );
END $$;
```

## Testing

```bash
pnpm test
```

## Dependencies

- `@pgpm/inflection`: String inflection utilities (pluralization, case conversion, etc.)
- `@pgpm/verify`: Verification utilities

## Related Packages

- [`@pgpm/inflection`](https://www.npmjs.com/package/@pgpm/inflection): The underlying string transformation library this package builds on

## Related Tooling

* [pgpm](https://github.com/constructive-io/constructive/tree/main/pgpm/cli): **🖥️ PostgreSQL Package Manager** for modular Postgres development. Works with database workspaces, scaffolding, migrations, seeding, and installing database packages.
* [pgsql-test](https://github.com/constructive-io/constructive/tree/main/postgres/pgsql-test): **📊 Isolated testing environments** with per-test transaction rollbacks—ideal for integration tests, complex migrations, and RLS simulation.
* [supabase-test](https://github.com/constructive-io/constructive/tree/main/postgres/supabase-test): **🧪 Supabase-native test harness** preconfigured for the local Supabase stack—per-test rollbacks, JWT/role context helpers, and CI/GitHub Actions ready.
* [graphile-test](https://github.com/constructive-io/constructive/tree/main/graphile/graphile-test): **🔐 Authentication mocking** for Graphile-focused test helpers and emulating row-level security contexts.
* [pgsql-parser](https://github.com/constructive-io/pgsql-parser): **🔄 SQL conversion engine** that interprets and converts PostgreSQL syntax.
* [libpg-query-node](https://github.com/constructive-io/libpg-query-node): **🌉 Node.js bindings** for `libpg_query`, converting SQL into parse trees.
* [pg-proto-parser](https://github.com/constructive-io/pg-proto-parser): **📦 Protobuf parser** for parsing PostgreSQL Protocol Buffers definitions to generate TypeScript interfaces, utility functions, and JSON mappings for enums.

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.
