-- Verify schemas/app_jobs/tables/scheduled_jobs/indexes/scheduled_jobs_next_run_at_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.scheduled_jobs_next_run_at_idx'::regclass, 'app_jobs.scheduled_jobs'::regclass);

ROLLBACK;
