-- Verify schemas/app_jobs/procedures/grants/grant_execute_add_job_to_authenticated on pg

BEGIN;

SELECT assert_function_grant('app_jobs.add_job(text, json, text, text, timestamptz, integer, integer)'::regprocedure, 'authenticated', 'EXECUTE');

ROLLBACK;
