-- Verify schemas/app_jobs/procedures/complete_job  on pg

BEGIN;

SELECT assert_function('app_jobs.complete_job(text, int8)'::regprocedure);

ROLLBACK;
