-- Revert schemas/metaschema_modules_public/tables/events_module/alterations/add_record_error from pg

BEGIN;

ALTER TABLE metaschema_modules_public.events_module
  DROP COLUMN record_error;

COMMIT;
