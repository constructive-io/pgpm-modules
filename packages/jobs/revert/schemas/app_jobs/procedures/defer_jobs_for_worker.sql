-- Revert schemas/app_jobs/procedures/defer_jobs_for_worker from pg

BEGIN;

DROP FUNCTION app_jobs.defer_jobs_for_worker(text, bigint[], text[]);

COMMIT;
