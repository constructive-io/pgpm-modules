-- Deploy schemas/app_jobs/procedures/fire_due_scheduled_jobs to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/procedures/run_scheduled_job
-- requires: schemas/app_jobs/procedures/schedule_next_run
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- The schedule clock's one entry point. Spawns a queue job for up to
-- batch_size schedules whose next_run_at has passed and advances each one to
-- its next occurrence. The caller is a stateless metronome (the compute
-- worker's ScheduleClock, or any process that can run SQL): it calls this on
-- a fixed interval and calls again at once while processed = batch_size.
-- Any number of callers may run concurrently; FOR UPDATE SKIP LOCKED
-- partitions the due rows between them, so every due row fires once.
--
-- Each schedule fires in its own sub-transaction: a schedule whose spawn
-- fails (its fire trigger raising, say) records the error on its own row and
-- still advances, so it neither blocks the other schedules nor fires again
-- before its next occurrence. ALREADY_SCHEDULED from run_scheduled_job means
-- the previous spawn is still pending/running and is not an error.
--
-- Returns the batch's tally: {"fired": n, "skipped": n, "failed": n,
-- "processed": n}. processed = batch_size means more rows may be due;
-- processed < batch_size means the due set is drained.
CREATE FUNCTION app_jobs.fire_due_scheduled_jobs (batch_size integer DEFAULT 200)
  RETURNS jsonb
  AS $$
DECLARE
  sched app_jobs.scheduled_jobs;
  spawned app_jobs.jobs;
  fired int := 0;
  skipped int := 0;
  failed int := 0;
  error_message text;
  error_detail text;
BEGIN
  IF batch_size IS NULL OR batch_size <= 0 THEN
    PERFORM errors.raise_error('SCHEDULE_BATCH_SIZE_INVALID', jsonb_build_object('batch_size', batch_size), 'public');
  END IF;

  FOR sched IN
  SELECT
    s.*
  FROM
    app_jobs.scheduled_jobs AS s
  WHERE
    s.next_run_at <= now()
  ORDER BY
    s.next_run_at,
    s.id
  LIMIT batch_size
  FOR UPDATE
    SKIP LOCKED LOOP
      BEGIN
        spawned := app_jobs.run_scheduled_job(sched.id);
        fired := fired + 1;
        UPDATE
          app_jobs.scheduled_jobs
        SET
          last_error = NULL,
          last_error_at = NULL
        WHERE
          id = sched.id
          AND last_error IS NOT NULL;
      EXCEPTION
        WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT,
          error_detail = PG_EXCEPTION_DETAIL;
          IF error_message = 'ALREADY_SCHEDULED' THEN
            skipped := skipped + 1;
          ELSE
            failed := failed + 1;
            RAISE WARNING 'fire_due_scheduled_jobs: schedule % (%) failed to spawn: % %', sched.id, sched.task_identifier, error_message, error_detail;
            UPDATE
              app_jobs.scheduled_jobs
            SET
              last_error = concat_ws(' ', error_message, nullif(error_detail, '')),
              last_error_at = now()
            WHERE
              id = sched.id;
          END IF;
      END;
    -- the fire trigger may have deleted a one-shot schedule; then there is
    -- nothing to advance
    UPDATE
      app_jobs.scheduled_jobs
    SET
      next_run_at = app_jobs.schedule_next_run(schedule_info, now())
    WHERE
      id = sched.id;
  END LOOP;

  RETURN jsonb_build_object('fired', fired, 'skipped', skipped, 'failed', failed, 'processed', fired + skipped + failed);
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
