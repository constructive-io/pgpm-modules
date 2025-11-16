# @pgpm/geotypes

Geographic data types and spatial functions for PostgreSQL.

## Overview

`@pgpm/geotypes` provides PostgreSQL domain types for geographic data, built on top of PostGIS geometry types. This package enables type-safe storage and validation of geographic coordinates and polygons with proper SRID (Spatial Reference System Identifier) enforcement.

## Features

- **geolocation**: A domain type for geographic points (latitude/longitude) using WGS84 (SRID 4326)
- **geopolygon**: A domain type for geographic polygons using WGS84 (SRID 4326)
- Automatic SRID validation to ensure coordinate system consistency
- Integration with PostGIS spatial functions

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
cd packages/data-types/geotypes
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

### Creating Tables with Geographic Types

```sql
CREATE TABLE places (
  id serial PRIMARY KEY,
  loc geolocation,
  area geopolygon
);
```

### Inserting Geographic Data

```sql
-- Insert a point location (San Francisco)
INSERT INTO places (loc)
VALUES (
  ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)
);

-- Insert a polygon area
INSERT INTO places (area)
VALUES (
  ST_SetSRID(
    ST_GeomFromText('POLYGON((-122.5 37.7, -122.4 37.7, -122.4 37.8, -122.5 37.8, -122.5 37.7))'),
    4326
  )
);
```

### SRID Validation

The domain types automatically enforce SRID 4326 (WGS84):

```sql
-- This will fail - incorrect SRID
INSERT INTO places (loc)
VALUES (
  ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 3857)
);
-- ERROR: value for domain geolocation violates check constraint
```

## Domain Types

### geolocation

A PostgreSQL domain based on `geometry(Point, 4326)` that stores geographic point coordinates.

- **Base Type**: `geometry(Point, 4326)`
- **Use Case**: Storing latitude/longitude coordinates for locations
- **SRID**: 4326 (WGS84 - World Geodetic System 1984)

### geopolygon

A PostgreSQL domain based on `geometry(Polygon, 4326)` that stores geographic polygon areas.

- **Base Type**: `geometry(Polygon, 4326)`
- **Use Case**: Storing geographic boundaries, regions, or areas
- **SRID**: 4326 (WGS84)
- **Validation**: Ensures valid polygon geometry (closed rings, proper vertex count)

## Dependencies

- `@pgpm/types`: Core PostgreSQL type definitions
- `@pgpm/verify`: Verification utilities for database objects
- PostGIS extension (required for geometry types)

## Testing

```bash
pnpm test
```

The test suite validates:
- Successful insertion of valid points and polygons
- SRID validation and rejection of incorrect coordinate systems
- Polygon geometry validation

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
