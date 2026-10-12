-- Revert schemas/function_resolution/procedures/fire_due_scheduled_jobs from pg

BEGIN;

DROP FUNCTION function_resolution.fire_due_scheduled_jobs(integer, interval);

COMMIT;
