-- Verify schemas/pgpm_cron/procedures/sync_scheduled_cron on pg

BEGIN;

SELECT has_function_privilege('pgpm_cron.sync_scheduled_cron()', 'execute');

ROLLBACK;
