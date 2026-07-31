import { getConnections, PgTestClient } from 'constructive-test';

jest.setTimeout(15000);

let pg: PgTestClient;
let teardown:  () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());

  await pg.any(`
    CREATE TABLE places (
      id serial PRIMARY KEY,
      loc geo_point,
      area geo_polygon,
      loc_earth geography_point,
      area_earth geography_polygon
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
      INSERT INTO places (loc_earth, area_earth)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
        ST_GeogFromText('POLYGON((-122.5 37.7, -122.4 37.7, -122.4 37.8, -122.5 37.8, -122.5 37.7))')
      );
    `)).resolves.not.toThrow();
  });

  it('computes distance in meters for geography_point', async () => {
    const result = await pg.one<{ dist: number }>(`
      SELECT ST_Distance(
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
        ST_SetSRID(ST_MakePoint(-73.9857, 40.7484), 4326)::geography
      ) as dist;
    `);
    // ST_Distance on geography returns meters; SF to NYC is ~4,000 km
    expect(result.dist).toBeGreaterThan(4000000);
    expect(result.dist).toBeLessThan(5000000);
  });

  it('fails if geography point SRID is incorrect', async () => {
    await expect(pg.any(`
      INSERT INTO places (loc_earth)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 3857)::geography
      );
    `)).rejects.toThrow();
  });
});
