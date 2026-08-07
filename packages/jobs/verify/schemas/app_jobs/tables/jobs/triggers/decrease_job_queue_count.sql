-- Verify schemas/app_jobs/tables/jobs/triggers/decrease_job_queue_count  on pg

BEGIN;

SELECT assert_function('app_jobs.tg_decrease_job_queue_count()'::regprocedure, 'trigger'::regtype);

-- AFTER (0) DELETE (8) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    'decrease_job_queue_count_on_delete',
    'app_jobs.tg_decrease_job_queue_count'::regproc,
    9
);

-- AFTER (0) UPDATE (16) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    'decrease_job_queue_count_on_update',
    'app_jobs.tg_decrease_job_queue_count'::regproc,
    17
);

ROLLBACK;
