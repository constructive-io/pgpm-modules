-- Verify schemas/app_jobs/helpers/json_build_object_apply  on pg

BEGIN;

SELECT assert_function('app_jobs.json_build_object_apply(text[])'::regprocedure);

ROLLBACK;
