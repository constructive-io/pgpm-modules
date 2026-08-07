-- Verify schemas/app_jobs/procedures/fail_job  on pg

BEGIN;

SELECT assert_function('app_jobs.fail_job(text, int8, text)'::regprocedure);

ROLLBACK;
