-- Verify schemas/app_jobs/procedures/fire_scheduled_job  on pg

BEGIN;

SELECT assert_function('app_jobs.fire_scheduled_job(app_jobs.scheduled_jobs)'::regprocedure);

ROLLBACK;
