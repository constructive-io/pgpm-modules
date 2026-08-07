-- Revert schemas/app_jobs/procedures/add_scheduled_job from pg

BEGIN;

DROP FUNCTION app_jobs.add_scheduled_job(text, json, json, text, text, int4, int4, uuid, uuid);

COMMIT;
