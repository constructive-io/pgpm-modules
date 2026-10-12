import { getConnections, PgTestClient } from 'pgsql-test';
import type { GetConnectionResult } from 'pgsql-test';

/**
 * Batch claim and completion for the worker: get_jobs(worker, tasks, n) takes
 * up to n unqueued jobs in one statement (n <= 1 is get_job, named queues
 * included), complete_jobs_for_worker / fail_jobs_for_worker finish or
 * release a worker's claimed jobs in one call and ignore ids the worker does
 * not hold.
 */

let pg: PgTestClient;
let manager: GetConnectionResult['manager'];
let teardown: () => Promise<void>;

const database_id = '5b720132-17d5-424d-9bcb-ee7b17c13d43';

type Job = {
  id: string;
  queue_name: string | null;
  task_identifier: string;
  priority: number;
  attempts: number;
  locked_by: string | null;
  locked_at: string | null;
  last_error: string | null;
  run_at: string;
};

const addJob = async (identifier: string, queue_name: string | null, priority = 0) => {
  const [job] = await pg.any<Job>(
    `SELECT * FROM app_jobs.add_job(
      identifier := $1::text,
      queue_name := $2::text,
      priority := $3::int,
      db_id := $4::uuid
    )`,
    [identifier, queue_name, priority, database_id]
  );
  return job;
};

const getJobs = (client: PgTestClient, worker: string, n: number | null, tasks: string[] | null = null) =>
  client.any<Job>(`SELECT * FROM app_jobs.get_jobs($1, $2::text[], $3::int)`, [worker, tasks, n]);

const jobsTable = () =>
  pg.any<Job>(`SELECT id, task_identifier, queue_name, attempts, locked_by, last_error FROM app_jobs.jobs ORDER BY id`);

const queueLocks = () =>
  pg.any<{ queue_name: string; locked_by: string | null }>(
    `SELECT queue_name, locked_by FROM app_jobs.job_queues ORDER BY queue_name`
  );

