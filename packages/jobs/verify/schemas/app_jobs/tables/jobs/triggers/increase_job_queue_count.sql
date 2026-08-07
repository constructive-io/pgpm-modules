-- Verify schemas/app_jobs/tables/jobs/triggers/increase_job_queue_count  on pg

BEGIN;

SELECT assert_function('app_jobs.tg_increase_job_queue_count()'::regprocedure, 'trigger'::regtype);

-- AFTER (0) INSERT (4) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    '_500_increase_job_queue_count_on_insert',
    'app_jobs.tg_increase_job_queue_count'::regproc,
    5
);

-- AFTER (0) UPDATE (16) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    '_500_increase_job_queue_count_on_update',
    'app_jobs.tg_increase_job_queue_count'::regproc,
    17
);

ROLLBACK;
