# @pgpm/base32

RFC4648 Base32 encode/decode in plpgsql

## Overview

`@pgpm/base32` implements Base32 encoding and decoding entirely in PostgreSQL using plpgsql. Base32 is commonly used for encoding binary data in a human-readable format, particularly for TOTP secrets, API keys, and other security tokens. This package provides a pure SQL implementation without external dependencies.

## Features

- **Pure plpgsql Implementation**: No external dependencies or libraries required
- **RFC 4648 Compliant**: Follows the Base32 standard
- **Bidirectional Conversion**: Encode to Base32 and decode back to original
- **Case Insensitive**: Handles both uppercase and lowercase Base32 strings
- **TOTP Integration**: Perfect for encoding TOTP secrets
- **Lightweight**: Minimal overhead, runs entirely in PostgreSQL

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
cd packages/utils/base32
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

```sql
select base32.encode('foo');
-- MZXW6===


select base32.decode('MZXW6===');
-- foo
```

## Use Cases

### TOTP Secret Encoding

Base32 is the standard encoding for TOTP secrets:

```sql
-- Generate a random secret and encode it
SELECT base32.encode('randomsecret123');
-- Result: MJQXGZJTGIQGS4ZAON2XAZLSEBRW63LNN5XCA2LOEBRW63LQMFZXG===

-- Use with TOTP
SELECT totp.generate(base32.encode('mysecret'));
```

### API Key Encoding

Encode binary data as human-readable API keys:

```sql
-- Encode a UUID as Base32
SELECT base32.encode(gen_random_uuid()::text);

-- Create a table with Base32-encoded keys
CREATE TABLE api_keys (
  id serial PRIMARY KEY,
  user_id uuid,
  key_encoded text DEFAULT base32.encode(gen_random_bytes(20)::text),
  created_at timestamptz DEFAULT now()
);
```

### Data Obfuscation

Encode sensitive identifiers:

```sql
-- Encode user IDs for public URLs
CREATE FUNCTION get_public_user_id(user_uuid uuid)
RETURNS text AS $$
BEGIN
  RETURN base32.encode(user_uuid::text);
END;
$$ LANGUAGE plpgsql;

-- Decode back to UUID
CREATE FUNCTION get_user_from_public_id(public_id text)
RETURNS uuid AS $$
BEGIN
  RETURN base32.decode(public_id)::uuid;
END;
$$ LANGUAGE plpgsql;
```

### File Integrity Verification

Encode checksums and hashes:

```sql
-- Encode a SHA256 hash
SELECT base32.encode(
  encode(digest('file contents', 'sha256'), 'hex')
);
```

## Integration Examples

### With @pgpm/totp

Base32 is essential for TOTP authentication:

```sql
-- Store TOTP secret in Base32 format
CREATE TABLE user_2fa (
  user_id uuid PRIMARY KEY,
  secret_base32 text NOT NULL,
  enabled boolean DEFAULT false
);

-- Generate and store Base32-encoded secret
INSERT INTO user_2fa (user_id, secret_base32)
VALUES (
  'user-uuid',
  base32.encode('randomsecret')
);

-- Generate TOTP code from Base32 secret
SELECT totp.generate(
  base32.decode(secret_base32)
) FROM user_2fa WHERE user_id = 'user-uuid';
```

### With @pgpm/encrypted-secrets

Combine with encrypted secrets for secure storage:

```sql
-- Store Base32-encoded secret encrypted
SELECT encrypted_secrets.secrets_upsert(
  'user-uuid',
  'totp_secret',
  base32.encode('mysecret'),
  'pgp'
);

-- Retrieve and use
SELECT totp.generate(
  base32.decode(
    encrypted_secrets.secrets_getter('user-uuid', 'totp_secret')
  )
);
```

## Character Set

Base32 uses the following character set (RFC 4648):

```
A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 2 3 4 5 6 7
```

Padding character: `=`

## Comparison with Base64

Base32 vs Base64:

| Feature | Base32 | Base64 |
|---------|--------|--------|
| Character Set | A-Z, 2-7 | A-Z, a-z, 0-9, +, / |
| Case Sensitive | No | Yes |
| URL Safe | Yes | Requires modification |
| Human Readable | More readable | Less readable |
| Efficiency | ~60% overhead | ~33% overhead |
| Use Case | TOTP, user-facing | General encoding |

Base32 is preferred for TOTP because:
- Case insensitive (easier to type)
- No ambiguous characters (0/O, 1/I/l)
- URL-safe without modification

## Testing

```bash
pnpm test
```

## Dependencies

None - this is a pure plpgsql implementation.

## Credits

Thanks to 

https://tools.ietf.org/html/rfc4648

https://www.youtube.com/watch?v=Va8FLD-iuTg

---

## Development

## start the postgres db process

First you'll want to start the postgres docker (you can also just use `docker-compose up -d`):

```sh
make up
```

## install modules

Install modules

```sh
yarn install
```

## install the Postgres extensions

Now that the postgres process is running, install the extensions:

```sh
make install
```

This basically `ssh`s into the postgres instance with the `packages/` folder mounted as a volume, and installs the bundled sql code as pgxn extensions.

## testing

Testing will load all your latest sql changes and create fresh, populated databases for each sqitch module in `packages/`.

```sh
yarn test:watch
```

## building new modules

Create a new folder in `packages/`

```sh
pgpm init
```

Then, run a generator:

```sh
pgpm generate
```

You can also add arguments if you already know what you want to do:

```sh
pgpm generate schema --schema myschema
pgpm generate table --schema myschema --table mytable
```

## deploy code as extensions

`cd` into `packages/<module>`, and run `pgpm package`. This will make an sql file in `packages/<module>/sql/` used for `CREATE EXTENSION` calls to install your sqitch module as an extension.

## recursive deploy

You can also deploy all modules utilizing versioning as sqtich modules. Remove `--createdb` if you already created your db:

```sh
pgpm deploy <database_name> --yes --recursive --createdb
```

---

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
