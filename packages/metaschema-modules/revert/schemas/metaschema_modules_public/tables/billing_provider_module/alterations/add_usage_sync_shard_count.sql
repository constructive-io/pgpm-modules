-- Revert schemas/metaschema_modules_public/tables/billing_provider_module/alterations/add_usage_sync_shard_count from pg

BEGIN;

ALTER TABLE metaschema_modules_public.billing_provider_module
  DROP COLUMN IF EXISTS usage_sync_shard_count;

COMMIT;
