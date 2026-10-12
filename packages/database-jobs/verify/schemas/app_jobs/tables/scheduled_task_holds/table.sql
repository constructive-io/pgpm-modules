-- Verify schemas/app_jobs/tables/scheduled_task_holds/table on pg

BEGIN;

SELECT assert_table('app_jobs.scheduled_task_holds'::regclass);

ROLLBACK;
