-- Verify schemas/app_jobs/tables/jobs/indexes/priority_run_at_id_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.priority_run_at_id_idx'::regclass, 'app_jobs.jobs'::regclass);

ROLLBACK;
