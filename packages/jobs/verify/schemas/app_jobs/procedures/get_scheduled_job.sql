-- Verify schemas/app_jobs/procedures/get_scheduled_job  on pg

BEGIN;

SELECT assert_function('app_jobs.get_scheduled_job(text, text[])'::regprocedure);

ROLLBACK;
