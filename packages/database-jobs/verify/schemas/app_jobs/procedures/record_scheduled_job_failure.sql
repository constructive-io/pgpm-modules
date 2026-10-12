-- Verify schemas/app_jobs/procedures/record_scheduled_job_failure  on pg

BEGIN;

SELECT assert_function('app_jobs.record_scheduled_job_failure(app_jobs.scheduled_jobs, text, text)'::regprocedure);

ROLLBACK;
