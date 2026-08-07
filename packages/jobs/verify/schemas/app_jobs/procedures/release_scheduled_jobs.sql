-- Verify schemas/app_jobs/procedures/release_scheduled_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.release_scheduled_jobs(text, int8[])'::regprocedure);

ROLLBACK;
