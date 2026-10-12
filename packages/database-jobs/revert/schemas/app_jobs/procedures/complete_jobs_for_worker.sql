-- Revert schemas/app_jobs/procedures/complete_jobs_for_worker from pg

BEGIN;

DROP FUNCTION app_jobs.complete_jobs_for_worker(text, bigint[]);

COMMIT;
