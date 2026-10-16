-- Revert schemas/app_jobs/procedures/scheduled_task_identifiers from pg

BEGIN;

DROP FUNCTION app_jobs.scheduled_task_identifiers(uuid);

COMMIT;
