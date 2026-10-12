-- Verify schemas/app_jobs/tables/job_queues/indexes/job_queues_locked_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.job_queues_locked_idx'::regclass, 'app_jobs.job_queues'::regclass);

-- Exactly one key column, queue_name, over the locked rows only.
SELECT 1 / (count(*) = 1)::int
  FROM pg_index AS i
 WHERE i.indexrelid = 'app_jobs.job_queues_locked_idx'::regclass
   AND i.indnkeyatts = 1
   AND i.indkey::text = (
     SELECT a.attnum::text
       FROM pg_attribute AS a
      WHERE a.attrelid = 'app_jobs.job_queues'::regclass
        AND a.attname = 'queue_name'
   )
   AND pg_get_expr(i.indpred, i.indrelid) = '(locked_at IS NOT NULL)';

ROLLBACK;
