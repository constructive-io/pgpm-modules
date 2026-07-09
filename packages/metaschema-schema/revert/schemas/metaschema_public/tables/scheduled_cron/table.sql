-- Revert schemas/metaschema_public/tables/scheduled_cron/table from pg

BEGIN;

DROP TABLE metaschema_public.scheduled_cron;

COMMIT;
