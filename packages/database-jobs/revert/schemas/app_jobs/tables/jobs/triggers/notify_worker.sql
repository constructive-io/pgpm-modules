-- Revert schemas/app_jobs/tables/jobs/triggers/notify_worker from pg

BEGIN;

DROP TRIGGER _900_after_insert ON app_jobs.jobs;
DROP FUNCTION app_jobs.tg_jobs__after_insert();

COMMIT;
