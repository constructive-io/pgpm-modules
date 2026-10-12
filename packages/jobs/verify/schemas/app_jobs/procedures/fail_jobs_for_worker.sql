-- Verify schemas/app_jobs/procedures/fail_jobs_for_worker  on pg

BEGIN;

SELECT assert_function('app_jobs.fail_jobs_for_worker(text, bigint[], text[])'::regprocedure);

ROLLBACK;
