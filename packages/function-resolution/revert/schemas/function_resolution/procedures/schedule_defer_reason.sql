-- Revert schemas/function_resolution/procedures/schedule_defer_reason from pg

BEGIN;

DROP FUNCTION function_resolution.schedule_defer_reason(app_jobs.scheduled_jobs);

COMMIT;
