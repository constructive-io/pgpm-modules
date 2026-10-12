import { getConnections, PgTestClient } from 'pgsql-test';
import type { PgTestConnector } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;
let manager: PgTestConnector;

const after = '2026-09-29T07:04:30Z';

const nextRun = async (schedule_info: unknown) => {
  const row = await pg.one(
    `SELECT app_jobs.schedule_next_run($1::json, $2::timestamptz) AS next_run_at`,
    [JSON.stringify(schedule_info), after]
  );
  return row.next_run_at === null ? null : (row.next_run_at as Date).toISOString();
};

const schedule = async (key: string, rule = '0 0 4 * * *', task = 'transport_job') =>
  pg.one(
    `INSERT INTO app_jobs.scheduled_jobs (task_identifier, schedule_info, key)
     VALUES ($1, $2::json, $3)
     RETURNING *`,
    [task, JSON.stringify({ rule }), key]
  );

const fire = async (batch_size: number, client: PgTestClient = pg) =>
  (await client.one(`SELECT app_jobs.fire_due_scheduled_jobs($1) AS result`, [batch_size])).result;

const makeDue = async (ids: Array<string | number>) =>
  pg.any(`UPDATE app_jobs.scheduled_jobs SET next_run_at = now() - interval '1 second' WHERE id = ANY($1::bigint[])`, [
    ids,
  ]);

const dueCount = async () =>
  Number((await pg.one(`SELECT count(*) AS n FROM app_jobs.scheduled_jobs WHERE next_run_at <= now()`)).n);

const spawnedKeys = async () =>
  (await pg.any(`SELECT key FROM app_jobs.jobs WHERE task_identifier = 'transport_job' ORDER BY key`)).map(
    (j) => j.key as string
  );

describe('app_jobs.schedule_next_run', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
  });

  afterAll(async () => {
    await teardown();
  });

  it('evaluates six-field cron rules (seconds first) on the UTC clock', async () => {
    expect(await nextRun({ rule: '0 * * * * *' })).toBe('2026-09-29T07:05:00.000Z');
    expect(await nextRun({ rule: '0 */15 * * * *' })).toBe('2026-09-29T07:15:00.000Z');
    expect(await nextRun({ rule: '0 30 * * * *' })).toBe('2026-09-29T07:30:00.000Z');
    expect(await nextRun({ rule: '0 0 2 1 * *' })).toBe('2026-10-01T02:00:00.000Z');
    expect(await nextRun({ rule: '0 0 9 * * MON-FRI' })).toBe('2026-09-29T09:00:00.000Z');
    expect(await nextRun({ rule: '0 0 0 * * 7' })).toBe('2026-10-04T00:00:00.000Z');
    expect(await nextRun({ rule: '0 0 0 29 2 *' })).toBe('2028-02-29T00:00:00.000Z');
  });

  it('evaluates five-field cron rules at minute resolution', async () => {
    expect(await nextRun({ rule: '*/5 * * * *' })).toBe('2026-09-29T07:05:00.000Z');
    expect(await nextRun({ rule: '15 10 * * 1' })).toBe('2026-10-05T10:15:00.000Z');
  });

  it('evaluates node-schedule recurrence objects', async () => {
    expect(await nextRun({ second: 0, minute: [0, 30], hour: 9, dayOfWeek: [1, 2, 3] })).toBe(
      '2026-09-29T09:00:00.000Z'
    );
    expect(await nextRun({ minute: { start: 0, end: 59, step: 20 } })).toBe('2026-09-29T07:20:00.000Z');
    expect(await nextRun({ month: 0, date: 1 })).toBe('2027-01-01T00:00:00.000Z');
    expect(await nextRun({})).toBe('2026-09-29T07:05:00.000Z');
  });

  it('honours start/end windows', async () => {
    expect(await nextRun({ rule: '*/1 * * * *', start: '2026-10-01T00:00:30Z', end: '2026-10-01T00:05:00Z' })).toBe(
      '2026-10-01T00:01:00.000Z'
    );
    expect(await nextRun({ rule: '*/1 * * * *', end: '2026-09-29T07:04:40Z' })).toBeNull();
  });

  it('rejects rules it cannot evaluate instead of guessing', async () => {
    await expect(nextRun({ rule: '0 0 L * *' })).rejects.toThrow('SCHEDULE_RULE_INVALID');
    await expect(nextRun({ rule: 'every day' })).rejects.toThrow('SCHEDULE_RULE_INVALID');
    await expect(nextRun({ rule: '0 0 0 31 2 *' })).rejects.toThrow('SCHEDULE_RULE_UNSATISFIABLE');
  });
});

