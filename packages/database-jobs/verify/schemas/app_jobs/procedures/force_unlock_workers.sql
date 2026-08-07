-- Verify schemas/app_jobs/procedures/force_unlock_workers  on pg

BEGIN;

SELECT assert_function('app_jobs.force_unlock_workers(text[])'::regprocedure);

ROLLBACK;
