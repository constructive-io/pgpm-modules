import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;

describe('run_scheduled_job concurrency safety', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  beforeEach(async () => {
    await pg.beforeEach();
  });

  afterEach(async () => {
    await pg.afterEach();
  });

  afterAll(async () => {
    await teardown();
  });

  const addScheduledJob = async (key: string) => {
    const [scheduled] = await pg.any(
      `SELECT * FROM app_jobs.add_scheduled_job(
        identifier := $1::text,
        payload := $2::json,
        schedule_info := $3::json,
        job_key := $4::text
      )`,
      ['my_job', { just: 'run it' }, { rule: '*/1 * * * *' }, key]
    );
    return scheduled;
  };

  it('stale-read second invocation upserts instead of dying on jobs_key_key', async () => {
    const scheduled = await addScheduledJob('race_key_1');

    const [first] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [scheduled.id]
    );
    expect(first.id).toBeTruthy();
    expect(first.key).toBe('race_key_1');

    // simulate the racing runner's stale read: it never saw the first
    // invocation's last_scheduled_id, so the already-scheduled probe passes
    await pg.any(
      `UPDATE app_jobs.scheduled_jobs SET last_scheduled_id = NULL WHERE id = $1`,
      [scheduled.id]
    );

    const [second] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [scheduled.id]
    );

    // the insert conflicts on jobs_key_key and refreshes the pending job
    expect(second.id).toBe(first.id);

    const jobs = await pg.any(
      `SELECT * FROM app_jobs.jobs WHERE key = $1`,
      ['race_key_1']
    );
    expect(jobs.length).toBe(1);
    expect(jobs[0].attempts).toBe(0);
    expect(jobs[0].last_error).toBeNull();

    const [sched] = await pg.any(
      `SELECT last_scheduled_id FROM app_jobs.scheduled_jobs WHERE id = $1`,
      [scheduled.id]
    );
    expect(sched.last_scheduled_id).toBe(first.id);
  });

  it('returns a null record when a BEFORE INSERT trigger suppresses the transport row', async () => {
    // mirrors the function_module cron fire trigger, which converts the keyed
    // transport row into a pending invocation and RETURN NULLs
    await pg.any(`
      CREATE FUNCTION pg_temp.suppress_job ()
        RETURNS TRIGGER AS $$
      BEGIN
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER suppress_job_tg
        BEFORE INSERT ON app_jobs.jobs
        FOR EACH ROW
        EXECUTE PROCEDURE pg_temp.suppress_job ();
    `);

    const scheduled = await addScheduledJob('race_key_4');
    const [result] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [scheduled.id]
    );
    expect(result.id).toBeNull();

    const jobs = await pg.any(`SELECT * FROM app_jobs.jobs WHERE key = $1`, [
      'race_key_4',
    ]);
    expect(jobs.length).toBe(0);

    await pg.any(`DROP TRIGGER suppress_job_tg ON app_jobs.jobs`);
  });

  it('raises ALREADY_SCHEDULED when the keyed job is locked (in flight)', async () => {
    const scheduled = await addScheduledJob('race_key_2');

    const [first] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [scheduled.id]
    );

    await pg.any(
      `UPDATE app_jobs.jobs SET locked_at = NOW(), locked_by = 'worker-1' WHERE id = $1`,
      [first.id]
    );
    await pg.any(
      `UPDATE app_jobs.scheduled_jobs SET last_scheduled_id = NULL WHERE id = $1`,
      [scheduled.id]
    );

    const jobs = await pg.any(
      `SELECT * FROM app_jobs.jobs WHERE key = $1`,
      ['race_key_2']
    );
    expect(jobs.length).toBe(1);

    // raising aborts the surrounding test transaction, so this stays last
    await expect(
      pg.any(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [scheduled.id])
    ).rejects.toThrow('ALREADY_SCHEDULED');
  });

  it('raises ALREADY_SCHEDULED when last_scheduled_id points at a pending job', async () => {
    const scheduled = await addScheduledJob('race_key_3');

    await pg.any(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [
      scheduled.id,
    ]);

    await expect(
      pg.any(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [scheduled.id])
    ).rejects.toThrow('ALREADY_SCHEDULED');
  });

  it('returns a null record when the scheduled job does not exist', async () => {
    const [result] = await pg.any(
      `SELECT * FROM app_jobs.run_scheduled_job($1)`,
      [999999999]
    );
    expect(result.id).toBeNull();
  });
});