describe('scheduled_jobs clock: next_run_at and fire_due_scheduled_jobs(batch_size)', () => {
  let other: PgTestClient;

  beforeAll(async () => {
    ({ pg, teardown, manager } = await getConnections());
    other = manager.getClient(pg.config);
    await pg.any(`
      CREATE FUNCTION app_jobs.tg_test_reject_poison() RETURNS trigger AS $$
      BEGIN
        IF NEW.task_identifier = 'poison_job' THEN
          RAISE EXCEPTION 'POISON_JOB_REJECTED';
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER test_reject_poison BEFORE INSERT ON app_jobs.jobs
        FOR EACH ROW EXECUTE FUNCTION app_jobs.tg_test_reject_poison();
    `);
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.any(`DELETE FROM app_jobs.jobs`);
    await pg.any(`DELETE FROM app_jobs.scheduled_jobs`);
  });

  afterEach(async () => {
    const { n } = await pg.one(`SELECT count(*) AS n FROM app_jobs.jobs WHERE task_identifier = 'scheduled_jobs:tick'`);
    expect(Number(n)).toBe(0);
  });

  it('stamps next_run_at on insert and rejects invalid rules at insert', async () => {
    const sched = await schedule('clock:stamp');
    expect(sched.next_run_at).not.toBeNull();
    expect(new Date(sched.next_run_at).getUTCHours()).toBe(4);

    await expect(schedule('clock:bad', 'not a rule')).rejects.toThrow('SCHEDULE_RULE_INVALID');
  });

  it('fires at most batch_size due schedules per call and drains over successive calls', async () => {
    const rows = [];
    for (let i = 0; i < 5; i++) rows.push(await schedule(`clock:batch-${i}`));
    await makeDue(rows.map((r) => r.id));

    expect(await fire(2)).toEqual({ fired: 2, skipped: 0, failed: 0, processed: 2 });
    expect(await spawnedKeys()).toHaveLength(2);
    expect(await dueCount()).toBe(3);

    expect((await fire(2)).processed).toBe(2);
    expect((await fire(2)).processed).toBe(1);
    expect(await fire(2)).toEqual({ fired: 0, skipped: 0, failed: 0, processed: 0 });
    expect(await spawnedKeys()).toEqual(rows.map((r) => r.key).sort());
  });

  it('partitions due rows between concurrent callers: every due row fires exactly once', async () => {
    const rows = [];
    for (let i = 0; i < 4; i++) rows.push(await schedule(`clock:concurrent-${i}`));
    await makeDue(rows.map((r) => r.id));

    await pg.any('BEGIN');
    try {
      expect((await fire(2)).processed).toBe(2);
      // the first caller still holds its two rows; SKIP LOCKED hands the
      // second caller the rest without waiting
      expect(await fire(10, other)).toMatchObject({ fired: 2, failed: 0, processed: 2 });
    } finally {
      await pg.any('COMMIT');
    }

    expect(await fire(10)).toMatchObject({ processed: 0 });
    const spawned = await pg.any(
      `SELECT key, count(*) AS n FROM app_jobs.jobs WHERE task_identifier = 'transport_job' GROUP BY key ORDER BY key`
    );
    expect(spawned.map((j) => [j.key, Number(j.n)])).toEqual(rows.map((r) => [r.key, 1]).sort());
  });

  it('makes a committed batch claimable before the rest of the due set fires', async () => {
    const rows = [];
    for (let i = 0; i < 3; i++) rows.push(await schedule(`clock:visible-${i}`));
    await makeDue(rows.map((r) => r.id));

    expect((await fire(1)).processed).toBe(1);

    const claimed = await other.one(`SELECT * FROM app_jobs.get_job('worker-b', ARRAY['transport_job'])`);
    expect(claimed.id).not.toBeNull();
    expect(claimed.key).toBe(rows[0].key);

    const unfired = await pg.any(
      `SELECT key FROM app_jobs.scheduled_jobs WHERE next_run_at <= now() AND last_scheduled_id IS NULL ORDER BY key`
    );
    expect(unfired.map((r) => r.key)).toEqual([rows[1].key, rows[2].key]);
  });

  it('isolates a failing schedule, records its error and still advances it', async () => {
    const good = await schedule('clock:good');
    const poison = await schedule('clock:poison', '0 0 4 * * *', 'poison_job');
    const future = await schedule('clock:future');
    await makeDue([good.id, poison.id]);

    expect(await fire(10)).toEqual({ fired: 1, skipped: 0, failed: 1, processed: 2 });

    const spawned = await pg.any(`SELECT * FROM app_jobs.jobs WHERE task_identifier = 'transport_job'`);
    expect(spawned).toHaveLength(1);
    expect(spawned[0].key).toBe('clock:good');

    const rows = await pg.any(`SELECT * FROM app_jobs.scheduled_jobs ORDER BY id`);
    const byKey = Object.fromEntries(rows.map((r) => [r.key, r]));
    expect(byKey['clock:good'].last_error).toBeNull();
    expect(byKey['clock:good'].last_scheduled_id).toBe(spawned[0].id);
    expect(byKey['clock:poison'].last_error).toContain('POISON_JOB_REJECTED');
    expect(byKey['clock:poison'].last_error_at).not.toBeNull();
    expect(byKey['clock:poison'].last_scheduled_id).toBeNull();
    expect(new Date(byKey['clock:poison'].next_run_at).getTime()).toBeGreaterThan(Date.now());
    expect(new Date(byKey['clock:good'].next_run_at).getTime()).toBeGreaterThan(Date.now());
    expect(byKey['clock:future'].next_run_at).toEqual(future.next_run_at);

    expect((await fire(10)).processed).toBe(0);
  });

  it('treats a schedule whose previous job is still pending as a no-op, not an error', async () => {
    const sched = await schedule('clock:pending');
    await makeDue([sched.id]);
    expect(await fire(10)).toMatchObject({ fired: 1, failed: 0 });

    await makeDue([sched.id]);
    expect(await fire(10)).toEqual({ fired: 0, skipped: 1, failed: 0, processed: 1 });
    const row = await pg.one(`SELECT last_error FROM app_jobs.scheduled_jobs WHERE id = $1`, [sched.id]);
    expect(row.last_error).toBeNull();
    expect(await spawnedKeys()).toEqual(['clock:pending']);
  });

  it('rejects a batch_size that is not positive', async () => {
    await expect(fire(0)).rejects.toThrow('SCHEDULE_BATCH_SIZE_INVALID');
    await expect(fire(-1)).rejects.toThrow('SCHEDULE_BATCH_SIZE_INVALID');
  });
});

