-- Revert schemas/app_jobs/procedures/schedule_next_run from pg

BEGIN;

DROP FUNCTION app_jobs.schedule_next_run(json, timestamptz);
DROP FUNCTION app_jobs.recurrence_field_values(json, int, int);

COMMIT;
