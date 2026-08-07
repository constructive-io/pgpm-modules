import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const DB_A = '22222222-2222-2222-2222-222222222222';
const DB_B = '33333333-3333-3333-3333-333333333333';
// A database still registering into its own hash-named catalog, as databases
// provisioned before the published module do.
const LEGACY_DB = '44444444-4444-4444-4444-444444444444';

const ids: Record<string, string> = {};

// The published capability planes: ONE catalog_private.buckets and ONE
// catalog_private.apis holding every database's rows, separated only by the
// database_id the catalog-sync triggers stamp. The hazard this suite pins is a
// probe answered with another tenant's row — the shared plane makes that a
// single missing predicate away, and both resolvers must be tenant-exact while
// the legacy database keeps reading its own plane.
describe('capability resolution against the published catalog planes', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'db_a', false),
              ($3, 'db_b', false), ($4, 'legacy_db', false)`,
      [PLATFORM_DB, DB_A, DB_B, LEGACY_DB]
    );

    // --- The published planes ------------------------------------------------
    await pg.query(`CREATE SCHEMA catalog_private`);
    await pg.query(
      `CREATE TABLE catalog_private.buckets (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         key text NOT NULL,
         type text NOT NULL,
         physical_name text,
         tags text[]
       )`
    );
    // The database-qualified claims the published catalog carries: two
    // databases may each own a bucket with the same (scope, key, bucket key).
    await pg.query(
      `CREATE UNIQUE INDEX buckets_db_owner_key_idx
       ON catalog_private.buckets (database_id, owner_scope, owner_key, key)
       WHERE owner_key IS NOT NULL`
    );
    await pg.query(
      `CREATE UNIQUE INDEX buckets_db_owner_scope_key_idx
       ON catalog_private.buckets (database_id, owner_scope, key)
       WHERE owner_key IS NULL`
    );
    await pg.query(
      `CREATE TABLE catalog_private.apis (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         name text NOT NULL
       )`
    );
    await pg.query(
      `CREATE UNIQUE INDEX apis_db_owner_key_name_idx
       ON catalog_private.apis (database_id, owner_scope, owner_key, name)
       WHERE owner_key IS NOT NULL`
    );
    await pg.query(
      `CREATE UNIQUE INDEX apis_db_owner_scope_name_idx
       ON catalog_private.apis (database_id, owner_scope, name)
       WHERE owner_key IS NULL`
    );

    await pg.query(
      `CREATE TABLE catalog_private.bindings (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         function_id uuid,
         graph_id uuid,
         bucket_id uuid,
         lifecycle text NOT NULL,
         key text NOT NULL
       )`
    );
    await pg.query(
      `CREATE INDEX bindings_db_owner_fn_key_idx
       ON catalog_private.bindings (database_id, owner_scope, owner_key, function_id, key)`
    );

    // --- A legacy, hash-named plane of the same shape ------------------------
    await pg.query(`CREATE SCHEMA cap_legacy_catalog_private`);
    await pg.query(
      `CREATE TABLE cap_legacy_catalog_private.buckets (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         key text NOT NULL,
         type text NOT NULL,
         physical_name text,
         tags text[]
       )`
    );
    await pg.query(
      `CREATE TABLE cap_legacy_catalog_private.apis (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         name text NOT NULL
       )`
    );

    // --- Rows: the same identity in two databases ---------------------------
    ids.bucketA = 'aaaaaaaa-0000-0000-0000-000000000001';
    ids.bucketB = 'bbbbbbbb-0000-0000-0000-000000000001';
    ids.bucketAVisible = 'aaaaaaaa-0000-0000-0000-000000000002';
    ids.bucketLegacy = 'cccccccc-0000-0000-0000-000000000001';
    ids.apiA = 'aaaaaaaa-0000-0000-0000-000000000011';
    ids.apiB = 'bbbbbbbb-0000-0000-0000-000000000011';
    ids.apiLegacy = 'cccccccc-0000-0000-0000-000000000011';
    // One function definition id, bound by BOTH databases at the same (scope,
    // key) coordinates: the pair the shared bindings plane must keep apart.
    ids.functionDef = 'dddddddd-0000-0000-0000-000000000001';
    ids.bindingA = 'aaaaaaaa-0000-0000-0000-000000000021';
    ids.bindingB = 'bbbbbbbb-0000-0000-0000-000000000021';

    await pg.query(
      `INSERT INTO catalog_private.buckets
         (id, owner_scope, owner_key, is_visible, database_id, key, type, physical_name, tags)
       VALUES ($1, 'database', $2, false, $2, 'exports', 'private', 'phys-a-exports', ARRAY['exports']),
              ($3, 'database', $4, false, $4, 'exports', 'private', 'phys-b-exports', ARRAY['exports']),
              ($5, 'database', $2, true,  $2, 'shared', 'public', 'phys-a-shared', ARRAY['shared'])`,
      [ids.bucketA, DB_A, ids.bucketB, DB_B, ids.bucketAVisible]
    );
    await pg.query(
      `INSERT INTO catalog_private.apis
         (id, owner_scope, owner_key, is_visible, database_id, name)
       VALUES ($1, 'database', $2, false, $2, 'admin'),
              ($3, 'database', $4, false, $4, 'admin')`,
      [ids.apiA, DB_A, ids.apiB, DB_B]
    );
    await pg.query(
      `INSERT INTO cap_legacy_catalog_private.buckets
         (id, owner_scope, owner_key, is_visible, database_id, key, type, physical_name, tags)
       VALUES ($1, 'database', $2, false, $2, 'exports', 'private', 'phys-legacy-exports', ARRAY['exports'])`,
      [ids.bucketLegacy, LEGACY_DB]
    );
    await pg.query(
      `INSERT INTO cap_legacy_catalog_private.apis
         (id, owner_scope, owner_key, is_visible, database_id, name)
       VALUES ($1, 'database', $2, false, $2, 'admin')`,
      [ids.apiLegacy, LEGACY_DB]
    );

    await pg.query(
      `INSERT INTO catalog_private.bindings
         (id, owner_scope, owner_key, database_id, function_id, bucket_id, lifecycle, key)
       VALUES ($1, 'database', $2, $2, $5, $6, 'deployment', 'reports'),
              ($3, 'database', $4, $4, $5, $7, 'deployment', 'reports')`,
      [ids.bindingA, DB_A, ids.bindingB, DB_B, ids.functionDef, ids.bucketA, ids.bucketB]
    );

    // --- Metaschema wiring: which plane each database registers into --------
    // The published planes are ONE physical schema, so they have ONE metaschema
    // schema row (schema_name is globally unique) and one table row per kind;
    // every database that deploys the published module points its
    // catalog_module at them. That is exactly why the rows carry database_id.
    const publishedSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'catalog_private', 'catalog_private') RETURNING id`,
      [PLATFORM_DB]
    );
    const publishedBuckets = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'buckets') RETURNING id`,
      [PLATFORM_DB, publishedSchema.id]
    );
    const publishedApis = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'apis') RETURNING id`,
      [PLATFORM_DB, publishedSchema.id]
    );
    const publishedBindings = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'bindings') RETURNING id`,
      [PLATFORM_DB, publishedSchema.id]
    );

    for (const [dbId, schemaName, label] of [
      [DB_A, 'catalog_private', 'a'],
      [DB_B, 'catalog_private', 'b'],
      [LEGACY_DB, 'cap_legacy_catalog_private', 'legacy'],
    ] as const) {
      let bucketsTableId = publishedBuckets.id;
      let apisTableId = publishedApis.id;
      let bindingsTableId = publishedBindings.id;
      let schemaId = publishedSchema.id;

      if (schemaName !== 'catalog_private') {
        const schema = await pg.one(
          `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
           VALUES ($1, $2, $2) RETURNING id`,
          [dbId, schemaName]
        );
        const buckets = await pg.one(
          `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
           VALUES ($1, $2, 'buckets') RETURNING id`,
          [dbId, schema.id]
        );
        const apis = await pg.one(
          `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
           VALUES ($1, $2, 'apis') RETURNING id`,
          [dbId, schema.id]
        );
        // The legacy database's catalog has no bindings table at all, as every
        // database provisioned before the bindings kind does: its bindings stay
        // in the scoped source table the transition branch reads.
        schemaId = schema.id;
        bucketsTableId = buckets.id;
        apisTableId = apis.id;
        bindingsTableId = buckets.id;
      }

      await pg.query(
        `INSERT INTO metaschema_modules_public.catalog_module
           (database_id, schema_id, functions_table_id,
            domains_table_id, apis_table_id, sites_table_id, namespaces_table_id,
            resources_table_id, resource_definitions_table_id,
            resource_installations_table_id, apps_table_id, buckets_table_id,
            bindings_table_id, sites_web_config_table_id,
            sites_error_pages_table_id,
            sites_app_links_table_id, sites_deep_links_table_id, scope)
         VALUES ($1, $2, $3, $3, $4, $3, $3, $3, $3, $3, $3, $5, $6, $3, $3, $3, $3, 'database')`,
        [dbId, schemaId, bucketsTableId, apisTableId, bucketsTableId, bindingsTableId]
      );
      // Label kept for readability of the fixture rows above.
      void label;
    }
  });

  afterAll(async () => {
    await teardown();
  });

  it('resolve_bucket(): each database is answered with its own row', async () => {
    const [a] = await pg.any(
      `SELECT bucket_id, physical_name, owner_database_id
       FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['exports'], NULL)`,
      [DB_A]
    );
    expect(a).toEqual({
      bucket_id: ids.bucketA,
      physical_name: 'phys-a-exports',
      owner_database_id: DB_A,
    });

    const [b] = await pg.any(
      `SELECT bucket_id, physical_name, owner_database_id
       FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['exports'], NULL)`,
      [DB_B]
    );
    expect(b).toEqual({
      bucket_id: ids.bucketB,
      physical_name: 'phys-b-exports',
      owner_database_id: DB_B,
    });
  });

  it('resolve_bucket(): a plane that is not the published one is read by nothing', async () => {
    // LEGACY_DB's rows sit in its own hash-named plane. The fallback that used
    // to read it is gone, so its own bucket is simply not found.
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['exports'], NULL)`,
        [LEGACY_DB]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_NOT_FOUND/);
  });

  it('resolve_bucket(): a tag present only in another database is not found', async () => {
    await pg.query(
      `INSERT INTO catalog_private.buckets
         (id, owner_scope, owner_key, is_visible, database_id, key, type, physical_name, tags)
       VALUES ($1, 'database', $2, false, $2, 'b-only', 'private', 'phys-b-only', ARRAY['b-only'])`,
      ['bbbbbbbb-0000-0000-0000-000000000002', DB_B]
    );
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['b-only'], NULL)`,
        [DB_A]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_NOT_FOUND/);
  });

  it('bucket_catalog_row(): a binding cannot reach another database bucket', async () => {
    const [own] = await pg.any(
      `SELECT bucket_key, physical_name, owner_database_id
       FROM function_resolution.bucket_catalog_row($1, 'database', $1, $2)`,
      [DB_A, ids.bucketA]
    );
    expect(own).toEqual({
      bucket_key: 'exports',
      physical_name: 'phys-a-exports',
      owner_database_id: DB_A,
    });

    // DB_B's bucket lives in the same relation, is not visible, and must not
    // be reachable from DB_A even though its id is known.
    const foreign = await pg.any(
      `SELECT * FROM function_resolution.bucket_catalog_row($1, 'database', $1, $2)`,
      [DB_A, ids.bucketB]
    );
    expect(foreign).toEqual([]);
  });

  it('bucket_catalog_row(): a visible bucket of another database is unreachable without a shared frame', async () => {
    // is_visible relaxes the ownership check only for a frame in the caller's
    // own chain; DB_B's chain contains no frame owning DB_A's row.
    const rows = await pg.any(
      `SELECT * FROM function_resolution.bucket_catalog_row($1, 'database', $1, $2)`,
      [DB_B, ids.bucketAVisible]
    );
    expect(rows).toEqual([]);
  });

  it('resolve_api(): the name path answers each database with its own surface', async () => {
    const [a] = await pg.any(
      `SELECT api_id, api_name, owner_database_id
       FROM function_resolution.resolve_api($1, 'database', $1, 'admin')`,
      [DB_A]
    );
    expect(a).toEqual({ api_id: ids.apiA, api_name: 'admin', owner_database_id: DB_A });

    const [b] = await pg.any(
      `SELECT api_id, owner_database_id
       FROM function_resolution.resolve_api($1, 'database', $1, 'admin')`,
      [DB_B]
    );
    expect(b).toEqual({ api_id: ids.apiB, owner_database_id: DB_B });

    // LEGACY_DB carries the same name in its own hash-named plane, which is no
    // longer read at all.
    await expect(
      pg.any(`SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'admin')`, [
        LEGACY_DB,
      ])
    ).rejects.toThrow(/CAPABILITY_API_NOT_FOUND/);
  });

  it('resolve_api(): an api present only in another database is not found', async () => {
    await pg.query(
      `INSERT INTO catalog_private.apis
         (id, owner_scope, owner_key, is_visible, database_id, name)
       VALUES ($1, 'database', $2, false, $2, 'b-only-api')`,
      ['bbbbbbbb-0000-0000-0000-000000000012', DB_B]
    );
    await expect(
      pg.any(`SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'b-only-api')`, [
        DB_A,
      ])
    ).rejects.toThrow(/CAPABILITY_API_NOT_FOUND/);
  });

  it('api_catalog_row(): another database surface is unreachable by id', async () => {
    const [own] = await pg.any(
      `SELECT api_name, owner_database_id
       FROM function_resolution.api_catalog_row($1, 'database', $1, $2)`,
      [DB_A, ids.apiA]
    );
    expect(own).toEqual({ api_name: 'admin', owner_database_id: DB_A });

    const foreign = await pg.any(
      `SELECT * FROM function_resolution.api_catalog_row($1, 'database', $1, $2)`,
      [DB_A, ids.apiB]
    );
    expect(foreign).toEqual([]);
  });

  it('bound_bucket_id(): each database is answered with its own binding', async () => {
    const [a] = await pg.any(
      `SELECT function_resolution.bound_bucket_id($1, 'database', $1, $2, 'reports') AS bucket_id`,
      [DB_A, ids.functionDef]
    );
    expect(a.bucket_id).toBe(ids.bucketA);

    const [b] = await pg.any(
      `SELECT function_resolution.bound_bucket_id($1, 'database', $1, $2, 'reports') AS bucket_id`,
      [DB_B, ids.functionDef]
    );
    expect(b.bucket_id).toBe(ids.bucketB);
  });

  it('bound_bucket_id(): an unbound key is left to discovery', async () => {
    const [none] = await pg.any(
      `SELECT function_resolution.bound_bucket_id($1, 'database', $1, $2, 'exports') AS bucket_id`,
      [DB_A, ids.functionDef]
    );
    expect(none.bucket_id).toBeNull();
  });

  it('the published planes are authoritative — removing the row stops resolution', async () => {
    await pg.query(`DELETE FROM catalog_private.buckets WHERE id = $1`, [ids.bucketA]);
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['exports'], NULL)`,
        [DB_A]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_NOT_FOUND/);
  });
});
