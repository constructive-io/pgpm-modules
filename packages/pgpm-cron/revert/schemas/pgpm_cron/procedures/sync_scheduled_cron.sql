-- Revert schemas/pgpm_cron/procedures/sync_scheduled_cron from pg

BEGIN;

DROP FUNCTION pgpm_cron.sync_scheduled_cron();

COMMIT;
