-- Verify schemas/app_jobs/procedures/cron_field_values  on pg

BEGIN;

SELECT assert_function('app_jobs.cron_field_values(text, int, int, text[])'::regprocedure);
SELECT assert_function('app_jobs.cron_field_token(text, int, text[])'::regprocedure);

ROLLBACK;
