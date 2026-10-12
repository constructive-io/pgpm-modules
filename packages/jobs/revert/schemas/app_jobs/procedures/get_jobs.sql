-- Revert schemas/app_jobs/procedures/get_jobs from pg

BEGIN;

DROP FUNCTION app_jobs.get_jobs(text, text[], integer, interval);

COMMIT;
