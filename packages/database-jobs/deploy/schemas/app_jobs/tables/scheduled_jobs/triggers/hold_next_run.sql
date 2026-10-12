-- Deploy schemas/app_jobs/tables/scheduled_jobs/triggers/hold_next_run to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/tables/scheduled_task_holds/table
-- requires: schemas/app_jobs/tables/scheduled_jobs/triggers/stamp_next_run

BEGIN;
-- Runs after _100_stamp_next_run: a schedule registered (or re-ruled) while
-- its task is held starts dormant instead of firing until the next hold sweep.
CREATE FUNCTION app_jobs.tg_hold_next_run ()
  RETURNS TRIGGER
  AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM app_jobs.scheduled_task_holds AS h
    WHERE h.task_identifier = NEW.task_identifier
  ) THEN
    NEW.next_run_at := NULL;
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

CREATE TRIGGER _110_hold_next_run
  BEFORE INSERT OR UPDATE OF schedule_info ON app_jobs.scheduled_jobs
  FOR EACH ROW
  EXECUTE PROCEDURE app_jobs.tg_hold_next_run ();
COMMIT;
