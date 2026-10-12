-- Verify schemas/app_jobs/tables/scheduled_jobs/triggers/hold_next_run  on pg

BEGIN;

SELECT assert_function('app_jobs.tg_hold_next_run()'::regprocedure, 'trigger'::regtype);

-- BEFORE (2) INSERT (4) OR UPDATE (16) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.scheduled_jobs'::regclass,
    '_110_hold_next_run',
    'app_jobs.tg_hold_next_run'::regproc,
    23
);

ROLLBACK;
