import { getConnections, PgTestClient } from 'pgsql-test';

jest.setTimeout(15000);

let pg: PgTestClient;
let teardown:  () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());

  await pg.any(`
    CREATE TABLE places (
      id serial PRIMARY KEY,
      loc geo_point,
      area geo_polygon
    );
  `);

  await pg.any(`
    CREATE TABLE places_geo (
      id serial PRIMARY KEY,
      loc geography_point,
      area geography_polygon
    );
  `);
});

afterAll(async () => {
  await teardown();
});

describe('geometry domains (geo_point, geo_polygon)', () => {
  it('inserts valid point and polygon', async () => {
    await expect(pg.any(`
      INSERT INTO places (loc, area)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326),
        ST_SetSRID(
          ST_GeomFromText('POLYGON((-122.5 37.7, -122.4 37.7, -122.4 37.8, -122.5 37.8, -122.5 37.7))'),
          4326
        )
      );
    `)).resolves.not.toThrow();
  });

  it('fails if point SRID is incorrect', async () => {
    await expect(pg.any(`
      INSERT INTO places (loc)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 3857)
      );
    `)).rejects.toThrow();
  });

  it('fails if polygon is invalid', async () => {
    await expect(pg.any(`
      INSERT INTO places (area)
      VALUES (
        ST_SetSRID(ST_GeomFromText('POLYGON((0 0, 1 1, 2 2))'), 4326)
      );
    `)).rejects.toThrow();
  });
});

describe('geography domains (geography_point, geography_polygon)', () => {
  it('inserts valid geography point and polygon', async () => {
    await expect(pg.any(`
      INSERT INTO places_geo (loc, area)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
        ST_GeogFromText('POLYGON((-122.5 37.7, -122.4 37.7, -122.4 37.8, -122.5 37.8, -122.5 37.7))')
      );
    `)).resolves.not.toThrow();
  });

  it('computes distance in meters for geography_point', async () => {
    const result = await pg.one(`
      SELECT ST_Distance(
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-73.9857, 40.7484), 4326)::geography
      ) AS dist_meters;
    `);
    // SF to NYC is approximately 4,000 km
    expect(result.dist_meters).toBeGreaterThan(4000000);
    expect(result.dist_meters).toBeLessThan(5000000);
  });

  it('fails if geography point SRID is incorrect', async () => {
    await expect(pg.any(`
      INSERT INTO places_geo (loc)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 3857)::geography
      );
    `)).rejects.toThrow();
  });
});
