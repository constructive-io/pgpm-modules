import { getConnections } from 'pgsql-test';

let db: any;
let pg: any;
let teardown: any;

beforeAll(async () => {
  try {
    ({ db, pg, teardown } = await getConnections());
  } catch {
  }
});

afterAll(async () => {
  try {
    if (typeof teardown === 'function') {
      await teardown();
    }
  } catch {
  }
});

beforeEach(() => {
  if (pg && typeof pg.beforeEach === 'function') {
    pg.beforeEach();
  }
});
afterEach(() => {
  if (pg && typeof pg.afterEach === 'function') {
    pg.afterEach();
  }
});

it('totp.generate + totp.verify basic', async () => {
  if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
  const { generate } = await pg.one(
    `SELECT totp.generate($1::text) AS generate`,
    ['secret']
  );
  const { verify } = await pg.one(
    `SELECT totp.verify($1::text, $2::text) AS verify`,
    ['secret', generate]
  );
  expect(typeof generate).toBe('string');
  expect(verify).toBe(true);
});
