-- Deploy schemas/metaschema_modules_public/tables/storage_log_module/alterations/add_read_usage_period_function to pg

-- requires: schemas/metaschema_modules_public/tables/storage_log_module/table

BEGIN;

-- Output: the generated typed period reader of the storage usage summary
-- (<private>.read_storage_usage_period), which the billing bridge calls by
-- name instead of assembling SQL.
ALTER TABLE metaschema_modules_public.storage_log_module
  ADD COLUMN IF NOT EXISTS read_storage_usage_period_function text NOT NULL DEFAULT '';

COMMIT;
