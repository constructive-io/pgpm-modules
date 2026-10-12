import { getConnections, PgTestClient } from 'pgsql-test';
import type { GetConnectionResult } from 'pgsql-test';

/**
 * get_job takes a named queue's job_queues row before its head job, with
 * SKIP LOCKED on both, and a claimer that finds a queue taken or changing
 * hands moves on to the next candidate. One job in flight per named queue, claimed in
 * (priority, run_at, id) order, must hold under many concurrent claimers,
 * through expiry, release and completion.
 */

let pg: PgTestClient;
let manager: GetConnectionResult['manager'];
let teardown: () => Promise<void>;

const database_id = '5b720132-17d5-424d-9bcb-ee7b17c13d43';

const addJobFrom = async (client: PgTestClient, identifier: string, queue_name: string | null) => {
  const [job] = await client.any<{ id: string; queue_name: string | null }>(
    `SELECT * FROM app_jobs.add_job(
      identifier := $1::text,
      queue_name := $2::text,
      db_id := $3::uuid
    )`,
    [identifier, queue_name, database_id]
  );
  return job;
};

const addJob = (identifier: string, queue_name: string | null) => addJobFrom(pg, identifier, queue_name);

const extras: PgTestClient[] = [];
const extraClient = () => {
  const client = manager.getClient(pg.config);
  extras.push(client);
  return client;
};

const claim = (client: PgTestClient, worker: string) =>
  client.one<{ id: string | null; queue_name: string | null; task_identifier: string | null }>(
    `SELECT id, queue_name, task_identifier FROM app_jobs.get_job($1)`,
    [worker]
  );

