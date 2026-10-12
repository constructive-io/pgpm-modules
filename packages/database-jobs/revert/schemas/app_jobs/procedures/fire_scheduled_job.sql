-- Revert schemas/app_jobs/procedures/fire_scheduled_job from pg

BEGIN;

DROP FUNCTION app_jobs.fire_scheduled_job(app_jobs.scheduled_jobs);

COMMIT;
