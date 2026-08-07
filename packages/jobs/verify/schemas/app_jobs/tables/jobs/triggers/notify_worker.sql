-- Verify schemas/app_jobs/tables/jobs/triggers/notify_worker  on pg

BEGIN;

-- AFTER (0) INSERT (4) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    '_900_notify_worker',
    'app_jobs.do_notify'::regproc,
    5
);

ROLLBACK;
