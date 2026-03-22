# @pgpm/geotypes

<p align="center" width="100%">
  <img height="250" src="https://raw.githubusercontent.com/constructive-io/constructive/refs/heads/main/assets/outline-logo.svg" />
</p>

<p align="center" width="100%">
  <a href="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml">
    <img height="20" src="https://github.com/constructive-io/pgpm-modules/actions/workflows/ci.yml/badge.svg" />
  </a>
   <a href="https://github.com/constructive-io/pgpm-modules/blob/main/LICENSE"><img height="20" src="https://img.shields.io/badge/license-MIT-blue.svg"/></a>
   <a href="https://www.npmjs.com/package/@pgpm/geotypes"><img height="20" src="https://img.shields.io/github/package-json/v/constructive-io/pgpm-modules?filename=packages%2Fgeotypes%2Fpackage.json"/></a>
</p>

Geographic data types and spatial functions for PostgreSQL.

## Overview

`@pgpm/geotypes` provides PostgreSQL domain types for geographic data, built on top of PostGIS geometry and geography types. This package enables type-safe storage and validation of geographic coordinates and polygons with proper SRID (Spatial Reference System Identifier) enforcement.

## Features

- **geo_point**: A geometry domain for geographic points (latitude/longitude) using WGS84 (SRID 4326) — planar coordinates, fast computation
- **geo_polygon**: A geometry domain for geographic polygons using WGS84 (SRID 4326) — planar coordinates
- **geography_point**: A geography domain for geographic points using WGS84 (SRID 4326) — geodetic calculations on the sphere, distances in meters
- **geography_polygon**: A geography domain for geographic polygons using WGS84 (SRID 4326) — geodetic calculations on the sphere
- Automatic SRID validation to ensure coordinate system consistency
- Integration with PostGIS spatial functions

## Installation

If you have `pgpm` installed:

```bash
pgpm install @pgpm/geotypes
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
pgpm install @pgpm/geotypes

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
pgpm install @pgpm/geotypes

# 4. Deploy everything
pgpm deploy --createdb --database mydb1
```

## Usage

### Creating Tables with Geographic Types

```sql
-- Geometry (planar) types
CREATE TABLE places (
  id serial PRIMARY KEY,
  loc geo_point,
  area geo_polygon
);

-- Geography (spherical) types
CREATE TABLE places_geo (
  id serial PRIMARY KEY,
  loc geography_point,
  area geography_polygon
);
```

### Inserting Geographic Data

```sql
-- Insert a geometry point (San Francisco)
INSERT INTO places (loc)
VALUES (
  ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)
);

-- Insert a geometry polygon
INSERT INTO places (area)
VALUES (
  ST_SetSRID(
    ST_GeomFromText('POLYGON((-122.5 37.7, -122.4 37.7, -122.4 37.8, -122.5 37.8, -122.5 37.7))'),
    4326
  )
);

-- Insert a geography point (distances in meters, accounts for curvature)
INSERT INTO places_geo (loc)
VALUES (
  ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography
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
-- ERROR: value for domain geo_point violates check constraint
```

## Domain Types

### Geometry Domains (Planar)

#### geo_point

A PostgreSQL domain based on `geometry(Point, 4326)` that stores geographic point coordinates using planar (flat) coordinates.

- **Base Type**: `geometry(Point, 4326)`
- **Use Case**: Storing latitude/longitude coordinates for locations, fast computation
- **SRID**: 4326 (WGS84 - World Geodetic System 1984)

#### geo_polygon

A PostgreSQL domain based on `geometry(Polygon, 4326)` that stores geographic polygon areas using planar coordinates.

- **Base Type**: `geometry(Polygon, 4326)`
- **Use Case**: Storing geographic boundaries, regions, or areas
- **SRID**: 4326 (WGS84)
- **Validation**: Ensures valid polygon geometry (closed rings, proper vertex count)

### Geography Domains (Spherical)

#### geography_point

A PostgreSQL domain based on `geography(Point, 4326)` that stores geographic point coordinates using geodetic (spherical) calculations.

- **Base Type**: `geography(Point, 4326)`
- **Use Case**: Real-world GPS data where distances should be in meters and account for Earth's curvature
- **SRID**: 4326 (WGS84)

#### geography_polygon

A PostgreSQL domain based on `geography(Polygon, 4326)` that stores geographic polygon areas using geodetic calculations.

- **Base Type**: `geography(Polygon, 4326)`
- **Use Case**: Real-world geographic boundaries where area/distance calculations need to account for Earth's curvature
- **SRID**: 4326 (WGS84)

## Dependencies

- `@pgpm/types`: Core PostgreSQL type definitions
- `@pgpm/verify`: Verification utilities for database objects
- PostGIS extension (required for geometry types)

## Testing

```bash
pnpm test
```

The test suite validates:
- Successful insertion of valid geometry and geography points and polygons
- SRID validation and rejection of incorrect coordinate systems
- Polygon geometry validation
- Geography distance calculations return values in meters

## Related Tooling

* [pgpm](https://github.com/constructive-io/constructive/tree/main/packages/pgpm): **🖥️ PostgreSQL Package Manager** for modular Postgres development. Works with database workspaces, scaffolding, migrations, seeding, and installing database packages.
* [pgsql-test](https://github.com/constructive-io/constructive/tree/main/packages/pgsql-test): **📊 Isolated testing environments** with per-test transaction rollbacks—ideal for integration tests, complex migrations, and RLS simulation.
* [supabase-test](https://github.com/constructive-io/constructive/tree/main/packages/supabase-test): **🧪 Supabase-native test harness** preconfigured for the local Supabase stack—per-test rollbacks, JWT/role context helpers, and CI/GitHub Actions ready.
* [graphile-test](https://github.com/constructive-io/constructive/tree/main/packages/graphile-test): **🔐 Authentication mocking** for Graphile-focused test helpers and emulating row-level security contexts.
* [pgsql-parser](https://github.com/constructive-io/pgsql-parser): **🔄 SQL conversion engine** that interprets and converts PostgreSQL syntax.
* [libpg-query-node](https://github.com/constructive-io/libpg-query-node): **🌉 Node.js bindings** for `libpg_query`, converting SQL into parse trees.
* [pg-proto-parser](https://github.com/constructive-io/pg-proto-parser): **📦 Protobuf parser** for parsing PostgreSQL Protocol Buffers definitions to generate TypeScript interfaces, utility functions, and JSON mappings for enums.

## Disclaimer

AS DESCRIBED IN THE LICENSES, THE SOFTWARE IS PROVIDED "AS IS", AT YOUR OWN RISK, AND WITHOUT WARRANTIES OF ANY KIND.

No developer or entity involved in creating this software will be liable for any claims or damages whatsoever associated with your use, inability to use, or your interaction with other users of the code, including any direct, indirect, incidental, special, exemplary, punitive or consequential damages, or loss of profits, cryptocurrencies, tokens, or anything else of value.
