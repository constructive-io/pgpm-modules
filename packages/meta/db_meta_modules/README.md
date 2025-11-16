# @pgpm/meta-db-modules

Module metadata handling and dependency tracking.

## Overview

`@pgpm/meta-db-modules` extends the `@pgpm/meta-db` package with module-specific metadata tables. This package provides tables for tracking various LaunchQL modules including authentication, permissions, memberships, encrypted secrets, and more. It enables configuration and metadata storage for modular application features.

## Features

- **Module Metadata Tables**: Store configuration for various application modules
- **Authentication Modules**: Track user authentication, connected accounts, and crypto auth
- **Permission System**: Store permissions and membership configurations
- **Security Modules**: Track encrypted secrets and tokens
- **User Management**: Store user and membership module configurations
- **Field Modules**: Track custom field configurations
- **API Configuration**: Store API and RLS module settings

## Installation

### Prerequisites

```bash
# Install pgpm globally
npm install -g pgpm

# Start PostgreSQL
pgpm docker start

# Set environment variables
eval "$(pgpm env)"
```

### Deploy

#### Option 1: Deploy from Package Directory

```bash
cd packages/meta/db_meta_modules
pgpm deploy --createdb
```

#### Option 2: Deploy from Workspace Root

```bash
# Install workspace dependencies
pgpm install

# Deploy with dependencies
pgpm deploy mydb1 --yes --createdb
```

## Module Tables

The package provides metadata tables for the following modules:

### Authentication & Users
- **users_module**: User management configuration
- **user_auth_module**: User authentication settings
- **connected_accounts_module**: Connected account configurations
- **crypto_auth_module**: Cryptocurrency authentication settings
- **crypto_addresses_module**: Crypto address management

### Permissions & Memberships
- **permissions_module**: Permission system configuration
- **memberships_module**: Membership management settings
- **membership_types_module**: Membership type definitions
- **levels_module**: User level configurations

### Security
- **encrypted_secrets_module**: Encrypted secrets configuration
- **secrets_module**: Secret management settings
- **tokens_module**: Token management configuration

### Communication
- **emails_module**: Email module configuration
- **phone_numbers_module**: Phone number management settings
- **invites_module**: Invitation system configuration

### Other Modules
- **field_module**: Custom field configurations
- **default_ids_module**: Default ID generation settings
- **limits_module**: Rate limiting and quota configurations
- **rls_module**: Row-level security configurations
- **denormalized_table_field**: Denormalized field tracking

### Application Structure
- **apis**: API configurations
- **sites**: Site definitions

## Usage

### Storing Module Configuration

```sql
-- Configure users module
INSERT INTO meta_public.users_module (
  database_id,
  api_id,
  enabled,
  settings
) VALUES (
  'database-uuid',
  'api-uuid',
  true,
  '{"require_email_verification": true}'::jsonb
);

-- Configure permissions module
INSERT INTO meta_public.permissions_module (
  database_id,
  api_id,
  enabled,
  settings
) VALUES (
  'database-uuid',
  'api-uuid',
  true,
  '{"default_role": "user"}'::jsonb
);

-- Configure encrypted secrets module
INSERT INTO meta_public.encrypted_secrets_module (
  database_id,
  api_id,
  enabled,
  encryption_key_id
) VALUES (
  'database-uuid',
  'api-uuid',
  true,
  'key-uuid'
);
```

### Querying Module Configuration

```sql
-- Get all enabled modules for a database
SELECT 
  'users' as module_name, enabled 
FROM meta_public.users_module 
WHERE database_id = 'database-uuid'
UNION ALL
SELECT 
  'permissions' as module_name, enabled 
FROM meta_public.permissions_module 
WHERE database_id = 'database-uuid'
UNION ALL
SELECT 
  'encrypted_secrets' as module_name, enabled 
FROM meta_public.encrypted_secrets_module 
WHERE database_id = 'database-uuid';

-- Get RLS module configuration
SELECT * FROM meta_public.rls_module
WHERE api_id = 'api-uuid';
```

## Use Cases

### Modular Application Configuration

Store and manage configuration for optional application features:
- Enable/disable modules per database or API
- Store module-specific settings
- Track module dependencies
- Configure module behavior

### Multi-Tenant Applications

Manage module configurations per tenant:
- Different modules enabled per tenant
- Tenant-specific module settings
- Isolated module configurations

### Dynamic Feature Flags

Use module tables as feature flags:
- Enable/disable features at runtime
- A/B testing configurations
- Gradual feature rollouts

## Dependencies

- `@pgpm/meta-db`: Core metadata management
- `@pgpm/verify`: Verification utilities

## Testing

```bash
pnpm test
```

## Development

See the [Development](#development) section below for information on working with this package.

---

## Development

### **Before You Begin**

```bash
# 1. Install pgpm
npm install -g pgpm

# 2. Start Postgres (Docker or local)
pgpm docker start

# 3. Load PG* environment variables (PGHOST, PGUSER, ...)
eval "$(pgpm env)"
```

---

### **Starting a New Project**

```bash
# 1. Create a workspace
pgpm init --workspace
cd my-app

# 2. Create your first module
pgpm init

# 3. Add a migration
pgpm add some_change

# 4. Deploy (auto-creates database)
pgpm deploy --createdb
```

---

### **Working With an Existing Project**

```bash
# 1. Clone and enter the project
git clone <repo> && cd <project>

# 2. Install dependencies
pnpm install

# 3. Deploy locally
pgpm deploy --createdb
```

---

### **Testing a Module Inside a Workspace**

```bash
# 1. Install workspace deps
pnpm install

# 2. Enter the module directory
cd packages/<some-module>

# 3. Run tests in watch mode
pnpm test:watch
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
