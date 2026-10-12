-- Revert schemas/app_jobs/tables/scheduled_jobs/triggers/stamp_next_run from pg

BEGIN;

DROP TRIGGER _100_stamp_next_run ON app_jobs.scheduled_jobs;
DROP FUNCTION app_jobs.tg_stamp_next_run();

COMMIT;
