-- Revert schemas/app_jobs/procedures/cron_field_values from pg

BEGIN;

DROP FUNCTION app_jobs.cron_field_values(text, int, int, text[]);
DROP FUNCTION app_jobs.cron_field_token(text, int, text[]);

COMMIT;
