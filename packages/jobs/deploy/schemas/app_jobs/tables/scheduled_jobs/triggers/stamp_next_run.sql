-- Deploy schemas/app_jobs/tables/scheduled_jobs/triggers/stamp_next_run to pg
-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/tables/scheduled_jobs/table
-- requires: schemas/app_jobs/procedures/schedule_next_run

BEGIN;
-- Every schedule row carries the instant it fires next; an unparseable
-- schedule_info is rejected here, at registration, so the tick never meets
-- one.
CREATE FUNCTION app_jobs.tg_stamp_next_run ()
  RETURNS TRIGGER
  AS $$
BEGIN
  NEW.next_run_at := app_jobs.schedule_next_run(NEW.schedule_info, now());
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;

CREATE TRIGGER _100_stamp_next_run
  BEFORE INSERT OR UPDATE OF schedule_info ON app_jobs.scheduled_jobs
  FOR EACH ROW
  EXECUTE PROCEDURE app_jobs.tg_stamp_next_run ();
COMMIT;
