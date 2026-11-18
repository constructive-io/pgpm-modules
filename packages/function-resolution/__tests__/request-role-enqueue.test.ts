// function_resolution.enqueue forwards a caller-chosen task and payload to
// app_jobs.add_job as its owner, so a request role that could call it could
// queue any job. Only the SECURITY DEFINER triggers that run as its owner may
// call it.
import { getConnections, PgTestClient } from 'pgsql-test';

jest.setTimeout(120_000);

const TENANT_DB = '22222222-2222-2222-2222-222222222222';
const ACTOR_ID = '55555555-5555-5555-5555-555555555555';
const SIGNATURE =
  'function_resolution.enqueue(text, json, text, uuid, uuid, text, text, text, timestamptz, integer, integer, uuid, text, boolean, text, uuid, uuid, uuid, uuid)';

let pg: PgTestClient;
let teardown: () => Promise<void>;

beforeAll(async () => {
  ({ pg, teardown } = await getConnections());
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

describe.each(['authenticated', 'authenticated_client'])('as %s', (role) => {
  // pg.beforeEach opened the savepoint; afterEach rolls the role back.
  it('cannot call function_resolution.enqueue', async () => {
    await pg.query(
      `SELECT set_config('jwt.claims.database_id', $1, true),
              set_config('jwt.claims.user_id', $2, true),
              set_config('jwt.claims.principal_id', $2, true)`,
      [TENANT_DB, ACTOR_ID]
    );
    await pg.query(`SET LOCAL ROLE ${role}`);
    await expect(
      pg.query(
        `SELECT id FROM function_resolution.enqueue(
           task_identifier := 'deployment:function_deprovision',
           payload := '{"namespace":"victim"}'::json,
           scope := 'app'
         )`
      )
    ).rejects.toThrow(/permission denied for function enqueue/);
  });
});

// Its callers are SECURITY DEFINER triggers, which run as the owner, so no
// role holds EXECUTE: not PUBLIC, not a request role, not the platform login.
it('grants EXECUTE on function_resolution.enqueue to no role', async () => {
  const grants = await pg.one<Record<string, boolean>>(
    `SELECT has_function_privilege('platform_service', $1, 'EXECUTE') AS platform_service,
            has_function_privilege('authenticated', $1, 'EXECUTE') AS authenticated,
            has_function_privilege('authenticated_client', $1, 'EXECUTE') AS authenticated_client,
            has_function_privilege('anonymous', $1, 'EXECUTE') AS anonymous,
            EXISTS (
              SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
               WHERE p.oid = $1::regprocedure AND a.grantee = 0
            ) AS public`,
    [SIGNATURE]
  );
  expect(grants).toEqual({
    platform_service: false,
    authenticated: false,
    authenticated_client: false,
    anonymous: false,
    public: false
  });
});
