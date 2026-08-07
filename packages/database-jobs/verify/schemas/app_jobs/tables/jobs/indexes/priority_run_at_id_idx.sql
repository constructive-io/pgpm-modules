-- Verify schemas/app_jobs/tables/jobs/indexes/priority_run_at_id_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.jobs_main_index'::regclass, 'app_jobs.jobs'::regclass);
SELECT assert_index('app_jobs.jobs_no_queue_index'::regclass, 'app_jobs.jobs'::regclass);

ROLLBACK;
