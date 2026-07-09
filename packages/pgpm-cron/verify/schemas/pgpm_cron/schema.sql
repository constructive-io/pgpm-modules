-- Verify schemas/pgpm_cron/schema on pg

BEGIN;

SELECT 1/count(*) FROM pg_catalog.pg_namespace WHERE nspname = 'pgpm_cron';

ROLLBACK;
