-- Revert schemas/app_jobs/procedures/record_scheduled_job_failure from pg

BEGIN;

DROP FUNCTION app_jobs.record_scheduled_job_failure(app_jobs.scheduled_jobs, text, text);

COMMIT;
