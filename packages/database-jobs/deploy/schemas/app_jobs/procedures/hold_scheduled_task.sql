-- Deploy schemas/app_jobs/procedures/hold_scheduled_task to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/tables/scheduled_task_holds/table
-- requires: schemas/app_jobs/tables/scheduled_jobs/triggers/hold_next_run
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Stops every schedule of task_identifier from firing: records the hold (so
-- schedules registered later start dormant) and clears next_run_at on the
-- existing rows, which takes them out of fire_due_scheduled_jobs' due probe.
-- A row the clock has already locked is updated once that batch commits, so
-- it fires at most the once it was already firing. Idempotent; returns the
-- number of rows made dormant by this call.
CREATE FUNCTION app_jobs.hold_scheduled_task (task_identifier text, reason text DEFAULT NULL)
  RETURNS integer
  AS $$
DECLARE
  dormant integer;
BEGIN
  IF hold_scheduled_task.task_identifier IS NULL THEN
    PERFORM errors.raise_error('SCHEDULED_TASK_IDENTIFIER_REQUIRED', '{}'::jsonb, 'public');
  END IF;

  INSERT INTO app_jobs.scheduled_task_holds AS h (task_identifier, reason)
  VALUES (hold_scheduled_task.task_identifier, hold_scheduled_task.reason)
  ON CONFLICT ON CONSTRAINT scheduled_task_holds_pkey
    DO UPDATE SET
      reason = EXCLUDED.reason;

  UPDATE
    app_jobs.scheduled_jobs AS s
  SET
    next_run_at = NULL
  WHERE
    s.task_identifier = hold_scheduled_task.task_identifier
    AND s.next_run_at IS NOT NULL;
  GET DIAGNOSTICS dormant = ROW_COUNT;

  RETURN dormant;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

COMMIT;
