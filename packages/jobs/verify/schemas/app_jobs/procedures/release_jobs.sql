-- Verify schemas/app_jobs/procedures/release_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.release_jobs(text)'::regprocedure);

ROLLBACK;
