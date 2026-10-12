-- Verify schemas/app_jobs/procedures/hold_scheduled_task  on pg

BEGIN;

SELECT assert_function('app_jobs.hold_scheduled_task(text, text)'::regprocedure);

ROLLBACK;
