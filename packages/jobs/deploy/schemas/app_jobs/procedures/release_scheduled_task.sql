-- Deploy schemas/app_jobs/procedures/release_scheduled_task to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/tables/scheduled_task_holds/table
-- requires: schemas/app_jobs/procedures/schedule_next_run
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Lifts a hold placed by hold_scheduled_task: each dormant row of the task is
-- re-stamped with its next occurrence from now, so it fires at its first
-- scheduled instant after the release. A task that was not held is left
-- untouched (and no rows are scanned). Returns the number of rows woken.
CREATE FUNCTION app_jobs.release_scheduled_task (task_identifier text)
  RETURNS integer
  AS $$
DECLARE
  woken integer;
BEGIN
  IF release_scheduled_task.task_identifier IS NULL THEN
    PERFORM errors.raise_error('SCHEDULED_TASK_IDENTIFIER_REQUIRED', '{}'::jsonb, 'public');
  END IF;

  DELETE FROM app_jobs.scheduled_task_holds AS h
  WHERE h.task_identifier = release_scheduled_task.task_identifier;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  WITH restamped AS (
    UPDATE
      app_jobs.scheduled_jobs AS s
    SET
      next_run_at = app_jobs.schedule_next_run(s.schedule_info, now())
    WHERE
      s.task_identifier = release_scheduled_task.task_identifier
      AND s.next_run_at IS NULL
    RETURNING
      s.next_run_at
  )
  SELECT
    count(*) INTO woken
  FROM
    restamped AS r
  WHERE
    r.next_run_at IS NOT NULL;

  RETURN woken;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
