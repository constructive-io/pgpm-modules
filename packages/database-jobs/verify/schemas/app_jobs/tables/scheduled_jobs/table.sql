-- Verify schemas/app_jobs/tables/scheduled_jobs/table on pg

BEGIN;

SELECT assert_table('app_jobs.scheduled_jobs'::regclass);

ROLLBACK;
