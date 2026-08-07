-- Verify schemas/app_jobs/procedures/complete_jobs  on pg

BEGIN;

SELECT assert_function('app_jobs.complete_jobs(int8[])'::regprocedure);

ROLLBACK;
