import { getConnections, PgTestClient } from 'pgsql-test';
import { seed } from 'pgsql-test/seed';

let pg: PgTestClient;
let teardown: () => Promise<void>;
const userId = '00000000-0000-0000-0000-000000000001';
const otherId = '00000000-0000-0000-0000-000000000002';

beforeAll(async () => {
  ({ pg, teardown } = await getConnections({}, [
    seed.fn(async ({ pg }) => {
      await pg.query(`
        DO $$ BEGIN
          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
            CREATE ROLE anon NOINHERIT NOLOGIN;
          END IF;
        END $$;
      `);
    }),
    seed.pgpm()
  ]));
  await pg.query(`
    CREATE TABLE public.anonymous_read (value text);
    INSERT INTO public.anonymous_read VALUES ('public content');
    GRANT SELECT ON public.anonymous_read TO anonymous;
    CREATE TABLE public.owned_rows (user_id uuid PRIMARY KEY);
    INSERT INTO public.owned_rows VALUES ('${userId}'), ('${otherId}');
    ALTER TABLE public.owned_rows ENABLE ROW LEVEL SECURITY;
    GRANT SELECT ON public.owned_rows TO authenticated;
    CREATE POLICY own_rows ON public.owned_rows TO authenticated
      USING (user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
  `);
});

afterAll(async () => { await teardown?.(); });
beforeEach(async () => {
  pg.setContext({ role: null, 'request.jwt.claims': null });
  await pg.beforeEach();
});
afterEach(async () => { await pg.afterEach(); });

async function preRequestThen(sql: string) {
  const results: any = await pg.query(`SELECT supabase_integration.pre_request(); ${sql}`);
  return results[1].rows;
}

it('does not inherit anonymous grants before pre_request', async () => {
  pg.setContext({ role: 'anon' });
  await pg.expectError(() => pg.query('SELECT * FROM public.anonymous_read'), /permission denied/);
});

it('switches anon to anonymous and reads anonymous grants', async () => {
  pg.setContext({ role: 'anon' });
  expect(await preRequestThen('SELECT current_user, value FROM public.anonymous_read'))
    .toEqual([{ current_user: 'anonymous', value: 'public content' }]);
});

it('bridges both identity claims and restricts rows to the subject', async () => {
  pg.setContext({ role: 'authenticated', 'request.jwt.claims': JSON.stringify({ sub: userId }) });
  expect(await preRequestThen(`SELECT user_id,
    current_setting('jwt.claims.user_id', true) AS claim,
    current_setting('jwt.claims.principal_id', true) AS principal
    FROM public.owned_rows`)).toEqual([{ user_id: userId, claim: userId, principal: userId }]);
});

it.each([null, '', '{}', '{"sub":""}'])('handles absent subject in claims %p', async claims => {
  pg.setContext({ role: 'authenticated', 'request.jwt.claims': claims });
  expect(await preRequestThen('SELECT * FROM public.owned_rows')).toEqual([]);
});

it('does nothing for other roles', async () => {
  pg.setContext({ role: null, 'request.jwt.claims': JSON.stringify({ sub: userId }) });
  expect(await preRequestThen(`SELECT current_user = session_user AS unchanged,
    nullif(current_setting('jwt.claims.user_id', true), '') AS claim`))
    .toEqual([{ unchanged: true, claim: null }]);
});

it('allows a role with no grants to call the hook as a no-op', async () => {
  await pg.query('CREATE ROLE supabase_test_service NOINHERIT NOLOGIN');
  pg.setContext({ role: 'supabase_test_service', 'request.jwt.claims': JSON.stringify({ sub: userId }) });
  expect(await preRequestThen(`SELECT current_user,
    nullif(current_setting('jwt.claims.user_id', true), '') AS claim,
    nullif(current_setting('jwt.claims.principal_id', true), '') AS principal`))
    .toEqual([{ current_user: 'supabase_test_service', claim: null, principal: null }]);
});

it('rejects malformed JWT JSON', async () => {
  pg.setContext({ role: 'authenticated', 'request.jwt.claims': 'invalid' });
  await pg.expectError(() => pg.query('SELECT supabase_integration.pre_request()'), /invalid input syntax for type json/);
});
