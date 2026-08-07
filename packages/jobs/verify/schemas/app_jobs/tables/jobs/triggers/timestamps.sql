-- Verify schemas/app_jobs/tables/jobs/triggers/timestamps  on pg

BEGIN;

SELECT
    created_at
FROM
    app_jobs.jobs
LIMIT 1;

SELECT
    updated_at
FROM
    app_jobs.jobs
LIMIT 1;

-- BEFORE (2) INSERT (4) OR UPDATE (16) FOR EACH ROW (1).
SELECT assert_trigger(
    'app_jobs.jobs'::regclass,
    '_100_update_jobs_modtime_tg',
    'app_jobs.tg_update_timestamps'::regproc,
    23
);

ROLLBACK;
