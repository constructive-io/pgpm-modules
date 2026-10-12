-- Deploy schemas/app_jobs/procedures/defer_scheduled_job to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/procedures/schedule_next_run
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Defers a claimed schedule that cannot run yet (its task has no function
-- definition registered, say) instead of firing it. No job is spawned, so no
-- job attempt is spent. The reason is raised as a WARNING and recorded in
-- last_error as 'DEFERRED: <reason>', and the schedule comes due again after
-- defer_for, or at its next occurrence if that is sooner, so the owed run
-- happens late rather than failing. The next successful fire clears
-- last_error.
CREATE FUNCTION app_jobs.defer_scheduled_job (sched app_jobs.scheduled_jobs, reason text, defer_for interval DEFAULT '1 minute')
  RETURNS void
  AS $$
BEGIN
  IF reason IS NULL OR reason = '' THEN
    PERFORM errors.raise_error('SCHEDULE_DEFER_REASON_REQUIRED', jsonb_build_object('scheduled_job_id', sched.id), 'public');
  END IF;
  IF defer_for IS NULL OR defer_for <= interval '0' THEN
    PERFORM errors.raise_error('SCHEDULE_DEFER_INTERVAL_INVALID', jsonb_build_object('defer_for', defer_for), 'public');
  END IF;

  RAISE WARNING 'fire_due_scheduled_jobs: schedule % (%) deferred for %: %', sched.id, sched.task_identifier, defer_for, reason;
  UPDATE
    app_jobs.scheduled_jobs
  SET
    last_error = concat('DEFERRED: ', reason),
    last_error_at = now(),
    next_run_at = LEAST(app_jobs.schedule_next_run(schedule_info, now()), now() + defer_for)
  WHERE
    id = sched.id;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
