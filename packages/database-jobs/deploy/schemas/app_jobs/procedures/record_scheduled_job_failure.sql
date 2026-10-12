-- Deploy schemas/app_jobs/procedures/record_scheduled_job_failure to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/procedures/schedule_next_run

BEGIN;

-- Records why a claimed schedule could not fire: raises a WARNING, stores the
-- error in last_error/last_error_at and advances the row to its next
-- occurrence, so one bad schedule neither blocks the others nor fires again
-- before then. The caller catches the error in its own sub-transaction and
-- counts the schedule as failed.
CREATE FUNCTION app_jobs.record_scheduled_job_failure (sched app_jobs.scheduled_jobs, error_message text, error_detail text DEFAULT NULL)
  RETURNS void
  AS $$
BEGIN
  RAISE WARNING 'fire_due_scheduled_jobs: schedule % (%) failed to spawn: % %', sched.id, sched.task_identifier, error_message, error_detail;
  UPDATE
    app_jobs.scheduled_jobs
  SET
    last_error = concat_ws(' ', error_message, nullif(error_detail, '')),
    last_error_at = now()
  WHERE
    id = sched.id;
  -- the fire trigger may have deleted a one-shot schedule; then there is
  -- nothing to advance
  UPDATE
    app_jobs.scheduled_jobs
  SET
    next_run_at = app_jobs.schedule_next_run(schedule_info, now())
  WHERE
    id = sched.id;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
