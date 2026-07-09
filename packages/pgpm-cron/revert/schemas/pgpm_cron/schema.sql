-- Revert schemas/pgpm_cron/schema from pg

BEGIN;

DROP SCHEMA pgpm_cron;

COMMIT;
