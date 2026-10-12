-- Verify schemas/app_jobs/procedures/defer_scheduled_job  on pg

BEGIN;

SELECT assert_function('app_jobs.defer_scheduled_job(app_jobs.scheduled_jobs, text, interval)'::regprocedure);

ROLLBACK;
