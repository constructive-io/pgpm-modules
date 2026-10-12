import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

const DATABASE_ID = '22222222-2222-2222-2222-222222222222';

// anonymous has no USAGE on app_scope at all; authenticated does, so it is the
// function-level revoke that stops it.
const EXPOSED_ROLES: [string, RegExp][] = [
  ['anonymous', /permission denied for schema app_scope/],
  ['authenticated', /permission denied for function dyn_lookup_uuid/]
];

// Every app_scope SECURITY DEFINER function is internal: its only legitimate
// callers are other owner-run (SECURITY DEFINER) functions. Postgres grants
// EXECUTE to PUBLIC by default and authenticated has USAGE on app_scope, so
// without an explicit revoke dyn_lookup_uuid is an RLS-bypassing read oracle.
// Resolvers that INVOKER planes (routing_tables, settings/site readers,
// generated triggers) call as the authenticated caller.
const AUTHENTICATED_RESOLVERS = [
  'app_scope.frame_owns(uuid,text,uuid,text,uuid,uuid)',
  'app_scope.frames(uuid,text,uuid)',
  'app_scope.platform_database_id()'
];

describe('app_scope grants', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
    await pg.query(
      `INSERT INTO metaschema_public.database (id, name) VALUES ($1, 'app_scope_grants_db')`,
      [DATABASE_ID]
    );
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

  it('only the read-only resolvers are executable, and only by authenticated', async () => {
    const rows = await pg.any<{ fn: string; role: string; can_execute: boolean }>(
      `SELECT p.oid::regprocedure::text AS fn,
              r.role,
              CASE r.role
                WHEN 'public' THEN EXISTS (
                  SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                   WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE')
                ELSE has_function_privilege(r.role, p.oid, 'EXECUTE')
              END AS can_execute
         FROM pg_proc p
         JOIN pg_namespace n ON n.oid = p.pronamespace
        CROSS JOIN unnest(ARRAY['public', 'anonymous', 'authenticated']) AS r(role)
        WHERE n.nspname = 'app_scope' AND p.prosecdef
        ORDER BY 1, 2`
    );
    expect(new Set(rows.map((r) => r.fn)).size).toBe(8);
    expect(
      rows.filter((r) => r.can_execute).map((r) => `${r.role} ${r.fn}`)
    ).toEqual(AUTHENTICATED_RESOLVERS.map((fn) => `authenticated ${fn}`));
  });

  it.each(EXPOSED_ROLES)('%s cannot call dyn_lookup_uuid', async (role, denied) => {
    await expect(
      pg.query(
        `SET LOCAL ROLE ${role};
         SELECT app_scope.dyn_lookup_uuid('metaschema_public', 'database', 'owner_id', '${DATABASE_ID}'::uuid)`
      )
    ).rejects.toThrow(denied);
  });

  it('an owner-run SECURITY DEFINER caller still reaches local_frames for authenticated', async () => {
    await pg.query(
      `CREATE FUNCTION public.app_scope_grants_probe(database_id uuid)
         RETURNS SETOF text AS $$
           SELECT f.scope FROM app_scope.local_frames(database_id, 'database') f
         $$ LANGUAGE sql STABLE SECURITY DEFINER`
    );
    await pg.query(`GRANT EXECUTE ON FUNCTION public.app_scope_grants_probe(uuid) TO authenticated`);
    await pg.query(`SET LOCAL ROLE authenticated`);
    const rows = await pg.any<{ scope: string }>(
      `SELECT app_scope_grants_probe AS scope FROM public.app_scope_grants_probe($1)`,
      [DATABASE_ID]
    );
    expect(rows.map((r) => r.scope)).toContain('database');
  });
});
