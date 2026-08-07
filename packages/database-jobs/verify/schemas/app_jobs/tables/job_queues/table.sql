-- Verify schemas/app_jobs/tables/job_queues/table on pg

BEGIN;

SELECT assert_table('app_jobs.job_queues'::regclass);

ROLLBACK;
