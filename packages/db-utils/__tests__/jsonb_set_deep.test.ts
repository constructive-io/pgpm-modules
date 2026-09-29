jest.setTimeout(60000);

import { getConnections, PgTestClient } from 'pgsql-test';

let db: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ db, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});

beforeEach(async () => {
  await db.beforeEach();
});

afterEach(async () => {
  await db.afterEach();
});

describe('db_utils.jsonb_set_deep', () => {
  it('creates missing intermediate objects and keeps siblings', async () => {
    const [{ out }] = await db.any<{ out: unknown }>(
      `SELECT db_utils.jsonb_set_deep('{"resources":{"requests":{"cpu":"100m"}}}'::jsonb,
                                      ARRAY['resources','limits','memory'],
                                      '"4Gi"'::jsonb) AS out`
    );
    expect(out).toEqual({
      resources: { requests: { cpu: '100m' }, limits: { memory: '4Gi' } },
    });
  });

  it('replaces a non-object sitting on the declared path', async () => {
    const [{ out }] = await db.any<{ out: unknown }>(
      `SELECT db_utils.jsonb_set_deep('{"settings":"nope"}'::jsonb,
                                      ARRAY['settings','NODE_ENV'],
                                      '"production"'::jsonb) AS out`
    );
    expect(out).toEqual({ settings: { NODE_ENV: 'production' } });
  });
});
