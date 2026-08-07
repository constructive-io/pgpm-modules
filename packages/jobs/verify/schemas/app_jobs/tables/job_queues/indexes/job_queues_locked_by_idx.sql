-- Verify schemas/app_jobs/tables/job_queues/indexes/job_queues_locked_by_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.job_queues_locked_by_idx'::regclass, 'app_jobs.job_queues'::regclass);

ROLLBACK;
