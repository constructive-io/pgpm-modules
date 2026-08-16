import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const ORG_ID = '33333333-3333-3333-3333-333333333333';
const PLATFORM_ORG_ID = '44444444-4444-4444-4444-444444444444';

// Ids captured during seeding.
const ids: Record<string, string> = {};

// End-to-end functional proof: the ported closure resolves function
// definitions across the scope chain using ONLY format()/EXECUTE dynamic
// SELECTs (no AST/deparser) against real catalog rows + real definitions tables.
describe('function-resolution end-to-end (format-based, no AST)', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    // --- Catalog: platform + tenant databases -------------------------------
    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false)`,
      [PLATFORM_DB, TENANT_DB]
    );
    // Tenant is owned by an org (drives the 'org' frame emission). The platform
    // database is likewise a real database owned by an org, so it contributes
    // its own database -> org -> app frames before the terminal platform frame.
    await pg.query(
      `UPDATE metaschema_public.database SET owner_id = $2 WHERE id = $1`,
      [TENANT_DB, ORG_ID]
    );
    await pg.query(
      `UPDATE metaschema_public.database SET owner_id = $2 WHERE id = $1`,
      [PLATFORM_DB, PLATFORM_ORG_ID]
    );

    // --- Physical app-scope definitions table (global: entity_field NULL) ----
    await pg.query(`CREATE SCHEMA app_defs`);
    await pg.query(
      `CREATE TABLE app_defs.app_function_definitions (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         task_identifier text NOT NULL,
         queue_name text,
         priority integer,
         max_attempts integer
       )`
    );
    const appDef = await pg.one(
      `INSERT INTO app_defs.app_function_definitions (task_identifier, queue_name, priority, max_attempts)
       VALUES ('email:send', 'emails', 5, 3) RETURNING id`
    );
    ids.appDef = appDef.id;

    // --- Physical database-scope definitions table (entity_field=database_id) -
    await pg.query(`CREATE SCHEMA db_defs`);
    await pg.query(
      `CREATE TABLE db_defs.db_function_definitions (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         task_identifier text NOT NULL,
         database_id uuid,
         queue_name text,
         priority integer,
         max_attempts integer
       )`
    );
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

    // --- Catalog schema/table rows describing those physical tables ---------
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

    // --- function_module rows (the resolver's routing catalog) --------------
    // app scope: global, entity_field NULL.
    await pg.query(
      `INSERT INTO metaschema_modules_public.function_module
         (database_id, scope, entity_field, schema_id, private_schema_id,
          definitions_table_id, bindings_table_id)
       VALUES ($1, 'app', NULL, $2, $2, $3, $3)`,
      [TENANT_DB, appSchema.id, appTable.id]
    );
    // database scope: keyed by database_id.
    await pg.query(
      `INSERT INTO metaschema_modules_public.function_module
         (database_id, scope, entity_field, schema_id, private_schema_id,
          definitions_table_id, bindings_table_id)
       VALUES ($1, 'database', 'database_id', $2, $2, $3, $3)`,
      [TENANT_DB, dbSchema.id, dbTable.id]
    );

    // --- Typed functions catalog (the resolver's read path) -----------------
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
    await pg.query(
      `INSERT INTO catalog_private.functions
         (id, owner_scope, owner_key, is_visible, database_id, task_identifier,
          queue_name, priority, max_attempts)
       VALUES ($1, 'app', NULL, false, $4, 'email:send', 'emails', 5, 3),
              ($2, 'database', $4, false, $4, 'report:run', 'reports', 9, 10),
              ($3, 'database', NULL, false, $4, 'report:run', 'reports_default', 1, 2)`,
      [ids.appDef, ids.dbExact, ids.dbDefault, TENANT_DB]
    );
    const catSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'catalog_private', 'catalog_private') RETURNING id`,
      [TENANT_DB]
    );
    const catTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'functions') RETURNING id`,
      [TENANT_DB, catSchema.id]
    );
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
      [TENANT_DB, catSchema.id, catTable.id]
    );
  });

  afterAll(async () => {
    await teardown();
  });

  it('platform_database_id() returns the platform db (strict)', async () => {
    const [{ platform_database_id }] = await pg.any(
      `SELECT app_scope.platform_database_id() AS platform_database_id`
    );
    expect(platform_database_id).toBe(PLATFORM_DB);
  });

  it('frames(): tenant database execution -> tenant db chain then platform db chain', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'database', NULL)`,
      [TENANT_DB]
    );
    expect(rows).toEqual([
      { scope: 'database', lookup_database_id: TENANT_DB, key_value: TENANT_DB },
      { scope: 'org', lookup_database_id: TENANT_DB, key_value: ORG_ID },
      { scope: 'app', lookup_database_id: TENANT_DB, key_value: null },
      { scope: 'database', lookup_database_id: PLATFORM_DB, key_value: TENANT_DB },
      { scope: 'org', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_ORG_ID },
      { scope: 'app', lookup_database_id: PLATFORM_DB, key_value: null },
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });

  it('frames(): app execution -> tenant app then platform db chain', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'app', NULL)`,
      [TENANT_DB]
    );
    expect(rows).toEqual([
      { scope: 'app', lookup_database_id: TENANT_DB, key_value: null },
      // the tenant's OWN database frame precedes the platform fall-through
      { scope: 'database', lookup_database_id: TENANT_DB, key_value: TENANT_DB },
      { scope: 'database', lookup_database_id: PLATFORM_DB, key_value: TENANT_DB },
      { scope: 'org', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_ORG_ID },
      { scope: 'app', lookup_database_id: PLATFORM_DB, key_value: null },
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });

  it('frames(): platform-database execution -> platform db chain (database, org, app, platform)', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'database', NULL)`,
      [PLATFORM_DB]
    );
    expect(rows).toEqual([
      { scope: 'database', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_DB },
      { scope: 'org', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_ORG_ID },
      { scope: 'app', lookup_database_id: PLATFORM_DB, key_value: null },
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });

  it('frames(): NULL scope is a hard error (no silent default)', async () => {
    await expect(
      pg.any(`SELECT * FROM app_scope.frames($1, NULL, NULL)`, [TENANT_DB])
    ).rejects.toThrow(/APP_SCOPE_FRAMES_SCOPE_REQUIRED/);
  });

  it('resolve(): falls back to the scope-default (owner_key IS NULL) row', async () => {
    // Without the exact-key catalog row, the same frame's scope-default
    // (owner_key IS NULL) row wins instead.
    await pg.query(`DELETE FROM catalog_private.functions WHERE id = $1`, [ids.dbExact]);
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'database', NULL, 'report:run', true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ function_definition_id: ids.dbDefault, resolved_scope: 'database' });
    await pg.query(
      `INSERT INTO catalog_private.functions
         (id, owner_scope, owner_key, is_visible, database_id, task_identifier,
          queue_name, priority, max_attempts)
       VALUES ($1, 'database', $2, false, $2, 'report:run', 'reports', 9, 10)`,
      [ids.dbExact, TENANT_DB]
    );
  });

  it('routing(): loads queue metadata from the resolved definition', async () => {
    const [row] = await pg.any(
      `SELECT queue_name, priority, max_attempts
       FROM function_resolution.routing($1, $2)`,
      [TENANT_DB, ids.appDef]
    );
    expect(row).toEqual({ queue_name: 'emails', priority: 5, max_attempts: 3 });
  });

  it('resolve(): cross-scope resolver returns the app-scope hit', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'app', NULL, 'email:send', true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ function_definition_id: ids.appDef, resolved_scope: 'app' });
  });

  it('resolve(): database-scope hit before app/platform', async () => {
    const [row] = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'database', $1, 'report:run', true)`,
      [TENANT_DB]
    );
    expect(row).toEqual({ function_definition_id: ids.dbExact, resolved_scope: 'database' });
  });

  it('resolve(): definition-less task raises when required', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve($1, 'app', NULL, 'does:not-exist', true)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_NOT_FOUND/);
  });

  it('resolve(): definition-less task returns no rows when not required', async () => {
    const rows = await pg.any(
      `SELECT function_definition_id, resolved_scope
       FROM function_resolution.resolve($1, 'app', NULL, 'does:not-exist', false)`,
      [TENANT_DB]
    );
    expect(rows).toEqual([]);
  });

  it('resolve_invocation(): definition-less task returns a single NULL row', async () => {
    const rows = await pg.any(
      `SELECT function_definition_id, definition_scope
       FROM function_resolution.resolve_invocation($1, 'app', NULL, 'does:not-exist')`,
      [TENANT_DB]
    );
    expect(rows).toEqual([{ function_definition_id: null, definition_scope: null }]);
  });

  it('resolve_invocation(): validates a supplied (id, scope) pair', async () => {
    const rows = await pg.any(
      `SELECT function_definition_id, definition_scope
       FROM function_resolution.resolve_invocation($1, 'app', NULL, 'email:send', $2, 'app')`,
      [TENANT_DB, ids.appDef]
    );
    expect(rows).toEqual([{ function_definition_id: ids.appDef, definition_scope: 'app' }]);
  });

  it('resolve_invocation(): rejects a mismatched (id, scope) pair', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_invocation($1, 'app', NULL, 'report:run', $2, 'app')`,
        [TENANT_DB, ids.appDef]
      )
    ).rejects.toThrow(/FUNCTION_DEFINITION_INVALID_PAIR/);
  });

  it('enqueue(): full portable path resolves, routes, and inserts a job', async () => {
    // enqueue reads the execution database from jwt_private.current_database_id()
    // (the jwt.claims.database_id GUC), set transaction-locally around the call.
    await pg.begin();
    await pg.query(`SELECT set_config('jwt.claims.database_id', $1, true)`, [TENANT_DB]);
    const job = await pg.one(
      `SELECT * FROM function_resolution.enqueue(
         task_identifier := 'email:send',
         scope := 'app'
       )`
    );
    await pg.commit();

    expect(job.function_definition_id).toBe(ids.appDef);
    expect(job.definition_scope).toBe('app');
    expect(job.queue_name).toBe('emails');
    expect(job.priority).toBe(5);
    expect(job.max_attempts).toBe(3);
    expect(job.database_id).toBe(TENANT_DB);
    expect(job.task_identifier).toBe('email:send');
  });

  it('enqueue(): NULL scope is a hard error', async () => {
    await pg.begin();
    await pg.query(`SELECT set_config('jwt.claims.database_id', $1, true)`, [TENANT_DB]);
    await expect(
      pg.one(`SELECT * FROM function_resolution.enqueue(task_identifier := 'email:send')`)
    ).rejects.toThrow(/ENQUEUE_SCOPE_REQUIRED/);
    await pg.query(`ROLLBACK`);
  });
});
