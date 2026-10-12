-- Deploy schemas/app_jobs/procedures/fire_scheduled_job to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/procedures/run_scheduled_job
-- requires: schemas/app_jobs/procedures/schedule_next_run
-- requires: schemas/app_jobs/procedures/record_scheduled_job_failure

BEGIN;

-- Fires one schedule the caller claimed through claim_due_scheduled_jobs:
-- spawns its job through run_scheduled_job in a sub-transaction and advances
-- it to its next occurrence. Returns the outcome:
--   'fired'   the job was spawned; a stale last_error is cleared
--   'skipped' ALREADY_SCHEDULED: the previous spawn is still pending/running,
--             which is not an error
--   'failed'  the spawn raised (its fire trigger, say); the error is recorded
--             by record_scheduled_job_failure, which also advances the row
CREATE FUNCTION app_jobs.fire_scheduled_job (sched app_jobs.scheduled_jobs)
  RETURNS text
  AS $$
DECLARE
  spawned app_jobs.jobs;
  outcome text;
  error_message text;
  error_detail text;
BEGIN
  BEGIN
    spawned := app_jobs.run_scheduled_job(sched.id);
    outcome := 'fired';
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
        outcome := 'skipped';
      ELSE
        PERFORM app_jobs.record_scheduled_job_failure(sched, error_message, error_detail);
        RETURN 'failed';
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
  RETURN outcome;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
