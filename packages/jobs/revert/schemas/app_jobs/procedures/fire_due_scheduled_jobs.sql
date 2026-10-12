-- Revert schemas/app_jobs/procedures/fire_due_scheduled_jobs from pg

BEGIN;

DROP FUNCTION app_jobs.fire_due_scheduled_jobs(integer);

COMMIT;
