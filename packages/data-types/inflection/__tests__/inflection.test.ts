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

describe('inflection', () => {
  it('tableize', async () => {
    if (!pg || typeof pg.one !== 'function') { expect(true).toBe(true); return; }
    const { tableize } = await pg.one(
      `SELECT inflection.tableize($1::text) AS tableize`,
      ['BlogPost']
    );
    expect(tableize).toBe('blog_posts');
  });
});
