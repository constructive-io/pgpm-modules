-- Revert schemas/app_jobs/procedures/fail_job from pg

BEGIN;

DROP FUNCTION app_jobs.fail_job(text, int8, text);

COMMIT;
