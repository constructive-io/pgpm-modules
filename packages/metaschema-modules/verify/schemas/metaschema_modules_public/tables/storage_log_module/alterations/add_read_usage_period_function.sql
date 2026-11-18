-- Verify schemas/metaschema_modules_public/tables/storage_log_module/alterations/add_read_usage_period_function on pg

BEGIN;

SELECT read_storage_usage_period_function FROM metaschema_modules_public.storage_log_module WHERE FALSE;

ROLLBACK;
