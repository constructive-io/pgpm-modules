import { getConnections, PgTestClient } from 'pgsql-test';

/**
 * defer_jobs_for_worker hands a claimed job back unstarted — its function has
 * no active deployment yet — without spending the attempt the claim took.
 * This is the `fun up` race behind billing:sync_usage: a fanout child is
 * enqueued with max_attempts = 1, claimed before its billing deployment is
 * active, and a failure would leave it dead on its first and only attempt.
 */

let pg: PgTestClient;
let teardown: () => Promise<void>;

const database_id = '5b720132-17d5-424d-9bcb-ee7b17c13d43';

type Job = {
  id: string;
  queue_name: string | null;
  attempts: number;
  max_attempts: number;
  locked_by: string | null;
  last_error: string | null;
  deferred_at: string | null;
};

const addJob = async (identifier: string, queue_name: string | null = null, max_attempts = 1) => {
  const [job] = await pg.any<Job>(
    `SELECT * FROM app_jobs.add_job(
      identifier := $1::text,
      queue_name := $2::text,
      max_attempts := $3::int,
      db_id := $4::uuid
    )`,
    [identifier, queue_name, max_attempts, database_id]
  );
  return job;
};

const claim = async (worker: string) => {
  const [job] = await pg.any<Job>(`SELECT * FROM app_jobs.get_jobs($1, NULL::text[], 1)`, [worker]);
  return job;
};

const defer = (worker: string, ids: string[], reasons: string[]) =>
  pg.any<Job>(`SELECT * FROM app_jobs.defer_jobs_for_worker($1, $2::bigint[], $3::text[])`, [worker, ids, reasons]);

const jobRow = async (id: string) => {
  const [row] = await pg.any<Job & { delay: number }>(
    `SELECT *, extract(epoch FROM run_at - now())::float8 AS delay FROM app_jobs.jobs WHERE id = $1`,
    [id]
  );
  return row;
};

const makeDue = (id: string) => pg.any(`UPDATE app_jobs.jobs SET run_at = now() WHERE id = $1`, [id]);

const NO_DEPLOYMENT = 'NO_ACTIVE_DEPLOYMENT: no active deployment for image "functions/billing"';

describe('defer_jobs_for_worker', () => {
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

  it('a single-attempt job claimed before its deployment exists survives to run once it does', async () => {
    const { id } = await addJob('billing:sync_usage');

    expect(await claim('worker_one')).toMatchObject({ id, attempts: 1, max_attempts: 1 });
    const [deferred] = await defer('worker_one', [id], [NO_DEPLOYMENT]);

    expect(deferred).toMatchObject({
      id,
      attempts: 0,
      locked_by: null,
      last_error: `DEFERRED: ${NO_DEPLOYMENT}`,
    });
    expect(deferred.deferred_at).not.toBeNull();
    const row = await jobRow(id);
    expect(row.delay).toBeGreaterThan(0);
    expect(row.delay).toBeLessThanOrEqual(1);
    expect(await claim('worker_one')).toBeUndefined();

    await makeDue(id);
    expect(await claim('worker_two')).toMatchObject({ id, attempts: 1, locked_by: 'worker_two' });
    await pg.any(`SELECT app_jobs.complete_jobs_for_worker('worker_two', $1::bigint[])`, [[id]]);
    expect(await jobRow(id)).toBeUndefined();
  });

  it('failing the same claim instead spends its only attempt', async () => {
    const { id } = await addJob('billing:sync_usage');
    await claim('worker_one');
    await pg.any(`SELECT app_jobs.fail_jobs_for_worker('worker_one', $1::bigint[], $2::text[])`, [
      [id],
      ['No service URL'],
    ]);

    await makeDue(id);
    expect(await claim('worker_two')).toBeUndefined();
    expect(await jobRow(id)).toMatchObject({ attempts: 1, max_attempts: 1 });
  });

  it('keeps the first deferral and backs off for as long as the job has waited, capped at 30s', async () => {
    const { id } = await addJob('billing:sync_usage');
    await claim('worker_one');
    const [first] = await defer('worker_one', [id], [NO_DEPLOYMENT]);

    await pg.any(`UPDATE app_jobs.jobs SET deferred_at = deferred_at - interval '20 seconds', run_at = now() WHERE id = $1`, [id]);
    await claim('worker_one');
    const [second] = await defer('worker_one', [id], [NO_DEPLOYMENT]);
    expect(new Date(second.deferred_at as string).getTime()).toBe(
      new Date(first.deferred_at as string).getTime() - 20_000
    );
    const backedOff = await jobRow(id);
    expect(backedOff.attempts).toBe(0);
    expect(backedOff.delay).toBeGreaterThan(19);
    expect(backedOff.delay).toBeLessThanOrEqual(21);

    await pg.any(`UPDATE app_jobs.jobs SET deferred_at = deferred_at - interval '10 minutes', run_at = now() WHERE id = $1`, [id]);
    await claim('worker_one');
    await defer('worker_one', [id], [NO_DEPLOYMENT]);
    const capped = await jobRow(id);
    expect(capped.delay).toBeGreaterThan(29);
    expect(capped.delay).toBeLessThanOrEqual(30);
  });

  it('a failure ends the wait, so a later deferral starts a fresh one', async () => {
    const { id } = await addJob('billing:sync_usage', null, 3);
    await claim('worker_one');
    await defer('worker_one', [id], [NO_DEPLOYMENT]);
    await pg.any(`UPDATE app_jobs.jobs SET deferred_at = deferred_at - interval '1 hour', run_at = now() WHERE id = $1`, [id]);

    await claim('worker_one');
    await pg.any(`SELECT app_jobs.fail_jobs_for_worker('worker_one', $1::bigint[], $2::text[])`, [
      [id],
      ['handler returned 500'],
    ]);
    expect((await jobRow(id)).deferred_at).toBeNull();

    await makeDue(id);
    await claim('worker_one');
    const [again] = await defer('worker_one', [id], [NO_DEPLOYMENT]);
    expect(Date.now() - new Date(again.deferred_at as string).getTime()).toBeLessThan(60_000);
  });

  it('frees the named queue and ignores jobs the worker does not hold', async () => {
    const queued = await addJob('queued', 'serial', 5);
    const other = await addJob('other', null, 5);
    await claim('worker_one');
    await claim('worker_two');

    const deferred = await defer('worker_one', [queued.id, other.id], ['a', 'b']);
    expect(deferred.map((j) => j.id)).toEqual([queued.id]);
    expect(await pg.any(`SELECT queue_name, locked_by FROM app_jobs.job_queues`)).toEqual([
      { queue_name: 'serial', locked_by: null },
    ]);
    expect(await jobRow(other.id)).toMatchObject({ locked_by: 'worker_two', attempts: 1, deferred_at: null });
  });

  it('rejects duplicate ids and mismatched reasons', async () => {
    const { id } = await addJob('billing:sync_usage');
    await claim('worker_one');
    await expect(defer('worker_one', [id, id], ['a', 'b'])).rejects.toThrow('DUPLICATE_JOB_IDS');
    await expect(defer('worker_one', [id], [])).rejects.toThrow('JOB_DEFERRAL_ARRAYS_MISMATCH');
  });
});
