-- Revert schemas/app_jobs/procedures/defer_scheduled_job from pg

BEGIN;

DROP FUNCTION app_jobs.defer_scheduled_job(app_jobs.scheduled_jobs, text, interval);

COMMIT;
