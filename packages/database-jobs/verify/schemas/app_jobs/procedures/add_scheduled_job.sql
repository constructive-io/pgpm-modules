-- Verify schemas/app_jobs/procedures/add_scheduled_job  on pg

BEGIN;

SELECT assert_function('app_jobs.add_scheduled_job(text, json, json, text, text, int4, int4, uuid, uuid, text, uuid, uuid, uuid)'::regprocedure);

ROLLBACK;
