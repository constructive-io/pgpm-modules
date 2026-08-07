-- Verify schemas/app_jobs/schema  on pg

BEGIN;

SELECT assert_schema('app_jobs'::regnamespace);

ROLLBACK;
