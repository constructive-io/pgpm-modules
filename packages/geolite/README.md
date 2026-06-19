# @pgpm/geolite

GeoLite2 IP geolocation tables and lookup functions for PostgreSQL.

Provides a `geolite` schema with tables for MaxMind's GeoLite2 City and ASN
databases, plus convenience functions for IP→location lookups. All tables are
globally readable (`GRANT SELECT TO public`).

## Architecture

The module has two parts:

1. **pgpm extension** — defines the schema (tables, indexes, functions). Deployed
   via standard `pgpm deploy`. This is lightweight DDL only.
2. **TypeScript loader** (`src/loader.ts`) — downloads GeoLite2 `.mmdb` files from
   [P3TERX/GeoLite.mmdb](https://github.com/P3TERX/GeoLite.mmdb), walks the MMDB
   binary trie to extract all network→record pairs, and bulk-loads them via
   `COPY`. Runs outside of pgpm's transactional deploy.

## Schema

### `geolite.network`

CIDR blocks mapped to geoname locations and coordinates (~4M rows for City IPv4).

| Column | Type | Description |
|--------|------|-------------|
| `id` | `uuid` | Primary key (uuidv7) |
| `network` | `cidr` | IPv4 or IPv6 CIDR block |
| `geoname_id` | `int` | FK to `geolite.location` |
| `latitude` | `numeric` | Approximate centroid latitude |
| `longitude` | `numeric` | Approximate centroid longitude |
| `accuracy_radius` | `int` | Accuracy in km |
| ... | | See source for full schema |

Indexed with GiST on `network` for fast `>>=` (contains) lookups.

### `geolite.location`

Location metadata keyed by `(geoname_id, locale_code)`.

| Column | Type | Description |
|--------|------|-------------|
| `id` | `uuid` | Primary key (uuidv7) |
| `geoname_id` | `int` | GeoNames identifier |
| `locale_code` | `text` | Locale (e.g. `en`) |
| `country_iso_code` | `text` | ISO 3166-1 alpha-2 |
| `country_name` | `text` | Country name |
| `city_name` | `text` | City name |
| `time_zone` | `text` | IANA time zone |
| ... | | See source for full schema |

### `geolite.asn`

ASN (Autonomous System Number) data mapping CIDR blocks to ISP/org info.

### `geolite.data_version`

Tracks which GeoLite2 release is loaded.

## Lookup Functions

```sql
-- City/country lookup for an IP
SELECT * FROM geolite.lookup('8.8.8.8'::inet);

-- ASN/ISP lookup
SELECT * FROM geolite.lookup_asn('8.8.8.8'::inet);
```

## Loading Data

After deploying the pgpm extension, run the TypeScript loader to populate tables:

```bash
# Set your database connection
export DATABASE_URL="postgresql://user:pass@localhost:5432/mydb"

# Run the loader (downloads .mmdb files automatically)
pnpm geolite:load

# Include IPv6 blocks (larger dataset, takes longer)
pnpm geolite:load -- --ipv6
```

The loader:
1. Downloads `.mmdb` files from P3TERX/GeoLite.mmdb (cached in `.data/`)
2. Walks the MMDB binary trie to extract all network/record pairs
3. Streams records into PostgreSQL via `COPY` (fast bulk insert)
4. Updates `geolite.data_version` with the current date

Re-run periodically to update (P3TERX updates weekly). The loader truncates
and reloads atomically.

## License

MIT — see [LICENSE](LICENSE).

GeoLite2 data: CC BY-SA 4.0 by MaxMind. See
[GeoLite2 EULA](https://www.maxmind.com/en/geolite2/eula).
