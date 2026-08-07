-- Verify schemas/app_jobs/tables/scheduled_jobs/grants/grant_select_insert_update_delete_to_administrator on pg

BEGIN;

  SELECT assert_table_grant('app_jobs.scheduled_jobs'::regclass, 'administrator', 'SELECT');
  SELECT assert_table_grant('app_jobs.scheduled_jobs'::regclass, 'administrator', 'INSERT');
  SELECT assert_table_grant('app_jobs.scheduled_jobs'::regclass, 'administrator', 'UPDATE');
  SELECT assert_table_grant('app_jobs.scheduled_jobs'::regclass, 'administrator', 'DELETE');
  
ROLLBACK;
