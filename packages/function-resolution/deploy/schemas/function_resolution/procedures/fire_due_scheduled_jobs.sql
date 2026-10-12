-- Deploy schemas/function_resolution/procedures/fire_due_scheduled_jobs to pg

-- requires: schemas/function_resolution/schema
-- requires: schemas/function_resolution/procedures/schedule_defer_reason
-- requires: pgpm-database-jobs:schemas/app_jobs/procedures/claim_due_scheduled_jobs
-- requires: pgpm-database-jobs:schemas/app_jobs/procedures/fire_scheduled_job
-- requires: pgpm-database-jobs:schemas/app_jobs/procedures/defer_scheduled_job
-- requires: pgpm-database-jobs:schemas/app_jobs/procedures/record_scheduled_job_failure
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- The compute worker's schedule-clock entry point: app_jobs.fire_due_scheduled_jobs
-- plus a registration check. Each schedule claimed by
-- app_jobs.claim_due_scheduled_jobs is first asked
-- function_resolution.schedule_defer_reason; one whose job has no function
-- definition yet (the worker booted before registration finished) is deferred
-- through app_jobs.defer_scheduled_job, which spawns no job and so spends no
-- job attempt, instead of spawning a job the worker could only fail. Every
-- other schedule fires through app_jobs.fire_scheduled_job exactly as
-- app_jobs.fire_due_scheduled_jobs fires it.
--
-- The check runs in its own sub-transaction: a check that raises is recorded
-- on its schedule by app_jobs.record_scheduled_job_failure (WARNING,
-- last_error, advanced to the next occurrence) and counted as failed, like a
-- failed spawn, so it neither blocks the other schedules nor goes unreported.
--
-- Returns app_jobs.fire_due_scheduled_jobs' tally plus "deferred":
-- {"fired": n, "skipped": n, "failed": n, "deferred": n, "processed": n}.
CREATE FUNCTION function_resolution.fire_due_scheduled_jobs (batch_size integer DEFAULT 200, defer_for interval DEFAULT '1 minute')
  RETURNS jsonb
  AS $$
DECLARE
  sched app_jobs.scheduled_jobs;
  outcome text;
  defer_reason text;
  check_failed boolean;
  fired int := 0;
  skipped int := 0;
  failed int := 0;
  deferred int := 0;
  error_message text;
  error_detail text;
BEGIN
  IF defer_for IS NULL OR defer_for <= interval '0' THEN
    PERFORM errors.raise_error('SCHEDULE_DEFER_INTERVAL_INVALID', jsonb_build_object('defer_for', defer_for), 'public');
  END IF;

  FOR sched IN
  SELECT
    *
  FROM
    app_jobs.claim_due_scheduled_jobs(batch_size)
    LOOP
      defer_reason := NULL;
      check_failed := false;
      BEGIN
        defer_reason := function_resolution.schedule_defer_reason(sched);
      EXCEPTION
        WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT,
          error_detail = PG_EXCEPTION_DETAIL;
          check_failed := true;
      END;

      IF check_failed THEN
        PERFORM app_jobs.record_scheduled_job_failure(sched, error_message, error_detail);
        failed := failed + 1;
      ELSIF defer_reason IS NOT NULL THEN
        PERFORM app_jobs.defer_scheduled_job(sched, defer_reason, defer_for);
        deferred := deferred + 1;
      ELSE
        outcome := app_jobs.fire_scheduled_job(sched);
        IF outcome = 'fired' THEN
          fired := fired + 1;
        ELSIF outcome = 'skipped' THEN
          skipped := skipped + 1;
        ELSE
          failed := failed + 1;
        END IF;
      END IF;
    END LOOP;

  RETURN jsonb_build_object('fired', fired, 'skipped', skipped, 'failed', failed, 'deferred', deferred, 'processed', fired + skipped + failed + deferred);
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
