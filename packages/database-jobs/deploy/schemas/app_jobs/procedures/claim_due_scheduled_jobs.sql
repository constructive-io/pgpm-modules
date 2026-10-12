-- Deploy schemas/app_jobs/procedures/claim_due_scheduled_jobs to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Locks and returns up to batch_size schedules whose next_run_at has passed,
-- oldest first. FOR UPDATE SKIP LOCKED partitions the due rows between
-- concurrent callers, and the row locks are held until the caller's
-- transaction ends, so a caller that fires or defers each returned row in the
-- same transaction owns it exclusively. Every schedule-clock entry point
-- (app_jobs.fire_due_scheduled_jobs and the ones layered above it) selects
-- through here.
CREATE FUNCTION app_jobs.claim_due_scheduled_jobs (batch_size integer DEFAULT 200)
  RETURNS SETOF app_jobs.scheduled_jobs
  AS $$
BEGIN
  IF batch_size IS NULL OR batch_size <= 0 THEN
    PERFORM errors.raise_error('SCHEDULE_BATCH_SIZE_INVALID', jsonb_build_object('batch_size', batch_size), 'public');
  END IF;

  RETURN QUERY
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
    SKIP LOCKED;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
