import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});

describe('to_path', () => {
  it('converts slash path with leading slash', async () => {
    const { to_path } = await pg.one(
      `SELECT ltree_helpers.to_path($1)::text AS to_path`,
      ['/projects/alpha/docs']
    );
    expect(to_path).toBe('projects.alpha.docs');
  });

  it('converts slash path without leading slash', async () => {
    const { to_path } = await pg.one(
      `SELECT ltree_helpers.to_path($1)::text AS to_path`,
      ['projects/alpha']
    );
    expect(to_path).toBe('projects.alpha');
  });

  it('converts single segment', async () => {
    const { to_path } = await pg.one(
      `SELECT ltree_helpers.to_path($1)::text AS to_path`,
      ['/root']
    );
    expect(to_path).toBe('root');
  });
});

describe('to_slash', () => {
  it('converts ltree to slash path', async () => {
    const { to_slash } = await pg.one(
      `SELECT ltree_helpers.to_slash($1::ltree) AS to_slash`,
      ['projects.alpha.docs']
    );
    expect(to_slash).toBe('/projects/alpha/docs');
  });

  it('converts single label', async () => {
    const { to_slash } = await pg.one(
      `SELECT ltree_helpers.to_slash($1::ltree) AS to_slash`,
      ['root']
    );
    expect(to_slash).toBe('/root');
  });
});

describe('to_query', () => {
  it('converts single-level wildcard', async () => {
    const { to_query } = await pg.one(
      `SELECT ltree_helpers.to_query($1)::text AS to_query`,
      ['/projects/*/docs']
    );
    expect(to_query).toBe('projects.*.docs');
  });

  it('converts recursive wildcard', async () => {
    const { to_query } = await pg.one(
      `SELECT ltree_helpers.to_query($1)::text AS to_query`,
      ['/projects/**']
    );
    expect(to_query).toBe('projects.*{1,}');
  });

  it('converts exact path (no wildcards)', async () => {
    const { to_query } = await pg.one(
      `SELECT ltree_helpers.to_query($1)::text AS to_query`,
      ['/projects/alpha']
    );
    expect(to_query).toBe('projects.alpha');
  });
});

describe('roundtrip', () => {
  it('to_path then to_slash returns original path', async () => {
    const { roundtrip } = await pg.one(
      `SELECT ltree_helpers.to_slash(ltree_helpers.to_path($1)) AS roundtrip`,
      ['/projects/alpha/docs']
    );
    expect(roundtrip).toBe('/projects/alpha/docs');
  });
});
