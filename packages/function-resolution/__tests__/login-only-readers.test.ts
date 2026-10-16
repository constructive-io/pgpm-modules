import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let db: PgTestClient;
let teardown: () => Promise<void>;

const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const OTHER_DB = '33333333-3333-3333-3333-333333333333';
const SERVICE_USER = '44444444-4444-4444-4444-444444444444';
const OWNER_USER = '45454545-4545-4545-4545-454545454545';
const USERS_TABLE = '46464646-4646-4646-4646-464646464646';
const TENANT_API = '55555555-5555-5555-5555-555555555555';

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
    pg.setContext({ role: pg.config.user });
  }
};

const READERS: Array<[string, string]> = [
  ['api_by_name', `SELECT * FROM function_resolution.api_by_name('${TENANT_DB}', 'app')`],
  ['api_hostnames', `SELECT * FROM function_resolution.api_hostnames('${TENANT_DB}')`],
  ['service_principal', `SELECT * FROM function_resolution.service_principal('platform-service')`],
  ['tenant_auth_entry', `SELECT * FROM function_resolution.tenant_auth_entry('${TENANT_DB}')`],
  ['cors_origins', `SELECT * FROM function_resolution.cors_origins('${TENANT_DB}', NULL)`],
  ['pubkey_entry', `SELECT * FROM function_resolution.pubkey_entry('${TENANT_DB}')`],
  ['webauthn_entry', `SELECT * FROM function_resolution.webauthn_entry('${TENANT_DB}')`],
  ['database_features', `SELECT * FROM function_resolution.database_features('${TENANT_DB}', NULL)`],
  ['request_protection', `SELECT * FROM function_resolution.request_protection('${TENANT_DB}', NULL)`],
  ['database_export_catalog', `SELECT * FROM function_resolution.database_export_catalog('${TENANT_DB}')`]
];

