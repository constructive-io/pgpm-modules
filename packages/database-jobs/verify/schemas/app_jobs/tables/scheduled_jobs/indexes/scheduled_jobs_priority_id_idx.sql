-- Verify schemas/app_jobs/tables/scheduled_jobs/indexes/scheduled_jobs_priority_id_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.scheduled_jobs_priority_id_idx'::regclass, 'app_jobs.scheduled_jobs'::regclass);

ROLLBACK;
