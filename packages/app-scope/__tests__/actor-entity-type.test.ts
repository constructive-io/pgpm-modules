import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const DATABASE_ID = '22222222-2222-2222-2222-222222222222';
const EMPTY_DATABASE_ID = '33333333-3333-3333-3333-333333333333';
const PRINCIPAL_DATABASE_ID = '77777777-7777-7777-7777-777777777777';
const APP_USER_ID = '44444444-4444-4444-4444-444444444444';
const ORG_USER_ID = '55555555-5555-5555-5555-555555555555';
const UNKNOWN_USER_ID = '66666666-6666-6666-6666-666666666666';
const PRINCIPAL_OWNER_ID = '88888888-8888-8888-8888-888888888888';
const PRINCIPAL_USER_ID = '99999999-9999-9999-9999-999999999999';
const ORPHAN_PRINCIPAL_USER_ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const NESTED_OWNER_ID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const NESTED_PRINCIPAL_USER_ID = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

describe('app_scope.actor_entity', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    await pg.query(
      `INSERT INTO metaschema_public.database (id, name)
       VALUES
         ($1, 'actor_entity_type_db'),
         ($2, 'actor_entity_type_empty_db'),
         ($3, 'actor_entity_type_principal_db')`,
      [DATABASE_ID, EMPTY_DATABASE_ID, PRINCIPAL_DATABASE_ID]
    );
    await pg.query(`CREATE SCHEMA actor_entity_type_test`);
    await pg.query(`CREATE TABLE actor_entity_type_test.role_types (
      id integer PRIMARY KEY,
      name text NOT NULL
    )`);
    await pg.query(`CREATE TABLE actor_entity_type_test.users (
      id uuid PRIMARY KEY,
      type integer NOT NULL
    )`);
    await pg.query(
      `INSERT INTO actor_entity_type_test.role_types (id, name)
       VALUES (1, 'User'), (2, 'Organization'), (3, 'Principal')`
    );
    await pg.query(
      `INSERT INTO actor_entity_type_test.users (id, type)
       VALUES ($1, 1), ($2, 2)`,
      [APP_USER_ID, ORG_USER_ID]
    );

    const schema = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'actor_entity_type_test', 'actor_entity_type_test')
       RETURNING id`,
      [DATABASE_ID]
    );
    const users = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'users')
       RETURNING id`,
      [DATABASE_ID, schema.id]
    );
    const roleTypes = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'role_types')
       RETURNING id`,
      [DATABASE_ID, schema.id]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.users_module
         (database_id, schema_id, table_id, type_table_id)
       VALUES ($1, $2, $3, $4)`,
      [DATABASE_ID, schema.id, users.id, roleTypes.id]
    );

    await pg.query(`CREATE SCHEMA actor_entity_principal_test`);
    await pg.query(`CREATE TABLE actor_entity_principal_test.role_types (
      id integer PRIMARY KEY,
      name text NOT NULL
    )`);
    await pg.query(`CREATE TABLE actor_entity_principal_test.users (
      id uuid PRIMARY KEY,
      type integer NOT NULL
    )`);
    await pg.query(`CREATE TABLE actor_entity_principal_test.principals (
      user_id uuid PRIMARY KEY,
      owner_id uuid NOT NULL
    )`);
    await pg.query(`CREATE TABLE actor_entity_principal_test.principal_entities (
      user_id uuid NOT NULL,
      entity_id uuid NOT NULL
    )`);
    await pg.query(`CREATE TABLE actor_entity_principal_test.sessions (
      id uuid PRIMARY KEY
    )`);
    await pg.query(`CREATE TABLE actor_entity_principal_test.session_credentials (
      id uuid PRIMARY KEY
    )`);
    await pg.query(
      `INSERT INTO actor_entity_principal_test.role_types (id, name)
       VALUES (1, 'User'), (2, 'Organization'), (3, 'Principal')`
    );
    await pg.query(
      `INSERT INTO actor_entity_principal_test.users (id, type)
       VALUES
         ($1, 1),
         ($2, 3),
         ($3, 3),
         ($4, 3),
         ($5, 3)`,
      [
        PRINCIPAL_OWNER_ID,
        PRINCIPAL_USER_ID,
        ORPHAN_PRINCIPAL_USER_ID,
        NESTED_OWNER_ID,
        NESTED_PRINCIPAL_USER_ID,
      ]
    );
    await pg.query(
      `INSERT INTO actor_entity_principal_test.principals (user_id, owner_id)
       VALUES ($1, $2), ($3, $4)`,
      [PRINCIPAL_USER_ID, PRINCIPAL_OWNER_ID, NESTED_PRINCIPAL_USER_ID, NESTED_OWNER_ID]
    );

    const principalSchema = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'actor_entity_principal_test', 'actor_entity_principal_test')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID]
    );
    const principalUsers = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'users')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID, principalSchema.id]
    );
    const principalRoleTypes = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'role_types')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID, principalSchema.id]
    );
    const principalPrincipals = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'principals')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID, principalSchema.id]
    );
    const principalEntities = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'principal_entities')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID, principalSchema.id]
    );
    const principalSessions = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'sessions')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID, principalSchema.id]
    );
    const principalSessionCredentials = await pg.one<{ id: string }>(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'session_credentials')
       RETURNING id`,
      [PRINCIPAL_DATABASE_ID, principalSchema.id]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.users_module
         (database_id, schema_id, table_id, type_table_id)
       VALUES ($1, $2, $3, $4)`,
      [
        PRINCIPAL_DATABASE_ID,
        principalSchema.id,
        principalUsers.id,
        principalRoleTypes.id,
      ]
    );
    await pg.query(
      `INSERT INTO metaschema_modules_public.principal_auth_module
         (
           database_id,
           schema_id,
           principals_table_id,
           principal_entities_table_id,
           users_table_id,
           sessions_table_id,
           session_credentials_table_id
         )
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        PRINCIPAL_DATABASE_ID,
        principalSchema.id,
        principalPrincipals.id,
        principalEntities.id,
        principalUsers.id,
        principalSessions.id,
        principalSessionCredentials.id,
      ]
    );
  });

  afterAll(() => teardown());

  it('resolves an ordinary user from the users role-types registry', async () => {
    const actual = await pg.one<{ entity_id: string; entity_type: string }>(
      `SELECT * FROM app_scope.actor_entity($1, $2)`,
      [DATABASE_ID, APP_USER_ID]
    );
    expect(actual).toEqual({ entity_id: APP_USER_ID, entity_type: 'app' });
  });

  it('resolves an organization-typed users row to the org scope', async () => {
    const actual = await pg.one<{ entity_id: string; entity_type: string }>(
      `SELECT * FROM app_scope.actor_entity($1, $2)`,
      [DATABASE_ID, ORG_USER_ID]
    );
    expect(actual).toEqual({ entity_id: ORG_USER_ID, entity_type: 'org' });
  });

  it('raises for an unknown actor', async () => {
    await expect(
      pg.one(`SELECT * FROM app_scope.actor_entity($1, $2)`, [DATABASE_ID, UNKNOWN_USER_ID])
    ).rejects.toMatchObject({ code: '42704' });
  });

  it('resolves in a database that installs users without principal_auth (minimal preset)', async () => {
    // Minimal is the preset the sync gateway serves; the previous implementation 500'd on it.
    const actual = await pg.one<{ entity_id: string; entity_type: string }>(
      `SELECT * FROM app_scope.actor_entity($1, $2)`,
      [DATABASE_ID, APP_USER_ID]
    );
    expect(actual).toEqual({ entity_id: APP_USER_ID, entity_type: 'app' });
  });

  it('resolves a principal to its type-1 owner in a database with principal_auth', async () => {
    const actual = await pg.one<{ entity_id: string; entity_type: string }>(
      `SELECT * FROM app_scope.actor_entity($1, $2)`,
      [PRINCIPAL_DATABASE_ID, PRINCIPAL_USER_ID]
    );
    expect(actual).toEqual({ entity_id: PRINCIPAL_OWNER_ID, entity_type: 'app' });
  });

  it('raises when a principal has no principals row', async () => {
    await expect(
      pg.one(`SELECT * FROM app_scope.actor_entity($1, $2)`, [
        PRINCIPAL_DATABASE_ID,
        ORPHAN_PRINCIPAL_USER_ID,
      ])
    ).rejects.toMatchObject({ code: '42704' });
  });

  it('raises when a principal owner is itself a principal', async () => {
    await expect(
      pg.one(`SELECT * FROM app_scope.actor_entity($1, $2)`, [
        PRINCIPAL_DATABASE_ID,
        NESTED_PRINCIPAL_USER_ID,
      ])
    ).rejects.toMatchObject({ code: '42704' });
  });

  it('raises when the database has no users module', async () => {
    await expect(
      pg.one(`SELECT * FROM app_scope.actor_entity($1, $2)`, [EMPTY_DATABASE_ID, UNKNOWN_USER_ID])
    ).rejects.toMatchObject({ code: '42704' });
  });
});
