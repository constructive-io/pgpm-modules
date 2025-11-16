# @pgpm/types

Core PostgreSQL data types with SQL scripts.

## Overview

`@pgpm/types` provides a collection of validated PostgreSQL domain types for common data formats. These domains enforce data integrity at the database level through regex-based validation, ensuring that only properly formatted data is stored.

## Features

- **email**: Case-insensitive email address validation
- **url**: HTTP/HTTPS URL validation
- **hostname**: Domain name validation
- **image**: JSON-based image metadata with URL and MIME type
- **attachment**: JSON-based file attachment metadata with URL and MIME type
- **upload**: File upload metadata
- **single_select**: Single selection field
- **multiple_select**: Multiple selection field

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
cd packages/data-types/types
pgpm deploy --createdb
```

#### Option 2: Deploy from Workspace Root

```bash
# Install workspace dependencies
pgpm install

# Deploy with dependencies
pgpm deploy <database_name> --yes --recursive --createdb
```

## Usage

### Creating Tables with Validated Types

```sql
CREATE TABLE customers (
  id serial PRIMARY KEY,
  email email,
  website url,
  domain hostname,
  profile_image image,
  document attachment
);
```

### Email Domain

The `email` domain validates email addresses using a comprehensive regex pattern and stores them as case-insensitive text (`citext`).

```sql
-- Valid emails
INSERT INTO customers (email) VALUES
  ('user@example.com'),
  ('john.doe@company.co.uk'),
  ('support+tag@service.io');

-- Invalid email (will fail)
INSERT INTO customers (email) VALUES ('not-an-email');
-- ERROR: value for domain email violates check constraint
```

**Validation Pattern**: RFC-compliant email format with support for special characters and subdomains.

### URL Domain

The `url` domain validates HTTP and HTTPS URLs.

```sql
-- Valid URLs
INSERT INTO customers (website) VALUES
  ('http://example.com'),
  ('https://www.example.com/path?query=value'),
  ('http://foo.bar/path_(with)_parens');

-- Invalid URLs (will fail)
INSERT INTO customers (website) VALUES
  ('ftp://example.com'),  -- Only http/https allowed
  ('example.com'),        -- Missing protocol
  ('http://');            -- Incomplete URL
```

**Validation Pattern**: Requires `http://` or `https://` protocol and valid URL structure.

### Hostname Domain

The `hostname` domain validates domain names without protocol or path.

```sql
-- Valid hostnames
INSERT INTO customers (domain) VALUES
  ('example.com'),
  ('subdomain.example.com'),
  ('my-site.co.uk');

-- Invalid hostnames (will fail)
INSERT INTO customers (domain) VALUES
  ('http://example.com'),           -- No protocol allowed
  ('example.com/path'),              -- No path allowed
  ('invalid..domain.com');           -- Invalid format
```

**Validation Pattern**: Standard domain name format with support for subdomains and hyphens.

### Image and Attachment Domains

The `image` and `attachment` domains store JSON objects with URL and MIME type information.

```sql
-- Valid image
INSERT INTO customers (profile_image) VALUES
  ('{"url": "https://cdn.example.com/photo.jpg", "mime": "image/jpeg"}'::json);

-- Valid attachment
INSERT INTO customers (document) VALUES
  ('{"url": "https://storage.example.com/file.pdf", "mime": "application/pdf"}'::json);
```

**Structure**: Both domains expect JSON objects with `url` and `mime` properties.

## Domain Types Reference

| Domain | Base Type | Description | Example |
|--------|-----------|-------------|---------|
| `email` | `citext` | Case-insensitive email address | `user@example.com` |
| `url` | `text` | HTTP/HTTPS URL | `https://example.com/path` |
| `hostname` | `text` | Domain name without protocol | `example.com` |
| `image` | `json` | Image metadata with URL and MIME | `{"url": "...", "mime": "image/jpeg"}` |
| `attachment` | `json` | File attachment metadata | `{"url": "...", "mime": "application/pdf"}` |
| `upload` | `text` | File upload identifier | Various formats |
| `single_select` | `text` | Single selection value | Text value |
| `multiple_select` | `text[]` | Multiple selection values | Array of text values |

## Validation Benefits

Using domain types provides several advantages over plain text columns:

1. **Data Integrity**: Invalid data is rejected at insert/update time
2. **Self-Documenting**: Column types clearly indicate expected format
3. **Consistent Validation**: Same rules applied across all tables
4. **Database-Level Enforcement**: No reliance on application-level validation alone

## Dependencies

- `@pgpm/verify`: Verification utilities for database objects
- PostgreSQL `citext` extension (for email domain)

## Testing

```bash
pnpm test
```

The test suite validates:
- Email format validation (valid and invalid cases)
- URL format validation with extensive test cases
- Hostname format validation
- Image and attachment JSON structure validation

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
pgpm install

# 3. Deploy locally
pgpm deploy --createdb
```

---

### **Testing a Module Inside a Workspace**

```bash
# 1. Install workspace deps
pgpm install

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
