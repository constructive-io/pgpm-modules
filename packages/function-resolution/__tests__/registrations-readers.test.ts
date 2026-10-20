import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';

// One reader per module table the platform login reads (module loader, worker,
// reconciler). The login is NOBYPASSRLS, so these SECURITY DEFINER readers are
// its only way to the rows; no request or lane role may call them.
const READER_COUNT = 43;
const REQUEST_ROLES = ['anonymous', 'authenticated', 'authenticated_client'];

interface Reader {
  signature: string;
  nargs: number;
}
let readers: Reader[] = [];

const callOf = (reader: Reader): string =>
  `SELECT * FROM ${reader.signature.slice(0, reader.signature.indexOf('('))}(` +
  `${reader.nargs === 2 ? 'NULL::uuid, NULL::text' : 'NULL::uuid'})`;

// Run one statement as another role inside a savepoint, so a refusal neither
// aborts the test transaction nor leaks the role.
const asRole = async (role: string, run: () => Promise<unknown>): Promise<void> => {
  await pg.savepoint('as_role');
  pg.setContext({ role });
  try {
    await run();
  } finally {
    await pg.rollback('as_role');
    pg.setContext({ role: pg.config.user });
  }
};

describe('function_resolution *_registrations readers', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
    readers = await pg.any(
      `SELECT p.oid::regprocedure::text AS signature, p.pronargs::int AS nargs
         FROM pg_proc p
        WHERE p.pronamespace = 'function_resolution'::regnamespace
          AND p.proname LIKE '%\\_registrations'
        ORDER BY 1`
    );

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false)`,
      [PLATFORM_DB, TENANT_DB]
    );
    for (const [database, name, scope] of [
      [PLATFORM_DB, 'platform', 'platform'],
      [TENANT_DB, 'tenant', 'database'],
    ]) {
      const schema = await pg.one(
        `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
         VALUES ($1, 'storage', $2) RETURNING id`,
        [database, `${name}_storage_public`]
      );
      const buckets = await pg.one(
        `INSERT INTO metaschema_public.table (database_id, schema_id, name)
         VALUES ($1, $2, 'buckets') RETURNING id`,
        [database, schema.id]
      );
      const files = await pg.one(
        `INSERT INTO metaschema_public.table (database_id, schema_id, name)
         VALUES ($1, $2, 'files') RETURNING id`,
        [database, schema.id]
      );
      const logs = await pg.one(
        `INSERT INTO metaschema_public.field (database_id, table_id, name, type)
         VALUES ($1, $2, 'logs', '{"name": "text"}') RETURNING id`,
        [database, files.id]
      );
      const storage = await pg.one(
        `INSERT INTO metaschema_modules_public.storage_module
           (database_id, scope, schema_id, private_schema_id, buckets_table_id, files_table_id,
            endpoint, provider, region, public_url_prefix)
         VALUES ($1, $2, $3, $3, $4, $5, $6, 'rustfs', 'us-east-1', $7) RETURNING id`,
        [
          database, scope, schema.id, buckets.id, files.id,
          database === PLATFORM_DB ? 'http://storage.platform' : null,
          database === PLATFORM_DB ? 'http://cdn.platform' : null,
        ]
      );
      await pg.query(
        `INSERT INTO metaschema_modules_public.file_ref_field
           (database_id, table_id, field_id, storage_module_id, bucket_key)
         VALUES ($1, $2, $3, $4, $5)`,
        [database, files.id, logs.id, storage.id, `${name}-logs`]
      );
      const definitions = await pg.one(
        `INSERT INTO metaschema_public.table (database_id, schema_id, name)
         VALUES ($1, $2, 'function_definitions') RETURNING id`,
        [database, schema.id]
      );
      await pg.query(
        `INSERT INTO metaschema_modules_public.function_module
           (database_id, scope, schema_id, private_schema_id, definitions_table_id, bindings_table_id)
         VALUES ($1, $2, $3, $3, $4, $4)`,
        [database, scope, schema.id, definitions.id]
      );
    }
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

  it(`defines exactly ${READER_COUNT} readers, each SECURITY DEFINER with no search_path and no PUBLIC execute`, async () => {
    expect(readers).toHaveLength(READER_COUNT);
    const unsafe = await pg.any(
      `SELECT p.oid::regprocedure::text AS signature
         FROM pg_proc p
        WHERE p.pronamespace = 'function_resolution'::regnamespace
          AND p.proname LIKE '%\\_registrations'
          AND (NOT p.prosecdef
               OR p.proconfig IS NOT NULL
               OR has_function_privilege('public', p.oid, 'EXECUTE'))`
    );
    expect(unsafe).toEqual([]);
  });

  describe.each(REQUEST_ROLES)('as %s', (role) => {
    it('is refused every reader with permission denied', async () => {
      const refused: string[] = [];
      for (const reader of readers) {
        await asRole(role, async () => {
          await expect(pg.query(callOf(reader))).rejects.toThrow(/permission denied for (function|schema function_resolution)/);
          refused.push(reader.signature);
        });
      }
      expect(refused).toHaveLength(READER_COUNT);
    });
  });

  it('answers a database its own registrations and a surface lookup every owner at that scope', async () => {
    expect(
      await pg.any(
        `SELECT database_id, scope, platform_owned
           FROM function_resolution.function_module_registrations($1)`,
        [TENANT_DB]
      )
    ).toEqual([{ database_id: TENANT_DB, scope: 'database', platform_owned: false }]);
    expect(
      await pg.any(
        `SELECT database_id, scope, platform_owned
           FROM function_resolution.function_module_registrations(NULL, 'platform')`
      )
    ).toEqual([{ database_id: PLATFORM_DB, scope: 'platform', platform_owned: true }]);
  });

  it('inherits the platform storage connection and resolves the physical relations', async () => {
    const row = await pg.one(
      `SELECT public_schema, buckets_schema, buckets_table, files_table,
              endpoint, provider, region, public_url_prefix, connection_overrides
         FROM function_resolution.storage_module_registrations($1)`,
      [TENANT_DB]
    );
    expect(row).toEqual({
      public_schema: 'tenant_storage_public',
      buckets_schema: 'tenant_storage_public',
      buckets_table: 'buckets',
      files_table: 'files',
      endpoint: 'http://storage.platform',
      provider: 'rustfs',
      region: 'us-east-1',
      public_url_prefix: 'http://cdn.platform',
      connection_overrides: [],
    });
  });

  it('names a file_ref_field by its physical schema, table and field', async () => {
    expect(
      await pg.any(
        `SELECT schema_name, table_name, field_name, bucket_key
           FROM function_resolution.file_ref_field_registrations($1)`,
        [TENANT_DB]
      )
    ).toEqual([
      { schema_name: 'tenant_storage_public', table_name: 'files', field_name: 'logs', bucket_key: 'tenant-logs' },
    ]);
  });
});
