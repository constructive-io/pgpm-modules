-- Verify schemas/app_jobs/tables/scheduled_task_holds/grants/grant_select_insert_update_delete_to_administrator on pg

BEGIN;

SELECT assert_table_grant('app_jobs.scheduled_task_holds'::regclass, 'administrator', 'SELECT');
SELECT assert_table_grant('app_jobs.scheduled_task_holds'::regclass, 'administrator', 'INSERT');
SELECT assert_table_grant('app_jobs.scheduled_task_holds'::regclass, 'administrator', 'UPDATE');
SELECT assert_table_grant('app_jobs.scheduled_task_holds'::regclass, 'administrator', 'DELETE');

ROLLBACK;
