import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let db: PgTestClient;
let teardown: () => Promise<void>;

const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const OTHER_DB = '33333333-3333-3333-3333-333333333333';

// What the storage plugins may read on the request lane: configuration only.
const STORAGE_MODULE_COLUMNS = [
  'id', 'database_id', 'scope', 'buckets_table_id', 'entity_field', 'entity_table_id',
  'buckets_schema', 'buckets_table',
  'files_schema', 'files_table', 'private_schema', 'endpoint',
  'public_url_prefix', 'provider', 'region', 'connection_overrides',
  'allowed_origins', 'upload_url_expiry_seconds', 'download_url_expiry_seconds',
  'default_max_file_size', 'max_filename_length', 'cache_ttl_seconds',
  'max_bulk_files', 'max_bulk_total_size', 'has_path_shares', 'has_versioning',
  'has_content_hash', 'has_confirm_upload', 'entity_schema', 'entity_table'
];

const ids: Record<string, string> = {};

// Run one statement on the superuser connection as another role (only a
// superuser may assume the pg-wire lane floor role here), inside a savepoint so
// a refusal neither aborts the test transaction nor leaks the role.
const asRole = async (ctx: Record<string, string>, run: () => Promise<unknown>): Promise<void> => {
  await pg.savepoint('as_role');
  pg.setContext(ctx);
  try {
    await run();
  } finally {
    await pg.rollback('as_role');
    // clearContext() would fall back to anonymous; return to the connection's own login.
    pg.setContext({ role: pg.config.user });
  }
};

