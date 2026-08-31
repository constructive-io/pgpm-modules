-- Revert schemas/app_jobs/procedures/add_job from pg

BEGIN;

DROP FUNCTION app_jobs.add_job(text, json, text, text, timestamptz, int4, int4, uuid, uuid, text, uuid, text, uuid, uuid, uuid);

COMMIT;
