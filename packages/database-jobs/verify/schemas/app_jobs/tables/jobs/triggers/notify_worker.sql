-- Verify schemas/app_jobs/tables/jobs/triggers/notify_worker  on pg

BEGIN;

SELECT assert_function('app_jobs.tg_jobs__after_insert()'::regprocedure, 'trigger'::regtype);

-- AFTER (0) INSERT (4) FOR EACH STATEMENT (0).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    '_900_after_insert',
    'app_jobs.tg_jobs__after_insert'::regproc,
    4
);

ROLLBACK;
