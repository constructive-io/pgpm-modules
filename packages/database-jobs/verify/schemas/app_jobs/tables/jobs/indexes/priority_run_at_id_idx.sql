-- Verify schemas/app_jobs/tables/jobs/indexes/priority_run_at_id_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.jobs_main_index'::regclass, 'app_jobs.jobs'::regclass);
SELECT assert_index('app_jobs.jobs_no_queue_index'::regclass, 'app_jobs.jobs'::regclass);

-- id must be a key column (indnkeyatts covers it), not merely INCLUDEd;
-- divides by zero unless both indexes key three columns.
SELECT 1 / (count(*) = 2)::int
  FROM pg_index AS i
 WHERE i.indexrelid IN ('app_jobs.jobs_main_index'::regclass, 'app_jobs.jobs_no_queue_index'::regclass)
   AND i.indnkeyatts = 3;

ROLLBACK;
