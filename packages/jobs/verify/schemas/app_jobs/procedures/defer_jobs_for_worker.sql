-- Verify schemas/app_jobs/procedures/defer_jobs_for_worker  on pg

BEGIN;

SELECT assert_function('app_jobs.defer_jobs_for_worker(text, bigint[], text[])'::regprocedure);

ROLLBACK;
