-- Verify schemas/app_jobs/procedures/complete_jobs_for_worker  on pg

BEGIN;

SELECT assert_function('app_jobs.complete_jobs_for_worker(text, bigint[])'::regprocedure);

ROLLBACK;
