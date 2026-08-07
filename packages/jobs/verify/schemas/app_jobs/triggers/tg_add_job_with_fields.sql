-- Verify schemas/app_jobs/triggers/tg_add_job_with_fields  on pg

BEGIN;

SELECT assert_function('app_jobs.trigger_job_with_fields()'::regprocedure);

ROLLBACK;