describe('batch claim and completion', () => {
  beforeAll(async () => {
    ({ pg, manager, teardown } = await getConnections());
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'false', false)`);
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.any(`DELETE FROM app_jobs.jobs`);
  });

  it('n <= 1 is get_job: one row, named queues included, none when nothing is claimable', async () => {
    await addJob('serial_first', 'serial');
    await addJob('serial_second', 'serial');
    await addJob('solo', null);

    const first = await getJobs(pg, 'worker_one', 1);
    expect(first.map((j) => j.task_identifier)).toEqual(['serial_first']);
    expect(first[0]).toMatchObject({ locked_by: 'worker_one', attempts: 1 });
    expect(first[0].locked_at).not.toBeNull();
    expect(await queueLocks()).toEqual([{ queue_name: 'serial', locked_by: 'worker_one' }]);

    expect((await getJobs(pg, 'worker_two', 0)).map((j) => j.task_identifier)).toEqual(['solo']);
    expect(await getJobs(pg, 'worker_three', null)).toEqual([]);
    expect(await pg.any(`SELECT id FROM app_jobs.get_jobs('worker_four')`)).toEqual([]);

    await pg.any(`SELECT app_jobs.complete_job('worker_one', $1::bigint)`, [first[0].id]);
    expect((await getJobs(pg, 'worker_three', 1)).map((j) => j.task_identifier)).toEqual(['serial_second']);
  });

  it('a batch takes only unqueued jobs, in claim order, stamped like get_job', async () => {
    await addJob('queued', 'serial');
    await addJob('late', null, 5);
    await addJob('early_a', null, 1);
    await addJob('early_b', null, 1);
    await addJob('middle', null, 3);
    await addJob('other_task', null, 0);

    const batch = await getJobs(pg, 'worker_one', 10, ['late', 'early_a', 'early_b', 'middle']);
    expect(batch.map((j) => j.task_identifier)).toEqual(['early_a', 'early_b', 'middle', 'late']);
    for (const job of batch) {
      expect(job).toMatchObject({ queue_name: null, locked_by: 'worker_one', attempts: 1 });
      expect(job.locked_at).not.toBeNull();
    }

    expect(await getJobs(pg, 'worker_two', 10, ['late'])).toEqual([]);
    expect((await getJobs(pg, 'worker_two', 10)).map((j) => j.task_identifier)).toEqual(['other_task']);

    const rows = await jobsTable();
    expect(rows.find((j) => j.task_identifier === 'queued')).toMatchObject({ locked_by: null, attempts: 0 });
    expect(await queueLocks()).toEqual([{ queue_name: 'serial', locked_by: null }]);
  });

  it('a batch reclaims unqueued jobs whose lock has expired', async () => {
    await addJob('stranded_a', null);
    await addJob('stranded_b', null);
    expect(await getJobs(pg, 'dead_worker', 10)).toHaveLength(2);
    expect(await getJobs(pg, 'worker_one', 10)).toEqual([]);

    await pg.any(`UPDATE app_jobs.jobs SET locked_at = now() - interval '5 hours'`);

    const batch = await getJobs(pg, 'worker_one', 10);
    expect(batch.map((j) => j.task_identifier)).toEqual(['stranded_a', 'stranded_b']);
    for (const job of batch) {
      expect(job).toMatchObject({ locked_by: 'worker_one', attempts: 2 });
    }
  });

  it('n caps the batch and the rest stays claimable', async () => {
    for (let i = 0; i < 5; i++) {
      await addJob(`bulk_${i}`, null);
    }
    expect((await getJobs(pg, 'worker_one', 2)).map((j) => j.task_identifier)).toEqual(['bulk_0', 'bulk_1']);
    expect((await getJobs(pg, 'worker_two', 2)).map((j) => j.task_identifier)).toEqual(['bulk_2', 'bulk_3']);
    expect((await getJobs(pg, 'worker_three', 2)).map((j) => j.task_identifier)).toEqual(['bulk_4']);
    expect(await getJobs(pg, 'worker_four', 2)).toEqual([]);
  });

  it('returns every row with its own identity columns', async () => {
    await addJob('a', null);
    await addJob('b', null);
    const batch = await pg.any<{ database_id: string; task_identifier: string }>(
      `SELECT database_id, task_identifier FROM app_jobs.get_jobs('worker_one', NULL, 10)`
    );
    expect(batch).toEqual([
      { database_id, task_identifier: 'a' },
      { database_id, task_identifier: 'b' },
    ]);
  });

  it('complete_jobs_for_worker removes only the jobs the worker holds and frees their queues', async () => {
    await addJob('queued', 'serial');
    await addJob('queued_next', 'serial');
    await addJob('mine_a', null);
    await addJob('mine_b', null);
    await addJob('theirs', null);

    const [queued] = await getJobs(pg, 'worker_one', 1);
    const mine = await getJobs(pg, 'worker_one', 2);
    const [theirs] = await getJobs(pg, 'worker_two', 1);
    expect([queued.task_identifier, ...mine.map((j) => j.task_identifier), theirs.task_identifier]).toEqual([
      'queued',
      'mine_a',
      'mine_b',
      'theirs',
    ]);

    const completed = await pg.any<Job>(
      `SELECT task_identifier FROM app_jobs.complete_jobs_for_worker($1, $2::bigint[]) ORDER BY id`,
      ['worker_one', [queued.id, ...mine.map((j) => j.id), theirs.id, '999999999']]
    );
    expect(completed.map((j) => j.task_identifier)).toEqual(['queued', 'mine_a', 'mine_b']);

    const rows = await jobsTable();
    expect(rows.map((j) => [j.task_identifier, j.locked_by])).toEqual([
      ['queued_next', null],
      ['theirs', 'worker_two'],
    ]);
    expect(await queueLocks()).toEqual([{ queue_name: 'serial', locked_by: null }]);
    expect((await getJobs(pg, 'worker_three', 1)).map((j) => j.task_identifier)).toEqual(['queued_next']);

    expect(await pg.any(`SELECT id FROM app_jobs.complete_jobs_for_worker('worker_one', NULL)`)).toEqual([]);
  });

  it('fail_jobs_for_worker releases only the jobs the worker holds, each with its own error', async () => {
    await addJob('queued', 'serial');
    await addJob('mine_a', null);
    await addJob('mine_b', null);
    await addJob('theirs', null);

    const [queued] = await getJobs(pg, 'worker_one', 1);
    const mine = await getJobs(pg, 'worker_one', 2);
    const [theirs] = await getJobs(pg, 'worker_two', 1);

    const failed = await pg.any<Job & { rescheduled: boolean }>(
      `SELECT task_identifier, last_error, attempts, locked_by, locked_at, run_at > now() AS rescheduled
         FROM app_jobs.fail_jobs_for_worker($1, $2::bigint[], $3::text[]) ORDER BY id`,
      ['worker_one', [queued.id, mine[0].id, theirs.id, mine[1].id], ['queue boom', 'boom a', 'not mine', 'boom b']]
    );
    expect(failed).toEqual([
      { task_identifier: 'queued', last_error: 'queue boom', attempts: 1, locked_by: null, locked_at: null, rescheduled: true },
      { task_identifier: 'mine_a', last_error: 'boom a', attempts: 1, locked_by: null, locked_at: null, rescheduled: true },
      { task_identifier: 'mine_b', last_error: 'boom b', attempts: 1, locked_by: null, locked_at: null, rescheduled: true },
    ]);

    const rows = await jobsTable();
    expect(rows.find((j) => j.task_identifier === 'theirs')).toMatchObject({ locked_by: 'worker_two', last_error: null });
    expect(await queueLocks()).toEqual([{ queue_name: 'serial', locked_by: null }]);
    expect(await getJobs(pg, 'worker_three', 10)).toEqual([]);

    await expect(
      pg.any(`SELECT * FROM app_jobs.fail_jobs_for_worker('worker_two', $1::bigint[], ARRAY['one', 'two'])`, [[theirs.id]])
    ).rejects.toThrow('JOB_FAILURE_ARRAYS_MISMATCH');
    await expect(
      pg.any(`SELECT * FROM app_jobs.fail_jobs_for_worker('worker_two', $1::bigint[], NULL)`, [[theirs.id]])
    ).rejects.toThrow('JOB_FAILURE_ARRAYS_MISMATCH');
    expect(await pg.any(`SELECT id FROM app_jobs.fail_jobs_for_worker('worker_two', NULL, NULL)`)).toEqual([]);
  });

  it('rejects duplicate job ids without touching any job', async () => {
    await addJob('mine_a', null);
    await addJob('mine_b', null);
    const mine = await getJobs(pg, 'worker_one', 2);
    const ids = [mine[0].id, mine[1].id, mine[0].id];

    await expect(
      pg.any(`SELECT * FROM app_jobs.complete_jobs_for_worker('worker_one', $1::bigint[])`, [ids])
    ).rejects.toThrow('DUPLICATE_JOB_IDS');
    await expect(
      pg.any(`SELECT * FROM app_jobs.fail_jobs_for_worker('worker_one', $1::bigint[], ARRAY['a', 'b', 'c'])`, [ids])
    ).rejects.toThrow('DUPLICATE_JOB_IDS');

    const rows = await jobsTable();
    expect(rows.map((j) => [j.task_identifier, j.locked_by, j.last_error])).toEqual([
      ['mine_a', 'worker_one', null],
      ['mine_b', 'worker_one', null],
    ]);
    expect(
      (await pg.any<Job>(`SELECT id FROM app_jobs.complete_jobs_for_worker('worker_one', $1::bigint[])`, [[mine[0].id, mine[1].id]])).length
    ).toBe(2);
  });

  it('rejects a NULL worker id', async () => {
    await expect(pg.any(`SELECT * FROM app_jobs.get_jobs(NULL, NULL, 10)`)).rejects.toThrow('INVALID_WORKER_ID');
    await expect(pg.any(`SELECT * FROM app_jobs.complete_jobs_for_worker(NULL, ARRAY[1]::bigint[])`)).rejects.toThrow(
      'INVALID_WORKER_ID'
    );
    await expect(
      pg.any(`SELECT * FROM app_jobs.fail_jobs_for_worker(NULL, ARRAY[1]::bigint[], ARRAY['x'])`)
    ).rejects.toThrow('INVALID_WORKER_ID');
  });

  it('64 concurrent batch claimers never claim a job twice and complete everything', async () => {
    const total = 640;
    await pg.any(
      `SELECT app_jobs.add_job(identifier := 'bulk_' || i, db_id := $1::uuid) FROM generate_series(1, $2::int) AS i`,
      [database_id, total]
    );

    const workers = Array.from({ length: 64 }, (_, i) => ({
      id: `batch_worker_${i}`,
      client: manager.getClient(pg.config),
    }));
    const claimed = await Promise.all(workers.map((w) => getJobs(w.client, w.id, 10)));
    const ids = claimed.flat().map((j) => j.id);
    expect(ids.length).toBe(total);
    expect(new Set(ids).size).toBe(total);
    for (let i = 0; i < workers.length; i++) {
      for (const job of claimed[i]) {
        expect(job.locked_by).toBe(workers[i].id);
      }
    }

    const completed = await Promise.all(
      workers.map((w, i) =>
        w.client.any<{ id: string }>(`SELECT id FROM app_jobs.complete_jobs_for_worker($1, $2::bigint[])`, [
          w.id,
          claimed[i].map((j) => j.id),
        ])
      )
    );
    expect(completed.flat().length).toBe(total);
    expect(await jobsTable()).toEqual([]);
  });
});
