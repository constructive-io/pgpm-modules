-- Verify schemas/app_jobs/tables/jobs/indexes/jobs_locked_by_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.jobs_locked_by_idx'::regclass, 'app_jobs.jobs'::regclass);

ROLLBACK;
