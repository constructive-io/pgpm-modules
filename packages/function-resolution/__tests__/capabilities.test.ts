import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

// Deterministic fixture ids.
const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const OTHER_DB = '33333333-3333-3333-3333-333333333333';
const ORG_ID = '44444444-4444-4444-4444-444444444444';

const ids: Record<string, string> = {};

// Capability resolution: a tenant-agnostic declaration plus a tenant's own
// labelled rows (or an explicit binding) produce exactly one answer per
// capability, or the invocation fails loudly before any code runs.
describe('function-resolution capability resolution', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false), ($3, 'other_db', false)`,
      [PLATFORM_DB, TENANT_DB, OTHER_DB]
    );
    await pg.query(
      `UPDATE metaschema_public.database SET owner_id = $2 WHERE id = $1`,
      [TENANT_DB, ORG_ID]
    );

    // --- Definitions + capability bindings (database scope) -----------------
    await pg.query(`CREATE SCHEMA cap_defs`);
    await pg.query(
      `CREATE TABLE cap_defs.function_definitions (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         database_id uuid,
         task_identifier text NOT NULL,
         access_channels text[] NOT NULL DEFAULT '{}',
         required_buckets text[] NOT NULL DEFAULT '{}',
         required_modules text[] NOT NULL DEFAULT '{}',
         required_models text[] NOT NULL DEFAULT '{}',
         integrations text[] NOT NULL DEFAULT '{}'
       )`
    );
    await pg.query(
      `CREATE TABLE cap_defs.function_capability_bindings (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         database_id uuid,
         function_id uuid,
         graph_id uuid,
         bucket_id uuid,
         key text NOT NULL,
         lifecycle text NOT NULL DEFAULT 'execution'
       )`
    );

    // --- Typed catalog: functions + buckets + apis --------------------------
    await pg.query(`CREATE SCHEMA catalog_private`);
    await pg.query(
      `CREATE TABLE catalog_private.functions (
         id uuid PRIMARY KEY,
         owner_scope text NOT NULL,
         owner_key uuid,
         is_visible boolean NOT NULL DEFAULT false,
         database_id uuid NOT NULL,
         task_identifier text NOT NULL
       )`
    );
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
    // The bindings kind of the same plane. Its lifecycle values order a tie
    // within one frame; they are not scopes.
    await pg.query(
      `CREATE TABLE catalog_private.bindings (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         owner_scope text NOT NULL,
         owner_key uuid,
         database_id uuid NOT NULL,
         function_id uuid,
         graph_id uuid,
         bucket_id uuid,
         key text NOT NULL,
         lifecycle text NOT NULL DEFAULT 'execution'
       )`
    );

    // --- Api surface source plane (what module selectors resolve through) ---
    await pg.query(`CREATE SCHEMA api_src`);
    await pg.query(
      `CREATE TABLE api_src.apis (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         database_id uuid,
         name text NOT NULL
       )`
    );
    await pg.query(
      `CREATE TABLE api_src.api_schemas (
         id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
         database_id uuid,
         api_id uuid NOT NULL,
         schema_id uuid NOT NULL
       )`
    );

    // A payload table reference target.
    await pg.query(`CREATE SCHEMA docs`);
    await pg.query(`CREATE TABLE docs.documents (id uuid PRIMARY KEY)`);

    // --- Metaschema wiring --------------------------------------------------
    const schemaIds = new Map<string, string>();
    const reg = async (schemaName: string, tableName: string, database = TENANT_DB) => {
      if (!schemaIds.has(schemaName)) {
        const schema = await pg.one(
          `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
           VALUES ($1, $2, $2) RETURNING id`,
          [database, schemaName]
        );
        schemaIds.set(schemaName, schema.id);
      }
      const schemaId = schemaIds.get(schemaName)!;
      const table = await pg.one(
        `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
         VALUES ($1, $2, $3) RETURNING id`,
        [database, schemaId, tableName]
      );
      return { schemaId, tableId: table.id };
    };

    const defs = await reg('cap_defs', 'function_definitions');
    const bindings = await reg('cap_defs', 'function_capability_bindings');
    const catFunctions = await reg('catalog_private', 'functions');
    const catBuckets = await reg('catalog_private', 'buckets');
    const catApis = await reg('catalog_private', 'apis');
    const catBindings = await reg('catalog_private', 'bindings');
    const srcApis = await reg('api_src', 'apis');
    const srcApiSchemas = await reg('api_src', 'api_schemas');
    const docs = await reg('docs', 'documents');

    ids.docsTable = docs.tableId;
    ids.notifSchema = docs.schemaId;

    await pg.query(
      `INSERT INTO metaschema_modules_public.function_module
         (database_id, scope, entity_field, schema_id, private_schema_id,
          definitions_table_id, bindings_table_id, capability_bindings_table_id)
       VALUES ($1, 'database', 'database_id', $2, $2, $3, $3, $4)`,
      [TENANT_DB, defs.schemaId, defs.tableId, bindings.tableId]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.catalog_module
         (database_id, schema_id, functions_table_id,
          domains_table_id, apis_table_id, sites_table_id, namespaces_table_id,
          resources_table_id, resource_definitions_table_id,
          resource_installations_table_id, apps_table_id, buckets_table_id,
          sites_web_config_table_id, sites_error_pages_table_id,
          sites_app_links_table_id, sites_deep_links_table_id,
          bindings_table_id, scope)
       VALUES ($1, $2, $3, $3, $4, $3, $3, $3, $3, $3, $3, $5, $3, $3, $3, $3, $6, 'database')`,
      [
        TENANT_DB,
        catFunctions.schemaId,
        catFunctions.tableId,
        catApis.tableId,
        catBuckets.tableId,
        catBindings.tableId,
      ]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.api_surface_module
         (database_id, scope, schema_id, apis_table_id, api_schemas_table_id,
          api_settings_table_id, cors_settings_table_id)
       VALUES ($1, 'database', $2, $3, $4, $4, $4)`,
      [TENANT_DB, srcApis.schemaId, srcApis.tableId, srcApiSchemas.tableId]
    );

    // --- Buckets: tenant-owned, tagged --------------------------------------
    const bucket = async (
      key: string,
      type: string,
      tags: string[],
      database = TENANT_DB,
      isVisible = false
    ) => {
      const row = await pg.one(
        `INSERT INTO catalog_private.buckets (id, owner_scope, owner_key, is_visible, database_id, key, type, physical_name, tags)
         VALUES (gen_random_uuid(), 'database', $1, $2, $1, $3, $4, $5, $6) RETURNING id`,
        [database, isVisible, key, type, `phys-${key}`, tags]
      );
      return row.id;
    };

    ids.exports = await bucket('exports', 'private', ['exports']);
    ids.publicVariants = await bucket('variants-public', 'public', ['variants']);
    ids.privateVariants = await bucket('variants-private', 'private', ['variants']);
    ids.foreign = await bucket('foreign', 'private', ['exports'], OTHER_DB);

    // --- Apis: catalog rows + source rows + a module attachment -------------
    const adminApi = await pg.one(
      `INSERT INTO api_src.apis (database_id, name) VALUES ($1, 'admin') RETURNING id`,
      [TENANT_DB]
    );
    ids.adminApi = adminApi.id;
    await pg.query(
      `INSERT INTO catalog_private.apis (id, owner_scope, owner_key, is_visible, database_id, name)
       VALUES ($1, 'database', $2, false, $2, 'admin')`,
      [ids.adminApi, TENANT_DB]
    );
    // notifications_module carries an api_name and a schema_id (and no scope
    // column), so it stands in for any module whose schemas are attached to a
    // surface — and proves the selector does not require a scoped registration.
    const notifRefs = await pg.any(
      `SELECT column_name
       FROM information_schema.columns
       WHERE table_schema = 'metaschema_modules_public'
         AND table_name = 'notifications_module'
         AND (column_name LIKE '%_table_id' OR column_name LIKE '%schema_id')`
    );
    const notifColumns = ['database_id', 'api_name'].concat(
      notifRefs.map((c: any) => c.column_name)
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.notifications_module (${notifColumns.join(', ')})
       VALUES (${notifColumns.map((_, i) => `$${i + 1}`).join(', ')})`,
      [TENANT_DB, 'admin'].concat(
        notifRefs.map((c: any) =>
          c.column_name.endsWith('_table_id') ? ids.docsTable : ids.notifSchema
        )
      )
    );
    await pg.query(
      `INSERT INTO api_src.api_schemas (database_id, api_id, schema_id)
       VALUES ($1, $2, $3)`,
      [TENANT_DB, ids.adminApi, ids.notifSchema]
    );

    // --- Definitions --------------------------------------------------------
    const exporter = await pg.one(
      `INSERT INTO cap_defs.function_definitions
         (database_id, task_identifier, access_channels, required_buckets, required_modules, required_models)
       VALUES ($1, 'report:export', ARRAY['api'], ARRAY['exports'], ARRAY['notifications_module'], ARRAY['gpt-4o'])
       RETURNING id`,
      [TENANT_DB]
    );
    ids.exporter = exporter.id;
    const ambiguous = await pg.one(
      `INSERT INTO cap_defs.function_definitions
         (database_id, task_identifier, required_buckets)
       VALUES ($1, 'image:variants', ARRAY['variants']) RETURNING id`,
      [TENANT_DB]
    );
    ids.ambiguous = ambiguous.id;

    for (const id of [ids.exporter, ids.ambiguous]) {
      await pg.query(
        `INSERT INTO catalog_private.functions (id, owner_scope, owner_key, is_visible, database_id, task_identifier)
         SELECT d.id, 'database', d.database_id, false, d.database_id, d.task_identifier
         FROM cap_defs.function_definitions d WHERE d.id = $1`,
        [id]
      );
    }
  });

  afterAll(async () => {
    await teardown();
  });

  it('resolve_bucket(): one tag match resolves to coordinates', async () => {
    const [row] = await pg.any(
      `SELECT bucket_id, bucket_key, bucket_type, physical_name, owner_database_id
       FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['exports'], NULL)`,
      [TENANT_DB]
    );
    expect(row).toEqual({
      bucket_id: ids.exports,
      bucket_key: 'exports',
      bucket_type: 'private',
      physical_name: 'phys-exports',
      owner_database_id: TENANT_DB,
    });
  });

  it('resolve_bucket(): type narrows an otherwise ambiguous tag', async () => {
    const [priv] = await pg.any(
      `SELECT bucket_id FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['variants'], 'private')`,
      [TENANT_DB]
    );
    expect(priv.bucket_id).toBe(ids.privateVariants);

    const [pub] = await pg.any(
      `SELECT bucket_id FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['variants'], 'public')`,
      [TENANT_DB]
    );
    expect(pub.bucket_id).toBe(ids.publicVariants);
  });

  it('resolve_bucket(): zero and several matches both fail loudly', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['nope'], NULL)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_NOT_FOUND/);

    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['variants'], NULL)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_AMBIGUOUS/);

    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY[]::text[], NULL)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_SELECTOR_EMPTY/);
  });

  it('resolve_bucket(): another tenant\'s bucket is not a candidate', async () => {
    // The foreign bucket carries the exports tag too, and stays invisible.
    const [row] = await pg.any(
      `SELECT bucket_id FROM function_resolution.resolve_bucket($1, 'database', $1, ARRAY['exports'], NULL)`,
      [TENANT_DB]
    );
    expect(row.bucket_id).toBe(ids.exports);
    expect(row.bucket_id).not.toBe(ids.foreign);
  });

  it('resolve_api(): by module name, and by api name as the escape hatch', async () => {
    // A plain word that is not a module name is read as an api name.
    const [byName] = await pg.any(
      `SELECT api_id, api_name FROM function_resolution.resolve_api($1, 'database', $1, 'admin')`,
      [TENANT_DB]
    );
    expect(byName).toEqual({ api_id: ids.adminApi, api_name: 'admin' });

    // A module selector resolves through the api_schemas attachment — so it
    // survives a rename of the api the module named at registration time.
    await pg.query(`UPDATE api_src.apis SET name = 'admin_renamed' WHERE id = $1`, [ids.adminApi]);
    await pg.query(`UPDATE catalog_private.apis SET name = 'admin_renamed' WHERE id = $1`, [ids.adminApi]);

    const [byModule] = await pg.any(
      `SELECT api_id, api_name FROM function_resolution.resolve_api($1, 'database', $1, 'notifications_module')`,
      [TENANT_DB]
    );
    expect(byModule).toEqual({ api_id: ids.adminApi, api_name: 'admin_renamed' });

    // .<api> names the surface outright, and follows the rename.
    const [byModuleApi] = await pg.any(
      `SELECT api_id FROM function_resolution.resolve_api($1, 'database', $1, 'notifications_module.admin_renamed')`,
      [TENANT_DB]
    );
    expect(byModuleApi.api_id).toBe(ids.adminApi);

    // ...while the bare api name now misses, which is the point of the pair.
    await expect(
      pg.any(`SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'admin')`, [
        TENANT_DB,
      ])
    ).rejects.toThrow(/CAPABILITY_API_NOT_FOUND/);

    await pg.query(`UPDATE api_src.apis SET name = 'admin' WHERE id = $1`, [ids.adminApi]);
    await pg.query(`UPDATE catalog_private.apis SET name = 'admin' WHERE id = $1`, [ids.adminApi]);
  });

  it('resolve_api(): a module selector naming an api the module has not attached fails', async () => {
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'notifications_module.nope')`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/CAPABILITY_API_NOT_FOUND/);
  });

  it('resolve_api(): unknown module, qualified api name, and empty selector fail loudly', async () => {
    await expect(
      pg.any(`SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'nope_module')`, [
        TENANT_DB,
      ])
    ).rejects.toThrow(/CAPABILITY_API_MODULE_UNKNOWN/);

    // notifications_module has no scope column, so pinning a scope is a
    // selector error rather than a silent miss.
    await expect(
      pg.any(
        `SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'notifications_module@org')`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/CAPABILITY_API_SELECTOR_INVALID/);

    // Suffixes belong to module selectors only.
    await expect(
      pg.any(`SELECT * FROM function_resolution.resolve_api($1, 'database', $1, 'admin@org')`, [
        TENANT_DB,
      ])
    ).rejects.toThrow(/CAPABILITY_API_SELECTOR_INVALID/);

    await expect(
      pg.any(`SELECT * FROM function_resolution.resolve_api($1, 'database', $1, '')`, [TENANT_DB])
    ).rejects.toThrow(/CAPABILITY_API_SELECTOR_EMPTY/);
  });

  it('resolve_payload_refs(): rewrites tagged refs anywhere in the payload', async () => {
    const [{ resolved }] = await pg.any(
      `SELECT function_resolution.resolve_payload_refs($1, 'database', $1, $2::jsonb) AS resolved`,
      [
        TENANT_DB,
        JSON.stringify({
          plain: 'left alone',
          nested: {
            source: { $ref: 'bucket', tags: ['variants'], type: 'private' },
            list: [{ $ref: 'table', schema: 'docs', name: 'documents' }],
          },
          surface: { $ref: 'api', module: 'notifications_module' },
        }),
      ]
    );

    expect(resolved.plain).toBe('left alone');
    expect(resolved.nested.source).toEqual({
      $ref: 'bucket',
      bucket_id: ids.privateVariants,
      key: 'variants-private',
      type: 'private',
      physical_name: 'phys-variants-private',
      database_id: TENANT_DB,
    });
    expect(resolved.nested.list[0]).toEqual({
      $ref: 'table',
      schema: 'docs',
      name: 'documents',
      table_id: ids.docsTable,
    });
    expect(resolved.surface.api_id).toBe(ids.adminApi);
  });

  it('resolve_payload_refs(): an already-resolved payload is unchanged', async () => {
    const once = await pg.one(
      `SELECT function_resolution.resolve_payload_refs($1, 'database', $1, $2::jsonb) AS resolved`,
      [TENANT_DB, JSON.stringify({ b: { $ref: 'bucket', tags: ['exports'] } })]
    );
    const twice = await pg.one(
      `SELECT function_resolution.resolve_payload_refs($1, 'database', $1, $2::jsonb) AS resolved`,
      [TENANT_DB, JSON.stringify(once.resolved)]
    );
    expect(twice.resolved).toEqual(once.resolved);
  });

  it("resolve_payload_refs(): $ref: 'secret' is not a ref kind, and bad table refs raise", async () => {
    // A resolved reference becomes part of the payload the handler receives, so
    // there is deliberately no secret kind — `ctx.secrets` fetches at
    // invocation time instead. This asserts the rejection, not a lookup.
    await expect(
      pg.any(
        `SELECT function_resolution.resolve_payload_refs($1, 'database', $1, $2::jsonb)`,
        [TENANT_DB, JSON.stringify({ x: { $ref: 'secret', name: 'MAILGUN_API_KEY' } })]
      )
    ).rejects.toThrow(/CAPABILITY_REF_UNKNOWN/);

    await expect(
      pg.any(
        `SELECT function_resolution.resolve_payload_refs($1, 'database', $1, $2::jsonb)`,
        [TENANT_DB, JSON.stringify({ x: { $ref: 'table', schema: 'docs' } })]
      )
    ).rejects.toThrow(/CAPABILITY_TABLE_REF_INVALID/);

    await expect(
      pg.any(
        `SELECT function_resolution.resolve_payload_refs($1, 'database', $1, $2::jsonb)`,
        [TENANT_DB, JSON.stringify({ x: { $ref: 'table', schema: 'docs', name: 'missing' } })]
      )
    ).rejects.toThrow(/CAPABILITY_TABLE_NOT_FOUND/);
  });

  it('resolve_capabilities(): declarations become one resolved bundle', async () => {
    const [{ bundle }] = await pg.any(
      `SELECT function_resolution.resolve_capabilities($1, 'database', $1, $2, 'database', $1, $3::jsonb, 'api') AS bundle`,
      [TENANT_DB, ids.exporter, JSON.stringify({ subject: 'monthly' })]
    );

    expect(bundle.buckets.exports).toEqual({
      bucket_id: ids.exports,
      key: 'exports',
      type: 'private',
      physical_name: 'phys-exports',
      database_id: TENANT_DB,
      source: 'tags',
    });
    expect(bundle.apis['notifications_module'].api_id).toBe(ids.adminApi);
    expect(bundle.models).toEqual(['gpt-4o']);
    expect(bundle.payload).toEqual({ subject: 'monthly' });
  });

  it('resolve_capabilities(): an explicit binding overrides tag discovery', async () => {
    await pg.query(
      `INSERT INTO catalog_private.bindings
         (owner_scope, owner_key, database_id, function_id, bucket_id, key, lifecycle)
       VALUES ('database', $1, $1, $2, $3, 'variants', 'execution')`,
      [TENANT_DB, ids.ambiguous, ids.publicVariants]
    );

    const [{ bundle }] = await pg.any(
      `SELECT function_resolution.resolve_capabilities($1, 'database', $1, $2, 'database', $1) AS bundle`,
      [TENANT_DB, ids.ambiguous]
    );
    expect(bundle.buckets.variants.bucket_id).toBe(ids.publicVariants);
    expect(bundle.buckets.variants.source).toBe('binding');
  });

  it('resolve_capabilities(): a binding on an unreachable bucket raises', async () => {
    await pg.query(
      `UPDATE catalog_private.bindings SET bucket_id = $1 WHERE function_id = $2`,
      [ids.foreign, ids.ambiguous]
    );

    await expect(
      pg.any(
        `SELECT function_resolution.resolve_capabilities($1, 'database', $1, $2, 'database', $1)`,
        [TENANT_DB, ids.ambiguous]
      )
    ).rejects.toThrow(/CAPABILITY_BINDING_UNREACHABLE/);

    await pg.query(`DELETE FROM catalog_private.bindings WHERE function_id = $1`, [
      ids.ambiguous,
    ]);
  });

  it('resolve_capabilities(): an undeclared channel is refused', async () => {
    await expect(
      pg.any(
        `SELECT function_resolution.resolve_capabilities($1, 'database', $1, $2, 'database', $1, '{}'::jsonb, 'cron')`,
        [TENANT_DB, ids.exporter]
      )
    ).rejects.toThrow(/CAPABILITY_CHANNEL_REFUSED/);
  });

  it('resolve_capabilities(): a missing definition raises', async () => {
    await expect(
      pg.any(
        `SELECT function_resolution.resolve_capabilities($1, 'database', $1, gen_random_uuid(), 'database', $1)`,
        [TENANT_DB]
      )
    ).rejects.toThrow(/CAPABILITY_DEFINITION_NOT_FOUND/);
  });

  it('validate_capabilities(): passes when resolvable, raises when not', async () => {
    await pg.query(
      `SELECT function_resolution.validate_capabilities($1, 'database', $1, $2, 'database', $1)`,
      [TENANT_DB, ids.exporter]
    );

    await expect(
      pg.any(
        `SELECT function_resolution.validate_capabilities($1, 'database', $1, $2, 'database', $1)`,
        [TENANT_DB, ids.ambiguous]
      )
    ).rejects.toThrow(/CAPABILITY_BUCKET_AMBIGUOUS/);
  });
});
