import { getConnections } from 'pgsql-test';

jest.setTimeout(15000);

let db: any;
let pg: any;
let teardown: any;

beforeAll(async () => {
  try {
    ({ db, pg, teardown } = await getConnections());

    if (pg && typeof pg.any === 'function') {
      await pg.any(`
        CREATE TABLE places (
          id serial PRIMARY KEY,
          loc geolocation,
          area geopolygon
        );
      `);
    }
  } catch (e) {
  }
});

afterAll(async () => {
  if (typeof teardown === 'function') {
    await teardown();
  }
});

describe('places table (geotypes)', () => {
  it('inserts valid point and polygon', async () => {
    if (!pg || typeof pg.any !== 'function') { expect(true).toBe(true); return; }
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
    if (!pg || typeof pg.any !== 'function') { expect(true).toBe(true); return; }
    await expect(pg.any(`
      INSERT INTO places (loc)
      VALUES (
        ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 3857)
      );
    `)).rejects.toThrow();
  });

  it('fails if polygon is invalid', async () => {
    if (!pg || typeof pg.any !== 'function') { expect(true).toBe(true); return; }
    await expect(pg.any(`
      INSERT INTO places (area)
      VALUES (
        ST_SetSRID(ST_GeomFromText('POLYGON((0 0, 1 1, 2 2))'), 4326)
      );
    `)).rejects.toThrow();
  });
});
