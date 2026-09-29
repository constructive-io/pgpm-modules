import { getConnections, PgTestClient } from 'pgsql-test';

let pg: PgTestClient;
let teardown: () => Promise<void>;


// Mirrors compute_private.fn_invocations_cron_fire: a BEFORE INSERT trigger
// that enqueues the executable job through its own ledger path, records that
// job on the schedule, and suppresses the raw transport row by returning NULL.
const installFireTrigger = async () => {
  await pg.any(`
    CREATE FUNCTION app_jobs.tg_test_cron_fire() RETURNS trigger AS $$
    DECLARE
      v_job_id bigint;
    BEGIN
      IF NEW.key IS NULL OR NEW.key NOT LIKE 'suppressed:%' THEN
        RETURN NEW;
      END IF;
      INSERT INTO app_jobs.jobs (task_identifier, payload)
        VALUES ('ledger_job', jsonb_build_object('fired_from', NEW.key))
        RETURNING id INTO v_job_id;
      UPDATE app_jobs.scheduled_jobs s
        SET last_scheduled_id = v_job_id
        WHERE s.key = NEW.key;
      RETURN NULL;
    END
    $$ LANGUAGE plpgsql;
    CREATE TRIGGER test_cron_fire BEFORE INSERT ON app_jobs.jobs
      FOR EACH ROW EXECUTE FUNCTION app_jobs.tg_test_cron_fire();
  `);
};

describe('run_scheduled_job when a fire trigger suppresses the transport row', () => {
  beforeAll(async () => {
    ({ pg, teardown } = await getConnections());
    await pg.any(`SELECT set_config('jwt.strict_attribution', 'false', false)`);
    await installFireTrigger();
  });

  afterAll(async () => {
    await teardown();
  });

  const schedule = async (key: string) =>
    pg.one(
      `INSERT INTO app_jobs.scheduled_jobs (task_identifier, schedule_info, key)
       VALUES ('transport_job', '{"rule": "* * * * *"}', $1)
       RETURNING *`,
      [key]
    );

  it('returns the ledger-enqueued job on every tick, so the scheduler keeps the schedule', async () => {
    const sched = await schedule('suppressed:keeps-ticking');

    const first = await pg.one(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [sched.id]);
    expect(first.id).not.toBeNull();
    expect(first.task_identifier).toBe('ledger_job');
    expect(first.payload).toEqual({ fired_from: 'suppressed:keeps-ticking' });

    const after = await pg.one(`SELECT last_scheduled_id, last_scheduled FROM app_jobs.scheduled_jobs WHERE id = $1`, [sched.id]);
    expect(String(after.last_scheduled_id)).toBe(String(first.id));
    expect(after.last_scheduled).not.toBeNull();

    // release the first tick's job the way the worker would, then tick again
    await pg.any(`DELETE FROM app_jobs.jobs WHERE id = $1`, [first.id]);
    const second = await pg.one(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [sched.id]);
    expect(second.id).not.toBeNull();
    expect(String(second.id)).not.toBe(String(first.id));
    expect(second.task_identifier).toBe('ledger_job');
  });

  it('still returns a null record when the schedule itself is gone', async () => {
    const sched = await schedule('suppressed:deleted');
    await pg.any(`DELETE FROM app_jobs.scheduled_jobs WHERE id = $1`, [sched.id]);
    const gone = await pg.one(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [sched.id]);
    expect(gone.id).toBeNull();
  });

  it('returns a null record when the trigger suppressed the row and enqueued nothing (declined tick)', async () => {
    const sched = await schedule('suppressed:declined');
    // mirrors fn_invocations_cron_fire on a skipped invocation: it suspends the
    // schedule and RETURN NULLs without enqueueing or touching last_scheduled_id
    const first = await pg.one(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [sched.id]);
    expect(first.id).not.toBeNull();
    await pg.any(`DELETE FROM app_jobs.jobs WHERE id = $1`, [first.id]);
    await pg.any(`
      CREATE OR REPLACE FUNCTION app_jobs.tg_test_cron_fire() RETURNS trigger AS $$
      BEGIN
        IF NEW.key = 'suppressed:declined' THEN RETURN NULL; END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    `);
    // the stale recorded id must not be handed back as this tick's job
    const declined = await pg.one(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [sched.id]);
    expect(declined.id).toBeNull();
    const after = await pg.one(`SELECT last_scheduled_id FROM app_jobs.scheduled_jobs WHERE id = $1`, [sched.id]);
    expect(String(after.last_scheduled_id)).toBe(String(first.id));
  });

  it('raises when the trigger recorded a job id that does not exist', async () => {
    const sched = await schedule('suppressed:dangling');
    await pg.any(`
      CREATE OR REPLACE FUNCTION app_jobs.tg_test_cron_fire() RETURNS trigger AS $$
      BEGIN
        IF NEW.key = 'suppressed:dangling' THEN
          UPDATE app_jobs.scheduled_jobs s SET last_scheduled_id = 2147483647 WHERE s.key = NEW.key;
          RETURN NULL;
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    `);
    await expect(
      pg.one(`SELECT * FROM app_jobs.run_scheduled_job($1)`, [sched.id])
    ).rejects.toThrow(/SCHEDULED_JOB_NOT_ENQUEUED/);
  });
});
