-- Revert schemas/app_jobs/procedures/release_scheduled_task from pg

BEGIN;

DROP FUNCTION app_jobs.release_scheduled_task(text);

COMMIT;
