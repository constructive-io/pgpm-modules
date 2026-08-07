-- Verify schemas/app_jobs/tables/jobs/table on pg

BEGIN;

SELECT assert_table('app_jobs.jobs'::regclass);

ROLLBACK;
