-- Verify schemas/app_jobs/procedures/add_job  on pg

BEGIN;

SELECT assert_function('app_jobs.add_job(text, json, text, text, timestamptz, int4, int4)'::regprocedure);

ROLLBACK;
