import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const database_id = '11111111-1111-4111-8111-111111111111';
const schema_id = '22222222-2222-4222-8222-222222222222';
const table_id = '33333333-3333-4333-8333-333333333333';
const field_id = '44444444-4444-4444-8444-444444444444';
const partition_id = '55555555-5555-4555-8555-555555555555';

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
});

afterAll(async () => {
  await teardown();
});

beforeEach(async () => {
  await pg.beforeEach();

  await pg.any(`CREATE SCHEMA partman_test_public`);
  await pg.any(`CREATE TABLE partman_test_public.events (
    id uuid NOT NULL,
    created_at timestamptz NOT NULL
  ) PARTITION BY RANGE (created_at)`);

  await pg.any(
    `INSERT INTO metaschema_public.database (id, name, schema_hash, hash)
       VALUES ($1, 'partman_test', 'partman_test', gen_random_uuid())`,
    [database_id]
  );
  await pg.any(
    `INSERT INTO metaschema_public.schema (id, database_id, name, schema_name)
       VALUES ($1, $2, 'partman_test_public', 'partman_test_public')`,
    [schema_id, database_id]
  );
  await pg.any(
    `INSERT INTO metaschema_public.table (id, database_id, schema_id, name)
       VALUES ($1, $2, $3, 'events')`,
    [table_id, database_id, schema_id]
  );
  await pg.any(
    `INSERT INTO metaschema_public.field (id, database_id, table_id, name, type)
       VALUES ($1, $2, $3, 'created_at', '"timestamp"'::jsonb)`,
    [field_id, database_id, table_id]
  );
});

afterEach(async () => {
  await pg.afterEach();
});

const parent = async () =>
  pg.any(
    `INSERT INTO metaschema_public.partition
       (id, database_id, table_id, strategy, partition_key_id, "interval", premake)
       VALUES ($1, $2, $3, 'range', $4, '1 day', 2)`,
    [partition_id, database_id, table_id, field_id]
  );

const templateExists = async () =>
  (
    await pg.one(
      `SELECT to_regclass('partman.template_partman_test_public_events') IS NOT NULL AS exists`
    )
  ).exists;

describe('metaschema partition rows', () => {
  it('parents the table with pg_partman on insert', async () => {
    await parent();

    const config = await pg.one(
      `SELECT parent_table, control FROM partman.part_config
         WHERE parent_table = 'partman_test_public.events'`
    );
    expect(config.control).toBe('created_at');
    expect(await templateExists()).toBe(true);
  });

  it('unparents the table on delete, leaving no template table behind', async () => {
    await parent();

    await pg.any(`DELETE FROM metaschema_public.partition WHERE id = $1`, [
      partition_id
    ]);

    const configs = await pg.any(
      `SELECT 1 FROM partman.part_config WHERE parent_table = 'partman_test_public.events'`
    );
    expect(configs).toHaveLength(0);

    // The template table outliving the parent is what blocked DROP TYPE on the
    // parent's column types during a revert.
    expect(await templateExists()).toBe(false);
  });
});
