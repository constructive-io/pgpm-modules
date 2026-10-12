-- Revert schemas/app_jobs/tables/scheduled_jobs/triggers/hold_next_run from pg

BEGIN;

DROP TRIGGER _110_hold_next_run ON app_jobs.scheduled_jobs;
DROP FUNCTION app_jobs.tg_hold_next_run();

COMMIT;
