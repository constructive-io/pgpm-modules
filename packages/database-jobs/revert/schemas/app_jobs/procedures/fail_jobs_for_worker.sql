-- Revert schemas/app_jobs/procedures/fail_jobs_for_worker from pg

BEGIN;

DROP FUNCTION app_jobs.fail_jobs_for_worker(text, bigint[], text[]);

COMMIT;
