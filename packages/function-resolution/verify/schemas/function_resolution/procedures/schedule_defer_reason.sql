-- Verify schemas/function_resolution/procedures/schedule_defer_reason  on pg

BEGIN;

SELECT assert_function('function_resolution.schedule_defer_reason(app_jobs.scheduled_jobs)'::regprocedure);

ROLLBACK;
