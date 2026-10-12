-- Verify schemas/app_jobs/procedures/release_scheduled_task  on pg

BEGIN;

SELECT assert_function('app_jobs.release_scheduled_task(text)'::regprocedure);

ROLLBACK;