// Request-time reads never switch role and never lean on a BYPASSRLS login:
// the storage plugins read their own database's configuration as the
// request's anonymous/authenticated role through a claim-scoped SECURITY
// DEFINER hop, and the cross-database routing-plane list is reachable by no
// request role at all.
describe('request-lane resolution reads', () => {
  beforeAll(async () => {
    ({ pg, db, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false), ($3, 'other_db', false)`,
      [PLATFORM_DB, TENANT_DB, OTHER_DB]
    );

    for (const [database, name] of [[PLATFORM_DB, 'platform'], [TENANT_DB, 'tenant'], [OTHER_DB, 'other']]) {
      const schema = await pg.one(
        `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
         VALUES ($1, $2, $3) RETURNING id`,
        [database, `${name}_storage`, `${name}_storage_public`]
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
      const field = await pg.one(
        `INSERT INTO metaschema_public.field (database_id, table_id, name, type)
         VALUES ($1, $2, 'avatar', '{"name": "text"}') RETURNING id`,
        [database, files.id]
      );
      const module = await pg.one(
        `INSERT INTO metaschema_modules_public.storage_module
           (database_id, scope, schema_id, private_schema_id, buckets_table_id, files_table_id,
            endpoint, provider, region, public_url_prefix)
         VALUES ($1, $2, $3, $3, $4, $5, $6, 'rustfs', 'us-east-1', $7) RETURNING id`,
        [
          database,
          database === PLATFORM_DB ? 'platform' : 'database',
          schema.id,
          buckets.id,
          files.id,
          database === PLATFORM_DB ? 'http://storage.platform' : null,
          database === PLATFORM_DB ? 'http://cdn.platform' : null
        ]
      );
      await pg.query(
        `INSERT INTO metaschema_modules_public.file_ref_field
           (database_id, table_id, field_id, storage_module_id, bucket_key)
         VALUES ($1, $2, $3, $4, $5)`,
        [database, files.id, field.id, module.id, `${name}-bucket`]
      );
      const routingTable = async (table: string): Promise<string> =>
        (await pg.one(
          `INSERT INTO metaschema_public.table (database_id, schema_id, name)
           VALUES ($1, $2, $3) RETURNING id`,
          [database, schema.id, table]
        )).id;
      await pg.query(
        `INSERT INTO metaschema_modules_public.route_module
           (database_id, scope, schema_id, private_schema_id, resolver_function_name,
            routes_table_id, hostname_bindings_table_id, route_bindings_table_id, redirects_table_id)
         VALUES ($1, 'database', $2, $2, 'resolve_route', $3, $4, $5, $6)`,
        [
          database,
          schema.id,
          await routingTable('routes'),
          await routingTable('hostname_bindings'),
          await routingTable('route_bindings'),
          await routingTable('redirects')
        ]
      );
      ids[name] = module.id;
    }
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.beforeEach();
    await db.beforeEach();
  });

  afterEach(async () => {
    await db.afterEach();
    await pg.afterEach();
  });

  describe.each(['anonymous', 'authenticated'])('as %s', (role) => {
    it('reads only its own database storage modules, configuration only', async () => {
      db.setContext({ role, 'jwt.claims.database_id': TENANT_DB });
      const result = await db.query(`SELECT * FROM function_resolution.storage_modules()`);

      expect(result.fields.map((f) => f.name)).toEqual(STORAGE_MODULE_COLUMNS);
      expect(result.rows.map((r) => r.id)).toEqual([ids.tenant]);
      expect(result.rows[0]).toMatchObject({
        database_id: TENANT_DB,
        buckets_schema: 'tenant_storage_public',
        files_table: 'files',
        endpoint: 'http://storage.platform',
        public_url_prefix: 'http://cdn.platform',
        provider: 'rustfs',
        region: 'us-east-1',
        connection_overrides: []
      });
    });

    it('reads its own database file-ref binding and no other database\'s', async () => {
      db.setContext({ role, 'jwt.claims.database_id': TENANT_DB });
      const own = await db.any(
        `SELECT * FROM function_resolution.storage_file_ref_field('tenant_storage_public', 'files', 'avatar')`
      );
      expect(own.map((r) => r.bucket_key)).toEqual(['tenant-bucket']);

      const other = await db.any(
        `SELECT * FROM function_resolution.storage_file_ref_field('other_storage_public', 'files', 'avatar')`
      );
      expect(other).toEqual([]);
    });

    it('raises without a database claim instead of reading any database', async () => {
      db.setContext({ role, 'jwt.claims.database_id': null });
      await expect(
        db.any(`SELECT * FROM function_resolution.storage_modules()`)
      ).rejects.toThrow(/DATABASE_CLAIM_REQUIRED/);
    });

    it('cannot enumerate the routing planes', async () => {
      db.setContext({ role, 'jwt.claims.database_id': TENANT_DB });
      await expect(
        db.any(`SELECT * FROM function_resolution.routing_planes()`)
      ).rejects.toThrow(/permission denied for function routing_planes/);
    });

  });

  it('refuses the routing-plane list to the pg-wire lane floor role', async () => {
    // The pg-wire lane connects at this role; only a superuser may assume it here.
    await asRole({ role: 'authenticated_client', 'jwt.claims.database_id': TENANT_DB }, () =>
      expect(
        pg.any(`SELECT * FROM function_resolution.routing_planes()`)
      ).rejects.toThrow(/permission denied for (schema function_resolution|function routing_planes)/)
    );
  });

  it('raises when the platform storage plane has no endpoint instead of returning NULL config', async () => {
    await pg.query(
      `UPDATE metaschema_modules_public.storage_module SET endpoint = NULL WHERE database_id = $1`,
      [PLATFORM_DB]
    );
    // Same connection as the change above, so the read sees it.
    await asRole({ role: 'authenticated', 'jwt.claims.database_id': TENANT_DB }, () =>
      expect(
        pg.any(`SELECT * FROM function_resolution.storage_modules()`)
      ).rejects.toThrow(/STORAGE_PLATFORM_ENDPOINT_MISSING/)
    );
  });

  it('raises when there is no platform storage plane at all', async () => {
    await pg.query(
      `DELETE FROM metaschema_modules_public.storage_module WHERE database_id = $1`,
      [PLATFORM_DB]
    );
    // Same connection as the change above, so the read sees it.
    await asRole({ role: 'authenticated', 'jwt.claims.database_id': TENANT_DB }, () =>
      expect(
        pg.any(`SELECT * FROM function_resolution.storage_modules()`)
      ).rejects.toThrow(/STORAGE_PLATFORM_ENDPOINT_MISSING/)
    );
  });

  it('lists every database-scope plane in resolution order for its grantee', async () => {
    const planes = await pg.any(`SELECT * FROM function_resolution.routing_planes()`);
    expect(planes).toEqual([
      { database_id: PLATFORM_DB, schema_name: 'platform_storage_public', resolver_function_name: 'resolve_route' },
      { database_id: TENANT_DB, schema_name: 'tenant_storage_public', resolver_function_name: 'resolve_route' },
      { database_id: OTHER_DB, schema_name: 'other_storage_public', resolver_function_name: 'resolve_route' }
    ]);
  });
});