describe('scheduled task holds: hold_scheduled_task / release_scheduled_task', () => {
  const HELD = 'usage:collect_prometheus';
  let other: PgTestClient;

  const heldJobs = async () =>
    Number((await pg.one(`SELECT count(*) AS n FROM app_jobs.jobs WHERE task_identifier = $1`, [HELD])).n);
  const hold = async (client: PgTestClient = pg) =>
    (await client.one(`SELECT app_jobs.hold_scheduled_task($1, 'collector-disabled') AS n`, [HELD])).n;
  const release = async () => (await pg.one(`SELECT app_jobs.release_scheduled_task($1) AS n`, [HELD])).n;
  const heldRows = async () =>
    pg.any(`SELECT * FROM app_jobs.scheduled_jobs WHERE task_identifier = $1 ORDER BY key`, [HELD]);

  beforeAll(async () => {
    ({ pg, teardown, manager } = await getConnections());
    other = manager.getClient(pg.config);
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'false', false)`);
    await other.any(`SELECT set_config('jwt.strict_attribution', 'false', false)`);
  });

  afterAll(async () => {
    await teardown();
  });

  beforeEach(async () => {
    await pg.any(`DELETE FROM app_jobs.jobs`);
    await pg.any(`DELETE FROM app_jobs.scheduled_jobs`);
    await pg.any(`DELETE FROM app_jobs.scheduled_task_holds`);
  });

  it('held → no job, released → job within a minute, held again → stops', async () => {
    const a = await schedule('hold:a', '0 * * * * *', HELD);
    await schedule('hold:b', '0 * * * * *', HELD);
    const unrelated = await schedule('hold:unrelated', '0 * * * * *');

    // disabled: every row of the task goes dormant; other tasks keep firing
    expect(await hold()).toBe(2);
    expect((await heldRows()).map((r) => r.next_run_at)).toEqual([null, null]);
    await makeDue([unrelated.id]);
    await pg.any(`UPDATE app_jobs.scheduled_jobs SET next_run_at = now() - interval '1 second' WHERE next_run_at IS NOT NULL`);
    expect(await fire(100)).toMatchObject({ fired: 1, failed: 0, processed: 1 });
    expect(await heldJobs()).toBe(0);
    expect(await spawnedKeys()).toEqual(['hold:unrelated']);

    // a schedule registered while held starts dormant; holding again is a no-op
    const late = await schedule('hold:late', '0 * * * * *', HELD);
    expect(late.next_run_at).toBeNull();
    expect(await hold()).toBe(0);
    expect(await fire(100)).toMatchObject({ processed: 0 });
    expect(await heldJobs()).toBe(0);

    // enabled: every row is re-stamped to its next minute boundary and fires
    const { released_at: releasedAt } = await pg.one(`SELECT now() AS released_at`);
    expect(await release()).toBe(3);
    for (const row of await heldRows()) {
      const next = new Date(row.next_run_at).getTime();
      expect(next).toBeGreaterThan(new Date(releasedAt).getTime());
      expect(next - new Date(releasedAt).getTime()).toBeLessThanOrEqual(60_000);
      expect(new Date(row.next_run_at).getUTCSeconds()).toBe(0);
    }
    expect(await release()).toBe(0);
    await makeDue((await heldRows()).map((r) => r.id));
    expect(await fire(100)).toMatchObject({ fired: 3, failed: 0, processed: 3 });
    expect(await heldJobs()).toBe(3);

    // disabled again: no further job, even once the rows would be due
    await pg.any(`DELETE FROM app_jobs.jobs WHERE task_identifier = $1`, [HELD]);
    expect(await hold()).toBe(3);
    expect(await fire(100)).toMatchObject({ processed: 0 });
    expect(await heldJobs()).toBe(0);
    const reruled = await pg.one(
      `UPDATE app_jobs.scheduled_jobs SET schedule_info = '{"rule":"0 */5 * * * *"}'::json WHERE id = $1 RETURNING next_run_at`,
      [a.id]
    );
    expect(reruled.next_run_at).toBeNull();
  });

  it('a hold placed while the clock is firing the row takes effect once that batch commits', async () => {
    const row = await schedule('hold:inflight', '0 * * * * *', HELD);
    await makeDue([row.id]);

    await pg.any('BEGIN');
    let held: Promise<unknown>;
    try {
      expect(await fire(10)).toMatchObject({ fired: 1, processed: 1 });
      held = hold(other);
    } finally {
      await pg.any('COMMIT');
    }
    expect(await held!).toBe(1);

    const after = await pg.one(`SELECT next_run_at FROM app_jobs.scheduled_jobs WHERE id = $1`, [row.id]);
    expect(after.next_run_at).toBeNull();
    expect(await heldJobs()).toBe(1);
    expect(await fire(10)).toMatchObject({ processed: 0 });
  });

  it('rejects a null task identifier', async () => {
    await expect(pg.one(`SELECT app_jobs.hold_scheduled_task(NULL) AS n`)).rejects.toThrow(
      'SCHEDULED_TASK_IDENTIFIER_REQUIRED'
    );
    await expect(pg.one(`SELECT app_jobs.release_scheduled_task(NULL) AS n`)).rejects.toThrow(
      'SCHEDULED_TASK_IDENTIFIER_REQUIRED'
    );
  });
});
