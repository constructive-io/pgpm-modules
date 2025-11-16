# @pgpm/encrypted-secrets-table

Table-based encrypted secrets storage and retrieval.

## Overview

`@pgpm/encrypted-secrets-table` provides the foundational storage layer for encrypted secrets management in PostgreSQL. This package creates the `secrets_schema.secrets_table` table that stores encrypted sensitive data such as API keys, passwords, tokens, and other credentials in a structured, secure format.

## Features

- **Structured Storage**: Dedicated table for encrypted secrets with proper indexing
- **UUID-Based Ownership**: Links secrets to owning entities via UUID foreign keys
- **Dual Encryption Support**: Supports both bytea (binary) and text-encoded encrypted values
- **Unique Constraints**: Prevents duplicate secrets per owner
- **Automatic Hashing**: Trigger-based hashing for secret verification
- **Foundation Layer**: Provides storage for higher-level secrets management APIs

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
cd packages/security/encrypted-secrets-table
pgpm deploy --createdb
```

#### Option 2: Deploy from Workspace Root

```bash
# Install workspace dependencies
pgpm install

# Deploy with dependencies
pgpm deploy mydb1 --yes --createdb
```

## Database Schema

### secrets_schema.secrets_table

The core table for storing encrypted secrets:

```sql
CREATE TABLE secrets_schema.secrets_table (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  secrets_owned_field uuid NOT NULL,           -- Owner entity ID
  name text NOT NULL,                          -- Secret name/identifier
  secrets_value_field bytea NULL,              -- Binary encrypted value
  secrets_enc_field text NULL,                 -- Text-encoded encrypted value
  UNIQUE(secrets_owned_field, name)            -- One secret per name per owner
);
```

**Columns:**
- `id`: Unique identifier for the secret record
- `secrets_owned_field`: UUID of the entity that owns this secret (e.g., user ID, organization ID)
- `name`: Human-readable name for the secret (e.g., "github_token", "stripe_api_key")
- `secrets_value_field`: Binary encrypted value (bytea format)
- `secrets_enc_field`: Text-encoded encrypted value (for PGP armor format)

**Constraints:**
- Primary key on `id`
- Unique constraint on `(secrets_owned_field, name)` ensures each owner can have only one secret with a given name

### Triggers

#### hash_secrets

Automatically hashes secrets for verification purposes:

```sql
CREATE TRIGGER hash_secrets
  BEFORE INSERT OR UPDATE ON secrets_schema.secrets_table
  FOR EACH ROW
  EXECUTE FUNCTION secrets_schema.hash_secrets_trigger();
```

This trigger ensures secrets are properly hashed before storage, enabling verification without exposing the raw values.

## Usage

### Storing a Secret

```sql
-- Insert an encrypted secret
INSERT INTO secrets_schema.secrets_table (
  secrets_owned_field,
  name,
  secrets_value_field
) VALUES (
  'user-uuid-here',
  'api_key',
  pgp_sym_encrypt('my-secret-value', 'encryption-password')
);
```

### Retrieving a Secret

```sql
-- Get encrypted secret
SELECT 
  id,
  name,
  pgp_sym_decrypt(secrets_value_field, 'encryption-password') AS decrypted_value
FROM secrets_schema.secrets_table
WHERE secrets_owned_field = 'user-uuid-here'
  AND name = 'api_key';
```

### Updating a Secret

```sql
-- Update existing secret
UPDATE secrets_schema.secrets_table
SET secrets_value_field = pgp_sym_encrypt('new-secret-value', 'encryption-password')
WHERE secrets_owned_field = 'user-uuid-here'
  AND name = 'api_key';
```

### Deleting a Secret

```sql
-- Remove a secret
DELETE FROM secrets_schema.secrets_table
WHERE secrets_owned_field = 'user-uuid-here'
  AND name = 'api_key';
```

## Common Patterns

### Multi-Tenant Secrets

```sql
-- Each organization has its own secrets
INSERT INTO secrets_schema.secrets_table (
  secrets_owned_field,
  name,
  secrets_value_field
) VALUES
  ('org-1-uuid', 'aws_access_key', pgp_sym_encrypt('...', 'password')),
  ('org-1-uuid', 'aws_secret_key', pgp_sym_encrypt('...', 'password')),
  ('org-2-uuid', 'aws_access_key', pgp_sym_encrypt('...', 'password'));
```

### User-Specific Secrets

```sql
-- Each user has their own API tokens
INSERT INTO secrets_schema.secrets_table (
  secrets_owned_field,
  name,
  secrets_value_field
) VALUES
  ('user-1-uuid', 'github_token', pgp_sym_encrypt('...', 'password')),
  ('user-2-uuid', 'github_token', pgp_sym_encrypt('...', 'password'));
```

### Listing All Secrets for an Owner

```sql
-- Get all secret names for an owner (without values)
SELECT id, name
FROM secrets_schema.secrets_table
WHERE secrets_owned_field = 'user-uuid-here'
ORDER BY name;
```

## Integration with Other Packages

### With @pgpm/encrypted-secrets

The `@pgpm/encrypted-secrets` package builds on this storage layer to provide:
- High-level API functions for secret management
- Role-based access control
- Encryption/decryption helpers
- Secret verification functions

```sql
-- @pgpm/encrypted-secrets provides functions like:
SELECT encrypted_secrets.secrets_getter('owner-uuid', 'secret-name');
SELECT encrypted_secrets.secrets_upsert('owner-uuid', 'secret-name', 'value');
```

### With Application Tables

Link secrets to your application entities:

```sql
-- Users table with secrets
CREATE TABLE users (
  id uuid PRIMARY KEY,
  email text,
  -- Secrets stored in secrets_schema.secrets_table
  -- with secrets_owned_field = users.id
);

-- Get user's secrets
SELECT s.*
FROM users u
JOIN secrets_schema.secrets_table s ON s.secrets_owned_field = u.id
WHERE u.email = 'user@example.com';
```

## Security Considerations

1. **Encryption Required**: Never store plaintext secrets in this table
2. **Access Control**: Use PostgreSQL RLS policies to restrict access
3. **Encryption Keys**: Store encryption passwords securely (not in database)
4. **Audit Logging**: Consider logging access to secrets table
5. **Key Rotation**: Plan for periodic re-encryption with new keys

### Row-Level Security Example

```sql
-- Enable RLS
ALTER TABLE secrets_schema.secrets_table ENABLE ROW LEVEL SECURITY;

-- Users can only access their own secrets
CREATE POLICY user_secrets ON secrets_schema.secrets_table
  FOR ALL
  TO authenticated
  USING (secrets_owned_field = jwt_public.current_user_id());

-- Administrators can access all secrets
CREATE POLICY admin_secrets ON secrets_schema.secrets_table
  FOR ALL
  TO administrator
  USING (true);
```

## Best Practices

1. **Use Unique Names**: Choose descriptive, unique names for each secret
2. **Consistent Ownership**: Use the same UUID scheme for `secrets_owned_field` across your application
3. **Binary vs Text**: Use `secrets_value_field` (bytea) for better performance, `secrets_enc_field` (text) for PGP armor format
4. **Don't Log Secrets**: Ensure database logs don't capture decrypted values
5. **Regular Cleanup**: Remove secrets when owners are deleted

## Dependencies

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