// The platform's own pre-request reads (X-Api-Name lookup, cache flush, the
// refusal recorder's identity) cross member RLS, so each is a narrow SECURITY
// DEFINER reader that only the platform login may execute, on its own
// connection with no role switch. Here the connection's superuser stands in for
// that login; every request role is refused.
describe('login-only pre-request readers', () => {
  beforeAll(async () => {
    ({ pg, db, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform)
       VALUES ($1, 'platform_db', true), ($2, 'tenant_db', false), ($3, 'other_db', false)`,
      [PLATFORM_DB, TENANT_DB, OTHER_DB]
    );

    await pg.query(`
      CREATE SCHEMA routing_public;
      CREATE TABLE routing_public.apis (
        id uuid PRIMARY KEY, database_id uuid NOT NULL, name text NOT NULL, dbname text,
        role_name text, anon_role text, is_published boolean NOT NULL DEFAULT false);
      CREATE TABLE routing_public.api_schemas (api_id uuid NOT NULL, schema_id uuid NOT NULL);
      CREATE TABLE routing_public.domains (database_id uuid NOT NULL, hostname text);
      CREATE SCHEMA plat_auth_public;
      CREATE TABLE plat_auth_public.principals (
        name text PRIMARY KEY, user_id uuid NOT NULL, bypass_step_up boolean NOT NULL,
        secret_hash text, owner_id uuid);
      CREATE SCHEMA plat_users_public;
      CREATE TABLE plat_users_public.users (id uuid PRIMARY KEY, type integer NOT NULL);
    `);

    const auth = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'auth', 'plat_auth_public') RETURNING id`,
      [PLATFORM_DB]
    );
    // A bare registration: the principals table id keeps its uuid_nil()
    // default, which the FK would reject outside replica mode.
    await pg.query(`SET session_replication_role TO replica`);
    const users = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'users', 'plat_users_public') RETURNING id`,
      [PLATFORM_DB]
    );
    await pg.query(
      `INSERT INTO metaschema_public.table (id, database_id, schema_id, name)
       VALUES ($1, $2, $3, 'users')`,
      [USERS_TABLE, PLATFORM_DB, users.id]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.principal_auth_module (database_id, schema_id, private_schema_id, users_table_id)
       VALUES ($1, $2, $2, $3)`,
      [PLATFORM_DB, auth.id, USERS_TABLE]
    );
    await pg.query(`SET session_replication_role TO DEFAULT`);

    const exposed = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'app', 'tenant_app_public') RETURNING id`,
      [TENANT_DB]
    );
    await pg.query(
      `INSERT INTO routing_public.apis (id, database_id, name, dbname, role_name, anon_role, is_published)
       VALUES ('55555555-5555-5555-5555-555555555555', $1, 'app', 'tenant', 'authenticated', 'anonymous', true),
              ('66666666-6666-6666-6666-666666666666', $2, 'app', 'other', 'authenticated', 'anonymous', true)`,
      [TENANT_DB, OTHER_DB]
    );
    await pg.query(
      `INSERT INTO routing_public.api_schemas (api_id, schema_id)
       VALUES ('55555555-5555-5555-5555-555555555555', $1)`,
      [exposed.id]
    );
    await pg.query(
      `INSERT INTO routing_public.domains (database_id, hostname)
       VALUES ($1, 'b.tenant.test'), ($1, 'a.tenant.test'), ($2, 'other.test')`,
      [TENANT_DB, OTHER_DB]
    );
    await pg.query(
      `INSERT INTO plat_auth_public.principals (name, user_id, bypass_step_up, secret_hash, owner_id)
       VALUES ('platform-service', $1, true, 'never-returned', $2)`,
      [SERVICE_USER, OWNER_USER]
    );
    await pg.query(`INSERT INTO plat_users_public.users (id, type) VALUES ($1, 2)`, [OWNER_USER]);

    await pg.query(`
      CREATE TABLE routing_public.rls_settings (
        database_id uuid NOT NULL, authenticate_schema_id uuid, role_schema_id uuid,
        authenticate_function_id uuid, authenticate_strict_function_id uuid,
        current_role_function_id uuid, current_role_id_function_id uuid,
        current_ip_address_function_id uuid, current_user_agent_function_id uuid);
      CREATE TABLE routing_public.cors_settings (
        database_id uuid NOT NULL, api_id uuid, allowed_origins text[]);
      CREATE TABLE routing_public.pubkey_settings (
        database_id uuid NOT NULL, schema_id uuid, crypto_network text,
        sign_up_with_key_function_id uuid, sign_in_request_challenge_function_id uuid,
        sign_in_record_failure_function_id uuid, sign_in_with_challenge_function_id uuid);
      CREATE TABLE routing_public.webauthn_settings (
        database_id uuid NOT NULL, schema_id uuid, credentials_schema_id uuid, sessions_schema_id uuid,
        session_secrets_schema_id uuid, rp_id text, rp_name text, origin_allowlist text[],
        attestation_type text, require_user_verification boolean, resident_key text,
        challenge_expiry_seconds bigint);
      CREATE TABLE routing_public.database_settings (
        database_id uuid NOT NULL, enable_aggregates boolean, enable_postgis boolean, enable_search boolean,
        enable_direct_uploads boolean, enable_presigned_uploads boolean, enable_many_to_many boolean,
        enable_connection_filter boolean, enable_ltree boolean, enable_llm boolean, enable_realtime boolean,
        enable_bulk boolean, enable_i18n boolean, statement_timeout_ms bigint,
        idle_in_transaction_timeout_ms bigint, lock_timeout_ms bigint, max_concurrent_requests int,
        max_queue_wait_ms int, rate_limit_rpm int, rate_limit_burst int, max_query_depth int,
        max_query_cost int, max_page_size int, max_request_bytes int, enable_introspection boolean);
      CREATE TABLE routing_public.api_settings (LIKE routing_public.database_settings);
      ALTER TABLE routing_public.api_settings ADD COLUMN api_id uuid;
    `);
    const authSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'auth', 'tenant_auth_private') RETURNING id`,
      [TENANT_DB]
    );
    const fn = async (name: string): Promise<string> =>
      (await pg.one(
        `INSERT INTO metaschema_public.function (database_id, schema_id, name) VALUES ($1, $2, $3) RETURNING id`,
        [TENANT_DB, authSchema.id, name]
      )).id;
    await pg.query(
      `INSERT INTO routing_public.rls_settings
         (database_id, authenticate_schema_id, role_schema_id, authenticate_function_id, current_role_id_function_id)
       VALUES ($1, $2, $3, $4, $5)`,
      [TENANT_DB, authSchema.id, exposed.id, await fn('authenticate'), await fn('current_user_id')]
    );
    await pg.query(
      `INSERT INTO routing_public.cors_settings (database_id, api_id, allowed_origins)
       VALUES ($1, NULL, ARRAY['https://default.test']), ($1, $2, ARRAY['https://api.test'])`,
      [TENANT_DB, TENANT_API]
    );
    await pg.query(
      `INSERT INTO routing_public.pubkey_settings (database_id, schema_id, crypto_network, sign_up_with_key_function_id)
       VALUES ($1, $2, 'cosmos', $3)`,
      [TENANT_DB, authSchema.id, await fn('sign_up_with_key')]
    );
    await pg.query(
      `INSERT INTO routing_public.webauthn_settings
         (database_id, schema_id, rp_id, rp_name, origin_allowlist, require_user_verification, challenge_expiry_seconds)
       VALUES ($1, $2, 'tenant.test', 'Tenant', ARRAY['https://tenant.test'], true, 300)`,
      [TENANT_DB, authSchema.id]
    );
    await pg.query(
      `INSERT INTO routing_public.database_settings (database_id, enable_search, enable_bulk, rate_limit_rpm, statement_timeout_ms)
       VALUES ($1, true, true, 600, 30000)`,
      [TENANT_DB]
    );
    await pg.query(
      `INSERT INTO routing_public.api_settings (database_id, api_id, enable_search, rate_limit_rpm)
       VALUES ($1, $2, false, 60)`,
      [TENANT_DB, TENANT_API]
    );
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

  it('api_by_name returns only that database\'s api and its schemas', async () => {
    const rows = await pg.any(`SELECT * FROM function_resolution.api_by_name($1, 'app')`, [TENANT_DB]);
    expect(rows).toEqual([{
      api_id: '55555555-5555-5555-5555-555555555555',
      api_database_id: TENANT_DB,
      dbname: 'tenant',
      role_name: 'authenticated',
      anon_role: 'anonymous',
      is_public: true,
      schemas: ['tenant_app_public']
    }]);
    expect(await pg.any(`SELECT * FROM function_resolution.api_by_name($1, 'missing')`, [TENANT_DB])).toEqual([]);
  });

  it('api_hostnames returns only that database\'s hostnames', async () => {
    const rows = await pg.any(`SELECT * FROM function_resolution.api_hostnames($1) AS hostname`, [TENANT_DB]);
    expect(rows.map((r) => r.hostname)).toEqual(['a.tenant.test', 'b.tenant.test']);
  });

  it('service_principal returns the platform principal\'s identity and nothing else', async () => {
    const result = await pg.query(`SELECT * FROM function_resolution.service_principal('platform-service')`);
    expect(result.fields.map((f) => f.name)).toEqual(['user_id', 'bypass_step_up', 'owner_id', 'owner_type']);
    expect(result.rows).toEqual([{ user_id: SERVICE_USER, bypass_step_up: true, owner_id: OWNER_USER, owner_type: 2 }]);
  });

  it('raises when the platform database has no principal_auth_module', async () => {
    await pg.query(`DELETE FROM metaschema_modules_public.principal_auth_module WHERE database_id = $1`, [PLATFORM_DB]);
    await expect(
      pg.any(`SELECT * FROM function_resolution.service_principal('platform-service')`)
    ).rejects.toThrow(/SERVICE_PRINCIPAL_MODULE_MISSING/);
  });

  it('returns nothing for a database with no apis or domains', async () => {
    const unknown = '77777777-7777-7777-7777-777777777777';
    expect(await pg.any(`SELECT * FROM function_resolution.api_by_name($1, 'app')`, [unknown])).toEqual([]);
    expect(await pg.any(`SELECT * FROM function_resolution.api_hostnames($1)`, [unknown])).toEqual([]);
  });

  it('tenant_auth_entry returns the auth function names and nothing for an unknown database', async () => {
    expect(await pg.any(`SELECT * FROM function_resolution.tenant_auth_entry($1)`, [TENANT_DB])).toEqual([{
      authenticate_schema: 'tenant_auth_private',
      authenticate_function: 'authenticate',
      authenticate_strict_function: null,
      role_schema: 'tenant_app_public',
      current_role_function: null,
      current_role_id_function: 'current_user_id',
      current_ip_address_function: null,
      current_user_agent_function: null
    }]);
    expect(await pg.any(`SELECT * FROM function_resolution.tenant_auth_entry($1)`, [OTHER_DB])).toEqual([]);
  });

  it('cors_origins prefers the API row and falls back to the database default', async () => {
    const origins = async (apiId: string | null) =>
      (await pg.any(`SELECT * FROM function_resolution.cors_origins($1, $2)`, [TENANT_DB, apiId]));
    expect(await origins(TENANT_API)).toEqual([{ allowed_origins: ['https://api.test'] }]);
    expect(await origins(null)).toEqual([{ allowed_origins: ['https://default.test'] }]);
    expect(await origins('66666666-6666-6666-6666-666666666666')).toEqual([{ allowed_origins: ['https://default.test'] }]);
    expect(await pg.any(`SELECT * FROM function_resolution.cors_origins($1, NULL)`, [OTHER_DB])).toEqual([]);
  });

  it('pubkey_entry and webauthn_entry return that database\'s settings', async () => {
    expect(await pg.one(`SELECT * FROM function_resolution.pubkey_entry($1)`, [TENANT_DB])).toEqual({
      schema_name: 'tenant_auth_private', crypto_network: 'cosmos', sign_up_with_key: 'sign_up_with_key',
      sign_in_request_challenge: null, sign_in_record_failure: null, sign_in_with_challenge: null
    });
    expect(await pg.one(`SELECT * FROM function_resolution.webauthn_entry($1)`, [TENANT_DB])).toMatchObject({
      schema_name: 'tenant_auth_private', rp_id: 'tenant.test', rp_name: 'Tenant',
      origin_allowlist: ['https://tenant.test'], require_user_verification: true,
      challenge_expiry_seconds: '300'
    });
    expect(await pg.any(`SELECT * FROM function_resolution.pubkey_entry($1)`, [OTHER_DB])).toEqual([]);
    expect(await pg.any(`SELECT * FROM function_resolution.webauthn_entry($1)`, [OTHER_DB])).toEqual([]);
  });

  it('database_features lets the API override each flag', async () => {
    const api = await pg.one(`SELECT * FROM function_resolution.database_features($1, $2)`, [TENANT_DB, TENANT_API]);
    expect(api).toMatchObject({ enable_search: false, enable_bulk: true, enable_llm: null });
    const db = await pg.one(`SELECT * FROM function_resolution.database_features($1, NULL)`, [TENANT_DB]);
    expect(db).toMatchObject({ enable_search: true, enable_bulk: true });
  });

  it('request_protection returns the database bounds and API overrides side by side', async () => {
    const row = await pg.one(`SELECT * FROM function_resolution.request_protection($1, $2)`, [TENANT_DB, TENANT_API]);
    expect(row).toMatchObject({
      db_rate_limit_rpm: 600, api_rate_limit_rpm: 60, db_statement_timeout_ms: '30000', api_statement_timeout_ms: null
    });
    expect(await pg.any(`SELECT * FROM function_resolution.request_protection($1, NULL)`, [OTHER_DB])).toEqual([]);
  });

  describe.each(['anonymous', 'authenticated'])('as %s', (role) => {
    it.each(READERS)('is refused %s', async (name, sql) => {
      db.setContext({ role, 'jwt.claims.database_id': TENANT_DB });
      await expect(db.any(sql)).rejects.toThrow(new RegExp(`permission denied for function ${name}`));
    });
  });

  it.each(READERS)('refuses %s to the pg-wire lane floor role', async (name, sql) => {
    await asRole({ role: 'authenticated_client', 'jwt.claims.database_id': TENANT_DB }, () =>
      expect(pg.any(sql)).rejects.toThrow(
        new RegExp(`permission denied for (schema function_resolution|function ${name})`)
      )
    );
  });
});
