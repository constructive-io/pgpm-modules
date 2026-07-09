-- Verify schemas/metaschema_public/tables/scheduled_cron/table on pg

BEGIN;

SELECT verify_table ('metaschema_public.scheduled_cron');

ROLLBACK;