describe('get_job claims a named queue, queue row first, then its head job', () => {
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

  afterEach(async () => {
    await Promise.all(extras.splice(0).map((client) => client.close()));
  });

  it('skips a locked queue and claims the next free one in priority order', async () => {
    await addJob('held_first', 'held');
    await addJob('held_second', 'held');
    await addJob('free_first', 'free');
    await addJob('unnamed', null);

    expect((await claim(pg, 'worker_one')).task_identifier).toBe('held_first');
    expect((await claim(pg, 'worker_two')).task_identifier).toBe('free_first');
    expect((await claim(pg, 'worker_three')).task_identifier).toBe('unnamed');
    expect((await claim(pg, 'worker_four')).id).toBeNull();

    const queues = await pg.any<{ queue_name: string; locked_by: string | null }>(
      `SELECT queue_name, locked_by FROM app_jobs.job_queues ORDER BY queue_name`
    );
    expect(queues).toEqual([
      { queue_name: 'free', locked_by: 'worker_two' },
      { queue_name: 'held', locked_by: 'worker_one' },
    ]);
  });

  it('complete_job frees the queue for the next job on it', async () => {
    await addJob('first', 'serial');
    await addJob('second', 'serial');

    const first = await claim(pg, 'worker_one');
    expect((await claim(pg, 'worker_two')).id).toBeNull();

    await pg.any(`SELECT app_jobs.complete_job('worker_one', $1::bigint)`, [first.id]);

    const second = await claim(pg, 'worker_two');
    expect(second.task_identifier).toBe('second');
    expect(second.queue_name).toBe('serial');
  });

  it('release_jobs frees the queue and the job for another worker', async () => {
    await addJob('only', 'serial');

    const first = await claim(pg, 'worker_one');
    expect(first.task_identifier).toBe('only');

    await pg.any(`SELECT app_jobs.release_jobs('worker_one')`);

    const again = await claim(pg, 'worker_two');
    expect(again.id).toBe(first.id);
    const queue = await pg.one<{ locked_by: string }>(
      `SELECT locked_by FROM app_jobs.job_queues WHERE queue_name = 'serial'`
    );
    expect(queue.locked_by).toBe('worker_two');
  });

  it('takes over a queue whose lock has expired, but respects a live one', async () => {
    const job = await addJob('orphaned', 'serial');
    await pg.any(
      `UPDATE app_jobs.job_queues
       SET locked_by = 'dead_worker', locked_at = now() - interval '5 hours'
       WHERE queue_name = 'serial'`
    );

    const reclaimed = await claim(pg, 'worker_one');
    expect(reclaimed.id).toBe(job.id);
    const queue = await pg.one<{ locked_by: string }>(
      `SELECT locked_by FROM app_jobs.job_queues WHERE queue_name = 'serial'`
    );
    expect(queue.locked_by).toBe('worker_one');

    await pg.any(`SELECT app_jobs.release_jobs('worker_one')`);
    await pg.any(
      `UPDATE app_jobs.job_queues
       SET locked_by = 'live_worker', locked_at = now()
       WHERE queue_name = 'serial'`
    );
    expect((await claim(pg, 'worker_two')).id).toBeNull();
  });

  it('reclaims a job whose worker died holding it once its lock expires, named or not', async () => {
    const named = await addJob('stranded_named', 'serial');
    const unnamed = await addJob('stranded_unnamed', null);
    expect((await claim(pg, 'dead_worker')).id).toBe(named.id);
    expect((await claim(pg, 'dead_worker')).id).toBe(unnamed.id);
    expect((await claim(pg, 'worker_one')).id).toBeNull();

    await pg.any(
      `UPDATE app_jobs.jobs SET locked_at = now() - interval '5 hours' WHERE locked_by = 'dead_worker'`
    );
    await pg.any(
      `UPDATE app_jobs.job_queues SET locked_at = now() - interval '5 hours' WHERE locked_by = 'dead_worker'`
    );

    expect((await claim(pg, 'worker_one')).id).toBe(named.id);
    expect((await claim(pg, 'worker_two')).id).toBe(unnamed.id);
    const rows = await pg.any<{ id: string; locked_by: string; attempts: number }>(
      `SELECT id, locked_by, attempts FROM app_jobs.jobs ORDER BY id`
    );
    expect(rows).toEqual([
      { id: named.id, locked_by: 'worker_one', attempts: 2 },
      { id: unnamed.id, locked_by: 'worker_two', attempts: 2 },
    ]);
    const queue = await pg.one<{ locked_by: string }>(
      `SELECT locked_by FROM app_jobs.job_queues WHERE queue_name = 'serial'`
    );
    expect(queue.locked_by).toBe('worker_one');
  });

  it('never locks a queue row while scanning candidates', async () => {
    await addJob('held', 'held');
    await addJob('free', 'free');

    await pg.any(`BEGIN`);
    expect((await claim(pg, 'worker_one')).task_identifier).toBe('held');
    const locks = await pg.any<{ relname: string; mode: string }>(
      `SELECT c.relname, l.mode
       FROM pg_locks AS l
       JOIN pg_class AS c ON c.oid = l.relation
       WHERE l.pid = pg_backend_pid() AND c.relname IN ('jobs', 'job_queues')
       ORDER BY c.relname, l.mode`
    );
    await pg.any(`ROLLBACK`);

    expect(locks).toEqual([
      { relname: 'job_queues', mode: 'AccessShareLock' },
      { relname: 'job_queues', mode: 'RowExclusiveLock' },
      { relname: 'job_queues', mode: 'RowShareLock' },
      { relname: 'jobs', mode: 'AccessShareLock' },
      { relname: 'jobs', mode: 'RowExclusiveLock' },
      { relname: 'jobs', mode: 'RowShareLock' },
    ]);
  });

  it('does not block on a queue row held by an open producer transaction', async () => {
    await addJob('held_committed', 'held');
    await addJob('free_committed', 'free');

    const producer = extraClient();
    await producer.any(`BEGIN`);
    await producer.any(`SELECT set_config('jwt.strict_attribution', 'false', true)`);
    await addJobFrom(producer, 'held_uncommitted', 'held');

    const claimer = extraClient();
    await claimer.any(`SET lock_timeout = '1s'`);
    expect((await claim(claimer, 'worker_one')).task_identifier).toBe('free_committed');
    expect((await claim(claimer, 'worker_two')).id).toBeNull();

    await producer.any(`ROLLBACK`);
    expect((await claim(claimer, 'worker_three')).task_identifier).toBe('held_committed');
  });

  it('walks past any number of busy queues to reach a claimable job', async () => {
    const held = 12;
    for (let q = 0; q < held; q++) {
      await addJob(`held_${q}`, `held_${q}`);
    }
    await addJob('free_tail', 'free_tail');

    const producers = Array.from({ length: held }, () => extraClient());
    for (let q = 0; q < held; q++) {
      await producers[q].any(`BEGIN`);
      await producers[q].any(`SELECT set_config('jwt.strict_attribution', 'false', true)`);
      await addJobFrom(producers[q], `held_${q}_pending`, `held_${q}`);
    }

    const claimer = extraClient();
    await claimer.any(`SET lock_timeout = '1s'`);
    expect((await claim(claimer, 'worker_one')).task_identifier).toBe('free_tail');
    expect((await claim(claimer, 'worker_two')).id).toBeNull();

    for (const producer of producers) {
      await producer.any(`ROLLBACK`);
    }
    expect((await claim(claimer, 'worker_three')).task_identifier).toBe('held_0');
  });

  it('skips a job whose queue row is gone and still claims the next free queue', async () => {
    await addJob('orphan', 'gone');
    await addJob('next_up', 'other');
    await pg.any(`DELETE FROM app_jobs.job_queues WHERE queue_name = 'gone'`);

    expect((await claim(pg, 'worker_one')).task_identifier).toBe('next_up');
    expect((await claim(pg, 'worker_two')).id).toBeNull();
  });

  it('keeps one job in flight per queue under 64 concurrent claimers', async () => {
    const queues = 16;
    const perQueue = 4;
    for (let q = 0; q < queues; q++) {
      for (let j = 0; j < perQueue; j++) {
        await addJob(`job_${q}_${j}`, `queue_${q}`);
      }
    }

    const claimers = Array.from({ length: 64 }, () => extraClient());
    const claimed = await Promise.all(
      claimers.map((client, i) => claim(client, `racer_${String(i).padStart(2, '0')}`))
    );

    const won = claimed.filter((row) => row.id !== null);
    expect(won).toHaveLength(queues);
    expect(new Set(won.map((row) => row.queue_name)).size).toBe(queues);

    const inFlight = await pg.any<{ queue_name: string; n: number }>(
      `SELECT queue_name, count(*)::int AS n
       FROM app_jobs.jobs
       WHERE locked_at IS NOT NULL
       GROUP BY queue_name`
    );
    expect(inFlight.every((row) => row.n === 1)).toBe(true);
    expect(inFlight).toHaveLength(queues);

    const lockedQueues = await pg.one<{ n: number }>(
      `SELECT count(*)::int AS n FROM app_jobs.job_queues WHERE locked_at IS NOT NULL`
    );
    expect(lockedQueues.n).toBe(queues);
  });

  it('never claims a later job on a queue while its head job row is locked elsewhere', async () => {
    const first = await addJob('first', 'serial');
    await addJob('second', 'serial');
    await addJob('other', 'other');

    const holder = extraClient();
    await holder.any(`BEGIN`);
    await holder.any(`SELECT id FROM app_jobs.jobs WHERE id = $1::bigint FOR UPDATE`, [first.id]);

    const claimer = extraClient();
    await claimer.any(`SET lock_timeout = '1s'`);
    expect((await claim(claimer, 'worker_one')).task_identifier).toBe('other');
    expect((await claim(claimer, 'worker_two')).id).toBeNull();
    const queue = await pg.one<{ locked_by: string | null }>(
      `SELECT locked_by FROM app_jobs.job_queues WHERE queue_name = 'serial'`
    );
    expect(queue.locked_by).toBeNull();

    await holder.any(`ROLLBACK`);
    expect((await claim(claimer, 'worker_three')).task_identifier).toBe('first');
  });

  it('moves on to a named job when every unnamed job is locked by another transaction', async () => {
    const unnamed = await addJob('unnamed', null);
    await addJob('named', 'serial');

    const holder = extraClient();
    await holder.any(`BEGIN`);
    await holder.any(`SELECT id FROM app_jobs.jobs WHERE id = $1::bigint FOR UPDATE`, [unnamed.id]);

    const claimer = extraClient();
    await claimer.any(`SET lock_timeout = '1s'`);
    expect((await claim(claimer, 'worker_one')).task_identifier).toBe('named');
    expect((await claim(claimer, 'worker_two')).id).toBeNull();

    await holder.any(`ROLLBACK`);
    expect((await claim(claimer, 'worker_three')).task_identifier).toBe('unnamed');
  });

  it('claims one hot queue in (priority, run_at, id) order under 16 concurrent claimers', async () => {
    const jobs = 96;
    for (let j = 0; j < jobs; j++) {
      await addJob(`hot_${j}`, 'hot');
    }

    const claimers = Array.from({ length: 16 }, () => extraClient());
    const order: number[] = [];
    await Promise.all(
      claimers.map(async (client, i) => {
        const worker = `hot_racer_${String(i).padStart(2, '0')}`;
        for (let polls = 0; order.length < jobs && polls < 4000; polls++) {
          const row = await claim(client, worker);
          if (row.id === null) {
            continue;
          }
          order.push(Number(row.id));
          await client.any(`SELECT app_jobs.complete_job($1, $2::bigint)`, [worker, row.id]);
        }
      })
    );

    expect(order).toHaveLength(jobs);
    expect(order).toEqual([...order].sort((a, b) => a - b));
  });
});
