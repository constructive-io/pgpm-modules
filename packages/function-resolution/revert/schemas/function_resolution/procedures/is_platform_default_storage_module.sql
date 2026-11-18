-- Revert schemas/function_resolution/procedures/is_platform_default_storage_module from pg

BEGIN;

DROP FUNCTION function_resolution.is_platform_default_storage_module(uuid);

COMMIT;
