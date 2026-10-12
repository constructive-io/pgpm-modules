-- Verify schemas/app_jobs/procedures/get_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.get_jobs(text, text[], integer, interval)'::regprocedure);

ROLLBACK;
