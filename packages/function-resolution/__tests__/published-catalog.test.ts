import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const DB_A = '22222222-2222-2222-2222-222222222222';
const DB_B = '33333333-3333-3333-3333-333333333333';
// A database registered into a plane that is NOT the published one. Nothing
// resolves for it any more: the transition fallback that read such a plane is
// gone, so it is here to pin that the published plane is the only one read.
const LEGACY_DB = '44444444-4444-4444-4444-444444444444';

const ids: Record<string, string> = {};

// The published catalog plane: ONE relation (catalog_private.functions) holding
// every database's rows, separated by the database_id the catalog-sync
// triggers stamp. Resolution against it must be static AND tenant-exact — the
// hazard this suite pins is a probe answered with another database's row.
describe('function-resolution against the published catalog plane', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'db_a', false),
              ($3, 'db_b', false), ($4, 'legacy_db', false)`,
      [PLATFORM_DB, DB_A, DB_B, LEGACY_DB]
    );

    // --- The published plane -------------------------------------------------
    await pg.query(`CREATE SCHEMA catalog_private`);
    await pg.query(
      `CREATE TABLE catalog_private.functions (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         task_identifier text NOT NULL,
         queue_name text,
         priority integer,
         max_attempts integer
       )`
    );
    // The unique keys the published catalog carries: database-qualified, so
    // two databases may each own the same (scope, key, task).
    await pg.query(
      `CREATE UNIQUE INDEX functions_db_owner_scope_owner_key_task_idx
       ON catalog_private.functions (database_id, owner_scope, owner_key, task_identifier)
       WHERE owner_key IS NOT NULL`
    );
    await pg.query(
      `CREATE UNIQUE INDEX functions_db_owner_scope_task_idx
       ON catalog_private.functions (database_id, owner_scope, task_identifier)
       WHERE owner_key IS NULL`
    );
    await pg.query(
      `CREATE INDEX functions_database_id_idx ON catalog_private.functions (database_id)`
    );

    // --- A legacy, hash-named plane for the same shape -----------------------
    await pg.query(`CREATE SCHEMA fn_legacy_catalog_private`);
    await pg.query(
      `CREATE TABLE fn_legacy_catalog_private.functions (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         task_identifier text NOT NULL
       )`
    );
    await pg.query(
      `CREATE UNIQUE INDEX legacy_functions_owner_scope_task_idx
       ON fn_legacy_catalog_private.functions (owner_scope, task_identifier)
       WHERE owner_key IS NULL`
    );

    // --- Rows ----------------------------------------------------------------
    // Same (owner_scope, owner_key, task_identifier) in two databases: only
    // database_id tells them apart.
    ids.appA = 'aaaaaaaa-0000-0000-0000-000000000001';
    ids.appB = 'bbbbbbbb-0000-0000-0000-000000000001';
    ids.dbScopedA = 'aaaaaaaa-0000-0000-0000-000000000002';
    ids.legacy = 'cccccccc-0000-0000-0000-000000000001';

    await pg.query(
      `INSERT INTO catalog_private.functions
         (id, owner_scope, owner_key, is_visible, database_id, task_identifier,
          queue_name, priority, max_attempts)
       VALUES ($1, 'app', NULL, true, $2, 'email:send', 'email', 5, 3),
              ($3, 'app', NULL, true, $4, 'email:send', 'default', 0, 25),
              ($5, 'database', $2, true, $2, 'report:run', NULL, NULL, NULL)`,
      [ids.appA, DB_A, ids.appB, DB_B, ids.dbScopedA]
    );
    await pg.query(
      `INSERT INTO fn_legacy_catalog_private.functions
         (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
       VALUES ($1, 'app', NULL, true, $2, 'email:send')`,
      [ids.legacy, LEGACY_DB]
    );

    // --- Metaschema wiring: which plane each database registers into ---------
    // The published plane is ONE physical schema, so it has ONE metaschema
    // schema/table row (schema_name is globally unique); every database that
    // deploys the published module points its catalog_module at it. That is
    // exactly why the rows carry database_id.
    const publishedSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'catalog_private', 'catalog_private') RETURNING id`,
      [PLATFORM_DB]
    );
    const publishedTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'functions') RETURNING id`,
      [PLATFORM_DB, publishedSchema.id]
    );

    for (const [dbId, schemaName, label] of [
      [DB_A, 'catalog_private', 'a'],
      [DB_B, 'catalog_private', 'b'],
      [LEGACY_DB, 'fn_legacy_catalog_private', 'legacy'],
    ] as const) {
      let schemaId = publishedSchema.id;
      let tableId = publishedTable.id;
      if (schemaName !== 'catalog_private') {
        const schema = await pg.one(
          `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
           VALUES ($1, $2, $2) RETURNING id`,
          [dbId, schemaName]
        );
        const table = await pg.one(
          `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
           VALUES ($1, $2, 'functions') RETURNING id`,
          [dbId, schema.id]
        );
        schemaId = schema.id;
        tableId = table.id;
      }
      await pg.query(
        `INSERT INTO metaschema_modules_public.catalog_module
           (database_id, schema_id, functions_table_id,
            domains_table_id, apis_table_id, sites_table_id, namespaces_table_id,
            resources_table_id, resource_definitions_table_id,
            resource_installations_table_id, apps_table_id, buckets_table_id,
            sites_web_config_table_id, sites_error_pages_table_id,
            sites_app_links_table_id, sites_deep_links_table_id,
            redirects_table_id, bindings_table_id, images_table_id, scope)
         VALUES ($1, $2, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, $3, 'app')`,
        [dbId, schemaId, tableId]
      );

      // Each database also hosts a function module, so a catalog miss would
      // fail loud rather than being silently skipped.
      const defsSchema = await pg.one(
        `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
         VALUES ($1, $2, $2) RETURNING id`,
        [dbId, `defs_${label}`]
      );
      await pg.query(`CREATE SCHEMA defs_${label}`);
      await pg.query(
        `CREATE TABLE defs_${label}.app_function_definitions (
           id uuid PRIMARY KEY,
           task_identifier text NOT NULL,
           queue_name text,
           priority integer,
           max_attempts integer
         )`
      );
      const defsTable = await pg.one(
        `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
         VALUES ($1, $2, 'app_function_definitions') RETURNING id`,
        [dbId, defsSchema.id]
      );
      await pg.query(
        `INSERT INTO metaschema_modules_public.function_module
           (database_id, scope, entity_field, schema_id, private_schema_id,
            definitions_table_id, bindings_table_id)
         VALUES ($1, 'app', NULL, $2, $2, $3, $3)`,
        [dbId, defsSchema.id, defsTable.id]
      );
    }
  });

  afterAll(async () => {
    await teardown();
  });

  it('resolve(): answers from the shared plane', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope, owner_database_id
       FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
      [DB_A]
    );
    expect(row).toEqual({
      function_definition_id: ids.appA,
      resolved_scope: 'app',
      owner_database_id: DB_A,
    });
  });

  it('resolve(): a database never sees another database rows', async () => {
    const [rowB] = await pg.any(
      `SELECT function_definition_id, owner_database_id
       FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
      [DB_B]
    );
    expect(rowB).toEqual({
      function_definition_id: ids.appB,
      owner_database_id: DB_B,
    });

    // LEGACY_DB has an identical row in its own hash-named plane, which is now
    // read by nothing: only catalog_private answers, and it holds no row for
    // that database.
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
        [LEGACY_DB]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);
  });

  it('resolve(): a task present only in another database is not found', async () => {
    await pg.query(
      `INSERT INTO catalog_private.functions
         (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
       VALUES ($1, 'app', NULL, true, $2, 'b:only')`,
      ['bbbbbbbb-0000-0000-0000-000000000002', DB_B]
    );
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'b:only', true)`,
        [DB_A]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);
  });

  it('resolve(): database-scope rows key by their own database', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'database', $1, 'report:run', true)`,
      [DB_A]
    );
    expect(row).toEqual({
      function_definition_id: ids.dbScopedA,
      resolved_scope: 'database',
    });

    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'database', $1, 'report:run', true)`,
        [DB_B]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);
  });

  it('resolve_invocation(): validates a pair against the owning database only', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, definition_scope
       FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app', NULL)`,
      [DB_A, ids.appA]
    );
    expect(row).toEqual({ function_definition_id: ids.appA, definition_scope: 'app' });

    // DB_B's definition carries the same scope/key/task; validating it against
    // DB_A must fail rather than pass on the shared relation.
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app', NULL)`,
        [DB_A, ids.appB]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_INVALID_PAIR/);
  });

  it('routing(): reads queue behaviour from the same catalog row', async () => {
    const [row] = await pg.any(
      `SELECT queue_name, priority, max_attempts
       FROM function_resolution.routing($1, $2)`,
      [DB_A, ids.appA]
    );
    expect(row).toEqual({ queue_name: 'email', priority: 5, max_attempts: 3 });
  });

  it('routing(): another database definition id yields no row', async () => {
    const rows = await pg.any(
      `SELECT * FROM function_resolution.routing($1, $2)`,
      [DB_A, ids.appB]
    );
    expect(rows).toEqual([]);
  });

  it('routing(): an all-null routing row falls back to queue defaults', async () => {
    const rows = await pg.any(
      `SELECT * FROM function_resolution.routing($1, $2)`,
      [DB_A, ids.dbScopedA]
    );
    expect(rows).toEqual([]);
  });

  it('routing(): a definition outside the published plane yields no row', async () => {
    // The row is in LEGACY_DB's own plane, which routing does not read: queue
    // defaults apply rather than a value from an unpublished plane.
    const rows = await pg.any(
      `SELECT * FROM function_resolution.routing($1, $2)`,
      [LEGACY_DB, ids.legacy]
    );
    expect(rows).toEqual([]);
  });

  it('resolve(): the plane is authoritative — removing the row stops resolution', async () => {
    await pg.query(`DELETE FROM catalog_private.functions WHERE id = $1`, [ids.appA]);
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
        [DB_A]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);

    await pg.query(
      `INSERT INTO catalog_private.functions
         (id, owner_scope, owner_key, is_visible, database_id, task_identifier,
          queue_name, priority, max_attempts)
       VALUES ($1, 'app', NULL, true, $2, 'email:send', 'email', 5, 3)`,
      [ids.appA, DB_A]
    );
  });

  it('EXPLAIN: the static probe uses the database-qualified unique index', async () => {
    const rows = await pg.any(
      `EXPLAIN (FORMAT text)
       SELECT hit.id
       FROM unnest($1::text[], $2::uuid[], $3::uuid[], $4::bigint[])
           AS cand(owner_scope, owner_key, lookup_database_id, ord)
       CROSS JOIN LATERAL (
           SELECT c.id FROM catalog_private.functions c
           WHERE c.task_identifier = $5
             AND c.owner_scope = cand.owner_scope
             AND c.owner_key = cand.owner_key
             AND cand.owner_key IS NOT NULL
             AND c.database_id = CASE
                   WHEN cand.owner_scope = 'database' THEN cand.owner_key
                   ELSE cand.lookup_database_id
                 END
           UNION ALL
           SELECT c.id FROM catalog_private.functions c
           WHERE c.task_identifier = $5
             AND c.owner_scope = cand.owner_scope
             AND c.owner_key IS NULL
             AND cand.owner_key IS NULL
             AND c.database_id = cand.lookup_database_id
       ) hit
       ORDER BY cand.ord
       LIMIT 1`,
      [['app'], [null], [DB_A], ['1'], 'email:send']
    );
    const plan = rows.map((r: Record<string, string>) => Object.values(r)[0]).join('\n');
    expect(plan).toMatch(/functions_db_owner_scope_task_idx/);
  });
});
