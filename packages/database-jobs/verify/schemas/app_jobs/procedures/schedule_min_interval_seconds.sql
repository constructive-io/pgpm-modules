-- Verify schemas/app_jobs/procedures/schedule_min_interval_seconds  on pg

BEGIN;

SELECT assert_function('app_jobs.schedule_min_interval_seconds(json)'::regprocedure);

ROLLBACK;
