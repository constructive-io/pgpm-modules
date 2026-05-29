import { getConnections, PgTestClient, snapshot } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

describe('geolite', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.beforeEach();
  });

  afterEach(async () => {
    await pg.afterEach();
  });

  it('should have geolite schema created', async () => {
    const schemas = await pg.any(
      `SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'geolite'`
    );
    expect(schemas).toHaveLength(1);
    expect(schemas[0].schema_name).toBe('geolite');
  });

  it('should have network table with correct structure', async () => {
    const columns = await pg.any(
      `SELECT column_name, data_type, is_nullable
       FROM information_schema.columns
       WHERE table_schema = 'geolite' AND table_name = 'network'
       ORDER BY ordinal_position`
    );
    expect(snapshot({ columns })).toMatchSnapshot();
  });

  it('should have location table with correct structure', async () => {
    const columns = await pg.any(
      `SELECT column_name, data_type, is_nullable
       FROM information_schema.columns
       WHERE table_schema = 'geolite' AND table_name = 'location'
       ORDER BY ordinal_position`
    );
    expect(snapshot({ columns })).toMatchSnapshot();
  });

  it('should have asn table with correct structure', async () => {
    const columns = await pg.any(
      `SELECT column_name, data_type, is_nullable
       FROM information_schema.columns
       WHERE table_schema = 'geolite' AND table_name = 'asn'
       ORDER BY ordinal_position`
    );
    expect(snapshot({ columns })).toMatchSnapshot();
  });

  it('should have data_version table with correct structure', async () => {
    const columns = await pg.any(
      `SELECT column_name, data_type, is_nullable
       FROM information_schema.columns
       WHERE table_schema = 'geolite' AND table_name = 'data_version'
       ORDER BY ordinal_position`
    );
    expect(snapshot({ columns })).toMatchSnapshot();
  });

  it('should have GiST index on network table', async () => {
    const indexes = await pg.any(
      `SELECT indexname, indexdef
       FROM pg_indexes
       WHERE schemaname = 'geolite' AND tablename = 'network'`
    );
    expect(indexes.some((i: any) => i.indexdef.includes('gist'))).toBe(true);
  });

  it('should have GiST index on asn table', async () => {
    const indexes = await pg.any(
      `SELECT indexname, indexdef
       FROM pg_indexes
       WHERE schemaname = 'geolite' AND tablename = 'asn'`
    );
    expect(indexes.some((i: any) => i.indexdef.includes('gist'))).toBe(true);
  });

  it('should have lookup function', async () => {
    const funcs = await pg.any(
      `SELECT routine_name
       FROM information_schema.routines
       WHERE routine_schema = 'geolite' AND routine_name = 'lookup'`
    );
    expect(funcs).toHaveLength(1);
  });

  it('should have lookup_asn function', async () => {
    const funcs = await pg.any(
      `SELECT routine_name
       FROM information_schema.routines
       WHERE routine_schema = 'geolite' AND routine_name = 'lookup_asn'`
    );
    expect(funcs).toHaveLength(1);
  });

  it('should grant SELECT on all tables to public', async () => {
    for (const table of ['network', 'location', 'asn', 'data_version']) {
      const result = await pg.any(
        `SELECT has_table_privilege('public', 'geolite.${table}', 'SELECT') AS has_priv`
      );
      expect(result[0].has_priv).toBe(true);
    }
  });

  it('lookup should return empty when no data loaded', async () => {
    const result = await pg.any(
      `SELECT * FROM geolite.lookup('8.8.8.8'::inet)`
    );
    expect(result).toHaveLength(0);
  });

  it('should handle CIDR lookups on network table', async () => {
    await pg.any(
      `INSERT INTO geolite.network (network, geoname_id, latitude, longitude, accuracy_radius)
       VALUES ('8.8.8.0/24', 6252001, 37.751, -97.822, 1000)`
    );

    const result = await pg.any(
      `SELECT network, geoname_id, latitude, longitude
       FROM geolite.network
       WHERE network >>= '8.8.8.8'::inet`
    );
    expect(result).toHaveLength(1);
    expect(result[0].geoname_id).toBe(6252001);
  });

  it('should join network and location via lookup function', async () => {
    await pg.any(
      `INSERT INTO geolite.location (geoname_id, locale_code, country_iso_code, country_name, city_name, time_zone)
       VALUES (6252001, 'en', 'US', 'United States', 'Mountain View', 'America/Los_Angeles')`
    );
    await pg.any(
      `INSERT INTO geolite.network (network, geoname_id, latitude, longitude, accuracy_radius)
       VALUES ('8.8.8.0/24', 6252001, 37.386, -122.084, 1000)`
    );

    const result = await pg.any(
      `SELECT * FROM geolite.lookup('8.8.8.8'::inet)`
    );
    expect(result).toHaveLength(1);
    expect(result[0].country_iso_code).toBe('US');
    expect(result[0].city_name).toBe('Mountain View');
  });
});
