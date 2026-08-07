-- Verify schemas/app_jobs/tables/job_queues/grants/grant_select_insert_update_delete_to_administrator on pg

BEGIN;

  SELECT assert_table_grant('app_jobs.job_queues'::regclass, 'administrator', 'SELECT');
  SELECT assert_table_grant('app_jobs.job_queues'::regclass, 'administrator', 'INSERT');
  SELECT assert_table_grant('app_jobs.job_queues'::regclass, 'administrator', 'UPDATE');
  SELECT assert_table_grant('app_jobs.job_queues'::regclass, 'administrator', 'DELETE');
  
ROLLBACK;
