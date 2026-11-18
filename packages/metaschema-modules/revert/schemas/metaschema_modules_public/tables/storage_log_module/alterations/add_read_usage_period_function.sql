-- Revert schemas/metaschema_modules_public/tables/storage_log_module/alterations/add_read_usage_period_function from pg

BEGIN;

ALTER TABLE metaschema_modules_public.storage_log_module
  DROP COLUMN IF EXISTS read_storage_usage_period_function;

COMMIT;
