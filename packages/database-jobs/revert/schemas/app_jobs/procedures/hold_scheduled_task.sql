-- Revert schemas/app_jobs/procedures/hold_scheduled_task from pg

BEGIN;

DROP FUNCTION app_jobs.hold_scheduled_task(text, text);

COMMIT;
