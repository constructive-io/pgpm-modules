-- Verify schemas/app_jobs/tables/jobs/indexes/jobs_queue_head_idx  on pg

BEGIN;

SELECT assert_index('app_jobs.jobs_queue_head_idx'::regclass, 'app_jobs.jobs'::regclass);

-- Keyed on (queue_name, priority, run_at, id) over named jobs only.
SELECT 1 / (count(*) = 1)::int
  FROM pg_index AS i
 WHERE i.indexrelid = 'app_jobs.jobs_queue_head_idx'::regclass
   AND i.indnkeyatts = 4
   AND i.indkey::text = (
     SELECT string_agg(a.attnum::text, ' ' ORDER BY k.ord)
       FROM unnest(ARRAY['queue_name', 'priority', 'run_at', 'id']) WITH ORDINALITY AS k(attname, ord)
       JOIN pg_attribute AS a ON a.attrelid = 'app_jobs.jobs'::regclass AND a.attname = k.attname
   )
   AND pg_get_expr(i.indpred, i.indrelid) = '((attempts < max_attempts) AND (queue_name IS NOT NULL))';

ROLLBACK;
