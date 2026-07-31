import { getConnections, PgTestClient } from 'constructive-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const ORG_ID = '33333333-3333-3333-3333-333333333333';
const PLATFORM_ORG_ID = '44444444-4444-4444-4444-444444444444';
// A database that hosts function modules but has NO functions catalog.
const BARE_DB = '55555555-5555-5555-5555-555555555555';

const ids: Record<string, string> = {};

// Catalog resolution proof: resolve answers from ONE typed catalog table per
// frame database (partial-unique-index probes), ordered by app_scope.frames;
// a frame database hosting function modules without a catalog fails loud.
describe('function-resolution catalog fast-path', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false), ($3, 'bare_db', false)`,
      [PLATFORM_DB, TENANT_DB, BARE_DB]
    );
    await pg.query(
      `UPDATE metaschema_public.database SET owner_id = $2 WHERE id = $1`,
      [TENANT_DB, ORG_ID]
    );
    await pg.query(
      `UPDATE metaschema_public.database SET owner_id = $2 WHERE id = $1`,
      [PLATFORM_DB, PLATFORM_ORG_ID]
    );

    // --- Scoped source plane: app-scope + database-scope definitions --------
    await pg.query(`CREATE SCHEMA app_defs`);
    await pg.query(
      `CREATE TABLE app_defs.app_function_definitions (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         task_identifier text NOT NULL,
         is_published boolean NOT NULL DEFAULT false,
         queue_name text,
         priority integer,
         max_attempts integer
       )`
    );
    await pg.query(`CREATE SCHEMA db_defs`);
    await pg.query(
      `CREATE TABLE db_defs.db_function_definitions (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         task_identifier text NOT NULL,
         database_id uuid,
         is_published boolean NOT NULL DEFAULT false,
         queue_name text,
         priority integer,
         max_attempts integer
       )`
    );

    // --- Catalog projection: one typed functions table, both scopes ---------
    await pg.query(`CREATE SCHEMA cat_defs`);
    await pg.query(
      `CREATE TABLE cat_defs.functions (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         task_identifier text NOT NULL
       )`
    );
    await pg.query(
      `CREATE UNIQUE INDEX functions_owner_scope_owner_key_task_identifier_idx
       ON cat_defs.functions (owner_scope, owner_key, task_identifier)
       WHERE owner_key IS NOT NULL`
    );
    await pg.query(
      `CREATE UNIQUE INDEX functions_owner_scope_task_identifier_idx
       ON cat_defs.functions (owner_scope, task_identifier)
       WHERE owner_key IS NULL`
    );
    // Same-txn sync stand-in for the generated catalog_register triggers.
    await pg.query(
      `CREATE FUNCTION cat_defs.tg_app_sync() RETURNS trigger AS $$
       BEGIN
         INSERT INTO cat_defs.functions (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
         VALUES (NEW.id, 'app', NULL, COALESCE(NEW.is_published, false), '${TENANT_DB}', NEW.task_identifier)
         ON CONFLICT (id) DO UPDATE SET
           owner_key = EXCLUDED.owner_key,
           is_visible = EXCLUDED.is_visible,
           database_id = EXCLUDED.database_id,
           task_identifier = EXCLUDED.task_identifier;
         RETURN NEW;
       END $$ LANGUAGE plpgsql`
    );
    await pg.query(
      `CREATE TRIGGER catalog_sync AFTER INSERT OR UPDATE ON app_defs.app_function_definitions
       FOR EACH ROW EXECUTE FUNCTION cat_defs.tg_app_sync()`
    );
    await pg.query(
      `CREATE FUNCTION cat_defs.tg_db_sync() RETURNS trigger AS $$
       BEGIN
         INSERT INTO cat_defs.functions (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
         VALUES (NEW.id, 'database', NEW.database_id, COALESCE(NEW.is_published, false),
                 COALESCE(NEW.database_id, '${TENANT_DB}'), NEW.task_identifier)
         ON CONFLICT (id) DO UPDATE SET
           owner_key = EXCLUDED.owner_key,
           is_visible = EXCLUDED.is_visible,
           database_id = EXCLUDED.database_id,
           task_identifier = EXCLUDED.task_identifier;
         RETURN NEW;
       END $$ LANGUAGE plpgsql`
    );
    await pg.query(
      `CREATE TRIGGER catalog_sync AFTER INSERT OR UPDATE ON db_defs.db_function_definitions
       FOR EACH ROW EXECUTE FUNCTION cat_defs.tg_db_sync()`
    );

    // --- Definitions (sync triggers project them into the catalog) ----------
    const appDef = await pg.one(
      `INSERT INTO app_defs.app_function_definitions (task_identifier, queue_name, priority, max_attempts)
       VALUES ('email:send', 'emails', 5, 3) RETURNING id`
    );
    ids.appDef = appDef.id;
    const dbExact = await pg.one(
      `INSERT INTO db_defs.db_function_definitions (task_identifier, database_id, queue_name, priority, max_attempts)
       VALUES ('report:run', $1, 'reports', 9, 10) RETURNING id`,
      [TENANT_DB]
    );
    ids.dbExact = dbExact.id;
    const dbDefault = await pg.one(
      `INSERT INTO db_defs.db_function_definitions (task_identifier, database_id, queue_name, priority, max_attempts)
       VALUES ('report:run', NULL, 'reports_default', 1, 2) RETURNING id`
    );
    ids.dbDefault = dbDefault.id;
    // A definition shadowed at database scope AND present at app scope, to
    // prove precedence agrees between the two paths.
    const appShadowed = await pg.one(
      `INSERT INTO app_defs.app_function_definitions (task_identifier)
       VALUES ('report:run') RETURNING id`
    );
    ids.appShadowed = appShadowed.id;

    // --- Metaschema wiring ---------------------------------------------------
    const appSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'app_defs', 'app_defs') RETURNING id`,
      [TENANT_DB]
    );
    const appTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'app_function_definitions') RETURNING id`,
      [TENANT_DB, appSchema.id]
    );
    const dbSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'db_defs', 'db_defs') RETURNING id`,
      [TENANT_DB]
    );
    const dbTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'db_function_definitions') RETURNING id`,
      [TENANT_DB, dbSchema.id]
    );
    const catSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'cat_defs', 'cat_defs') RETURNING id`,
      [TENANT_DB]
    );
    const catTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'functions') RETURNING id`,
      [TENANT_DB, catSchema.id]
    );
    ids.catTable = catTable.id;

    await pg.query(
      `INSERT INTO metaschema_modules_public.function_module
         (database_id, scope, entity_field, schema_id, private_schema_id,
          definitions_table_id, bindings_table_id)
       VALUES ($1, 'app', NULL, $2, $2, $3, $3)`,
      [TENANT_DB, appSchema.id, appTable.id]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.function_module
         (database_id, scope, entity_field, schema_id, private_schema_id,
          definitions_table_id, bindings_table_id)
       VALUES ($1, 'database', 'database_id', $2, $2, $3, $3)`,
      [TENANT_DB, dbSchema.id, dbTable.id]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.catalog_module
         (database_id, schema_id, functions_table_id,
          domains_table_id, apis_table_id, sites_table_id, namespaces_table_id,
          resources_table_id, resource_definitions_table_id,
          resource_installations_table_id, apps_table_id, scope)
       VALUES ($1, $2, $3, $3, $3, $3, $3, $3, $3, $3, $3, 'app')`,
      [TENANT_DB, catSchema.id, catTable.id]
    );

    // --- Bare database: function module, NO catalog --------------------------
    await pg.query(`CREATE SCHEMA bare_defs`);
    await pg.query(
      `CREATE TABLE bare_defs.app_function_definitions (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         task_identifier text NOT NULL
       )`
    );
    const bareSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'bare_defs', 'bare_defs') RETURNING id`,
      [BARE_DB]
    );
    const bareTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'app_function_definitions') RETURNING id`,
      [BARE_DB, bareSchema.id]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.function_module
         (database_id, scope, entity_field, schema_id, private_schema_id,
          definitions_table_id, bindings_table_id)
       VALUES ($1, 'app', NULL, $2, $2, $3, $3)`,
      [BARE_DB, bareSchema.id, bareTable.id]
    );
  });

  afterAll(async () => {
    await teardown();
  });


  it('catalog_location(): resolves the functions catalog table', async () => {
    const [row] = await pg.any(
      `SELECT schema_name, table_name FROM function_resolution.catalog_location($1)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ schema_name: 'cat_defs', table_name: 'functions' });
  });

  it('catalog_location(): no catalog -> no rows', async () => {
    const rows = await pg.any(
      `SELECT * FROM function_resolution.catalog_location($1)`,
      [BARE_DB]
    );
    expect(rows).toEqual([]);
  });

  it('resolve(): app-scope hit with owner database', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope, owner_database_id
       FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({
      function_definition_id: ids.appDef,
      resolved_scope: 'app',
      owner_database_id: TENANT_DB,
    });
  });

  it('resolve(): exact database-scope hit shadows app scope', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'database', $1, 'report:run', true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ function_definition_id: ids.dbExact, resolved_scope: 'database' });
  });

  it('resolve(): unpublished (is_visible false) rows still resolve', async () => {
    const [{ is_visible }] = await pg.any(
      `SELECT is_visible FROM cat_defs.functions WHERE id = $1`,
      [ids.appDef]
    );
    expect(is_visible).toBe(false);
  });

  it('resolve(): missing task raises when required', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'does:not-exist', true)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);
  });

  it('resolve(): missing task returns no rows when not required', async () => {
    const rows = await pg.any(
      `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'does:not-exist', false)`,
      [TENANT_DB]
    );
    expect(rows).toEqual([]);
  });

  it('resolve(): function modules without a catalog fail loud', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'email:send', false)`,
        [BARE_DB]
      )
    ).rejects.toThrow(/FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE/);
  });

  it('resolve(): scope-default row answers when no exact scope-key row exists', async () => {
    await pg.query(`DELETE FROM cat_defs.functions WHERE id = $1`, [ids.dbExact]);
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'database', NULL, 'report:run', true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ function_definition_id: ids.dbDefault, resolved_scope: 'database' });
    await pg.query(
      `INSERT INTO cat_defs.functions (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
       VALUES ($1, 'database', $2, false, $2, 'report:run')`,
      [ids.dbExact, TENANT_DB]
    );
  });

  it('resolve(): the catalog is authoritative — a removed catalog row no longer resolves', async () => {
    await pg.query(`ALTER TABLE app_defs.app_function_definitions DISABLE TRIGGER catalog_sync`);
    await pg.query(`DELETE FROM cat_defs.functions WHERE id = $1`, [ids.appDef]);

    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);

    // Restore.
    await pg.query(
      `INSERT INTO cat_defs.functions (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
       VALUES ($1, 'app', NULL, false, $2, 'email:send')`,
      [ids.appDef, TENANT_DB]
    );
    await pg.query(`ALTER TABLE app_defs.app_function_definitions ENABLE TRIGGER catalog_sync`);
    const [row] = await pg.any(
      `SELECT function_definition_id FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
      [TENANT_DB]
    );
    expect(row.function_definition_id).toBe(ids.appDef);
  });

  it('resolve_invocation(): explicit pair validates via the catalog', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, definition_scope
       FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app', NULL)`,
      [TENANT_DB, ids.appDef]
    );
    expect(row).toEqual({ function_definition_id: ids.appDef, definition_scope: 'app' });

    // A pair that does not resolve to the declared scope's catalog row fails.
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app', NULL)`,
        [TENANT_DB, ids.dbExact]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_INVALID_PAIR/);
  });

  it('resolve_invocation(): a removed catalog row invalidates the pair', async () => {
    await pg.query(`ALTER TABLE app_defs.app_function_definitions DISABLE TRIGGER catalog_sync`);
    await pg.query(`DELETE FROM cat_defs.functions WHERE id = $1`, [ids.appDef]);

    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app', NULL)`,
        [TENANT_DB, ids.appDef]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_INVALID_PAIR/);

    await pg.query(
      `INSERT INTO cat_defs.functions (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
       VALUES ($1, 'app', NULL, false, $2, 'email:send')`,
      [ids.appDef, TENANT_DB]
    );
    await pg.query(`ALTER TABLE app_defs.app_function_definitions ENABLE TRIGGER catalog_sync`);
    const [row] = await pg.any(
      `SELECT function_definition_id
       FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app', NULL)`,
      [TENANT_DB, ids.appDef]
    );
    expect(row.function_definition_id).toBe(ids.appDef);
  });

  it('resolve_invocation(): pair validation fails loud without a catalog', async () => {
    const bare = await pg.one(
      `INSERT INTO bare_defs.app_function_definitions (task_identifier)
       VALUES ('bare:task') RETURNING id`
    );
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_invocation($1, 'app', NULL, 'bare:task', $2, 'app', NULL)`,
        [BARE_DB, bare.id]
      )
    ).rejects.toThrow(/FUNCTION_RESOLUTION_CATALOG_UNAVAILABLE/);
  });

  it('EXPLAIN: catalog probe uses the partial unique indexes', async () => {
    const [{ schema_name, table_name }] = await pg.any(
      `SELECT schema_name, table_name FROM function_resolution.catalog_location($1)`,
      [TENANT_DB]
    );
    const rows = await pg.any(
      `EXPLAIN (FORMAT text)
       SELECT hit.id
       FROM unnest($1::text[], $2::uuid[], $3::bigint[]) AS cand(owner_scope, owner_key, ord)
       CROSS JOIN LATERAL (
           SELECT c.id FROM ${schema_name}.${table_name} c
           WHERE c.task_identifier = $4
             AND c.owner_scope = cand.owner_scope
             AND c.owner_key = cand.owner_key
             AND cand.owner_key IS NOT NULL
           UNION ALL
           SELECT c.id FROM ${schema_name}.${table_name} c
           WHERE c.task_identifier = $4
             AND c.owner_scope = cand.owner_scope
             AND c.owner_key IS NULL
             AND cand.owner_key IS NULL
       ) hit
       ORDER BY cand.ord
       LIMIT 1`,
      [['database', 'database', 'app'], [TENANT_DB, null, null], [1, 2, 3], 'report:run']
    );
    const plan = rows.map((r: any) => r['QUERY PLAN']).join('\n');
    expect(plan).toMatch(/functions_owner_scope_owner_key_task_identifier_idx/);
    expect(plan).toMatch(/functions_owner_scope_task_identifier_idx/);
    expect(plan).not.toMatch(/Seq Scan on cat_defs\.functions/);
  });
});
