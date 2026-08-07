-- Verify schemas/app_jobs/procedures/remove_job  on pg

BEGIN;

SELECT assert_function('app_jobs.remove_job(text)'::regprocedure);

ROLLBACK;
