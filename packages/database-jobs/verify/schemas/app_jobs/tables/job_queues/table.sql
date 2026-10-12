-- Verify schemas/app_jobs/tables/job_queues/table on pg

BEGIN;

SELECT assert_table('app_jobs.job_queues'::regclass);

SELECT 1 / (count(*) = 1)::int
  FROM pg_class AS c
 WHERE c.oid = 'app_jobs.job_queues'::regclass
   AND c.reloptions @> ARRAY[
     'fillfactor=50',
     'autovacuum_vacuum_scale_factor=0.01',
     'autovacuum_vacuum_cost_delay=0'
   ];

ROLLBACK;
