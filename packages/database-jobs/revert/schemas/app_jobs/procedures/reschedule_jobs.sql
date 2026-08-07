-- Revert schemas/app_jobs/procedures/reschedule_jobs from pg

BEGIN;

DROP FUNCTION app_jobs.reschedule_jobs(int8[], timestamptz, int4, int4, int4);

COMMIT;
