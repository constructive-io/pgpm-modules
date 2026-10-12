-- Verify schemas/metaschema_modules_public/tables/billing_provider_module/alterations/add_usage_sync_shard_count on pg

BEGIN;

SELECT usage_sync_shard_count FROM metaschema_modules_public.billing_provider_module WHERE FALSE;

ROLLBACK;
