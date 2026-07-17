import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const PLATFORM_DB = '11111111-1111-1111-1111-111111111111';
const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const ORG_ID = '33333333-3333-3333-3333-333333333333';
const PLATFORM_ORG_ID = '44444444-4444-4444-4444-444444444444';
const TEAM_ID = '55555555-5555-5555-5555-555555555555';
const DEPT_ID = '66666666-6666-6666-6666-666666666666';

// Proves the portable scope-frame model: app_scope.membership_parent (catalog +
// dynamic types-table read) + app_scope.dyn_lookup_uuid (dynamic owner-FK
// SELECT) drive a multi-hop custom-entity climb (team -> department -> org),
// and app_scope.frames composes each database's local chain, falling through to
// the platform database's OWN full chain (database -> org -> app -> platform) —
// all using ONLY format()/EXECUTE, no AST/deparser.
describe('app_scope scope frames (membership climb + platform fall-through)', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());

    // Both databases are owned: the tenant database by an org, and the platform
    // database by Constructive's own org — the platform database is just the
    // root database, so it climbs database -> org -> app -> platform too.
    await pg.query(
      `INSERT INTO metaschema_public.database (id, name, platform, owner_id)
       VALUES ($1, 'platform_db', true, $3), ($2, 'tenant_db', false, $4)`,
      [PLATFORM_DB, TENANT_DB, PLATFORM_ORG_ID, ORG_ID]
    );

    // Physical membership-types + entity tables (team owned by department,
    // department owned by org).
    await pg.query(`CREATE SCHEMA mem`);
    await pg.query(
      `CREATE TABLE mem.membership_types (
         id integer PRIMARY KEY,
         scope text NOT NULL,
         parent_membership_type integer
       )`
    );
    await pg.query(
      `INSERT INTO mem.membership_types (id, scope, parent_membership_type)
       VALUES (1, 'app', NULL), (2, 'org', 1), (3, 'department', 2), (4, 'team', 3)`
    );
    await pg.query(
      `CREATE TABLE mem.departments (id uuid PRIMARY KEY, org_id uuid)`
    );
    await pg.query(
      `CREATE TABLE mem.teams (id uuid PRIMARY KEY, department_id uuid)`
    );
    await pg.query(`INSERT INTO mem.departments (id, org_id) VALUES ($1, $2)`, [
      DEPT_ID,
      ORG_ID,
    ]);
    await pg.query(`INSERT INTO mem.teams (id, department_id) VALUES ($1, $2)`, [
      TEAM_ID,
      DEPT_ID,
    ]);

    // Catalog rows describing them.
    const memSchema = await pg.one(
      `INSERT INTO metaschema_public.schema (database_id, name, schema_name)
       VALUES ($1, 'mem', 'mem') RETURNING id`,
      [TENANT_DB]
    );
    const typesTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'membership_types') RETURNING id`,
      [TENANT_DB, memSchema.id]
    );
    const deptsTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'departments') RETURNING id`,
      [TENANT_DB, memSchema.id]
    );
    const teamsTable = await pg.one(
      `INSERT INTO metaschema_public."table" (database_id, schema_id, name)
       VALUES ($1, $2, 'teams') RETURNING id`,
      [TENANT_DB, memSchema.id]
    );
    const deptOwnerField = await pg.one(
      `INSERT INTO metaschema_public.field (database_id, table_id, name, type)
       VALUES ($1, $2, 'org_id', '"uuid"'::jsonb) RETURNING id`,
      [TENANT_DB, deptsTable.id]
    );
    const teamOwnerField = await pg.one(
      `INSERT INTO metaschema_public.field (database_id, table_id, name, type)
       VALUES ($1, $2, 'department_id', '"uuid"'::jsonb) RETURNING id`,
      [TENANT_DB, teamsTable.id]
    );

    await pg.query(
      `INSERT INTO metaschema_modules_public.membership_types_module
         (database_id, schema_id, table_id)
       VALUES ($1, $2, $3)`,
      [TENANT_DB, memSchema.id, typesTable.id]
    );

    // memberships_module rows for the 'team' and 'department' scopes: all NOT
    // NULL table FK columns point at a real table to satisfy the FKs; only
    // entity_table_id + entity_table_owner_id are semantically read by
    // membership_parent.
    const insertMembershipsModule = async (
      scope: string,
      entityTableId: string,
      ownerFieldId: string
    ) =>
      pg.query(
        `INSERT INTO metaschema_modules_public.memberships_module (
           database_id, scope, schema_id, private_schema_id,
           memberships_table_id, membership_defaults_table_id, members_table_id,
           grants_table_id, sprt_table_id, actor_table_id, limits_table_id,
           default_limits_table_id, permissions_table_id, default_permissions_table_id,
           entity_table_id, entity_table_owner_id
         ) VALUES (
           $1, $2, $3, $3,
           $4, $4, $4,
           $4, $4, $4, $4,
           $4, $4, $4,
           $4, $5
         )`,
        [TENANT_DB, scope, memSchema.id, entityTableId, ownerFieldId]
      );

    await insertMembershipsModule('team', teamsTable.id, teamOwnerField.id);
    await insertMembershipsModule(
      'department',
      deptsTable.id,
      deptOwnerField.id
    );
  });

  afterAll(async () => {
    await teardown();
  });

  it('dyn_lookup_uuid(): dynamic owner-FK SELECT resolves the parent key', async () => {
    const [{ dyn_lookup_uuid }] = await pg.any(
      `SELECT app_scope.dyn_lookup_uuid('mem', 'teams', 'department_id', $1) AS dyn_lookup_uuid`,
      [TEAM_ID]
    );
    expect(dyn_lookup_uuid).toBe(DEPT_ID);
  });

  it('membership_parent(): resolves type, parent scope, entity table + owner field', async () => {
    const [row] = await pg.any(
      `SELECT membership_type, parent_scope, entity_schema, entity_table, owner_field
       FROM app_scope.membership_parent($1, 'team')`,
      [TENANT_DB]
    );
    expect(row).toEqual({
      membership_type: 4,
      parent_scope: 'department',
      entity_schema: 'mem',
      entity_table: 'teams',
      owner_field: 'department_id',
    });
  });

  it('local_frames(): one database climb, entity -> ... -> org -> app (no platform terminal)', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.local_frames($1, 'team', $2)`,
      [TENANT_DB, TEAM_ID]
    );
    expect(rows).toEqual([
      { scope: 'team', lookup_database_id: TENANT_DB, key_value: TEAM_ID },
      { scope: 'department', lookup_database_id: TENANT_DB, key_value: DEPT_ID },
      { scope: 'org', lookup_database_id: TENANT_DB, key_value: ORG_ID },
      { scope: 'app', lookup_database_id: TENANT_DB, key_value: null },
    ]);
  });

  it('frames(): custom entity climb then full platform fall-through (8 frames)', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'team', $2)`,
      [TENANT_DB, TEAM_ID]
    );
    expect(rows).toEqual([
      // tenant database local chain
      { scope: 'team', lookup_database_id: TENANT_DB, key_value: TEAM_ID },
      { scope: 'department', lookup_database_id: TENANT_DB, key_value: DEPT_ID },
      { scope: 'org', lookup_database_id: TENANT_DB, key_value: ORG_ID },
      { scope: 'app', lookup_database_id: TENANT_DB, key_value: null },
      // platform database full chain, then the global platform terminal
      {
        scope: 'database',
        lookup_database_id: PLATFORM_DB,
        key_value: PLATFORM_DB,
      },
      { scope: 'org', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_ORG_ID },
      { scope: 'app', lookup_database_id: PLATFORM_DB, key_value: null },
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });

  it('frames(): tenant database execution climbs database -> org -> app then platform fall-through', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'database')`,
      [TENANT_DB]
    );
    expect(rows).toEqual([
      { scope: 'database', lookup_database_id: TENANT_DB, key_value: TENANT_DB },
      { scope: 'org', lookup_database_id: TENANT_DB, key_value: ORG_ID },
      { scope: 'app', lookup_database_id: TENANT_DB, key_value: null },
      {
        scope: 'database',
        lookup_database_id: PLATFORM_DB,
        key_value: PLATFORM_DB,
      },
      { scope: 'org', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_ORG_ID },
      { scope: 'app', lookup_database_id: PLATFORM_DB, key_value: null },
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });

  it('frames(): platform database execution climbs its own chain, no cross-database fall-through', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'database')`,
      [PLATFORM_DB]
    );
    expect(rows).toEqual([
      {
        scope: 'database',
        lookup_database_id: PLATFORM_DB,
        key_value: PLATFORM_DB,
      },
      { scope: 'org', lookup_database_id: PLATFORM_DB, key_value: PLATFORM_ORG_ID },
      { scope: 'app', lookup_database_id: PLATFORM_DB, key_value: null },
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });

  it('frames(): platform execution scope yields only the global platform terminal', async () => {
    const rows = await pg.any(
      `SELECT scope, lookup_database_id, key_value
       FROM app_scope.frames($1, 'platform')`,
      [TENANT_DB]
    );
    expect(rows).toEqual([
      { scope: 'platform', lookup_database_id: PLATFORM_DB, key_value: null },
    ]);
  });
});
