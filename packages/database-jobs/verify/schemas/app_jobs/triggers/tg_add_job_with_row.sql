-- Verify schemas/app_jobs/triggers/tg_add_job_with_row  on pg

BEGIN;

SELECT assert_function('app_jobs.tg_add_job_with_row()'::regprocedure);

ROLLBACK;
