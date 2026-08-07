-- Verify schemas/app_jobs/procedures/get_job  on pg

BEGIN;

SELECT assert_function('app_jobs.get_job(text, text[], interval)'::regprocedure);

ROLLBACK;
