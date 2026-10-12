-- Revert schemas/app_jobs/procedures/claim_due_scheduled_jobs from pg

BEGIN;

DROP FUNCTION app_jobs.claim_due_scheduled_jobs(integer);

COMMIT;
