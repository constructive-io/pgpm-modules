import { getConnections, PgTestClient } from 'pgsql-test';

/**
 * queue_name is a mutual-exclusion lock: get_job holds the queue row for the
 * whole job and claims nothing else on it. The shared literal 'default' is a
 * routing label an author never chose, so it must not become a lock domain that
 * serializes every job in the database.
 */

let pg: PgTestClient;
let teardown: () => Promise<void>;

const database_id = '5b720132-17d5-424d-9bcb-ee7b17c13d43';

const addJob = async (identifier: string, queue_name: string | null) => {
  const [job] = await pg.any<{ id: string; queue_name: string | null }>(
    `SELECT * FROM app_jobs.add_job(
      identifier := $1::text,
      queue_name := $2::text,
      db_id := $3::uuid
    )`,
    [identifier, queue_name, database_id]
  );
  return job;
};

describe('queue names as locks', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'false', false)`);
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.any(`DELETE FROM app_jobs.jobs`);
  });

  it('records the shared literal, and a blank name, as no lock at all', async () => {
    const shared = await addJob('shared_literal', 'default');
    const blank = await addJob('blank_name', '');

    expect(shared.queue_name).toBeNull();
    expect(blank.queue_name).toBeNull();

    const queues = await pg.any(
      `SELECT queue_name FROM app_jobs.job_queues WHERE queue_name IN ('default', '')`
    );
    expect(queues).toEqual([]);
  });

  it('keeps a name its author chose', async () => {
    const job = await addJob('chosen_name', 'email');
    expect(job.queue_name).toBe('email');

    const [queue] = await pg.any<{ job_count: number }>(
      `SELECT job_count FROM app_jobs.job_queues WHERE queue_name = 'email'`
    );
    expect(queue.job_count).toBe(1);
  });

  it('lets two workers claim jobs that carried the shared literal', async () => {
    await addJob('shared_a', 'default');
    await addJob('shared_b', 'default');

    const first = await pg.one<{ id: string | null }>(
      `SELECT id FROM app_jobs.get_job('worker_one')`
    );
    const second = await pg.one<{ id: string | null }>(
      `SELECT id FROM app_jobs.get_job('worker_two')`
    );

    expect(first.id).not.toBeNull();
    expect(second.id).not.toBeNull();
    expect(second.id).not.toBe(first.id);
  });

  it('still serializes a name its author chose', async () => {
    await addJob('email_a', 'email');
    await addJob('email_b', 'email');

    const first = await pg.one<{ id: string | null }>(
      `SELECT id FROM app_jobs.get_job('worker_one')`
    );
    const second = await pg.one<{ id: string | null }>(
      `SELECT id FROM app_jobs.get_job('worker_two')`
    );

    expect(first.id).not.toBeNull();
    expect(second.id).toBeNull();
  });

  const addSchedule = async (task_identifier: string) =>
    pg.one<{ id: string }>(
      `INSERT INTO app_jobs.scheduled_jobs (database_id, task_identifier, queue_name, schedule_info)
       VALUES ($1, $2, 'default', $3)
       RETURNING id`,
      [database_id, task_identifier, { start: new Date(), rule: '*/1 * * * *' }]
    );

  it('spawns a scheduled job carrying the shared literal without a lock', async () => {
    const schedule = await addSchedule('scheduled_shared');

    const [job] = await pg.any<{ queue_name: string | null }>(
      `SELECT queue_name FROM app_jobs.run_scheduled_job($1)`,
      [schedule.id]
    );

    expect(job.queue_name).toBeNull();
  });

  // A schedule's protection against overlapping itself is its own, and does not
  // come from the queue: run_scheduled_job refuses a tick while the previous
  // one is still running. Dropping the shared queue therefore lets *different*
  // schedules overlap, never a schedule with itself.
  it('refuses a second tick while the first is still running', async () => {
    const schedule = await addSchedule('scheduled_reentrant');

    const [job] = await pg.any<{ id: string }>(
      `SELECT id FROM app_jobs.run_scheduled_job($1)`,
      [schedule.id]
    );
    await pg.any(
      `UPDATE app_jobs.jobs SET locked_at = now(), locked_by = 'worker_one' WHERE id = $1`,
      [job.id]
    );

    await expect(
      pg.any(`SELECT id FROM app_jobs.run_scheduled_job($1)`, [schedule.id])
    ).rejects.toThrow('ALREADY_SCHEDULED');
  });
});
