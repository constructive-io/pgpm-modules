-- Deploy schemas/app_jobs/procedures/fire_due_scheduled_jobs to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/procedures/claim_due_scheduled_jobs
-- requires: schemas/app_jobs/procedures/fire_scheduled_job

BEGIN;

-- The schedule clock's entry point. Spawns a queue job for up to
-- batch_size schedules whose next_run_at has passed and advances each one to
-- its next occurrence. The caller is a stateless metronome (the compute
-- worker's ScheduleClock, or any process that can run SQL): it calls this on
-- a fixed interval and calls again at once while processed = batch_size.
-- Any number of callers may run concurrently; claim_due_scheduled_jobs'
-- FOR UPDATE SKIP LOCKED partitions the due rows between them, so every due
-- row fires once.
--
-- Each schedule fires in its own sub-transaction (fire_scheduled_job): a
-- schedule whose spawn fails (its fire trigger raising, say) records the
-- error on its own row and still advances, so it neither blocks the other
-- schedules nor fires again before its next occurrence. ALREADY_SCHEDULED
-- from run_scheduled_job means the previous spawn is still pending/running
-- and is not an error.
--
-- Returns the batch's tally: {"fired": n, "skipped": n, "failed": n,
-- "processed": n}. processed = batch_size means more rows may be due;
-- processed < batch_size means the due set is drained.
CREATE FUNCTION app_jobs.fire_due_scheduled_jobs (batch_size integer DEFAULT 200)
  RETURNS jsonb
  AS $$
DECLARE
  sched app_jobs.scheduled_jobs;
  outcome text;
  fired int := 0;
  skipped int := 0;
  failed int := 0;
BEGIN
  FOR sched IN
  SELECT
    *
  FROM
    app_jobs.claim_due_scheduled_jobs(batch_size)
    LOOP
      outcome := app_jobs.fire_scheduled_job(sched);
      IF outcome = 'fired' THEN
        fired := fired + 1;
      ELSIF outcome = 'skipped' THEN
        skipped := skipped + 1;
      ELSE
        failed := failed + 1;
      END IF;
    END LOOP;

  RETURN jsonb_build_object('fired', fired, 'skipped', skipped, 'failed', failed, 'processed', fired + skipped + failed);
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
