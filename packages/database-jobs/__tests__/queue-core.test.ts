import { getConnections, PgTestClient } from 'pgsql-test';

/**
 * The recurring-schedule clock lives beside the queue, not in it: it reads and
 * advances app_jobs.scheduled_jobs and spawns through run_scheduled_job. The
 * queue core it must leave alone — app_jobs.jobs' columns and indexes, and
 * get_job — is pinned here; a change to any of them fails this snapshot.
 */

let pg: PgTestClient;
let teardown: () => Promise<void>;

describe('queue core', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  it('app_jobs.get_job is unchanged', async () => {
    const { def } = await pg.one(
      `SELECT pg_get_functiondef('app_jobs.get_job(text, text[], interval)'::regprocedure) AS def`
    );
    expect(def).toMatchSnapshot();
  });

  it('app_jobs.jobs columns and indexes are unchanged', async () => {
    const columns = await pg.any(
      `SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
        WHERE table_schema = 'app_jobs' AND table_name = 'jobs'
        ORDER BY ordinal_position`
    );
    const indexes = await pg.any(
      `SELECT indexname, indexdef FROM pg_indexes
        WHERE schemaname = 'app_jobs' AND tablename = 'jobs'
        ORDER BY indexname`
    );
    expect({ columns, indexes }).toMatchSnapshot();
  });

  it('no schedule tick lives in the queue', async () => {
    const { n } = await pg.one(
      `SELECT count(*) AS n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
        WHERE ns.nspname = 'app_jobs' AND p.proname IN ('schedule_tick', 'tg_schedule_tick')`
    );
    expect(Number(n)).toBe(0);
  });
});
